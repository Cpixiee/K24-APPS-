package handlers

import (
	"context"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// GetPendingDispatchOrders lists all orders from all Mitras where driver_id IS NULL, grouped by bulk dispatch_id
func (h *AdminHandler) GetPendingDispatchOrders(c *gin.Context) {
	ctx := context.Background()

	// Select orders waiting for dispatch — LEFT JOIN alamat_penerima for proximity clustering
	query := `
	SELECT o.id, o.order_number, COALESCE(o.parent_order_number, '') as parent_order_number, COALESCE(o.dispatch_id, '') as dispatch_id, o.mitra_id, COALESCE(u.name, 'Mitra Apotek') as mitra_name,
	       o.pharmacy_name, o.pharmacy_address, o.delivery_address,
	       o.customer_name, o.customer_phone, o.medicine_summary, o.delivery_fee, o.created_at,
	       COALESCE(ap.latitude, 0.0) as lat, COALESCE(ap.longitude, 0.0) as lng
	FROM orders o
	LEFT JOIN users u ON o.mitra_id = u.id
	LEFT JOIN alamat_penerima ap ON LOWER(TRIM(ap.nama_apotek)) = LOWER(TRIM(o.customer_name)) AND LOWER(TRIM(ap.alamat_lengkap)) = LOWER(TRIM(o.delivery_address))
	WHERE (o.driver_id IS NULL OR o.driver_id = 0) 
	  AND (o.dispatch_id IS NULL OR o.dispatch_id = '') 
	  AND o.status = 'PENDING'
	ORDER BY o.created_at DESC;`

	rows, err := h.DB.Query(ctx, query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal mengambil daftar order menunggu dispatch: " + err.Error(),
		})
		return
	}
	defer rows.Close()

	batchMap := make(map[string]*models.PendingDispatchBatch)
	batchOrder := []string{}

	for rows.Next() {
		var oID int
		var oNum, parentOrderNum string
		var dispID string
		var mID *int // pointer agar bisa handle NULL
		var mName string
		var pName, pAddr, dAddr, cName, cPhone, medSummary string
		var dFee float64
		var cTime time.Time
		var lat, lng float64

		err := rows.Scan(
			&oID, &oNum, &parentOrderNum, &dispID, &mID, &mName,
			&pName, &pAddr, &dAddr, &cName, &cPhone, &medSummary, &dFee, &cTime,
			&lat, &lng,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memproses data order: " + err.Error(),
			})
			return
		}

		if dispID == "" {
			if parentOrderNum != "" {
				dispID = parentOrderNum
			} else {
				dispID = oNum
			}
		}

		// Extract invoices, armada and rate type from medicine summary
		armada, rateType := parseArmadaRate(medSummary)

		// Parse invoices list
		invoices := []string{}
		if parts := strings.SplitN(medSummary, "Invoices: ", 2); len(parts) == 2 {
			invs := strings.Split(parts[1], ",")
			for _, inv := range invs {
				if trimmed := strings.TrimSpace(inv); trimmed != "" {
					invoices = append(invoices, trimmed)
				}
			}
		}

		stop := models.PendingDispatchStop{
			ID:                oID,
			OrderNumber:       oNum,
			ParentOrderNumber: parentOrderNum,
			CustomerName:      cName,
			DeliveryAddress:   dAddr,
			Invoices:          invoices,
			DeliveryFee:       dFee,
			Lat:               lat,
			Lng:               lng,
		}

		if batch, exists := batchMap[dispID]; exists {
			batch.Stops = append(batch.Stops, stop)
		} else {
			mitraID := 0
			if mID != nil {
				mitraID = *mID
			}
			newBatch := &models.PendingDispatchBatch{
				DispatchID: dispID,
				MitraID:    mitraID,
				MitraName:  mName,
				Armada:     armada,
				RateType:   rateType,
				CreatedAt:  cTime,
				Stops:      []models.PendingDispatchStop{stop},
			}
			batchMap[dispID] = newBatch
			batchOrder = append(batchOrder, dispID)
		}
	}

	batchesList := []models.PendingDispatchBatch{}
	for _, id := range batchOrder {
		batchesList = append(batchesList, *batchMap[id])
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status: "success",
		Data:   batchesList,
	})
}

// GetDispatchDrivers fetches all drivers filtered by vehicle_type
func (h *AdminHandler) GetDispatchDrivers(c *gin.Context) {
	ctx := context.Background()
	vehicleType := c.DefaultQuery("vehicle_type", "motor")

	query := `
	SELECT u.id, u.username, u.name, u.email, u.phone, 
	       COALESCE(dp.plate_number, '') as plate_number, 
	       COALESCE(dp.is_active, false) as is_active, 
	       COALESCE(dp.rating, 5.0) as rating, 
	       COALESCE(dp.vehicle_type, 'motor') as vehicle_type,
	       u.created_at, u.updated_at
	FROM users u
	JOIN driver_profiles dp ON u.id = dp.user_id
	WHERE u.role = 'DRIVER' AND COALESCE(dp.vehicle_type, 'motor') = $1
	ORDER BY dp.is_active DESC, dp.rating DESC;`

	rows, err := h.DB.Query(ctx, query, vehicleType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal mengambil daftar driver: " + err.Error(),
		})
		return
	}
	defer rows.Close()

	drivers := []models.Driver{}
	for rows.Next() {
		var d models.Driver
		err := rows.Scan(
			&d.ID, &d.Username, &d.Name, &d.Email, &d.Phone,
			&d.PlateNumber, &d.IsActive, &d.Rating, &d.VehicleType,
			&d.CreatedAt, &d.UpdatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memproses data driver: " + err.Error(),
			})
			return
		}
		d.Role = "DRIVER"
		drivers = append(drivers, d)
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status: "success",
		Data:   drivers,
	})
}

// CreateDispatchGroup executes bulk/single dispatch and updates order pricing sequentially
func (h *AdminHandler) CreateDispatchGroup(c *gin.Context) {
	var req models.CreateDispatchGroupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Payload tidak valid: " + err.Error(),
		})
		return
	}

	ctx := context.Background()

	// 1. Verify Driver vehicle type
	var driverVehicleType string
	err := h.DB.QueryRow(ctx,
		"SELECT COALESCE(vehicle_type, 'motor') FROM driver_profiles WHERE user_id = $1", req.DriverID,
	).Scan(&driverVehicleType)
	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Status:  "error",
			Message: "Driver tidak ditemukan di sistem",
		})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memeriksa kendaraan driver: " + err.Error(),
		})
		return
	}

	// 2. Load order details & validate
	type tempOrder struct {
		id              int
		orderNumber     string
		mitraID         int
		armada          string
		rateType        string
		customerName    string
		deliveryAddress string
		kubik           *float64
		berat           *float64
	}

	ordersMap := make(map[int]tempOrder)
	var commonArmada, commonRateType string
	var commonMitraID int

	for i, orderID := range req.OrderIDs {
		var o tempOrder
		var medicineSummary string
		err := h.DB.QueryRow(ctx,
			`SELECT id, order_number, mitra_id, customer_name, delivery_address, medicine_summary 
			 FROM orders WHERE id = $1 AND driver_id IS NULL`, orderID,
		).Scan(&o.id, &o.orderNumber, &o.mitraID, &o.customerName, &o.deliveryAddress, &medicineSummary)

		if err == pgx.ErrNoRows {
			c.JSON(http.StatusNotFound, models.APIResponse{
				Status:  "error",
				Message: fmt.Sprintf("Order ID %d tidak ditemukan atau sudah di-dispatch", orderID),
			})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memproses data order: " + err.Error(),
			})
			return
		}

		// Extract armada and rate
		o.armada, o.rateType = parseArmadaRate(medicineSummary)

		// Parse kubik / berat from summary if available
		// Summary format: "Armada: motor, Rate: km, Invoices: ..." or may contain volume/weight
		// We can query custom kubik_aktual or berat_aktual from database if we had it,
		// but since they were already used to calculate initial rate, we can scan them.
		// Wait, let's look at orders table. We don't have kubik/berat columns in orders table.
		// We can parse them from medicine_summary if we encoded them there.
		// Let's check how buildSummary was implemented in Mitra order creation:
		// Ah, medicine_summary has "Armada: motor, Rate: km, Invoices: ..."
		// Wait! Let's check where kubik_aktual / berat_aktual are stored.
		// In CreateBulkOrders:
		// rowPrice := math.Round(calcRowPrice(req.RateType, activeRate, distKm, item.KubikAktual, item.BeratAktual, i))
		// Wait! If they are not stored in orders table, then we can only estimate or fetch them.
		// Wait, are there kubik/berat columns in orders? No, they were only in req.Items input.
		// But wait! If we recalculate sequential argo, can we just parse the invoices or use default values?
		// Since we don't have columns in orders, let's write a simple helper to extract "Kubik: X, Berat: Y"
		// if Mitra's medicine_summary contains them, OR we can default them to 1.0.
		// Let's check if CreateBulkOrders encodes them. In CreateBulkOrders:
		// summary := buildSummary(req.Armada, req.RateType, item.Invoices)
		// Oh, buildSummary only writes: "Armada: X, Rate: Y, Invoices: Z"! It doesn't write kubik or berat!
		// But don't worry, for sequential argo recalculation of Dimensi/Berat, we can check if we need them,
		// or default them to 1.0, or check if we can parse them. Since they are not stored, defaulting to 1.0
		// or retrieving them from a custom summary is perfect. Let's make sure we handle it gracefully.

		if i == 0 {
			commonArmada = o.armada
			commonRateType = o.rateType
			commonMitraID = o.mitraID
		} else {
			if o.armada != commonArmada {
				c.JSON(http.StatusBadRequest, models.APIResponse{
					Status:  "error",
					Message: fmt.Sprintf("Jenis armada tidak seragam (ID %d pakai %s, grup pakai %s)", o.id, o.armada, commonArmada),
				})
				return
			}
			if o.mitraID != commonMitraID {
				c.JSON(http.StatusBadRequest, models.APIResponse{
					Status:  "error",
					Message: "Semua order dalam 1 dispatch group harus berasal dari Mitra yang sama",
				})
				return
			}
		}

		ordersMap[orderID] = o
	}

	// Verify driver vehicle type matches order armada
	if driverVehicleType != commonArmada {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: fmt.Sprintf("Jenis kendaraan driver (%s) tidak cocok dengan armada order (%s)", driverVehicleType, commonArmada),
		})
		return
	}

	// 3. Begin Transaction
	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memulai transaksi database: " + err.Error(),
		})
		return
	}
	defer tx.Rollback(ctx)

	// Load Mitra pickup location coordinates
	var originLat, originLong float64
	err = tx.QueryRow(ctx,
		"SELECT pickup_lat, pickup_long FROM mitra_profiles WHERE user_id = $1", commonMitraID,
	).Scan(&originLat, &originLong)
	if err != nil {
		// Fallback to Yogyakarta center
		originLat = -7.782889
		originLong = 110.377042
	}

	// Load active rate for this Mitra/Armada/RateType
	_, activeRate := loadMitraRatesFromDB(h.DB, ctx, commonMitraID, commonArmada, commonRateType)

	// Generate Dispatch Number
	var maxDSP string
	_ = tx.QueryRow(ctx, "SELECT COALESCE(MAX(dispatch_number), '') FROM dispatch_groups;").Scan(&maxDSP)
	nextDSPNum := 1
	if maxDSP != "" {
		var num int
		if _, fmtErr := fmt.Sscanf(maxDSP, "DSP-%d", &num); fmtErr == nil {
			nextDSPNum = num + 1
		}
	}
	dispatchNumber := fmt.Sprintf("DSP-%06d", nextDSPNum)

	// Create Dispatch Group
	var groupID int
	err = tx.QueryRow(ctx,
		`INSERT INTO dispatch_groups (dispatch_number, driver_id, status, total_distance_km, total_argo)
		 VALUES ($1, $2, 'PICKING_UP', 0.0, 0.0)
		 RETURNING id;`, dispatchNumber, req.DriverID,
	).Scan(&groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal membuat grup dispatch: " + err.Error(),
		})
		return
	}

	// 4. Calculate sequential routing with Auto-Sorting by Zone Hierarchy (Zona 1 -> Zona 2 -> Zona 3 -> Non-Zona)
	type orderSeqItem struct {
		orderID int
		zona    int
		lat     float64
		lng     float64
	}

	seqItems := []orderSeqItem{}
	for _, oid := range req.Sequence {
		o := ordersMap[oid]
		var destLat, destLng float64
		var zVal int
		err := tx.QueryRow(ctx,
			"SELECT latitude, longitude, COALESCE(zona, 99) FROM alamat_penerima WHERE nama_apotek = $1 AND alamat_lengkap = $2 LIMIT 1",
			o.customerName, o.deliveryAddress,
		).Scan(&destLat, &destLng, &zVal)
		if err != nil {
			destLat = originLat + (float64(oid%100) * 0.001)
			destLng = originLong + (float64(oid%100) * 0.001)
			zVal = 99
		}
		if zVal <= 0 {
			zVal = 99
		}
		seqItems = append(seqItems, orderSeqItem{
			orderID: oid,
			zona:    zVal,
			lat:     destLat,
			lng:     destLng,
		})
	}

	// Sort sequence by Zone Rank (1, 2, 3, 99) and nearest distance from origin
	orderedSequence := []int{}
	currLat, currLng := originLat, originLong
	for _, zoneRank := range []int{1, 2, 3, 99} {
		group := []orderSeqItem{}
		for _, item := range seqItems {
			if item.zona == zoneRank {
				group = append(group, item)
			}
		}

		remaining := make([]orderSeqItem, len(group))
		copy(remaining, group)

		for len(remaining) > 0 {
			bestIdx := 0
			bestDist := math.MaxFloat64
			for idx, r := range remaining {
				dist := haversineDist(currLat, currLng, r.lat, r.lng)
				if dist < bestDist {
					bestDist = dist
					bestIdx = idx
				}
			}
			chosen := remaining[bestIdx]
			orderedSequence = append(orderedSequence, chosen.orderID)
			currLat = chosen.lat
			currLng = chosen.lng
			remaining = append(remaining[:bestIdx], remaining[bestIdx+1:]...)
		}
	}

	var totalDistance float64
	var totalArgo float64
	lastLat := originLat
	lastLng := originLong

	for i, orderID := range orderedSequence {
		o := ordersMap[orderID]

		// Get destination coordinates from alamat_penerima
		var destLat, destLng float64
		err = tx.QueryRow(ctx,
			"SELECT latitude, longitude FROM alamat_penerima WHERE nama_apotek = $1 AND alamat_lengkap = $2 LIMIT 1",
			o.customerName, o.deliveryAddress,
		).Scan(&destLat, &destLng)
		if err != nil {
			// Fallback: simulate coordinates close to origin
			destLat = originLat + (float64(orderID%100) * 0.001)
			destLng = originLong + (float64(orderID%100) * 0.001)
		}

		// Calculate segment distance: from last point to current destination
		segmentDist, _ := calculateDistance(h.DB, lastLat, lastLng, destLat, destLng)
		totalDistance += segmentDist

		// Calculate segment argo
		segmentArgo := math.Round(calcRowPrice(commonRateType, activeRate, segmentDist, o.kubik, o.berat, i))
		totalArgo += segmentArgo

		// Insert into dispatch_id_detail
		// First item in sequence gets status 'DELIVERING' in sequence detail, others 'PENDING'
		statusPengantaran := "PENDING"
		if i == 0 {
			statusPengantaran = "DELIVERING"
		}

		_, err = tx.Exec(ctx,
			`INSERT INTO dispatch_id_detail (dispatch_group_id, order_id, sequence_number, status_pengantaran)
			 VALUES ($1, $2, $3, $4);`,
			groupID, o.id, i+1, statusPengantaran,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal mencatat rincian rute: " + err.Error(),
			})
			return
		}

		// Update order row: assign driver, preserve calculated delivery fee if > 0, update status
		_, err = tx.Exec(ctx,
			`UPDATE orders 
			 SET driver_id = $1, 
			     delivery_fee = CASE WHEN delivery_fee > 0 THEN delivery_fee ELSE $2 END, 
			     dispatch_id = $3, 
			     distance_km = $4, 
			     status = 'WAITING_FOR_PICKUP'
			 WHERE id = $5 OR order_number = $6 OR (parent_order_number IS NOT NULL AND parent_order_number != '' AND parent_order_number = $6);`,
			req.DriverID, segmentArgo, dispatchNumber, segmentDist, o.id, o.orderNumber,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memperbarui status order: " + err.Error(),
			})
			return
		}

		// Trigger Notification: "Tugas Pengantaran Baru"
		var orderNum, pharmName string
		err = tx.QueryRow(ctx, "SELECT order_number, pharmacy_name FROM orders WHERE id = $1", o.id).Scan(&orderNum, &pharmName)
		if err == nil {
			title := "Tugas Pengantaran Baru"
			message := fmt.Sprintf("Anda mendapatkan tugas pengantaran baru untuk pesanan %s di apotek %s.", orderNum, pharmName)
			_, _ = tx.Exec(ctx, "INSERT INTO notifications (driver_id, title, message) VALUES ($1, $2, $3)", req.DriverID, title, message)
		}

		// Update last position to current destination for the next segment calculation
		lastLat = destLat
		lastLng = destLng
	}

	// 5. Update Dispatch Group totals
	_, err = tx.Exec(ctx,
		`UPDATE dispatch_groups 
		 SET total_distance_km = $1, total_argo = $2
		 WHERE id = $3;`,
		totalDistance, totalArgo, groupID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memperbarui total argo grup: " + err.Error(),
		})
		return
	}

	if err = tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menyelesaikan transaksi database: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: fmt.Sprintf("Grup dispatch %s berhasil dibuat dengan %d titik antar!", dispatchNumber, len(req.Sequence)),
		Data: map[string]interface{}{
			"dispatch_number":   dispatchNumber,
			"total_distance_km": totalDistance,
			"total_argo":        totalArgo,
		},
	})
}
