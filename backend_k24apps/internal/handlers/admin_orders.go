package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// GetRecipients lists all master recipients from alamat_penerima (autocomplete source).
func (h *AdminHandler) GetRecipients(c *gin.Context) {
	ctx := context.Background()
	rows, err := h.DB.Query(ctx,
		`SELECT id, nama_apotek, alamat_lengkap, latitude, longitude, COALESCE(zona, 0) FROM alamat_penerima ORDER BY nama_apotek ASC;`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memuat daftar master alamat penerima: " + err.Error()})
		return
	}
	defer rows.Close()

	recipients := []models.Recipient{}
	for rows.Next() {
		var rec models.Recipient
		if err := rows.Scan(&rec.ID, &rec.NamaApotek, &rec.AlamatLengkap, &rec.Latitude, &rec.Longitude, &rec.Zona); err == nil {
			recipients = append(recipients, rec)
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Master alamat penerima berhasil diambil", Data: recipients})
}

func isSurabayaRegion(originAddress, recipientAddress, namaApotek string) bool {
	combined := strings.ToLower(originAddress + " " + recipientAddress + " " + namaApotek)
	return strings.Contains(combined, "surabaya") || strings.Contains(combined, "sidoarjo")
}

// CreateOrder creates a single new delivery order.
func (h *AdminHandler) CreateOrder(c *gin.Context) {
	var req models.CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	orderNumber := fmt.Sprintf("ORD-%d", r.Intn(900000)+100000)

	// Ensure uniqueness
	for {
		var exists bool
		if err := h.DB.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM orders WHERE order_number = $1)", orderNumber).Scan(&exists); err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memeriksa keunikan nomor order"})
			return
		}
		if !exists {
			break
		}
		orderNumber = fmt.Sprintf("ORD-%d", r.Intn(900000)+100000)
	}

	var driverFee float64
	if isSurabayaRegion(req.PharmacyAddress, req.DeliveryAddress, req.CustomerName) {
		driverFee = req.DeliveryFee
	} else {
		driverFee = math.Round(req.DeliveryFee * 0.80)
	}

	insertQuery := `
	INSERT INTO orders (order_number, status, pharmacy_name, pharmacy_address, delivery_address, customer_name, customer_phone, medicine_summary, delivery_fee, driver_fee)
	VALUES ($1, 'PICKING_UP', $2, $3, $4, $5, $6, $7, $8, $9)
	RETURNING id, order_number, status, pharmacy_name, pharmacy_address, delivery_address, customer_name, customer_phone, medicine_summary, delivery_fee, driver_fee, created_at;`

	var order models.Order
	err := h.DB.QueryRow(ctx, insertQuery,
		orderNumber, req.PharmacyName, req.PharmacyAddress, req.DeliveryAddress,
		req.CustomerName, req.CustomerPhone, req.MedicineSummary, req.DeliveryFee, driverFee,
	).Scan(&order.ID, &order.OrderNumber, &order.Status, &order.PharmacyName,
		&order.PharmacyAddress, &order.DeliveryAddress, &order.CustomerName,
		&order.CustomerPhone, &order.MedicineSummary, &order.DeliveryFee, &order.DriverFee, &order.CreatedAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan order: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, models.APIResponse{Status: "success", Message: "Order berhasil dibuat", Data: order})
}

type resolvedBulkItem struct {
	item      models.BulkOrderItemInput
	latitude  float64
	longitude float64
	zona      int
}

func sortBulkItemsNearestNeighbor(originLat, originLng float64, items []resolvedBulkItem) []resolvedBulkItem {
	if len(items) <= 1 {
		return items
	}

	remaining := make([]resolvedBulkItem, len(items))
	copy(remaining, items)
	sorted := make([]resolvedBulkItem, 0, len(items))

	currLat, currLng := originLat, originLng

	for len(remaining) > 0 {
		bestIdx := 0
		bestDist := math.MaxFloat64

		for i, r := range remaining {
			dist := haversineDist(currLat, currLng, r.latitude, r.longitude)
			if dist < bestDist {
				bestDist = dist
				bestIdx = i
			}
		}

		chosen := remaining[bestIdx]
		sorted = append(sorted, chosen)

		currLat = chosen.latitude
		currLng = chosen.longitude

		remaining = append(remaining[:bestIdx], remaining[bestIdx+1:]...)
	}

	return sorted
}

func haversineDist(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}

// CalculateOrderPrice pre-calculates pricing for proposed delivery stops.
func (h *AdminHandler) CalculateOrderPrice(c *gin.Context) {
	var req models.CalculateOrderPriceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Status: "error", Message: "Sesi tidak valid"})
		return
	}
	userID := userIDVal.(int)
	if req.MitraID > 0 {
		userID = req.MitraID
	}
	ctx := context.Background()

	fullRates := loadMitraFullRates(h.DB, ctx, userID)
	originLat, originLong := fullRates.OriginLat, fullRates.OriginLong
	var originName, originAddress string
	_ = h.DB.QueryRow(ctx, "SELECT pickup_name, alamat_lengkap FROM mitra_profiles WHERE user_id = $1", userID).Scan(&originName, &originAddress)

	activeRate := resolveRate(req.Armada, req.RateType,
		&fullRates.MotorDimensi, &fullRates.MotorKm, &fullRates.MotorTitik, &fullRates.MotorBerat,
		&fullRates.MobilDimensi, &fullRates.MobilKm, &fullRates.MobilTitik, &fullRates.MobilBerat, &fullRates.MobilLumpsum)

	// Resolve lat/lng and zone for all items first
	resolved := []resolvedBulkItem{}
	for _, item := range req.Items {
		var destLat, destLng float64
		var zonaVal int
		rec, _ := findRecipient(h.DB, item.NamaApotek, item.AlamatLengkap)
		if rec != nil && rec.Latitude != 0 && rec.Longitude != 0 {
			destLat = rec.Latitude
			destLng = rec.Longitude
			zonaVal = rec.Zona
		} else {
			var geocodeErr error
			destLat, destLng, geocodeErr = geocodeAddress(item.AlamatLengkap, originLat, originLong)
			if geocodeErr != nil || destLat == 0 || destLng == 0 {
				destLat = originLat + (float64(len(resolved)+1) * 0.01)
				destLng = originLong + (float64(len(resolved)+1) * 0.01)
			}
		}
		resolved = append(resolved, resolvedBulkItem{
			item: models.BulkOrderItemInput{
				NamaApotek:    item.NamaApotek,
				AlamatLengkap: item.AlamatLengkap,
				KubikAktual:   item.KubikAktual,
				BeratAktual:   item.BeratAktual,
				Invoices:      item.Invoices,
			},
			latitude:  destLat,
			longitude: destLng,
			zona:      zonaVal,
		})
	}

	// Sort items by Zone Hierarchy (Zona 1 -> Zona 2 -> Zona 3 -> Non-Zona) and nearest neighbor
	sorted := sortBulkItemsNearestNeighbor(originLat, originLong, resolved)

	response := models.CalculateOrderResponse{
		Items:      []models.CalculatedItemResult{},
		TotalPrice: 0,
	}

	var prevLat = originLat
	var prevLng = originLong

	for i, r := range sorted {
		distKm, _ := calculateDistance(h.DB, prevLat, prevLng, r.latitude, r.longitude)
		// Update previous leg coordinates for next stop distance calculation
		prevLat = r.latitude
		prevLng = r.longitude

		var rowPrice float64
		var matchedZona int
		var rateLabel string

		rec, _ := findRecipient(h.DB, r.item.NamaApotek, r.item.AlamatLengkap)
		var driverFee float64
		if req.RateType == "zona" {
			if rec != nil && rec.Zona > 0 {
				matchedZona = rec.Zona
				switch rec.Zona {
				case 1:
					rowPrice = fullRates.MotorZona1
					driverFee = 10500.0
					rateLabel = "Zona 1"
				case 2:
					rowPrice = fullRates.MotorZona2
					driverFee = 17500.0
					rateLabel = "Zona 2"
				case 3:
					rowPrice = fullRates.MotorZona3
					driverFee = 24500.0
					rateLabel = "Zona 3"
				case 4:
					kmRate := fullRates.MotorKm
					if kmRate <= 1750 {
						kmRate = 2500.0
					}
					rowPrice = distKm * kmRate
					driverFee = 26000.0
					rateLabel = "Zona 4"
				case 5:
					kmRate := fullRates.MotorKm
					if kmRate <= 1750 {
						kmRate = 2500.0
					}
					rowPrice = distKm * kmRate
					driverFee = 30000.0
					rateLabel = "Zona 5"
				default:
					kmRate := fullRates.MotorKm
					if kmRate <= 1750 {
						kmRate = 2500.0
					}
					rowPrice = distKm * kmRate
					driverFee = distKm * 1750.0
					rateLabel = fmt.Sprintf("Zona %d", matchedZona)
				}
			} else {
				// Outside zone database: KM rate calculated from Previous Point
				kmRate := fullRates.MotorKm
				if kmRate <= 1750 {
					kmRate = 2500.0
				}
				rowPrice = distKm * kmRate
				driverFee = distKm * 1750.0
				rateLabel = fmt.Sprintf("Tarif KM (%.1f km)", distKm)
			}
		} else {
			rowPrice = calcRowPrice(req.RateType, activeRate, distKm, r.item.KubikAktual, r.item.BeratAktual, i)
			if req.RateType == "km" {
				driverFee = distKm * 1750.0
			} else {
				driverFee = rowPrice
			}
			rateLabel = fmt.Sprintf("Skema %s", req.RateType)
		}

		isSurabaya := isSurabayaRegion(originName+" "+originAddress, r.item.AlamatLengkap, r.item.NamaApotek)
		if !isSurabaya {
			// For regions outside Surabaya (Jabodetabek, etc.), driver earnings are cut 20% from admin rowPrice (driver receives 80%)
			driverFee = math.Round(rowPrice * 0.80)
		}

		response.Items = append(response.Items, models.CalculatedItemResult{
			NamaApotek:    r.item.NamaApotek,
			AlamatLengkap: r.item.AlamatLengkap,
			JarakKm:       math.Round(distKm*100) / 100,
			Price:         math.Round(rowPrice),
			DriverFee:     math.Round(driverFee),
			Zona:          matchedZona,
			RateLabel:     rateLabel,
		})
		response.TotalPrice += math.Round(rowPrice)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Kalkulasi argo berhasil dihitung", Data: response})
}

// CreateBulkOrders saves an array of delivery stops as a single dispatch batch.
func (h *AdminHandler) CreateBulkOrders(c *gin.Context) {
	var req models.CreateBulkOrdersRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Status: "error", Message: "Sesi tidak valid"})
		return
	}
	userID := userIDVal.(int)
	if req.MitraID > 0 {
		userID = req.MitraID
	}
	ctx := context.Background()

	// Load mitra pickup location
	var originName, originAddress string
	var originLat, originLong float64
	if err := h.DB.QueryRow(ctx,
		"SELECT pickup_name, alamat_lengkap, pickup_lat, pickup_long FROM mitra_profiles WHERE user_id = $1", userID,
	).Scan(&originName, &originAddress, &originLat, &originLong); err != nil || originLat == 0 || originLong == 0 {
		originName = "PT K-24 Indonesia Cabang Jakarta"
		originAddress = "Jl. Raya Pasar Minggu No. 28, Pasar Minggu, Jakarta Selatan"
		originLat = -6.2019957
		originLong = 106.8551888
	}

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memulai transaksi database"})
		return
	}
	defer tx.Rollback(ctx)

	// Auto-increment dispatch ID from any existing orders (regardless of ORD-, ORDER-, or DSP- prefix)
	var maxNum int
	_ = tx.QueryRow(ctx, `
		SELECT COALESCE(
			MAX(GREATEST(
				CAST(NULLIF(REGEXP_REPLACE(parent_order_number, '\D', '', 'g'), '') AS INTEGER),
				CAST(NULLIF(REGEXP_REPLACE(dispatch_id, '\D', '', 'g'), '') AS INTEGER)
			)), 
			0
		) FROM orders;
	`).Scan(&maxNum)
	nextNum := maxNum + 1
	orderBaseNumber := fmt.Sprintf("ORDER-%06d", nextNum)

	fullRates := loadMitraFullRates(h.DB, ctx, userID)
	activeRate := resolveRate(req.Armada, req.RateType,
		&fullRates.MotorDimensi, &fullRates.MotorKm, &fullRates.MotorTitik, &fullRates.MotorBerat,
		&fullRates.MobilDimensi, &fullRates.MobilKm, &fullRates.MobilTitik, &fullRates.MobilBerat, &fullRates.MobilLumpsum)

	// Resolve lat/lng and zone for all items first
	resolved := []resolvedBulkItem{}
	for _, item := range req.Items {
		var finalLat, finalLng float64
		var zonaVal int
		rec, _ := findRecipient(h.DB, item.NamaApotek, item.AlamatLengkap)
		if rec != nil && rec.Latitude != 0 && rec.Longitude != 0 {
			finalLat = rec.Latitude
			finalLng = rec.Longitude
			zonaVal = rec.Zona
		} else {
			finalLat = item.Latitude
			finalLng = item.Longitude
			if finalLat == 0 && finalLng == 0 {
				finalLat, finalLng, _ = geocodeAddress(item.AlamatLengkap, originLat, originLong)
			}
			if finalLat == 0 || finalLng == 0 {
				finalLat = originLat + (float64(len(resolved)+1) * 0.01)
				finalLng = originLong + (float64(len(resolved)+1) * 0.01)
			}
			insertRecipient := `INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING;`
			_, _ = h.DB.Exec(ctx, insertRecipient, item.NamaApotek, item.AlamatLengkap, finalLat, finalLng)
		}
		resolved = append(resolved, resolvedBulkItem{
			item:      item,
			latitude:  finalLat,
			longitude: finalLng,
			zona:      zonaVal,
		})
	}

	// Sort items by nearest neighbor route sequence
	sorted := sortBulkItemsNearestNeighbor(originLat, originLong, resolved)

	savedOrders := []models.Order{}

	var prevLat = originLat
	var prevLng = originLong

	for i, r := range sorted {
		distKm, _ := calculateDistance(h.DB, prevLat, prevLng, r.latitude, r.longitude)
		prevLat = r.latitude
		prevLng = r.longitude
		var rowPrice float64
		rec, _ := findRecipient(h.DB, r.item.NamaApotek, r.item.AlamatLengkap)
		var driverFee float64

		if req.RateType == "zona" {
			if rec != nil && rec.Zona > 0 {
				switch rec.Zona {
				case 1:
					rowPrice = fullRates.MotorZona1
					driverFee = 10500.0
				case 2:
					rowPrice = fullRates.MotorZona2
					driverFee = 17500.0
				case 3:
					rowPrice = fullRates.MotorZona3
					driverFee = 24500.0
				case 4:
					kmRate := fullRates.MotorKm
					if kmRate <= 1750 {
						kmRate = 2500.0
					}
					rowPrice = distKm * kmRate
					driverFee = 26000.0
				case 5:
					kmRate := fullRates.MotorKm
					if kmRate <= 1750 {
						kmRate = 2500.0
					}
					rowPrice = distKm * kmRate
					driverFee = 30000.0
				default:
					kmRate := fullRates.MotorKm
					if kmRate <= 1750 {
						kmRate = 2500.0
					}
					rowPrice = distKm * kmRate
					driverFee = distKm * 1750.0
				}
			} else {
				kmRate := fullRates.MotorKm
				if kmRate <= 1750 {
					kmRate = 2500.0
				}
				rowPrice = distKm * kmRate
				driverFee = distKm * 1750.0
			}
		} else {
			rowPrice = calcRowPrice(req.RateType, activeRate, distKm, r.item.KubikAktual, r.item.BeratAktual, i)
			if req.RateType == "km" {
				driverFee = distKm * 1750.0
			} else {
				driverFee = rowPrice
			}
		}

		isSurabaya := isSurabayaRegion(originName+" "+originAddress, r.item.AlamatLengkap, r.item.NamaApotek)
		if !isSurabaya {
			// For regions outside Surabaya (Jabodetabek, etc.), driver earnings are cut 20% from admin rowPrice (driver receives 80%)
			driverFee = math.Round(rowPrice * 0.80)
		}

		rowPrice = math.Round(rowPrice)
		driverFee = math.Round(driverFee)
		summary := buildSummary(req.Armada, req.RateType, r.item.Invoices)
		rowOrderNumber := fmt.Sprintf("%s-%d", orderBaseNumber, i+1)

		insertOrderQuery := `
		INSERT INTO orders (order_number, parent_order_number, mitra_id, dispatch_id, status, pharmacy_name, pharmacy_address, delivery_address, customer_name, customer_phone, medicine_summary, delivery_fee, driver_fee, distance_km)
		VALUES ($1, $2, $3, '', 'PENDING', $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, order_number, parent_order_number, status, pharmacy_name, pharmacy_address, delivery_address, customer_name, customer_phone, medicine_summary, delivery_fee, driver_fee, distance_km, created_at;`

		var order models.Order
		err = tx.QueryRow(ctx, insertOrderQuery,
			rowOrderNumber, orderBaseNumber, userID,
			originName, originAddress, r.item.AlamatLengkap,
			r.item.NamaApotek, originName, summary, rowPrice, driverFee, distKm,
		).Scan(
			&order.ID, &order.OrderNumber, &order.ParentOrderNumber, &order.Status,
			&order.PharmacyName, &order.PharmacyAddress, &order.DeliveryAddress,
			&order.CustomerName, &order.CustomerPhone, &order.MedicineSummary,
			&order.DeliveryFee, &order.DriverFee, &order.DistanceKM, &order.CreatedAt,
		)

		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: fmt.Sprintf("Gagal mendaftarkan item order ke-%d: %s", i+1, err.Error()),
			})
			return
		}
		savedOrders = append(savedOrders, order)
	}

	if err = tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan batch order ke database"})
		return
	}

	c.JSON(http.StatusCreated, models.APIResponse{
		Status:  "success",
		Message: fmt.Sprintf("%d order berhasil dibuat secara bulk!", len(savedOrders)),
		Data:    savedOrders,
	})
}

// GetFlatInvoices returns every invoice as its own flat row across all orders.
// Format per row: invoice_no, nama_apotek, driver_name, status (DONE/MISSING), catatan, created_at, dispatch_id.
func (h *AdminHandler) GetFlatInvoices(c *gin.Context) {
	ctx := context.Background()
	roleVal, _ := c.Get("role")
	role := roleVal.(string)
	userIDVal, _ := c.Get("user_id")
	userID := userIDVal.(int)

	// Pick up optional ?date= query param (format: YYYY-MM-DD)
	dateFilter := c.Query("date") // e.g. "2026-07-24"

	baseQuery := `
	SELECT o.order_number,
	       COALESCE(NULLIF(o.parent_order_number, ''), o.order_number) as parent_order_number,
	       COALESCE(o.medicine_summary, '') as medicine_summary,
	       COALESCE(o.checked_invoices, '') as checked_invoices,
	       COALESCE(o.delivery_address, '') as delivery_address,
	       COALESCE(u_driver.name, '') as driver_name,
	       COALESCE(u_driver.phone, '') as driver_phone,
	       COALESCE(dp.plate_number, '') as driver_plate,
	       COALESCE(dp.vehicle_type, 'motor') as vehicle_type,
	       o.created_at, o.status,
	       COALESCE(o.dispatch_id, '') as dispatch_id,
	       COALESCE(o.customer_name, '') as customer_name,
	       COALESCE(o.pharmacy_name, '') as pharmacy_name,
	       COALESCE(o.reject_reason, '') as reject_reason,
	       COALESCE(o.reject_note, '') as reject_note,
	       COALESCE(o.extra_items_note, '') as extra_items_note,
	       COALESCE(o.unboxing_option, '') as unboxing_option,
	       COALESCE(o.pickup_note, '') as pickup_note,
	       COALESCE(o.arrived_photo_url, '') as arrived_photo_url,
	       COALESCE(o.facture_photo_url, '') as facture_photo_url,
	       COALESCE(o.signature_photo_url, '') as signature_photo_url,
	       COALESCE(o.pod_signature_photo_url, '') as pod_signature_photo_url,
	       COALESCE(o.handover_photo_url, '') as handover_photo_url,
	       COALESCE(o.arrived_note, '') as arrived_note
	FROM orders o
	LEFT JOIN users u_driver ON u_driver.id = o.driver_id
	LEFT JOIN driver_profiles dp ON dp.user_id = o.driver_id
	WHERE 1=1`

	if role == "MITRA" {
		baseQuery += ` AND o.mitra_id = $1`
	}
	if dateFilter != "" {
		if role == "MITRA" {
			baseQuery += ` AND DATE(o.created_at) = $2`
		} else {
			baseQuery += ` AND DATE(o.created_at) = $1`
		}
	}
	baseQuery += ` ORDER BY o.created_at DESC;`

	var rows interface {
		Next() bool
		Scan(...interface{}) error
		Err() error
		Close()
	}
	var err error
	if role == "MITRA" {
		if dateFilter != "" {
			rows, err = h.DB.Query(ctx, baseQuery, userID, dateFilter)
		} else {
			rows, err = h.DB.Query(ctx, baseQuery, userID)
		}
	} else {
		if dateFilter != "" {
			rows, err = h.DB.Query(ctx, baseQuery, dateFilter)
		} else {
			rows, err = h.DB.Query(ctx, baseQuery)
		}
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil data invoice: " + err.Error()})
		return
	}
	defer rows.Close()

	type FlatInvoiceRow struct {
		OrderNumber          string    `json:"order_number"`
		ParentOrderNumber    string    `json:"parent_order_number"`
		InvoiceNo            string    `json:"invoice_no"`
		NamaApotek           string    `json:"nama_apotek"`
		PharmacyName         string    `json:"pharmacy_name"`
		CustomerName         string    `json:"customer_name"`
		DeliveryAddress      string    `json:"delivery_address"`
		MedicineSummary      string    `json:"medicine_summary"`
		CheckedInvoices      string    `json:"checked_invoices"`
		DriverName           string    `json:"driver_name"`
		DriverPhone          string    `json:"driver_phone"`
		DriverPlate          string    `json:"driver_plate"`
		VehicleType          string    `json:"vehicle_type"`
		Status               string    `json:"status"`
		Catatan              string    `json:"catatan"`
		CreatedAt            time.Time `json:"created_at"`
		DispatchID           string    `json:"dispatch_id"`
		RejectReason         string    `json:"reject_reason,omitempty"`
		RejectNote           string    `json:"reject_note,omitempty"`
		ExtraItemsNote       string    `json:"extra_items_note,omitempty"`
		UnboxingOption       string    `json:"unboxing_option,omitempty"`
		PickupNote           string    `json:"pickup_note,omitempty"`
		ArrivedPhotoUrl      string    `json:"arrived_photo_url,omitempty"`
		FacturePhotoUrl      string    `json:"facture_photo_url,omitempty"`
		SignaturePhotoUrl    string    `json:"signature_photo_url,omitempty"`
		PodSignaturePhotoUrl string    `json:"pod_signature_photo_url,omitempty"`
		HandoverPhotoUrl     string    `json:"handover_photo_url,omitempty"`
		ArrivedNote          string    `json:"arrived_note,omitempty"`
	}

	var result []FlatInvoiceRow

	for rows.Next() {
		var orderNumber, parentOrderNumber, medicineSummary, checkedInvoices, deliveryAddress, driverName, driverPhone, driverPlate, vehicleType, orderStatus, dispatchID, customerName, pharmacyName string
		var rejectReason, rejectNote, extraItemsNote, unboxingOption, pickupNote string
		var arrivedPhotoUrl, facturePhotoUrl, signaturePhotoUrl, podSignaturePhotoUrl, handoverPhotoUrl, arrivedNote string
		var createdAt time.Time

		if err := rows.Scan(
			&orderNumber, &parentOrderNumber, &medicineSummary, &checkedInvoices,
			&deliveryAddress, &driverName, &driverPhone, &driverPlate, &vehicleType,
			&createdAt, &orderStatus, &dispatchID, &customerName, &pharmacyName,
			&rejectReason, &rejectNote, &extraItemsNote, &unboxingOption, &pickupNote,
			&arrivedPhotoUrl, &facturePhotoUrl, &signaturePhotoUrl, &podSignaturePhotoUrl, &handoverPhotoUrl, &arrivedNote,
		); err != nil {
			continue
		}

		// Determine apotek name from customer_name or pharmacy_name
		namaApotek := customerName
		if namaApotek == "" {
			namaApotek = pharmacyName
		}
		if namaApotek == "" {
			namaApotek = deliveryAddress
		}

		// Parse checked_invoices: "INV-001: DONE; INV-002: MISSING (Hilang: catatan); INV-003: DONE"
		checkedMap := map[string]struct{ Status, Catatan string }{}
		var invoiceList []string

		if checkedInvoices != "" {
			for _, entry := range strings.Split(checkedInvoices, "; ") {
				entry = strings.TrimSpace(entry)
				if entry == "" {
					continue
				}
				colonIdx := strings.Index(entry, ": ")
				if colonIdx < 0 {
					continue
				}
				invNo := strings.TrimSpace(entry[:colonIdx])
				rest := strings.TrimSpace(entry[colonIdx+2:])

				var status, catatan string
				if strings.HasPrefix(rest, "MISSING") {
					status = "MISSING"
					if parenStart := strings.Index(rest, "("); parenStart >= 0 {
						catatan = strings.TrimRight(rest[parenStart+1:], ")")
					}
				} else {
					status = "DONE"
					catatan = "Sesuai (Verified)"
				}
				checkedMap[invNo] = struct{ Status, Catatan string }{status, catatan}
				if invNo != "" {
					invoiceList = append(invoiceList, invNo)
				}
			}
		}

		// Also parse medicine_summary: "... Invoices: INV-001, INV-002, ..."
		if parts := strings.SplitN(medicineSummary, "Invoices: ", 2); len(parts) == 2 {
			for _, inv := range strings.Split(parts[1], ", ") {
				inv = strings.TrimSpace(inv)
				if inv != "" {
					alreadyIn := false
					for _, existing := range invoiceList {
						if strings.EqualFold(existing, inv) {
							alreadyIn = true
							break
						}
					}
					if !alreadyIn {
						invoiceList = append(invoiceList, inv)
					}
				}
			}
		}

		// Fallback: If no invoice extracted, add orderNumber as invoice number
		if len(invoiceList) == 0 {
			invoiceList = append(invoiceList, orderNumber)
		}

		// Expand: one row per invoice
		for _, invNo := range invoiceList {
			statusInfo, found := checkedMap[invNo]
			if !found {
				statusInfo = struct{ Status, Catatan string }{orderStatus, "Belum diperiksa"}
			}
			result = append(result, FlatInvoiceRow{
				OrderNumber:          orderNumber,
				ParentOrderNumber:    parentOrderNumber,
				InvoiceNo:            invNo,
				NamaApotek:           namaApotek,
				PharmacyName:         pharmacyName,
				CustomerName:         customerName,
				DeliveryAddress:      deliveryAddress,
				MedicineSummary:      medicineSummary,
				CheckedInvoices:      checkedInvoices,
				DriverName:           driverName,
				DriverPhone:          driverPhone,
				DriverPlate:          driverPlate,
				VehicleType:          vehicleType,
				Status:               statusInfo.Status,
				Catatan:              statusInfo.Catatan,
				CreatedAt:            createdAt,
				DispatchID:           dispatchID,
				RejectReason:         rejectReason,
				RejectNote:           rejectNote,
				ExtraItemsNote:       extraItemsNote,
				UnboxingOption:       unboxingOption,
				PickupNote:           pickupNote,
				ArrivedPhotoUrl:      arrivedPhotoUrl,
				FacturePhotoUrl:      facturePhotoUrl,
				SignaturePhotoUrl:    signaturePhotoUrl,
				PodSignaturePhotoUrl: podSignaturePhotoUrl,
				HandoverPhotoUrl:     handoverPhotoUrl,
			})
		}
	}

	if result == nil {
		result = []FlatInvoiceRow{}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: fmt.Sprintf("Berhasil mengambil %d baris invoice", len(result)),
		Data:    result,
	})
}

// GetOrders returns all bulk orders (grouped by parent_order_number).
// ADMIN sees all; MITRA sees only their own.
func (h *AdminHandler) GetOrders(c *gin.Context) {
	ctx := context.Background()
	roleVal, _ := c.Get("role")
	role := roleVal.(string)
	userIDVal, _ := c.Get("user_id")
	userID := userIDVal.(int)

	type OrderSummary struct {
		DispatchID    string    `json:"dispatch_id"`
		MitraID       int       `json:"mitra_id"`
		MitraName     string    `json:"mitra_name"`
		CreatedAt     time.Time `json:"created_at"`
		StopCount     int       `json:"stop_count"`
		TotalFee      float64   `json:"total_fee"`
		Status        string    `json:"status"`
		IsDispatched  bool      `json:"is_dispatched"`
		DriverName    string    `json:"driver_name"`
		DriverPhone   string    `json:"driver_phone"`
		Addresses     string    `json:"addresses"`
		PharmacyNames string    `json:"pharmacy_names"`
	}

	adminQuery := `
	SELECT COALESCE(NULLIF(o.dispatch_id, ''), o.parent_order_number) as dispatch_id, o.mitra_id, COALESCE(u.name,'') as mitra_name,
	       MIN(o.created_at) as created_at, COUNT(o.id) as stop_count,
	       SUM(o.delivery_fee) as total_fee, MAX(o.status) as status,
	       BOOL_OR(o.driver_id IS NOT NULL) as is_dispatched,
	       COALESCE(MAX(d.name), '') as driver_name,
	       COALESCE(MAX(d.phone), '') as driver_phone,
	       COALESCE(STRING_AGG(o.delivery_address, ' | '), '') as addresses,
	       COALESCE(STRING_AGG(o.pharmacy_name, ' | '), '') as pharmacy_names
	FROM orders o
	LEFT JOIN users u ON u.id = o.mitra_id
	LEFT JOIN users d ON d.id = o.driver_id
	WHERE o.parent_order_number IS NOT NULL AND o.parent_order_number != ''
	GROUP BY COALESCE(NULLIF(o.dispatch_id, ''), o.parent_order_number), o.mitra_id, u.name
	ORDER BY MIN(o.created_at) DESC;`

	mitraQuery := `
	SELECT COALESCE(NULLIF(o.dispatch_id, ''), o.parent_order_number) as dispatch_id, o.mitra_id, COALESCE(u.name,'') as mitra_name,
	       MIN(o.created_at) as created_at, COUNT(o.id) as stop_count,
	       SUM(o.delivery_fee) as total_fee, MAX(o.status) as status,
	       BOOL_OR(o.driver_id IS NOT NULL) as is_dispatched,
	       COALESCE(MAX(d.name), '') as driver_name,
	       COALESCE(MAX(d.phone), '') as driver_phone,
	       COALESCE(STRING_AGG(o.delivery_address, ' | '), '') as addresses,
	       COALESCE(STRING_AGG(o.pharmacy_name, ' | '), '') as pharmacy_names
	FROM orders o
	LEFT JOIN users u ON u.id = o.mitra_id
	LEFT JOIN users d ON d.id = o.driver_id
	WHERE o.mitra_id = $1 AND o.parent_order_number IS NOT NULL AND o.parent_order_number != ''
	GROUP BY COALESCE(NULLIF(o.dispatch_id, ''), o.parent_order_number), o.mitra_id, u.name
	ORDER BY MIN(o.created_at) DESC;`

	var pgRows interface {
		Next() bool
		Scan(...interface{}) error
		Err() error
		Close()
	}
	var err error

	if role == "ADMIN" {
		pgRows, err = h.DB.Query(ctx, adminQuery)
	} else {
		pgRows, err = h.DB.Query(ctx, mitraQuery, userID)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil data order: " + err.Error()})
		return
	}
	defer pgRows.Close()

	var summaries []OrderSummary
	for pgRows.Next() {
		var s OrderSummary
		if err := pgRows.Scan(&s.DispatchID, &s.MitraID, &s.MitraName, &s.CreatedAt,
			&s.StopCount, &s.TotalFee, &s.Status, &s.IsDispatched, &s.DriverName, &s.DriverPhone, &s.Addresses, &s.PharmacyNames); err != nil {
			continue
		}
		summaries = append(summaries, s)
	}
	if summaries == nil {
		summaries = []OrderSummary{}
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: summaries})
}

// GetOrderDetail returns the full breakdown of a single parent order or dispatch ID.
func (h *AdminHandler) GetOrderDetail(c *gin.Context) {
	dispatchID := c.Param("dispatch_id")
	ctx := context.Background()
	roleVal, _ := c.Get("role")
	role := roleVal.(string)
	userIDVal, _ := c.Get("user_id")
	userID := userIDVal.(int)

	query := `
	SELECT o.id, o.order_number, o.status, o.pharmacy_name, o.pharmacy_address,
	       o.delivery_address, o.customer_name, o.medicine_summary, o.delivery_fee,
	       o.created_at, o.mitra_id,
	       COALESCE(o.driver_id, 0) as driver_id,
	       COALESCE(u_driver.name, '') as driver_name,
	       COALESCE(u_driver.phone, '') as driver_phone,
	       COALESCE(dp.plate_number, '') as driver_plate,
	       COALESCE(dp.vehicle_type, '') as driver_vehicle,
	       COALESCE(o.distance_km, 0.0) as distance_km,
	       COALESCE(o.parent_order_number, '') as parent_order_number,
	       COALESCE(o.dispatch_id, '') as order_dispatch_id,
	       COALESCE(o.pickup_photo_url, '') as pickup_photo_url,
	       COALESCE(o.pickup_note, '') as pickup_note,
	       COALESCE(o.arrived_photo_url, '') as arrived_photo_url,
	       COALESCE(o.arrived_note, '') as arrived_note,
	       COALESCE(o.handover_photo_url, '') as handover_photo_url,
	       COALESCE(o.reject_photo_url, '') as reject_photo_url,
	       COALESCE(o.reject_note, '') as reject_note,
	       COALESCE(o.reject_reason, '') as reject_reason,
	       COALESCE(o.reject_approved, false) as reject_approved,
	       COALESCE(o.unboxing_option, '') as unboxing_option,
	       COALESCE(o.checked_invoices, '') as checked_invoices,
	       COALESCE(o.extra_items_note, '') as extra_items_note,
	       COALESCE(o.extra_items_photo_url, '') as extra_items_photo_url,
	       COALESCE(o.facture_photo_url, '') as facture_photo_url,
	       COALESCE(o.signature_photo_url, '') as signature_photo_url,
	       COALESCE(o.pod_signature_photo_url, '') as pod_signature_photo_url
	FROM orders o
	LEFT JOIN users u_driver ON u_driver.id = o.driver_id
	LEFT JOIN driver_profiles dp ON dp.user_id = o.driver_id
	WHERE (o.dispatch_id IS NOT NULL AND o.dispatch_id != '' AND o.dispatch_id = $1) OR ((o.dispatch_id IS NULL OR o.dispatch_id = '') AND o.parent_order_number = $1) OR o.order_number = $1`
	if role == "MITRA" {
		query += ` AND o.mitra_id = $2`
	}
	query += ` ORDER BY o.id;`

	type StopItem struct {
		ID                  int      `json:"id"`
		OrderNumber         string   `json:"order_number"`
		ParentOrderNumber   string   `json:"parent_order_number"`
		DispatchID          string   `json:"dispatch_id"`
		Status              string   `json:"status"`
		NamaApotek          string   `json:"nama_apotek"`
		Alamat              string   `json:"alamat"`
		Invoices            []string `json:"invoices"`
		Fee                 float64  `json:"fee"`
		DriverID            int      `json:"driver_id"`
		DriverName          string   `json:"driver_name"`
		DriverPhone         string   `json:"driver_phone"`
		DriverPlate         string   `json:"driver_plate"`
		DriverVehicle       string   `json:"driver_vehicle"`
		RateType            string   `json:"rate_type"`
		Armada              string   `json:"armada"`
		DistanceKM          float64  `json:"distance_km"`
		PickupPhotoUrl      string   `json:"pickup_photo_url"`
		PickupNote          string   `json:"pickup_note"`
		ArrivedPhotoUrl     string   `json:"arrived_photo_url"`
		ArrivedNote         string   `json:"arrived_note"`
		HandoverPhotoUrl    string   `json:"handover_photo_url"`
		RejectPhotoUrl      string   `json:"reject_photo_url"`
		RejectNote          string   `json:"reject_note"`
		RejectReason        string   `json:"reject_reason"`
		RejectApproved      bool     `json:"reject_approved"`
		UnboxingOption      string   `json:"unboxing_option"`
		CheckedInvoices     string   `json:"checked_invoices"`
		ExtraItemsNote      string   `json:"extra_items_note"`
		ExtraItemsPhotoUrl   string   `json:"extra_items_photo_url"`
		FacturePhotoUrl      string   `json:"facture_photo_url"`
		SignaturePhotoUrl    string   `json:"signature_photo_url"`
		PODSignaturePhotoUrl string   `json:"pod_signature_photo_url"`
	}

	var pgRows interface {
		Next() bool
		Scan(...interface{}) error
		Err() error
		Close()
	}
	var err error
	if role == "MITRA" {
		pgRows, err = h.DB.Query(ctx, query, dispatchID, userID)
	} else {
		pgRows, err = h.DB.Query(ctx, query, dispatchID)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil detail order: " + err.Error()})
		return
	}
	defer pgRows.Close()

	var stops []StopItem
	var grandTotal float64
	var minCreatedAt time.Time
	for pgRows.Next() {
		var s StopItem
		var mitraID int
		var medicineSummary string
		var createdAt time.Time
		var pharmName, pharmAddr, delivAddr, custName string
		err := pgRows.Scan(
			&s.ID, &s.OrderNumber, &s.Status, &pharmName, &pharmAddr,
			&delivAddr, &custName, &medicineSummary, &s.Fee,
			&createdAt, &mitraID, &s.DriverID,
			&s.DriverName, &s.DriverPhone, &s.DriverPlate, &s.DriverVehicle, &s.DistanceKM,
			&s.ParentOrderNumber, &s.DispatchID, &s.PickupPhotoUrl, &s.PickupNote,
			&s.ArrivedPhotoUrl, &s.ArrivedNote, &s.HandoverPhotoUrl,
			&s.RejectPhotoUrl, &s.RejectNote, &s.RejectReason, &s.RejectApproved,
			&s.UnboxingOption, &s.CheckedInvoices, &s.ExtraItemsNote, &s.ExtraItemsPhotoUrl,
			&s.FacturePhotoUrl, &s.SignaturePhotoUrl, &s.PODSignaturePhotoUrl,
		)
		if err != nil {
			continue
		}
		s.NamaApotek = custName
		if s.NamaApotek == "" {
			s.NamaApotek = pharmName
		}
		s.Alamat = delivAddr
		if s.Alamat == "" {
			s.Alamat = pharmAddr
		}
		// Parse armada, rate_type, invoices from medicine_summary
		s.Armada, s.RateType = parseArmadaRate(medicineSummary)
		if parts := strings.SplitN(medicineSummary, "Invoices: ", 2); len(parts) == 2 {
			s.Invoices = strings.Split(parts[1], ", ")
		}
		grandTotal += s.Fee
		stops = append(stops, s)

		if minCreatedAt.IsZero() || createdAt.Before(minCreatedAt) {
			minCreatedAt = createdAt
		}
	}
	if stops == nil {
		stops = []StopItem{}
	}

	// Group by driver
	type DriverGroup struct {
		DriverID   int        `json:"driver_id"`
		DriverName string     `json:"driver_name"`
		Stops      []StopItem `json:"stops"`
		TotalFee   float64    `json:"total_fee"`
	}
	driverMap := map[int]*DriverGroup{}
	for _, s := range stops {
		if _, ok := driverMap[s.DriverID]; !ok {
			driverMap[s.DriverID] = &DriverGroup{DriverID: s.DriverID, DriverName: s.DriverName}
		}
		driverMap[s.DriverID].Stops = append(driverMap[s.DriverID].Stops, s)
		driverMap[s.DriverID].TotalFee += s.Fee
	}
	var driverGroups []DriverGroup
	for _, dg := range driverMap {
		driverGroups = append(driverGroups, *dg)
	}

	batchRateType, batchArmada := "", ""
	if len(stops) > 0 {
		batchRateType = stops[0].RateType
		batchArmada = stops[0].Armada
	}

	type OrderDetailResponse struct {
		DispatchID   string        `json:"dispatch_id"`
		RateType     string        `json:"rate_type"`
		Armada       string        `json:"armada"`
		CreatedAt    time.Time     `json:"created_at"`
		Stops        []StopItem    `json:"stops"`
		DriverGroups []DriverGroup `json:"driver_groups,omitempty"`
		GrandTotal   float64       `json:"grand_total"`
	}

	resp := OrderDetailResponse{
		DispatchID: dispatchID, RateType: batchRateType, Armada: batchArmada,
		CreatedAt: minCreatedAt, Stops: stops, GrandTotal: grandTotal,
	}
	if role == "ADMIN" {
		resp.DriverGroups = driverGroups
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: resp})
}

// DeleteOrder deletes an order or dispatch group by ID / dispatch_id / parent_order_number.
func (h *AdminHandler) DeleteOrder(c *gin.Context) {
	targetID := c.Param("id")
	ctx := context.Background()
	roleVal, _ := c.Get("role")
	role := roleVal.(string)
	userIDVal, _ := c.Get("user_id")
	userID := userIDVal.(int)

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memulai transaksi database"})
		return
	}
	defer tx.Rollback(ctx)

	// Build WHERE clause for matching orders
	var orderIDs []int
	var selectQuery string
	var args []interface{}

	if role == "MITRA" {
		selectQuery = `SELECT id FROM orders WHERE (dispatch_id = $1 OR parent_order_number = $1 OR order_number = $1 OR id::text = $1) AND mitra_id = $2;`
		args = append(args, targetID, userID)
	} else {
		selectQuery = `SELECT id FROM orders WHERE (dispatch_id = $1 OR parent_order_number = $1 OR order_number = $1 OR id::text = $1);`
		args = append(args, targetID)
	}

	rows, err := tx.Query(ctx, selectQuery, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mencari order untuk dihapus: " + err.Error()})
		return
	}
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err == nil {
			orderIDs = append(orderIDs, id)
		}
	}
	rows.Close()

	if len(orderIDs) == 0 {
		c.JSON(http.StatusNotFound, models.APIResponse{Status: "error", Message: "Order tidak ditemukan atau Anda tidak memiliki hak akses"})
		return
	}

	// 1. Delete details from dispatch_id_detail
	_, _ = tx.Exec(ctx, `DELETE FROM dispatch_id_detail WHERE order_id = ANY($1);`, orderIDs)

	// 2. Clean empty dispatch_groups
	_, _ = tx.Exec(ctx, `DELETE FROM dispatch_groups WHERE dispatch_number = $1 OR id NOT IN (SELECT DISTINCT dispatch_group_id FROM dispatch_id_detail WHERE dispatch_group_id IS NOT NULL);`, targetID)

	// 3. Delete notifications
	_, _ = tx.Exec(ctx, `DELETE FROM notifications WHERE message ILIKE '%' || $1 || '%';`, targetID)

	// 4. Delete from orders table
	_, err = tx.Exec(ctx, `DELETE FROM orders WHERE id = ANY($1);`, orderIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghapus order: " + err.Error()})
		return
	}

	if err = tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan perubahan ke database"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: fmt.Sprintf("Order %s berhasil dihapus", targetID)})
}

// ─── Helper functions shared across order handlers ────────────────────────────

func calcRowPrice(rateType string, activeRate, distKm float64, kubik, berat *float64, index int) float64 {
	switch rateType {
	case "km":
		return activeRate * distKm
	case "titik":
		return activeRate
	case "dimensi":
		k := 1.0
		if kubik != nil {
			k = *kubik
		}
		return activeRate * k
	case "berat":
		b := 1.0
		if berat != nil {
			b = *berat
		}
		return activeRate * b
	case "lumpsum":
		if index == 0 {
			return activeRate
		}
		return 0
	default:
		return 15000.0
	}
}

func buildSummary(armada, rateType string, invoices []string) string {
	s := fmt.Sprintf("Armada: %s, Rate: %s, Invoices: ", armada, rateType)
	s += strings.Join(invoices, ", ")
	return s
}

func parseArmadaRate(summary string) (armada, rate string) {
	if ap := strings.SplitN(summary, "Armada: ", 2); len(ap) == 2 {
		rest := ap[1]
		if rp := strings.SplitN(rest, ", ", 2); len(rp) > 0 {
			armada = strings.TrimSpace(rp[0])
		}
	}
	if rp := strings.SplitN(summary, "Rate: ", 2); len(rp) == 2 {
		rest := rp[1]
		if kv := strings.SplitN(rest, ",", 2); len(kv) > 0 {
			rate = strings.TrimSpace(kv[0])
		}
	}
	return
}

func loadMitraRates(db *pgxpool.Pool, ctx context.Context, userID int, armada, rateType string) (originLat, originLong, activeRate float64) {
	originLat = -6.2019957
	originLong = 106.8551888

	var motorDimensi, motorKm, motorTitik, motorBerat *float64
	var mobilDimensi, mobilKm, mobilTitik, mobilBerat, mobilLumpsum *float64

	_ = db.QueryRow(ctx, `
	SELECT pickup_lat, pickup_long,
	       motor_dimensi, motor_km, motor_titik, motor_berat,
	       mobil_dimensi, mobil_km, mobil_titik, mobil_berat, mobil_lumpsum
	FROM mitra_profiles WHERE user_id = $1;`, userID).Scan(
		&originLat, &originLong,
		&motorDimensi, &motorKm, &motorTitik, &motorBerat,
		&mobilDimensi, &mobilKm, &mobilTitik, &mobilBerat, &mobilLumpsum,
	)

	activeRate = resolveRate(armada, rateType, motorDimensi, motorKm, motorTitik, motorBerat,
		mobilDimensi, mobilKm, mobilTitik, mobilBerat, mobilLumpsum)
	return
}

func loadMitraRatesFromDB(db *pgxpool.Pool, ctx context.Context, userID int, armada, rateType string) (float64, float64) {
	lat, _, rate := loadMitraRates(db, ctx, userID, armada, rateType)
	return lat, rate
}

func resolveRate(armada, rateType string, motDim, motKm, motTit, motBer, mobDim, mobKm, mobTit, mobBer, mobLump *float64) float64 {
	defaults := map[string]map[string]float64{
		"motor": {"km": 20000, "titik": 10000, "dimensi": 1333, "berat": 5000},
		"mobil": {"km": 25000, "titik": 12000, "dimensi": 1500, "berat": 6000, "lumpsum": 500000},
	}

	var rate float64
	if armada == "motor" {
		switch rateType {
		case "dimensi":
			if motDim != nil {
				rate = *motDim
			}
		case "km":
			if motKm != nil {
				rate = *motKm
			}
		case "titik":
			if motTit != nil {
				rate = *motTit
			}
		case "berat":
			if motBer != nil {
				rate = *motBer
			}
		}
	} else {
		switch rateType {
		case "dimensi":
			if mobDim != nil {
				rate = *mobDim
			}
		case "km":
			if mobKm != nil {
				rate = *mobKm
			}
		case "titik":
			if mobTit != nil {
				rate = *mobTit
			}
		case "berat":
			if mobBer != nil {
				rate = *mobBer
			}
		case "lumpsum":
			if mobLump != nil {
				rate = *mobLump
			}
		}
	}

	if rate == 0 {
		if d, ok := defaults[armada]; ok {
			if v, ok2 := d[rateType]; ok2 {
				return v
			}
		}
		return 10000.0
	}
	return rate
}

type MitraRates struct {
	OriginLat, OriginLong float64
	MotorKm, MotorTitik, MotorDimensi, MotorBerat float64
	MotorZona1, MotorZona2, MotorZona3 float64
	MobilKm, MobilTitik, MobilDimensi, MobilBerat, MobilLumpsum float64
}

func loadMitraFullRates(db *pgxpool.Pool, ctx context.Context, userID int) MitraRates {
	rates := MitraRates{
		OriginLat: -6.2019957, OriginLong: 106.8551888,
		MotorKm: 1750, MotorTitik: 10000, MotorDimensi: 1333.33, MotorBerat: 5000,
		MotorZona1: 0, MotorZona2: 0, MotorZona3: 0,
		MobilKm: 2500, MobilTitik: 12000, MobilDimensi: 1500, MobilBerat: 6000, MobilLumpsum: 700000,
	}

	var pLat, pLng *float64
	var pName string
	var mDim, mKm, mTit, mBer, mZ1, mZ2, mZ3 *float64
	var mbDim, mbKm, mbTit, mbBer, mbLump *float64

	_ = db.QueryRow(ctx, `
	SELECT pickup_lat, pickup_long, COALESCE(pickup_name, ''),
	       motor_dimensi, motor_km, motor_titik, motor_berat, motor_zona1, motor_zona2, motor_zona3,
	       mobil_dimensi, mobil_km, mobil_titik, mobil_berat, mobil_lumpsum
	FROM mitra_profiles WHERE user_id = $1;`, userID).Scan(
		&pLat, &pLng, &pName,
		&mDim, &mKm, &mTit, &mBer, &mZ1, &mZ2, &mZ3,
		&mbDim, &mbKm, &mbTit, &mbBer, &mbLump,
	)

	if pLat != nil && *pLat != 0 {
		rates.OriginLat = *pLat
	}
	if pLng != nil && *pLng != 0 {
		rates.OriginLong = *pLng
	}

	var userName, userEmail string
	_ = db.QueryRow(ctx, "SELECT name, email FROM users WHERE id = $1", userID).Scan(&userName, &userEmail)
	uStr := strings.ToLower(userName + " " + userEmail + " " + pName)
	if strings.Contains(uStr, "jakarta") && (pLat == nil || *pLat == 0 || math.Abs(*pLat - -7.782889) < 0.01) {
		rates.OriginLat = -6.2019957
		rates.OriginLong = 106.8551888
	}

	if mDim != nil && *mDim > 0 { rates.MotorDimensi = *mDim }
	if mKm != nil && *mKm > 0 { rates.MotorKm = *mKm }
	if mTit != nil && *mTit > 0 { rates.MotorTitik = *mTit }
	if mBer != nil && *mBer > 0 { rates.MotorBerat = *mBer }
	if mZ1 != nil && *mZ1 > 0 { rates.MotorZona1 = *mZ1 }
	if mZ2 != nil && *mZ2 > 0 { rates.MotorZona2 = *mZ2 }
	if mZ3 != nil && *mZ3 > 0 { rates.MotorZona3 = *mZ3 }

	if mbDim != nil && *mbDim > 0 { rates.MobilDimensi = *mbDim }
	if mbKm != nil && *mbKm > 0 { rates.MobilKm = *mbKm }
	if mbTit != nil && *mbTit > 0 { rates.MobilTitik = *mbTit }
	if mbBer != nil && *mbBer > 0 { rates.MobilBerat = *mbBer }
	if mbLump != nil && *mbLump > 0 { rates.MobilLumpsum = *mbLump }

	return rates
}

// ─── Geocoding & Routing helpers ──────────────────────────────────────────────

func findRecipient(db *pgxpool.Pool, namaApotek, alamatLengkap string) (*models.Recipient, error) {
	ctx := context.Background()
	var rec models.Recipient

	// Strip parens like "(CV. AKS PURI)" for flexible name matching
	cleanName := strings.TrimSpace(regexp.MustCompile(`\([^)]*\)`).ReplaceAllString(namaApotek, ""))

	err := db.QueryRow(ctx, `
	SELECT id, nama_apotek, alamat_lengkap, latitude, longitude, COALESCE(zona, 0)
	FROM alamat_penerima 
	WHERE LOWER(nama_apotek) = LOWER($1) 
	   OR (LOWER($2) != '' AND LOWER(nama_apotek) = LOWER($2))
	   OR LOWER(alamat_lengkap) = LOWER($3)
	   OR (LOWER($2) != '' AND (LOWER(nama_apotek) LIKE '%' || LOWER($2) || '%' OR LOWER($2) LIKE '%' || LOWER(nama_apotek) || '%'))
	ORDER BY 
		CASE 
			WHEN LOWER(nama_apotek) = LOWER($1) THEN 1 
			WHEN LOWER(nama_apotek) = LOWER($2) THEN 2 
			ELSE 3 
		END
	LIMIT 1;`, namaApotek, cleanName, alamatLengkap).Scan(
		&rec.ID, &rec.NamaApotek, &rec.AlamatLengkap, &rec.Latitude, &rec.Longitude, &rec.Zona)
	if err == nil {
		return &rec, nil
	}
	return nil, nil
}

func cleanAddressForOSM(addr string) string {
	// Strip parens like (PT. MORRIS MEDIKAFARMA INDONESIA)
	reParens := regexp.MustCompile(`\([^)]*\)`)
	addr = reParens.ReplaceAllString(addr, "")

	// Strip noisy building / unit tokens
	reNoisy := regexp.MustCompile(`(?i)\b(perkantoran|gedung|ruko|pt\.|cv\.|blok\s+\w+|no\.\s*\w+|no\s*\d+|rt\.\s*\d+|rw\.\s*\d+|rt\s*\d+|rw\s*\d+)\b`)
	cleaned := reNoisy.ReplaceAllString(addr, "")

	// Clean up extra spaces/commas
	words := strings.Fields(cleaned)
	return strings.TrimSpace(strings.Join(words, " "))
}

func extractStreetAndCityVariations(alamat string) []string {
	parts := strings.Split(alamat, ",")
	var rawStreet, cityPart string
	var results []string

	for i := len(parts) - 1; i >= 0; i-- {
		pTrimmed := strings.TrimSpace(parts[i])
		pLower := strings.ToLower(pTrimmed)

		if rawStreet == "" && (strings.HasPrefix(pLower, "jl.") || strings.HasPrefix(pLower, "jl ") || strings.HasPrefix(pLower, "jalan ")) {
			words := strings.Fields(pTrimmed)
			streetWords := []string{}
			for _, w := range words {
				wLower := strings.ToLower(w)
				if strings.HasPrefix(wLower, "no.") || wLower == "no" || strings.Contains(wLower, "rt.") || strings.Contains(wLower, "rw.") {
					break
				}
				streetWords = append(streetWords, w)
			}
			rawStreet = strings.Join(streetWords, " ")
			for _, prefix := range []string{"jl.", "jl ", "jalan "} {
				if strings.HasPrefix(strings.ToLower(rawStreet), prefix) {
					rawStreet = strings.TrimSpace(rawStreet[len(prefix):])
					break
				}
			}
		}

		if cityPart == "" && i > 0 {
			for _, city := range []string{"jakarta", "yogyakarta", "jogja", "sleman", "bantul", "tangerang", "bekasi", "depok", "bogor", "surabaya", "sidoarjo"} {
				if strings.Contains(pLower, city) {
					cityPart = strings.Title(city)
					if cityPart == "Jogja" {
						cityPart = "Yogyakarta"
					}
					break
				}
			}
		}
	}

	if rawStreet != "" && cityPart != "" {
		results = append(results, "Jalan "+rawStreet+", "+cityPart)
		results = append(results, rawStreet+", "+cityPart)
	}

	// Cleaned address fallback
	if cleaned := cleanAddressForOSM(alamat); cleaned != "" {
		results = append(results, cleaned)
	}

	return results
}

func geocodeAddress(alamat string, fallbackLat, fallbackLong float64) (float64, float64, error) {
	hereKey := os.Getenv("HERE_MAPS_API_KEY")
	if hereKey != "" {
		u := fmt.Sprintf("https://geocode.search.hereapi.com/v1/geocode?q=%s&apiKey=%s", url.QueryEscape(alamat), hereKey)
		httpClient := &http.Client{Timeout: 5 * time.Second}
		resp, err := httpClient.Get(u)
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				var data struct {
					Items []struct {
						Position struct {
							Lat float64 `json:"lat"`
							Lng float64 `json:"lng"`
						} `json:"position"`
					} `json:"items"`
				}
				if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && len(data.Items) > 0 {
					return data.Items[0].Position.Lat, data.Items[0].Position.Lng, nil
				}
			}
		}
	}

	apiKey := os.Getenv("GOOGLE_MAPS_API_KEY")
	if apiKey != "" {
		u := fmt.Sprintf("https://maps.googleapis.com/maps/api/geocode/json?address=%s&key=%s", url.QueryEscape(alamat), apiKey)
		httpClient := &http.Client{Timeout: 5 * time.Second}
		resp, err := httpClient.Get(u)
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				var data struct {
					Results []struct {
						Geometry struct {
							Location struct {
								Lat float64 `json:"lat"`
								Lng float64 `json:"lng"`
							} `json:"location"`
						} `json:"geometry"`
					} `json:"results"`
					Status string `json:"status"`
				}
				if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && len(data.Results) > 0 && data.Status == "OK" {
					return data.Results[0].Geometry.Location.Lat, data.Results[0].Geometry.Location.Lng, nil
				}
			}
		}
	}

	// OSM Nominatim & Photon fallback queries
	var queries []string
	queries = append(queries, extractStreetAndCityVariations(alamat)...)
	queries = append(queries, cleanAddressForOSM(alamat))
	queries = append(queries, alamat)

	httpClient := &http.Client{Timeout: 5 * time.Second}

	// Try Photon API (OSM Komoot geocoder)
	for _, queryVal := range queries {
		if strings.TrimSpace(queryVal) == "" {
			continue
		}
		u := fmt.Sprintf("https://photon.komoot.io/api/?q=%s&limit=1", url.QueryEscape(queryVal))
		req, err := http.NewRequest("GET", u, nil)
		if err == nil {
			req.Header.Set("User-Agent", "K24Apps/1.0 (contact: admin@k24.com)")
			resp, err := httpClient.Do(req)
			if err == nil {
				var data struct {
					Features []struct {
						Geometry struct {
							Coordinates []float64 `json:"coordinates"` // [lng, lat]
						} `json:"geometry"`
					} `json:"features"`
				}
				errDecode := json.NewDecoder(resp.Body).Decode(&data)
				resp.Body.Close()
				if errDecode == nil && len(data.Features) > 0 && len(data.Features[0].Geometry.Coordinates) >= 2 {
					lngVal := data.Features[0].Geometry.Coordinates[0]
					latVal := data.Features[0].Geometry.Coordinates[1]
					if latVal != 0 && lngVal != 0 {
						return latVal, lngVal, nil
					}
				}
			}
		}
	}

	// OSM Nominatim fallback
	for _, queryVal := range queries {
		if strings.TrimSpace(queryVal) == "" {
			continue
		}
		u := fmt.Sprintf("https://nominatim.openstreetmap.org/search?q=%s&format=json&limit=1", url.QueryEscape(queryVal))
		req, err := http.NewRequest("GET", u, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "K24Apps/1.0 (contact: admin@k24.com)")
		resp, err := httpClient.Do(req)
		if err != nil {
			continue
		}
		var data []struct {
			Lat string `json:"lat"`
			Lon string `json:"lon"`
		}
		errDecode := json.NewDecoder(resp.Body).Decode(&data)
		resp.Body.Close()
		if errDecode == nil && len(data) > 0 {
			latVal, err1 := strconv.ParseFloat(data[0].Lat, 64)
			lonVal, err2 := strconv.ParseFloat(data[0].Lon, 64)
			if err1 == nil && err2 == nil {
				return latVal, lonVal, nil
			}
		}
		time.Sleep(100 * time.Millisecond)
	}

	// Deterministic fallback from address string hash
	alamatLower := strings.ToLower(alamat)
	var sum int
	for _, char := range alamat {
		sum += int(char)
	}
	latOffset := (float64(sum%80) + 20.0) / 1000.0
	lngOffset := (float64((sum*3)%80) + 20.0) / 1000.0
	if sum%2 == 0 {
		latOffset = -latOffset
	}
	if (sum/3)%2 == 0 {
		lngOffset = -lngOffset
	}

	// City-aware offsets for known regions
	if fallbackLat > -6.5 && fallbackLat < -5.9 {
		switch {
		case strings.Contains(alamatLower, "tangerang"):
			latOffset, lngOffset = -0.15-(float64(sum%50)/1000.0), -0.25-(float64(sum%50)/1000.0)
		case strings.Contains(alamatLower, "bekasi"):
			latOffset, lngOffset = -0.05-(float64(sum%50)/1000.0), 0.22+(float64(sum%50)/1000.0)
		case strings.Contains(alamatLower, "bogor"):
			latOffset, lngOffset = -0.45-(float64(sum%50)/1000.0), 0.05+(float64(sum%50)/1000.0)
		case strings.Contains(alamatLower, "depok"):
			latOffset, lngOffset = -0.22-(float64(sum%50)/1000.0), -0.05-(float64(sum%50)/1000.0)
		}
	}
	if fallbackLat > -8.2 && fallbackLat < -7.5 {
		switch {
		case strings.Contains(alamatLower, "gunung kidul") || strings.Contains(alamatLower, "wonosari"):
			latOffset, lngOffset = -0.32-(float64(sum%80)/1000.0), 0.35+(float64(sum%80)/1000.0)
		case strings.Contains(alamatLower, "kulon progo") || strings.Contains(alamatLower, "wates"):
			latOffset, lngOffset = -0.15-(float64(sum%80)/1000.0), -0.38-(float64(sum%80)/1000.0)
		case strings.Contains(alamatLower, "bantul"):
			latOffset, lngOffset = -0.18-(float64(sum%50)/1000.0), -0.05-(float64(sum%50)/1000.0)
		case strings.Contains(alamatLower, "sleman"):
			latOffset, lngOffset = 0.08+(float64(sum%80)/1000.0), 0.02+(float64(sum%80)/1000.0)
		}
	}

	return fallbackLat + latOffset, fallbackLong + lngOffset, nil
}

func calculateDistance(db *pgxpool.Pool, originLat, originLng, destLat, destLng float64) (float64, error) {
	ctx := context.Background()
	var distance float64

	// If origin and destination are virtually identical (< 5 meters)
	if math.Abs(originLat-destLat) < 0.00005 && math.Abs(originLng-destLng) < 0.00005 {
		return 0.0, nil
	}

	// Check route cache using indexed range query (0.0001 deg is ~11 meters)
	err := db.QueryRow(ctx, `
	SELECT distance_km FROM route_cache 
	WHERE (origin_lat BETWEEN $1 - 0.0001 AND $1 + 0.0001)
	  AND (origin_long BETWEEN $2 - 0.0001 AND $2 + 0.0001)
	  AND (dest_lat BETWEEN $3 - 0.0001 AND $3 + 0.0001)
	  AND (dest_long BETWEEN $4 - 0.0001 AND $4 + 0.0001)
	LIMIT 1;`, originLat, originLng, destLat, destLng).Scan(&distance)
	if err == nil {
		return distance, nil
	}

	apiSuccess := false

	hereKey := os.Getenv("HERE_MAPS_API_KEY")
	if hereKey != "" {
		u := fmt.Sprintf("https://router.hereapi.com/v8/routes?transportMode=car&origin=%f,%f&destination=%f,%f&return=summary&apiKey=%s",
			originLat, originLng, destLat, destLng, hereKey)
		httpClient := &http.Client{Timeout: 4000 * time.Millisecond}
		resp, err := httpClient.Get(u)
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				var data struct {
					Routes []struct {
						Sections []struct {
							Summary struct {
								Length int `json:"length"`
							} `json:"summary"`
						} `json:"sections"`
					} `json:"routes"`
				}
				if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && len(data.Routes) > 0 && len(data.Routes[0].Sections) > 0 {
					distance = float64(data.Routes[0].Sections[0].Summary.Length) / 1000.0
					apiSuccess = true
				}
			}
		}
	}

	if !apiSuccess {
		apiKey := os.Getenv("GOOGLE_MAPS_API_KEY")
		if apiKey != "" {
			u := fmt.Sprintf("https://maps.googleapis.com/maps/api/distancematrix/json?origins=%f,%f&destinations=%f,%f&key=%s",
				originLat, originLng, destLat, destLng, apiKey)
			httpClient := &http.Client{Timeout: 4000 * time.Millisecond}
			resp, err := httpClient.Get(u)
			if err == nil {
				defer resp.Body.Close()
				if resp.StatusCode == http.StatusOK {
					var data struct {
						Rows []struct {
							Elements []struct {
								Distance struct {
									Value int `json:"value"`
								} `json:"distance"`
								Status string `json:"status"`
							} `json:"elements"`
						} `json:"rows"`
						Status string `json:"status"`
					}
					if err := json.NewDecoder(resp.Body).Decode(&data); err == nil &&
						data.Status == "OK" && len(data.Rows) > 0 &&
						len(data.Rows[0].Elements) > 0 && data.Rows[0].Elements[0].Status == "OK" {
						distance = float64(data.Rows[0].Elements[0].Distance.Value) / 1000.0
						apiSuccess = true
					}
				}
			}
		}
	}

	if !apiSuccess {
		u := fmt.Sprintf("http://router.project-osrm.org/route/v1/driving/%f,%f;%f,%f?overview=false",
			originLng, originLat, destLng, destLat)
		httpClient := &http.Client{Timeout: 4000 * time.Millisecond}
		resp, err := httpClient.Get(u)
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				var data struct {
					Routes []struct {
						Distance float64 `json:"distance"`
					} `json:"routes"`
					Code string `json:"code"`
				}
				if err := json.NewDecoder(resp.Body).Decode(&data); err == nil && data.Code == "Ok" && len(data.Routes) > 0 {
					distance = data.Routes[0].Distance / 1000.0
					apiSuccess = true
				}
			}
		}
	}

	if !apiSuccess {
		distance = haversineDistance(originLat, originLng, destLat, destLng) * 1.4
	}

	// Store in cache
	_, _ = db.Exec(ctx, `
	INSERT INTO route_cache (origin_lat, origin_long, dest_lat, dest_long, distance_km)
	VALUES ($1, $2, $3, $4, $5);`, originLat, originLng, destLat, destLng, distance)

	return distance, nil
}

func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	return R * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

// UpdateOrderPickup handles driver uploading pickup proof
func (h *AdminHandler) UpdateOrderPickup(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		PickupPhoto string `json:"pickup_photo" binding:"required"`
		PickupNote  string `json:"pickup_note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()

	// Retrieve order driver_id, dispatch_id, and parent_order_number
	var currentDriverID int
	var dispatchID, parentOrderNum, orderNum string
	_ = h.DB.QueryRow(ctx, "SELECT COALESCE(driver_id, 0), COALESCE(dispatch_id, ''), COALESCE(parent_order_number, ''), COALESCE(order_number, '') FROM orders WHERE id = $1", orderID).Scan(&currentDriverID, &dispatchID, &parentOrderNum, &orderNum)

	batchMatch := dispatchID
	if batchMatch == "" {
		batchMatch = parentOrderNum
	}
	if batchMatch == "" && strings.Contains(orderNum, "-") {
		parts := strings.Split(orderNum, "-")
		if len(parts) >= 2 {
			batchMatch = parts[0] + "-" + parts[1] // e.g. ORDER-000018
		}
	}

	if batchMatch != "" {
		// Update ALL sibling orders in the SAME dispatch/batch group
		_, err := h.DB.Exec(ctx,
			`UPDATE orders 
			 SET status = 'DELIVERING', pickup_photo_url = $1, pickup_note = $2 
			 WHERE (
			   (dispatch_id <> '' AND dispatch_id = $3) OR 
			   (parent_order_number <> '' AND parent_order_number = $4) OR 
			   (order_number LIKE $5 || '%') OR 
			   id::text = $6
			 )`,
			req.PickupPhoto, req.PickupNote, dispatchID, parentOrderNum, batchMatch, orderID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memperbarui status pickup batch: " + err.Error()})
			return
		}
	} else {
		_, err := h.DB.Exec(ctx,
			`UPDATE orders 
			 SET status = 'DELIVERING', pickup_photo_url = $1, pickup_note = $2 
			 WHERE id = $3`,
			req.PickupPhoto, req.PickupNote, orderID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memperbarui status pickup: " + err.Error()})
			return
		}
	}

	// Trigger Notifications for DELIVERING status transition
	var driverID, mitraID *int
	var pharmName, customerName string
	err := h.DB.QueryRow(ctx, "SELECT driver_id, mitra_id, pharmacy_name, customer_name, order_number FROM orders WHERE id = $1", orderID).Scan(&driverID, &mitraID, &pharmName, &customerName, &orderNum)
	if err == nil {
		if driverID != nil {
			title := "Pesanan DALAM PENGANTARAN (DELIVERING)"
			message := fmt.Sprintf("Order %s (%s) telah diambil di apotek dan sedang DALAM PENGANTARAN menuju penerima %s.", orderNum, pharmName, customerName)
			_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, message)
		}
		if mitraID != nil {
			title := "Pesanan DALAM PENGANTARAN (DELIVERING)"
			message := fmt.Sprintf("Order %s (%s) telah berhasil diambil oleh kurir dan sedang DALAM PENGANTARAN.", orderNum, pharmName)
			_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)", *mitraID, title, message)
		}
		NotifyAdmins(ctx, h.DB, "Pesanan DALAM PENGANTARAN (DELIVERING)", fmt.Sprintf("Order %s (%s) telah diambil oleh kurir driver.", orderNum, pharmName))
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Status berhasil diubah menjadi ON DELIVERY"})
}

// UpdateOrderArrived handles driver uploading arrival proof photo when arriving at location
func (h *AdminHandler) UpdateOrderArrived(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		ArrivedPhoto string `json:"arrived_photo" binding:"required"`
		ArrivedNote  string `json:"arrived_note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders 
		 SET arrived_photo_url = $1, arrived_note = $2 
		 WHERE id = $3`,
		req.ArrivedPhoto, req.ArrivedNote, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan foto tiba di lokasi: " + err.Error()})
		return
	}

	// Trigger Notification for Arrived event
	var driverID, mitraID *int
	var dispatchID, orderNum, pharmName string
	_ = h.DB.QueryRow(ctx, "SELECT driver_id, mitra_id, COALESCE(dispatch_id, ''), order_number, COALESCE(pharmacy_name, customer_name) FROM orders WHERE id = $1", orderID).Scan(&driverID, &mitraID, &dispatchID, &orderNum, &pharmName)
	
	var totalStops, stopNum int
	if dispatchID != "" {
		_ = h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE dispatch_id = $1", dispatchID).Scan(&totalStops)
		_ = h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE dispatch_id = $1 AND id <= $2", dispatchID, orderID).Scan(&stopNum)
	}
	if totalStops == 0 { totalStops = 1; stopNum = 1 }

	var driverName, driverPlate string
	if driverID != nil {
		_ = h.DB.QueryRow(ctx, "SELECT u.name, COALESCE(dp.plate_number, '') FROM users u LEFT JOIN driver_profiles dp ON dp.user_id = u.id WHERE u.id = $1", *driverID).Scan(&driverName, &driverPlate)
	}

	targetID := dispatchID
	if targetID == "" { targetID = orderNum }

	title := "Kurir Tiba di Lokasi"
	msg := fmt.Sprintf("Driver %s (%s) telah tiba di %s (Titik %d dari %d Titik) order %s.", driverName, driverPlate, pharmName, stopNum, totalStops, targetID)
	
	if driverID != nil { _, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, msg) }
	if mitraID != nil { _, _ = h.DB.Exec(ctx, "INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)", *mitraID, title, msg) }
	NotifyAdmins(ctx, h.DB, title, msg)

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Bukti tiba di lokasi berhasil disimpan"})
}

// UpdateOrderReject handles driver rejecting a stop pickup
func (h *AdminHandler) UpdateOrderReject(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		RejectPhoto  string `json:"reject_photo" binding:"required"`
		RejectNote   string `json:"reject_note" binding:"required"`
		RejectReason string `json:"reject_reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders 
		 SET status = 'REJECTED_WAITING_APPROVAL', reject_photo_url = $1, reject_note = $2, reject_reason = $3 
		 WHERE id = $4`,
		req.RejectPhoto, req.RejectNote, req.RejectReason, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses penolakan: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Penolakan berhasil diajukan, menunggu persetujuan Admin"})
}

// AdminApproveReject handles admin approving/denying a driver's rejection
func (h *AdminHandler) AdminApproveReject(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		Approve bool `json:"approve"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	status := "WAITING_FOR_PICKUP"
	if req.Approve {
		status = "CANCELLED"
	}

	_, err := h.DB.Exec(ctx,
		`UPDATE orders 
		 SET status = $1, reject_approved = $2 
		 WHERE id = $3`,
		status, req.Approve, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses keputusan penolakan: " + err.Error()})
		return
	}

	// Trigger Notification
	var driverID *int
	var orderNum, pharmName string
	err = h.DB.QueryRow(ctx, "SELECT driver_id, order_number, pharmacy_name FROM orders WHERE id = $1", orderID).Scan(&driverID, &orderNum, &pharmName)
	if err == nil && driverID != nil {
		var title, message string
		if req.Approve {
			title = "Penolakan Disetujui"
			message = fmt.Sprintf("Permohonan penolakan pickup pesanan %s di %s telah DISETUJUI oleh Admin.", orderNum, pharmName)
		} else {
			title = "Penolakan Ditolak"
			message = fmt.Sprintf("Permohonan penolakan pickup pesanan %s di %s telah DITOLAK oleh Admin. Silakan lakukan pickup ulang.", orderNum, pharmName)
		}
		_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, message)
	}

	msg := "Penolakan ditolak, status order dikembalikan ke WAITING FOR PICKUP"
	if req.Approve {
		msg = "Penolakan disetujui, status order menjadi REJECTED / CANCELLED"
	}
	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: msg})
}

// UnboxOrder handles driver or pharmacist submitting direct unboxing
func (h *AdminHandler) UnboxOrder(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		CheckedInvoices    string `json:"checked_invoices"`
		ExtraItemsNote     string `json:"extra_items_note"`
		ExtraItemsPhotoUrl string `json:"extra_items_photo_url"`
		FacturePhotoUrl    string `json:"facture_photo_url"`
		SignaturePhotoUrl  string `json:"signature_photo_url"`
		HandoverPhotoUrl   string `json:"handover_photo_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	now := time.Now()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders 
		 SET status = 'READY_FOR_PICKUP_FACTURE', unboxing_option = 'UNBOXING', 
		     checked_invoices = COALESCE(NULLIF($1, ''), checked_invoices), 
		     extra_items_note = COALESCE(NULLIF($2, ''), extra_items_note), 
		     extra_items_photo_url = COALESCE(NULLIF($3, ''), extra_items_photo_url), 
		     facture_photo_url = COALESCE(NULLIF($4, ''), facture_photo_url), 
		     signature_photo_url = COALESCE(NULLIF($5, ''), signature_photo_url), 
		     handover_photo_url = COALESCE(NULLIF($6, ''), handover_photo_url), 
		     completed_at = $7 
		 WHERE id = $8`,
		req.CheckedInvoices, req.ExtraItemsNote, req.ExtraItemsPhotoUrl, req.FacturePhotoUrl, req.SignaturePhotoUrl, req.HandoverPhotoUrl, now, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan hasil unboxing: " + err.Error()})
		return
	}

	// Trigger Notification for driver, mitra, and admin
	var driverID, mitraID *int
	var pharmName, pharmAddress, orderNum string
	err = h.DB.QueryRow(ctx, "SELECT driver_id, mitra_id, pharmacy_name, pharmacy_address, order_number FROM orders WHERE id = $1", orderID).Scan(&driverID, &mitraID, &pharmName, &pharmAddress, &orderNum)
	if err == nil {
		if driverID != nil {
			title := "Faktur Siap Diambil"
			message := fmt.Sprintf("Faktur dari alamat %s (%s) sudah selesai di-unbox, silakan kembali ke Gudang K-24.", pharmName, pharmAddress)
			_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, message)
		}
		if mitraID != nil {
			title := "Unboxing Selesai"
			message := fmt.Sprintf("Apoteker di %s telah memverifikasi faktur pesanan %s.", pharmName, orderNum)
			_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)", *mitraID, title, message)
		}
		NotifyAdmins(ctx, h.DB, "Verifikasi Apoteker Selesai", fmt.Sprintf("Faktur pesanan %s (%s) telah diverifikasi oleh Apoteker.", orderNum, pharmName))
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Unboxing selesai, order diset menjadi COMPLETED"})
}

// WaitUnboxOrder handles pharmacist choosing to wait for unboxing later
func (h *AdminHandler) WaitUnboxOrder(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Alasan tunda unboxing wajib diisi"})
		return
	}

	ctx := context.Background()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders 
		 SET status = 'PENDING', unboxing_option = 'WAITING_FOR_UNBOXING', extra_items_note = $1 
		 WHERE id = $2`,
		req.Reason, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memperbarui opsi unboxing: " + err.Error()})
		return
	}

	// Trigger Notification for driver: "Unboxing untuk pesanan X ditunda oleh apoteker"
	var driverID *int
	var pharmName, orderNum string
	err = h.DB.QueryRow(ctx, "SELECT driver_id, pharmacy_name, order_number FROM orders WHERE id = $1", orderID).Scan(&driverID, &pharmName, &orderNum)
	if err == nil && driverID != nil {
		title := "Unboxing Ditunda"
		message := fmt.Sprintf("Unboxing untuk pesanan %s di apotek %s ditunda. Alasan: \"%s\".", orderNum, pharmName, req.Reason)
		_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, message)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Opsi WAITING FOR UNBOXING disimpan dengan alasan tunda"})
}

// StartUnboxOrder sets unboxing_option = 'UNBOXING' when pharmacist starts unboxing
func (h *AdminHandler) StartUnboxOrder(c *gin.Context) {
	orderID := c.Param("id")
	ctx := context.Background()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders SET unboxing_option = 'UNBOXING' WHERE id = $1`,
		orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memulai unboxing: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Unboxing dimulai"})
}

// UpdateOrderFacture handles driver uploading physical signed invoice photo
func (h *AdminHandler) UpdateOrderFacture(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		FacturePhoto string `json:"facture_photo" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	now := time.Now()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders 
		 SET status = 'COMPLETED', facture_photo_url = $1, completed_at = $2 
		 WHERE id = $3`,
		req.FacturePhoto, now, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengunggah foto faktur: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Unggah faktur berhasil, order selesai (COMPLETED)"})
}

// AdminApproveFacture handles admin/mitra approving or rejecting the driver's uploaded physical facture photo
func (h *AdminHandler) AdminApproveFacture(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		Approve bool `json:"approve"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	status := "READY_FOR_PICKUP_FACTURE" // If rejected, driver needs to re-upload
	if req.Approve {
		status = "COMPLETED" // If approved, it is completed
	}

	_, err := h.DB.Exec(ctx,
		`UPDATE orders SET status = $1 WHERE id = $2`,
		status, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses keputusan faktur: " + err.Error()})
		return
	}

	// Trigger Notification
	var driverID *int
	var orderNum, pharmName string
	err = h.DB.QueryRow(ctx, "SELECT driver_id, order_number, pharmacy_name FROM orders WHERE id = $1", orderID).Scan(&driverID, &orderNum, &pharmName)
	if err == nil && driverID != nil {
		var title, message string
		if req.Approve {
			title = "Faktur Disetujui"
			message = fmt.Sprintf("Faktur fisik untuk pesanan %s di %s telah DISETUJUI oleh Admin. Pesanan selesai.", orderNum, pharmName)
		} else {
			title = "Faktur Ditolak"
			message = fmt.Sprintf("Faktur fisik untuk pesanan %s di %s telah DITOLAK oleh Admin. Silakan upload ulang foto faktur baru yang valid.", orderNum, pharmName)
		}
		_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, message)
	}

	msg := "Persetujuan faktur ditolak, driver harus mengunggah ulang"
	if req.Approve {
		msg = "Persetujuan faktur disetujui, order selesai (COMPLETED)"
	}
	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: msg})
}

// PublicApprovePOD handles staff K-24 scanning QR code and clicking DONE button to approve POD return and mark order COMPLETED
func (h *AdminHandler) PublicApprovePOD(c *gin.Context) {
	orderID := c.Param("id")
	ctx := context.Background()

	now := time.Now()
	_, err := h.DB.Exec(ctx,
		`UPDATE orders SET status = 'COMPLETED', completed_at = $1 WHERE id = $2`,
		now, orderID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses persetujuan POD: " + err.Error()})
		return
	}

	// Trigger Notification for driver
	var driverID *int
	var pharmName, orderNum string
	err = h.DB.QueryRow(ctx, "SELECT driver_id, pharmacy_name, order_number FROM orders WHERE id = $1", orderID).Scan(&driverID, &pharmName, &orderNum)
	if err == nil && driverID != nil {
		title := "Pengembalian POD Disetujui (Done)"
		message := fmt.Sprintf("Verifikasi pengembalian POD pesanan %s (%s) telah DISETUJUI oleh K-24. Pesanan SELESAI (COMPLETED).", orderNum, pharmName)
		_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, title, message)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Pengembalian POD berhasil disetujui (COMPLETED)"})
}

// CompletePODOrder handles driver completing POD return stage with POD digital signature
func (h *AdminHandler) CompletePODOrder(c *gin.Context) {
	orderID := c.Param("id")
	var req struct {
		PodSignaturePhotoUrl string `json:"pod_signature_photo_url"`
		FacturePhotoUrl      string `json:"facture_photo_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	now := time.Now()

	// Find target order's parent_order_number and dispatch_id
	var parentOrderNum, dispatchID string
	_ = h.DB.QueryRow(ctx, "SELECT COALESCE(parent_order_number, ''), COALESCE(dispatch_id, '') FROM orders WHERE id = $1", orderID).Scan(&parentOrderNum, &dispatchID)

	targetMatch := dispatchID
	if targetMatch == "" {
		targetMatch = parentOrderNum
	}

	var err error
	if targetMatch != "" {
		_, err = h.DB.Exec(ctx,
			`UPDATE orders 
			 SET status = 'COMPLETED', 
			     pod_signature_photo_url = COALESCE(NULLIF($1, ''), pod_signature_photo_url), 
			     facture_photo_url = COALESCE(NULLIF($2, ''), facture_photo_url), 
			     completed_at = $3 
			 WHERE dispatch_id = $4 OR parent_order_number = $4 OR order_number = $4 OR id::text = $4`,
			req.PodSignaturePhotoUrl, req.FacturePhotoUrl, now, targetMatch,
		)
	} else {
		_, err = h.DB.Exec(ctx,
			`UPDATE orders 
			 SET status = 'COMPLETED', 
			     pod_signature_photo_url = COALESCE(NULLIF($1, ''), pod_signature_photo_url), 
			     facture_photo_url = COALESCE(NULLIF($2, ''), facture_photo_url), 
			     completed_at = $3 
			 WHERE id::text = $4 OR order_number = $4`,
			req.PodSignaturePhotoUrl, req.FacturePhotoUrl, now, orderID,
		)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyelesaikan pengembalian POD: " + err.Error()})
		return
	}

	// Trigger Notification for driver, mitra, and admin
	var driverID, mitraID *int
	var pharmName, orderNum, delivAddress, custName string
	err = h.DB.QueryRow(ctx, "SELECT driver_id, mitra_id, pharmacy_name, order_number, COALESCE(delivery_address, ''), COALESCE(customer_name, '') FROM orders WHERE id::text = $1 OR order_number = $1", orderID).Scan(&driverID, &mitraID, &pharmName, &orderNum, &delivAddress, &custName)
	if err == nil {
		targetDispatch := dispatchID
		if targetDispatch == "" {
			targetDispatch = parentOrderNum
		}
		if targetDispatch == "" {
			targetDispatch = orderNum
		}

		var totalOrders, completedOrders int
		if targetDispatch != "" {
			_ = h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE dispatch_id = $1 OR parent_order_number = $1 OR order_number = $1", targetDispatch).Scan(&totalOrders)
			_ = h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE (dispatch_id = $1 OR parent_order_number = $1 OR order_number = $1) AND status = 'COMPLETED'", targetDispatch).Scan(&completedOrders)
		}

		var driverTitle, driverMsg, mitraTitle, mitraMsg, adminTitle, adminMsg string

		if totalOrders > 1 {
			remaining := totalOrders - completedOrders
			if remaining > 0 {
				driverTitle = fmt.Sprintf("Progress [%d/%d] Order Selesai", completedOrders, totalOrders)
				driverMsg = fmt.Sprintf("[%d/%d] Order %s ke %s (%s) SELESAI. Sisa %d alamat lagi dalam pengantaran.", completedOrders, totalOrders, orderNum, custName, delivAddress, remaining)

				mitraTitle = fmt.Sprintf("Progress [%d/%d] Alamat Diantar", completedOrders, totalOrders)
				mitraMsg = fmt.Sprintf("[%d/%d] Order %s di alamat %s (%s) telah SELESAI diantar. Sisa %d alamat lagi.", completedOrders, totalOrders, orderNum, delivAddress, custName, remaining)

				adminTitle = fmt.Sprintf("Progress [%d/%d] Order Batch %s", completedOrders, totalOrders, targetDispatch)
				adminMsg = fmt.Sprintf("[%d/%d] Order %s (%s) selesai diantar ke %s. Sisa %d alamat.", completedOrders, totalOrders, orderNum, pharmName, custName, remaining)
			} else {
				driverTitle = fmt.Sprintf("Pengantaran [%d/%d] Alamat SELESAI", totalOrders, totalOrders)
				driverMsg = fmt.Sprintf("Seluruh %d alamat pengantaran untuk Order %s (%s) telah SELESAI (COMPLETED).", totalOrders, orderNum, pharmName)

				mitraTitle = fmt.Sprintf("Pesanan SELESAI [%d/%d Alamat Done]", totalOrders, totalOrders)
				mitraMsg = fmt.Sprintf("Seluruh %d alamat pengantaran untuk Order %s (%s) telah berhasil diantar.", totalOrders, orderNum, pharmName)

				adminTitle = fmt.Sprintf("Pesanan SELESAI [%d/%d Done]", totalOrders, totalOrders)
				adminMsg = fmt.Sprintf("Seluruh %d alamat untuk Order Batch %s (%s) telah COMPLETED.", totalOrders, targetDispatch, pharmName)
			}
		} else {
			driverTitle = "Pengembalian POD Selesai"
			driverMsg = fmt.Sprintf("Verifikasi pengembalian POD pesanan %s (%s) telah SELESAI (COMPLETED).", orderNum, pharmName)

			mitraTitle = "Pesanan SELESAI (COMPLETED)"
			mitraMsg = fmt.Sprintf("Verifikasi pengembalian POD pesanan %s (%s) telah disetujui dan SELESAI (DONE).", orderNum, pharmName)

			adminTitle = "Pesanan SELESAI (DONE)"
			adminMsg = fmt.Sprintf("Order %s (%s) telah resmi COMPLETED setelah verifikasi POD.", orderNum, pharmName)
		}

		if driverID != nil {
			_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", *driverID, driverTitle, driverMsg)
		}
		if mitraID != nil {
			_, _ = h.DB.Exec(ctx, "INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)", *mitraID, mitraTitle, mitraMsg)
		}
		NotifyAdmins(ctx, h.DB, adminTitle, adminMsg)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Pengembalian POD berhasil diselesaikan (COMPLETED)"})
}

// GetPublicOrderDetail fetches order stop details for the pharmacist including all sibling orders for tabbed view
func (h *AdminHandler) GetPublicOrderDetail(c *gin.Context) {
	orderID := c.Param("id")
	ctx := context.Background()

	var o models.Order
	var medicineSummary string
	err := h.DB.QueryRow(ctx,
		`SELECT id, order_number, status, pharmacy_name, pharmacy_address, delivery_address, 
		        customer_name, customer_phone, medicine_summary, delivery_fee, created_at,
		        COALESCE(parent_order_number, ''), COALESCE(dispatch_id, ''),
		        COALESCE(unboxing_option, ''), COALESCE(checked_invoices, ''),
		        COALESCE(extra_items_note, ''), COALESCE(extra_items_photo_url, ''),
		        COALESCE(facture_photo_url, ''), COALESCE(pod_signature_photo_url, '')
		 FROM orders WHERE id::text = $1 OR order_number = $1 OR dispatch_id = $1 LIMIT 1`, orderID,
	).Scan(
		&o.ID, &o.OrderNumber, &o.Status, &o.PharmacyName, &o.PharmacyAddress, &o.DeliveryAddress,
		&o.CustomerName, &o.CustomerPhone, &medicineSummary, &o.DeliveryFee, &o.CreatedAt,
		&o.ParentOrderNumber, &o.DispatchID,
		&o.UnboxingOption, &o.CheckedInvoices, &o.ExtraItemsNote, &o.ExtraItemsPhotoUrl,
		&o.FacturePhotoUrl, &o.PODSignaturePhotoUrl,
	)

	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, models.APIResponse{Status: "error", Message: "Order tidak ditemukan"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil data order: " + err.Error()})
		return
	}

	// Parse main order invoices
	var invoices []string
	if parts := strings.SplitN(medicineSummary, "Invoices: ", 2); len(parts) == 2 {
		invoices = strings.Split(parts[1], ", ")
	}

	// Fetch all sibling orders in this dispatch batch if dispatch_id or parent_order_number is present
	type SiblingOrderInfo struct {
		ID                   int      `json:"id"`
		OrderNumber          string   `json:"order_number"`
		PharmacyName         string   `json:"pharmacy_name"`
		DeliveryAddress      string   `json:"delivery_address"`
		CustomerName         string   `json:"customer_name"`
		Status               string   `json:"status"`
		UnboxingOption       string   `json:"unboxing_option"`
		CheckedInvoices      string   `json:"checked_invoices"`
		Invoices             []string `json:"invoices"`
		FacturePhotoUrl      string   `json:"facture_photo_url"`
		PodSignaturePhotoUrl string   `json:"pod_signature_photo_url"`
		ExtraItemsNote       string   `json:"extra_items_note"`
		ExtraItemsPhotoUrl   string   `json:"extra_items_photo_url"`
	}

	allOrders := []SiblingOrderInfo{}

	querySiblings := `
		SELECT id, order_number, pharmacy_name, delivery_address, customer_name, status,
		       COALESCE(unboxing_option, ''), COALESCE(checked_invoices, ''),
		       medicine_summary, COALESCE(facture_photo_url, ''),
		       COALESCE(pod_signature_photo_url, ''), COALESCE(extra_items_note, ''),
		       COALESCE(extra_items_photo_url, '')
		FROM orders 
		WHERE (dispatch_id != '' AND dispatch_id = $1)
		   OR ((dispatch_id IS NULL OR dispatch_id = '') AND parent_order_number != '' AND parent_order_number = $2)
		   OR id = $3
		ORDER BY id ASC`

	rows, err := h.DB.Query(ctx, querySiblings, o.DispatchID, o.ParentOrderNumber, o.ID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var sib SiblingOrderInfo
			var medSum string
			if err := rows.Scan(
				&sib.ID, &sib.OrderNumber, &sib.PharmacyName, &sib.DeliveryAddress, &sib.CustomerName, &sib.Status,
				&sib.UnboxingOption, &sib.CheckedInvoices, &medSum, &sib.FacturePhotoUrl,
				&sib.PodSignaturePhotoUrl, &sib.ExtraItemsNote, &sib.ExtraItemsPhotoUrl,
			); err == nil {
				if parts := strings.SplitN(medSum, "Invoices: ", 2); len(parts) == 2 {
					sib.Invoices = strings.Split(parts[1], ", ")
				}
				allOrders = append(allOrders, sib)
			}
		}
	}

	// Fallback if no siblings returned
	if len(allOrders) == 0 {
		allOrders = append(allOrders, SiblingOrderInfo{
			ID:                   o.ID,
			OrderNumber:          o.OrderNumber,
			PharmacyName:         o.PharmacyName,
			DeliveryAddress:      o.DeliveryAddress,
			CustomerName:         o.CustomerName,
			Status:               o.Status,
			UnboxingOption:       o.UnboxingOption,
			CheckedInvoices:      o.CheckedInvoices,
			Invoices:             invoices,
			FacturePhotoUrl:      o.FacturePhotoUrl,
			PodSignaturePhotoUrl: o.PODSignaturePhotoUrl,
			ExtraItemsNote:       o.ExtraItemsNote,
			ExtraItemsPhotoUrl:   o.ExtraItemsPhotoUrl,
		})
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status: "success",
		Data: map[string]interface{}{
			"order":      o,
			"invoices":   invoices,
			"all_orders": allOrders,
		},
	})
}


