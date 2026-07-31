package handlers

import (
	"context"
	"net/http"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// GetDrivers fetches the list of all drivers, including their profile details.
func (h *AdminHandler) GetDrivers(c *gin.Context) {
	ctx := context.Background()

	query := `
	SELECT u.id, u.username, u.name, u.email, u.phone, 
	       COALESCE(dp.plate_number, '') as plate_number, 
	       COALESCE(dp.is_active, false) as is_active, 
	       COALESCE(dp.rating, 5.0) as rating, 
	       COALESCE(dp.vehicle_type, 'motor') as vehicle_type,
	       COALESCE(dp.is_approved, false) as is_approved,
	       COALESCE(dp.ktp_url, '') as ktp_url,
	       COALESCE(dp.sim_url, '') as sim_url,
	       COALESCE(dp.stnk_url, '') as stnk_url,
	       u.created_at, u.updated_at
	FROM users u
	LEFT JOIN driver_profiles dp ON u.id = dp.user_id
	WHERE u.role = 'DRIVER'
	ORDER BY u.created_at DESC;`

	rows, err := h.DB.Query(ctx, query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil daftar driver: " + err.Error()})
		return
	}
	defer rows.Close()

	drivers := make([]models.Driver, 0)
	for rows.Next() {
		var d models.Driver
		err := rows.Scan(
			&d.ID,
			&d.Username,
			&d.Name,
			&d.Email,
			&d.Phone,
			&d.PlateNumber,
			&d.IsActive,
			&d.Rating,
			&d.VehicleType,
			&d.IsApproved,
			&d.KTPUrl,
			&d.SIMUrl,
			&d.STNKUrl,
			&d.CreatedAt,
			&d.UpdatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses data driver: " + err.Error()})
			return
		}
		d.Role = "DRIVER"
		drivers = append(drivers, d)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: drivers})
}

// ApproveDriver marks a driver registration as approved
func (h *AdminHandler) ApproveDriver(c *gin.Context) {
	driverID := c.Param("id")
	ctx := context.Background()

	res, err := h.DB.Exec(ctx, "UPDATE driver_profiles SET is_approved = true WHERE user_id = $1", driverID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyetujui driver: " + err.Error()})
		return
	}

	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, models.APIResponse{Status: "error", Message: "Driver tidak ditemukan"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Driver berhasil disetujui"})
}

// RejectDriver deletes the unapproved driver registration
func (h *AdminHandler) RejectDriver(c *gin.Context) {
	driverID := c.Param("id")
	ctx := context.Background()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memulai transaksi: " + err.Error()})
		return
	}
	defer tx.Rollback(ctx)

	// Verify the driver exists and is not approved yet
	var isApproved bool
	err = tx.QueryRow(ctx, "SELECT COALESCE(is_approved, false) FROM driver_profiles WHERE user_id = $1", driverID).Scan(&isApproved)
	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, models.APIResponse{Status: "error", Message: "Profil driver tidak ditemukan"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memvalidasi driver: " + err.Error()})
		return
	}

	// Delete profile and user
	_, _ = tx.Exec(ctx, "DELETE FROM driver_profiles WHERE user_id = $1", driverID)
	_, err = tx.Exec(ctx, "DELETE FROM users WHERE id = $1 AND role = 'DRIVER'", driverID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menghapus user driver: " + err.Error()})
		return
	}

	if err = tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan perubahan: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Pendaftaran driver berhasil ditolak"})
}
