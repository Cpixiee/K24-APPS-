package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// UpdateDriverLocation processes real-time GPS coordinate updates from Flutter mobile app
func (h *DashboardHandler) UpdateDriverLocation(c *gin.Context) {
	driverIDVal, exists := c.Get("driver_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Driver tidak terotentikasi",
		})
		return
	}
	driverID := driverIDVal.(int)

	var req models.DriverLocationUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Payload lokasi tidak valid: " + err.Error(),
		})
		return
	}

	ctx := context.Background()
	_, err := h.DB.Exec(ctx, `
		UPDATE driver_profiles 
		SET current_lat = $1, current_lng = $2, last_location_update = CURRENT_TIMESTAMP 
		WHERE user_id = $3`,
		req.Latitude, req.Longitude, driverID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memperbarui lokasi driver: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Lokasi driver berhasil diperbarui",
		Data:    req,
	})
}

// GetDispatchLiveTracking retrieves driver live location + pickup pharmacy + 10 sequential delivery stops
func (h *AdminHandler) GetDispatchLiveTracking(c *gin.Context) {
	dispatchID := c.Param("dispatch_id")
	ctx := context.Background()

	var resp models.LiveTrackingResponse
	resp.DispatchNumber = dispatchID
	resp.Stops = make([]models.LiveTrackingStop, 0)

	// 1. Fetch Dispatch Group or Orders batch info
	var groupID int
	var driverID int
	var status string
	var totalDistance, totalArgo float64

	// Try dispatch_groups first
	err := h.DB.QueryRow(ctx, `
		SELECT id, driver_id, status, total_distance_km, total_argo
		FROM dispatch_groups
		WHERE dispatch_number = $1
		LIMIT 1`, dispatchID,
	).Scan(&groupID, &driverID, &status, &totalDistance, &totalArgo)

	if err == pgx.ErrNoRows {
		// Fallback to query driver_id from orders directly
		err = h.DB.QueryRow(ctx, `
			SELECT COALESCE(driver_id, 0), status, COALESCE(distance_km, 0.0), COALESCE(delivery_fee, 0.0)
			FROM orders
			WHERE (dispatch_id = $1 OR order_number = $1) AND driver_id IS NOT NULL
			LIMIT 1`, dispatchID,
		).Scan(&driverID, &status, &totalDistance, &totalArgo)
	}

	if err == pgx.ErrNoRows || driverID == 0 {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Status:  "error",
			Message: "Rincian tracking pengiriman " + dispatchID + " tidak ditemukan atau belum di-assign driver",
		})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal mengambil data tracking: " + err.Error(),
		})
		return
	}

	// Always calculate real total argo & distance sum from orders table
	var sumArgo, sumDistance float64
	_ = h.DB.QueryRow(ctx, `
		SELECT COALESCE(SUM(delivery_fee), 0.0), COALESCE(SUM(distance_km), 0.0)
		FROM orders
		WHERE dispatch_id = $1 OR parent_order_number = $1`, dispatchID,
	).Scan(&sumArgo, &sumDistance)

	resp.Status = status
	resp.TotalDistance = sumDistance
	if resp.TotalDistance == 0 {
		resp.TotalDistance = totalDistance
	}
	resp.TotalArgo = sumArgo
	if resp.TotalArgo == 0 {
		resp.TotalArgo = totalArgo
	}

	// 2. Fetch Driver Profile & Live Location
	var driverLastUpdate time.Time
	err = h.DB.QueryRow(ctx, `
		SELECT u.id, u.name, COALESCE(u.phone, ''), COALESCE(dp.plate_number, ''), 
		       COALESCE(dp.vehicle_type, 'motor'), COALESCE(dp.is_active, false),
		       COALESCE(dp.current_lat, 0.0), COALESCE(dp.current_lng, 0.0),
		       COALESCE(dp.last_location_update, u.updated_at)
		FROM users u
		JOIN driver_profiles dp ON u.id = dp.user_id
		WHERE u.id = $1`, driverID,
	).Scan(
		&resp.Driver.ID, &resp.Driver.Name, &resp.Driver.Phone, &resp.Driver.PlateNumber,
		&resp.Driver.VehicleType, &resp.Driver.IsActive,
		&resp.Driver.CurrentLat, &resp.Driver.CurrentLng,
		&driverLastUpdate,
	)
	if err == nil {
		resp.Driver.LastLocationUpdate = driverLastUpdate
		resp.Driver.LastUpdatedSecAgo = int(time.Since(driverLastUpdate).Seconds())
	}

	// 3. Fetch Pickup Pharmacy Details
	var commonMitraID int
	_ = h.DB.QueryRow(ctx, `
		SELECT o.pharmacy_name, o.pharmacy_address, COALESCE(o.mitra_id, 0),
		       COALESCE(mp.pickup_lat, -6.2019957), COALESCE(mp.pickup_long, 106.8551888)
		FROM orders o
		LEFT JOIN mitra_profiles mp ON o.mitra_id = mp.user_id
		WHERE o.dispatch_id = $1 OR o.order_number = $1
		LIMIT 1`, dispatchID,
	).Scan(&resp.PharmacyName, &resp.PharmacyAddress, &commonMitraID, &resp.PharmacyLat, &resp.PharmacyLng)

	// 4. Fetch Sequential Stops in this Dispatch Batch
	stopsQuery := `
		SELECT o.id, o.order_number, COALESCE(d.sequence_number, 1) as sequence_number,
		       o.customer_name, o.customer_phone, o.delivery_address, o.status, o.medicine_summary,
		       COALESCE(ap.latitude, 0.0) as lat, COALESCE(ap.longitude, 0.0) as lng
		FROM orders o
		LEFT JOIN dispatch_id_detail d ON o.id = d.order_id
		LEFT JOIN LATERAL (
			SELECT latitude, longitude 
			FROM alamat_penerima 
			WHERE (latitude != 0 AND longitude != 0) 
			  AND (
			    LOWER(TRIM(nama_apotek)) = LOWER(TRIM(REGEXP_REPLACE(o.customer_name, '\s*\(.*?\)', '')))
			    OR LOWER(TRIM(o.customer_name)) LIKE '%' || LOWER(TRIM(nama_apotek)) || '%'
			    OR LOWER(TRIM(nama_apotek)) LIKE '%' || LOWER(TRIM(o.customer_name)) || '%'
			    OR (alamat_lengkap IS NOT NULL AND LOWER(TRIM(alamat_lengkap)) = LOWER(TRIM(o.delivery_address)))
			  )
			ORDER BY CASE WHEN LOWER(TRIM(nama_apotek)) = LOWER(TRIM(REGEXP_REPLACE(o.customer_name, '\s*\(.*?\)', ''))) THEN 1 ELSE 2 END
			LIMIT 1
		) ap ON true
		WHERE o.dispatch_id = $1 OR o.order_number = $1 OR o.parent_order_number = $1
		ORDER BY COALESCE(d.sequence_number, 1) ASC, o.id ASC`

	rows, err := h.DB.Query(ctx, stopsQuery, dispatchID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var stop models.LiveTrackingStop
			var medicineSummary string
			errScan := rows.Scan(
				&stop.OrderID, &stop.OrderNumber, &stop.SequenceNumber,
				&stop.CustomerName, &stop.CustomerPhone, &stop.DeliveryAddress,
				&stop.Status, &medicineSummary, &stop.Lat, &stop.Lng,
			)
			if errScan == nil {
				// Fallback coordinate resolution if LATERAL join yielded 0.0
				if stop.Lat == 0 || stop.Lng == 0 {
					rec, _ := findRecipient(h.DB, stop.CustomerName, stop.DeliveryAddress)
					if rec != nil && rec.Latitude != 0 && rec.Longitude != 0 {
						stop.Lat = rec.Latitude
						stop.Lng = rec.Longitude
					} else {
						gLat, gLng, errGeo := geocodeAddress(stop.DeliveryAddress, resp.PharmacyLat, resp.PharmacyLng)
						if errGeo == nil && gLat != 0 {
							stop.Lat = gLat
							stop.Lng = gLng
						} else {
							stop.Lat = resp.PharmacyLat + (float64(stop.SequenceNumber) * 0.005)
							stop.Lng = resp.PharmacyLng + (float64(stop.SequenceNumber) * 0.005)
						}
					}
				}

				// Parse invoices list from medicine_summary
				stop.Invoices = []string{}
				if parts := strings.SplitN(medicineSummary, "Invoices: ", 2); len(parts) == 2 {
					invs := strings.Split(parts[1], ",")
					for _, inv := range invs {
						if trimmed := strings.TrimSpace(inv); trimmed != "" {
							stop.Invoices = append(stop.Invoices, trimmed)
						}
					}
				}
				resp.Stops = append(resp.Stops, stop)
			}
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status: "success",
		Data:   resp,
	})
}
