package handlers

import (
	"context"
	"net/http"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

// GetMitra fetches the list of all mitra partners.
func (h *AdminHandler) GetMitra(c *gin.Context) {
	ctx := context.Background()

	query := `
	SELECT u.id, u.username, u.name, u.email, u.phone, u.role, COALESCE(mp.mitra_type, 'K24') as mitra_type, u.created_at, u.updated_at
	FROM users u
	LEFT JOIN mitra_profiles mp ON u.id = mp.user_id
	WHERE u.role = 'MITRA'
	ORDER BY u.created_at DESC;`

	rows, err := h.DB.Query(ctx, query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil daftar mitra"})
		return
	}
	defer rows.Close()

	mitras := make([]models.User, 0)
	for rows.Next() {
		var u models.User
		err := rows.Scan(&u.ID, &u.Username, &u.Name, &u.Email, &u.Phone, &u.Role, &u.MitraType, &u.CreatedAt, &u.UpdatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses data mitra"})
			return
		}
		mitras = append(mitras, u)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: mitras})
}

// CreateMitra registers a new mitra partner with vehicle pricing configurations.
func (h *AdminHandler) CreateMitra(c *gin.Context) {
	var req models.CreateMitraRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Payload tidak valid: " + err.Error()})
		return
	}

	mitraType := req.MitraType
	if mitraType == "" {
		mitraType = "K24"
	}

	// Motor: minimal 1 tarif wajib diisi
	if req.MotorDimensi == nil && req.MotorKm == nil && req.MotorTitik == nil && req.MotorBerat == nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Konfigurasi Motor minimal harus mengisi 1 komponen tarif."})
		return
	}
	// Mobil: minimal 1 tarif wajib diisi
	if req.MobilDimensi == nil && req.MobilKm == nil && req.MobilTitik == nil && req.MobilBerat == nil && req.MobilLumpsum == nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{Status: "error", Message: "Konfigurasi Mobil minimal harus mengisi 1 komponen tarif."})
		return
	}

	ctx := context.Background()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memulai transaksi database"})
		return
	}
	defer tx.Rollback(ctx)

	// Check uniqueness
	var exists bool
	if err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)", req.Username).Scan(&exists); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memvalidasi username"})
		return
	}
	if exists {
		c.JSON(http.StatusConflict, models.APIResponse{Status: "error", Message: "Username sudah digunakan"})
		return
	}
	if err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", req.Email).Scan(&exists); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memvalidasi email"})
		return
	}
	if exists {
		c.JSON(http.StatusConflict, models.APIResponse{Status: "error", Message: "Email sudah terdaftar"})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal memproses password"})
		return
	}

	// Insert user
	var user models.User
	insertUserQuery := `
	INSERT INTO users (username, email, name, password_hash, phone, role)
	VALUES ($1, $2, $3, $4, $5, 'MITRA')
	RETURNING id, username, email, name, phone, role, created_at, updated_at;`

	err = tx.QueryRow(ctx, insertUserQuery, req.Username, req.Email, req.Name, string(hashedPassword), req.Phone).Scan(
		&user.ID, &user.Username, &user.Email, &user.Name, &user.Phone, &user.Role, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal membuat user mitra baru"})
		return
	}
	user.MitraType = mitraType

	// Insert mitra profile
	insertProfileQuery := `
	INSERT INTO mitra_profiles (
		user_id, pic_name, pic_nik, alamat_lengkap, pickup_name, pickup_lat, pickup_long, mitra_type,
		motor_dimensi, motor_km, motor_titik, motor_berat, motor_zona1, motor_zona2, motor_zona3,
		mobil_dimensi, mobil_km, mobil_titik, mobil_berat, mobil_lumpsum
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20);`

	_, err = tx.Exec(ctx, insertProfileQuery,
		user.ID, req.PicName, req.PicNik, req.AlamatLengkap,
		req.PickupName, req.PickupLat, req.PickupLong, mitraType,
		req.MotorDimensi, req.MotorKm, req.MotorTitik, req.MotorBerat, req.MotorZona1, req.MotorZona2, req.MotorZona3,
		req.MobilDimensi, req.MobilKm, req.MobilTitik, req.MobilBerat, req.MobilLumpsum,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal membuat profil konfigurasi mitra: " + err.Error()})
		return
	}

	if err = tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menyimpan data ke database"})
		return
	}

	c.JSON(http.StatusCreated, models.APIResponse{Status: "success", Message: "Mitra berhasil dibuat dengan konfigurasi tarif", Data: user})
}

// GetMitraProfile fetches the pricing profile for the logged-in mitra.
func (h *AdminHandler) GetMitraProfile(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Status: "error", Message: "Sesi tidak valid"})
		return
	}
	userID := userIDVal.(int)
	ctx := context.Background()

	var profile models.MitraProfileResponse
	profile.UserID = userID

	if err := h.DB.QueryRow(ctx, "SELECT name FROM users WHERE id = $1", userID).Scan(&profile.Name); err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil data user mitra"})
		return
	}

	profileQuery := `
	SELECT alamat_lengkap, pickup_name, pickup_lat, pickup_long,
	       motor_dimensi, motor_km, motor_titik, motor_berat, motor_zona1, motor_zona2, motor_zona3,
	       mobil_dimensi, mobil_km, mobil_titik, mobil_berat, mobil_lumpsum
	FROM mitra_profiles WHERE user_id = $1;`

	err := h.DB.QueryRow(ctx, profileQuery, userID).Scan(
		&profile.AlamatLengkap, &profile.PickupName, &profile.PickupLat, &profile.PickupLong,
		&profile.MotorDimensi, &profile.MotorKm, &profile.MotorTitik, &profile.MotorBerat, &profile.MotorZona1, &profile.MotorZona2, &profile.MotorZona3,
		&profile.MobilDimensi, &profile.MobilKm, &profile.MobilTitik, &profile.MobilBerat, &profile.MobilLumpsum,
	)

	if err == pgx.ErrNoRows || err != nil {
		// Return safe defaults when profile not yet configured
		defMotorDimensi := 1333.33
		defMotorKm := 20000.00
		defMotorTitik := 10000.00
		defMotorBerat := 5000.00
		defMotorZona1 := 10500.00
		defMotorZona2 := 17500.00
		defMotorZona3 := 24500.00

		defMobilDimensi := 1500.00
		defMobilKm := 25000.00
		defMobilTitik := 12000.00
		defMobilBerat := 6000.00
		defMobilLumpsum := 700000.00

		c.JSON(http.StatusOK, models.APIResponse{
			Status:  "success",
			Message: "Profil belum dikonfigurasi, gunakan data default",
			Data: models.MitraProfileResponse{
				UserID: userID, Name: profile.Name,
				AlamatLengkap: "Jl. Kaliurang KM 5.5, Yogyakarta",
				PickupName:    "Cabang Yogyakarta",
				PickupLat:     -7.782889, PickupLong: 110.377042,
				MotorDimensi: &defMotorDimensi, MotorKm: &defMotorKm,
				MotorTitik: &defMotorTitik, MotorBerat: &defMotorBerat,
				MotorZona1: &defMotorZona1, MotorZona2: &defMotorZona2, MotorZona3: &defMotorZona3,
				MobilDimensi: &defMobilDimensi, MobilKm: &defMobilKm,
				MobilTitik: &defMobilTitik, MobilBerat: &defMobilBerat,
				MobilLumpsum: &defMobilLumpsum,
			},
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Profil mitra berhasil diambil", Data: profile})
}
