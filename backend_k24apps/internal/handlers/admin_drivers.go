package handlers

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// GetDrivers fetches the list of all drivers, including their profile details.
func (h *AdminHandler) GetDrivers(c *gin.Context) {
	ctx := context.Background()

	query := `
	SELECT u.id, 
	       COALESCE(u.username, '') as username, 
	       COALESCE(u.name, '') as name, 
	       COALESCE(u.email, '') as email, 
	       COALESCE(u.phone, '') as phone, 
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

		// Optimization: If document fields contain large base64 image strings, convert them to lightweight
		// document API endpoint URLs to avoid transferring 100+ MB payload on driver list loads.
		if strings.HasPrefix(d.KTPUrl, "data:") || len(d.KTPUrl) > 500 {
			d.KTPUrl = fmt.Sprintf("/api/admin/drivers/%d/document?type=ktp", d.ID)
		}
		if strings.HasPrefix(d.SIMUrl, "data:") || len(d.SIMUrl) > 500 {
			d.SIMUrl = fmt.Sprintf("/api/admin/drivers/%d/document?type=sim", d.ID)
		}
		if strings.HasPrefix(d.STNKUrl, "data:") || len(d.STNKUrl) > 500 {
			d.STNKUrl = fmt.Sprintf("/api/admin/drivers/%d/document?type=stnk", d.ID)
		}

		drivers = append(drivers, d)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: drivers})
}

// GetDriverDocument returns the document image (KTP, SIM, or STNK) on-demand for a specific driver
func (h *AdminHandler) GetDriverDocument(c *gin.Context) {
	driverID := c.Param("id")
	docType := c.Query("type")

	ctx := context.Background()
	var colName string
	switch docType {
	case "sim":
		colName = "sim_url"
	case "stnk":
		colName = "stnk_url"
	default:
		colName = "ktp_url"
	}

	query := fmt.Sprintf("SELECT COALESCE(%s, '') FROM driver_profiles WHERE user_id = $1", colName)
	var docURL string
	err := h.DB.QueryRow(ctx, query, driverID).Scan(&docURL)
	if err == pgx.ErrNoRows || docURL == "" {
		c.JSON(http.StatusNotFound, models.APIResponse{Status: "error", Message: "Dokumen tidak ditemukan"})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil dokumen"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: gin.H{"doc_url": docURL}})
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

// UpdateDriver allows admin/superadmin to edit a driver's registration details (name, phone, email, vehicle_type, plate_number)
func (h *AdminHandler) UpdateDriver(c *gin.Context) {
	driverID := c.Param("id")
	var req struct {
		Name        string `json:"name" binding:"required"`
		Phone       string `json:"phone"`
		Email       string `json:"email"`
		VehicleType string `json:"vehicle_type"`
		PlateNumber string `json:"plate_number"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	ctx := context.Background()
	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memulai transaksi: " + err.Error()})
		return
	}
	defer tx.Rollback(ctx)

	// Update users table (name, phone, email)
	resUser, err := tx.Exec(ctx,
		`UPDATE users 
		 SET name = $1, 
		     phone = COALESCE(NULLIF($2, ''), phone), 
		     email = COALESCE(NULLIF($3, ''), email), 
		     updated_at = NOW() 
		 WHERE id = $4 AND role = 'DRIVER'`,
		req.Name, req.Phone, req.Email, driverID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memperbarui data user driver: " + err.Error()})
		return
	}

	if resUser.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, models.APIResponse{Status: "error", Message: "User driver tidak ditemukan"})
		return
	}

	// Update driver_profiles table (vehicle_type, plate_number)
	_, err = tx.Exec(ctx,
		`UPDATE driver_profiles 
		 SET vehicle_type = LOWER(COALESCE(NULLIF($1, ''), vehicle_type)), 
		     plate_number = COALESCE(NULLIF($2, ''), plate_number) 
		 WHERE user_id = $3`,
		req.VehicleType, req.PlateNumber, driverID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memperbarui profil armada driver: " + err.Error()})
		return
	}

	if err = tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan perubahan driver: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Data driver berhasil diperbarui!"})
}
