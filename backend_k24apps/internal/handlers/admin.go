package handlers

import (
	"context"
	"net/http"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AdminHandler holds the shared DB connection for all admin sub-handlers.
// Each logical domain (stats, drivers, mitra, orders) lives in its own file.
type AdminHandler struct {
	DB *pgxpool.Pool
}

// GetAdminStats fetches dashboard counts for drivers, mitra, and orders.
func (h *AdminHandler) GetAdminStats(c *gin.Context) {
	ctx := context.Background()
	var stats models.AdminStats

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE role = 'DRIVER'").Scan(&stats.TotalDrivers); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung jumlah driver"})
		return
	}

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM users WHERE role = 'MITRA'").Scan(&stats.TotalMitra); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung jumlah mitra"})
		return
	}

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders").Scan(&stats.TotalOrders); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung jumlah pesanan"})
		return
	}

	// Calculate Total Invoices across all orders (extracting only the invoice numbers after 'Invoices: ' prefix)
	_ = h.DB.QueryRow(ctx, `
		SELECT COALESCE(SUM(
			CASE 
				WHEN medicine_summary LIKE '%Invoices:%' THEN CARDINALITY(STRING_TO_ARRAY(SPLIT_PART(medicine_summary, 'Invoices: ', 2), ', '))
				ELSE 1 
			END
		), 0)
		FROM orders;
	`).Scan(&stats.TotalInvoices)

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE driver_id IS NULL").Scan(&stats.PendingDispatch); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung order pending dispatch"})
		return
	}

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE driver_id IS NOT NULL AND status IN ('PICKING_UP', 'DELIVERING')").Scan(&stats.ActiveDispatch); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung order aktif dispatch"})
		return
	}

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE status = 'COMPLETED'").Scan(&stats.CompletedOrders); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung order selesai"})
		return
	}

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE status = 'CANCELLED'").Scan(&stats.CancelledOrders); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung order batal"})
		return
	}

	if err := h.DB.QueryRow(ctx, "SELECT COUNT(*) FROM driver_profiles WHERE is_active = true").Scan(&stats.OnlineDrivers); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghitung driver aktif"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: stats})
}
