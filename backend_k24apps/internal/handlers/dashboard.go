package handlers

import (
	"context"
	"log"
	"net/http"
	"strconv"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DashboardHandler struct {
	DB *pgxpool.Pool
}

// GetDashboard retrieves driver details joined with profile, daily stats, active, and completed orders
func (h *DashboardHandler) GetDashboard(c *gin.Context) {
	driverIDVal, exists := c.Get("driver_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Driver tidak terotentikasi",
		})
		return
	}
	driverID := driverIDVal.(int)

	ctx := context.Background()
	var data models.DashboardData

	// 1. Fetch Joined Driver Details (Users + DriverProfiles tables)
	joinQuery := `
	SELECT u.id, u.username, u.name, u.email, u.phone, dp.plate_number, dp.is_active, dp.rating, COALESCE(u.profile_picture, ''), u.created_at, u.updated_at
	FROM users u
	JOIN driver_profiles dp ON u.id = dp.user_id
	WHERE u.id = $1 AND u.role = 'DRIVER';`

	err := h.DB.QueryRow(ctx, joinQuery, driverID).Scan(
		&data.Driver.ID,
		&data.Driver.Username,
		&data.Driver.Name,
		&data.Driver.Email,
		&data.Driver.Phone,
		&data.Driver.PlateNumber,
		&data.Driver.IsActive,
		&data.Driver.Rating,
		&data.Driver.ProfilePicture,
		&data.Driver.CreatedAt,
		&data.Driver.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Status:  "error",
			Message: "Profil Driver tidak ditemukan di sistem",
		})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal mengambil profil driver",
		})
		return
	}

	// 2. Fetch Aggregated Statistics
	statsQuery := `
	SELECT 
		COALESCE(SUM(CASE WHEN status = 'COMPLETED' AND completed_at >= CURRENT_DATE THEN COALESCE(NULLIF(driver_fee, 0), delivery_fee) ELSE 0 END), 0) as today_earnings,
		COUNT(CASE WHEN status = 'COMPLETED' AND completed_at >= CURRENT_DATE THEN 1 END) as today_orders,
		COALESCE(SUM(CASE WHEN status = 'COMPLETED' THEN COALESCE(NULLIF(driver_fee, 0), delivery_fee) ELSE 0 END), 0) as total_earnings,
		COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) as total_orders
	FROM orders
	WHERE driver_id = $1;`

	err = h.DB.QueryRow(ctx, statsQuery, driverID).Scan(
		&data.Stats.TodayEarnings,
		&data.Stats.TodayOrders,
		&data.Stats.TotalEarnings,
		&data.Stats.TotalOrders,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memproses statistik dashboard",
		})
		return
	}

	activeQuery := `
	SELECT o.id, o.order_number, o.driver_id, o.status, o.pharmacy_name, o.pharmacy_address, o.delivery_address, 
	       o.customer_name, o.customer_phone, o.medicine_summary, COALESCE(NULLIF(o.driver_fee, 0), NULLIF(o.delivery_fee, 0), 10500.0) as delivery_fee, o.created_at,
	       COALESCE(mp.pickup_lat, -6.17511) as pharmacy_lat, COALESCE(mp.pickup_long, 106.865039) as pharmacy_lng,
	       COALESCE(ap.latitude, -6.23) as customer_lat, COALESCE(ap.longitude, 106.99) as customer_lng,
	       COALESCE(o.unboxing_option, '') as unboxing_option,
	       COALESCE(o.extra_items_note, '') as extra_items_note,
	       COALESCE(o.parent_order_number, '') as parent_order_number,
	       COALESCE(o.dispatch_id, '') as dispatch_id,
	       COALESCE(o.checked_invoices, '') as checked_invoices,
	       COALESCE(o.facture_photo_url, '') as facture_photo_url,
	       COALESCE(o.pickup_photo_url, '') as pickup_photo_url,
	       COALESCE(o.signature_photo_url, '') as signature_photo_url,
	       COALESCE(o.arrived_photo_url, '') as arrived_photo_url,
	       COALESCE(o.arrived_note, '') as arrived_note,
	       COALESCE(o.handover_photo_url, '') as handover_photo_url
	FROM orders o
	LEFT JOIN dispatch_id_detail d ON o.id = d.order_id
	LEFT JOIN mitra_profiles mp ON o.mitra_id = mp.user_id
	LEFT JOIN LATERAL (
		SELECT latitude, longitude 
		FROM alamat_penerima 
		WHERE nama_apotek = o.customer_name AND alamat_lengkap = o.delivery_address 
		LIMIT 1
	) ap ON true
	WHERE o.driver_id = $1 
	  AND o.status IN ('WAITING_FOR_PICKUP', 'DELIVERING', 'REJECTED_WAITING_APPROVAL', 'PENDING', 'READY_FOR_PICKUP_FACTURE')
	ORDER BY COALESCE(d.sequence_number, 0) ASC;`

	data.ActiveOrders = make([]models.Order, 0)
	activeRows, err := h.DB.Query(ctx, activeQuery, driverID)
	if err == nil {
		defer activeRows.Close()
		for activeRows.Next() {
			var o models.Order
			errScan := activeRows.Scan(
				&o.ID,
				&o.OrderNumber,
				&o.DriverID,
				&o.Status,
				&o.PharmacyName,
				&o.PharmacyAddress,
				&o.DeliveryAddress,
				&o.CustomerName,
				&o.CustomerPhone,
				&o.MedicineSummary,
				&o.DeliveryFee,
				&o.CreatedAt,
				&o.PharmacyLat,
				&o.PharmacyLng,
				&o.CustomerLat,
				&o.CustomerLng,
				&o.UnboxingOption,
				&o.ExtraItemsNote,
				&o.ParentOrderNumber,
				&o.DispatchID,
				&o.CheckedInvoices,
				&o.FacturePhotoUrl,
				&o.PickupPhotoUrl,
				&o.SignaturePhotoUrl,
				&o.ArrivedPhotoUrl,
				&o.ArrivedNote,
				&o.HandoverPhotoUrl,
			)
			if errScan == nil {
				data.ActiveOrders = append(data.ActiveOrders, o)
			}
		}
		if len(data.ActiveOrders) > 0 {
			data.ActiveOrder = &data.ActiveOrders[0]
		}
	} else {
		log.Println("[Dashboard Query Error]:", err)
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memeriksa pesanan aktif: " + err.Error(),
		})
		return
	}

	// 4. Fetch Recent Completed / Cancelled Orders (up to 10)
	recentQuery := `
	SELECT id, order_number, driver_id, status, pharmacy_name, pharmacy_address, delivery_address, 
	       customer_name, customer_phone, medicine_summary, COALESCE(NULLIF(driver_fee, 0), NULLIF(delivery_fee, 0), 10500.0) as delivery_fee, created_at, completed_at
	FROM orders
	WHERE driver_id = $1 AND status IN ('COMPLETED', 'CANCELLED')
	ORDER BY completed_at DESC
	LIMIT 10;`

	rows, err := h.DB.Query(ctx, recentQuery, driverID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal mengambil riwayat pengantaran",
		})
		return
	}
	defer rows.Close()

	data.RecentOrders = make([]models.Order, 0)
	for rows.Next() {
		var o models.Order
		err := rows.Scan(
			&o.ID,
			&o.OrderNumber,
			&o.DriverID,
			&o.Status,
			&o.PharmacyName,
			&o.PharmacyAddress,
			&o.DeliveryAddress,
			&o.CustomerName,
			&o.CustomerPhone,
			&o.MedicineSummary,
			&o.DeliveryFee,
			&o.CreatedAt,
			&o.CompletedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal membaca baris riwayat pengantaran",
			})
			return
		}
		data.RecentOrders = append(data.RecentOrders, o)
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status: "success",
		Data:   data,
	})
}

// ToggleActive switches the driver online / offline status in driver_profiles table
func (h *DashboardHandler) ToggleActive(c *gin.Context) {
	driverIDVal, exists := c.Get("driver_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Driver tidak terotentikasi",
		})
		return
	}
	driverID := driverIDVal.(int)

	var req models.ToggleActiveRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Payload tidak valid",
		})
		return
	}

	ctx := context.Background()
	_, err := h.DB.Exec(ctx, "UPDATE driver_profiles SET is_active = $1 WHERE user_id = $2", req.IsActive, driverID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memperbarui status aktif",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Status aktif berhasil diperbarui",
		Data:    req,
	})
}

// CompleteOrder marks an active order as completed to update driver earnings dynamically
func (h *DashboardHandler) CompleteOrder(c *gin.Context) {
	driverIDVal, exists := c.Get("driver_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Driver tidak terotentikasi",
		})
		return
	}
	driverID := driverIDVal.(int)

	orderIDStr := c.Param("id")
	orderID, err := strconv.Atoi(orderIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "ID pesanan tidak valid",
		})
		return
	}

	ctx := context.Background()

	// Verify order belongs to this driver
	var currentStatus string
	err = h.DB.QueryRow(ctx, "SELECT status FROM orders WHERE id = $1 AND driver_id = $2", orderID, driverID).Scan(&currentStatus)
	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Status:  "error",
			Message: "Pesanan tidak ditemukan",
		})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memverifikasi status pesanan",
		})
		return
	}

	if currentStatus == "COMPLETED" || currentStatus == "CANCELLED" {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Pesanan sudah selesai atau dibatalkan",
		})
		return
	}

	// Update status
	_, err = h.DB.Exec(ctx,
		"UPDATE orders SET status = 'COMPLETED', completed_at = CURRENT_TIMESTAMP WHERE id = $1 AND driver_id = $2",
		orderID,
		driverID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menyelesaikan pengantaran pesanan",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Pengantaran pesanan berhasil diselesaikan!",
	})
}
