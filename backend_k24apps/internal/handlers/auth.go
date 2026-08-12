package handlers

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"backend_k24apps/internal/middleware"
	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	DB        *pgxpool.Pool
	JWTSecret string
}

// Register handles driver registration (maps to both users and driver_profiles tables)
func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Format input tidak valid atau kolom wajib belum terisi: " + err.Error(),
		})
		return
	}

	ctx := context.Background()

	// Begin Transaction (ensures data consistency between users and driver_profiles)
	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memulai transaksi registrasi",
		})
		return
	}
	defer tx.Rollback(ctx)

	// Check if user already exists (by email or username)
	// We use the email prefix or full email as username for new drivers
	var exists bool
	err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1 OR username = $1)", req.Email).Scan(&exists)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memeriksa email di database",
		})
		return
	}

	if exists {
		c.JSON(http.StatusConflict, models.APIResponse{
			Status:  "error",
			Message: "Email atau username ini sudah terdaftar",
		})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal mengenkripsi kata sandi",
		})
		return
	}

	// 1. Insert into users table
	var userID int
	var user models.User
	insertUserQuery := `
	INSERT INTO users (username, email, name, password_hash, phone, role)
	VALUES ($1, $2, $3, $4, $5, 'DRIVER')
	RETURNING id, username, email, name, phone, role, created_at, updated_at;`

	err = tx.QueryRow(ctx, insertUserQuery,
		req.Email, // Set username equal to email for seamless login
		req.Email,
		req.Name,
		string(hashedPassword),
		req.Phone,
	).Scan(
		&userID,
		&user.Username,
		&user.Email,
		&user.Name,
		&user.Phone,
		&user.Role,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menyimpan data user",
		})
		return
	}

	// 2. Insert into driver_profiles table
	insertProfileQuery := `
	INSERT INTO driver_profiles (user_id, plate_number, is_active, rating, vehicle_type, is_approved, ktp_url, sim_url, stnk_url)
	VALUES ($1, $2, false, 5.00, $3, false, $4, $5, $6);`

	_, err = tx.Exec(ctx, insertProfileQuery, userID, req.PlateNumber, req.VehicleType, req.KTPText, req.SIMText, req.STNKText)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menyimpan profil kendaraan driver: " + err.Error(),
		})
		return
	}

	// Commit Transaction
	err = tx.Commit(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menyelesaikan transaksi registrasi",
		})
		return
	}

	// Generate JWT
	token, err := middleware.GenerateToken(userID, user.Email, user.Role, h.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menerbitkan token otentikasi",
		})
		return
	}

	// Flat mapping for Flutter compatibility
	flatDriver := models.Driver{
		ID:          userID,
		Username:    user.Username,
		Name:        user.Name,
		Email:       user.Email,
		Phone:       user.Phone,
		PlateNumber: req.PlateNumber,
		IsActive:    false,
		Rating:      5.00,
		VehicleType: req.VehicleType,
		IsApproved:  false,
		KTPUrl:      req.KTPText,
		SIMUrl:      req.SIMText,
		STNKUrl:     req.STNKText,
		Role:        user.Role,
		CreatedAt:   user.CreatedAt,
		UpdatedAt:   user.UpdatedAt,
	}

	c.JSON(http.StatusCreated, models.APIResponse{
		Status:  "success",
		Message: "Registrasi driver berhasil diajukan. Menunggu persetujuan Admin.",
		Data: models.LoginResponse{
			Token:  token,
			Role:   user.Role,
			Driver: flatDriver,
		},
	})
}

// Login handles unified login for ADMIN, DRIVER, and MITRA roles
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Format email atau password tidak sesuai",
		})
		return
	}

	ctx := context.Background()
	var user models.User
	var passwordHash string

	// Search by email OR username (supports 'goodwheel' admin login)
	selectQuery := `
	SELECT id, username, email, name, password_hash, phone, role, COALESCE(profile_picture, ''), created_at, updated_at
	FROM users
	WHERE email = $1 OR username = $1;`

	err := h.DB.QueryRow(ctx, selectQuery, req.Email).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.Name,
		&passwordHash,
		&user.Phone,
		&user.Role,
		&user.ProfilePicture,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Username/Email atau kata sandi Anda salah",
		})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Terjadi kesalahan sistem saat memproses login",
		})
		return
	}

	// Verify password
	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password))
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Username/Email atau kata sandi Anda salah",
		})
		return
	}

	// Verify Admin Approval for Drivers
	var plateNumber string
	var isActive bool
	var rating float64
	var vehicleType string
	var isApproved bool
	var ktpUrl, simUrl, stnkUrl string

	var isSuspended bool
	var suspendedUntil *time.Time
	var suspendReason string

	if user.Role == "DRIVER" {
		err = h.DB.QueryRow(ctx,
			`SELECT plate_number, is_active, rating, COALESCE(vehicle_type, 'motor'), COALESCE(is_approved, false), 
			        COALESCE(is_suspended, false), suspended_until, COALESCE(suspend_reason, ''),
			        COALESCE(ktp_url, ''), COALESCE(sim_url, ''), COALESCE(stnk_url, '') 
			 FROM driver_profiles WHERE user_id = $1`,
			user.ID,
		).Scan(&plateNumber, &isActive, &rating, &vehicleType, &isApproved, &isSuspended, &suspendedUntil, &suspendReason, &ktpUrl, &simUrl, &stnkUrl)

		if err == pgx.ErrNoRows {
			// Auto create default profile if missing to prevent crashes
			plateNumber = "Belum diatur"
			isActive = false
			rating = 5.00
			vehicleType = "motor"
			isApproved = false // Require admin approval by default
			_, _ = h.DB.Exec(ctx, "INSERT INTO driver_profiles (user_id, plate_number, is_active, rating, vehicle_type, is_approved) VALUES ($1, $2, $3, $4, $5, false)", user.ID, plateNumber, isActive, rating, vehicleType)
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memproses profil driver",
			})
			return
		}

		// Auto-lift expired suspension
		if isSuspended && suspendedUntil != nil && time.Now().After(*suspendedUntil) {
			_, _ = h.DB.Exec(ctx, "UPDATE driver_profiles SET is_suspended = false, suspended_until = NULL, suspend_reason = '' WHERE user_id = $1", user.ID)
			isSuspended = false
		}

		if isSuspended {
			suspendMsg := "Akun driver Anda sedang di-suspend secara PERMANEN."
			if suspendedUntil != nil {
				suspendMsg = fmt.Sprintf("Akun driver Anda di-suspend hingga %s.", suspendedUntil.Format("02 Jan 2006 15:04 WIB"))
			}
			if suspendReason != "" {
				suspendMsg += " Alasan: " + suspendReason
			}
			c.JSON(http.StatusForbidden, models.APIResponse{
				Status:  "error",
				Message: suspendMsg,
			})
			return
		}

		if !isApproved {
			c.JSON(http.StatusForbidden, models.APIResponse{
				Status:  "error",
				Message: "Akun Anda belum disetujui oleh Admin. Silakan hubungi Admin K-24.",
			})
			return
		}
	}

	// Generate JWT
	token, err := middleware.GenerateToken(user.ID, user.Email, user.Role, h.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menerbitkan token otentikasi",
		})
		return
	}

	// Handle role-specific response mapping
	var responsePayload models.LoginResponse
	responsePayload.Token = token
	responsePayload.Role = user.Role

	if user.Role == "DRIVER" {
		responsePayload.Driver = models.Driver{
			ID:          user.ID,
			Username:    user.Username,
			Name:        user.Name,
			Email:       user.Email,
			Phone:       user.Phone,
			PlateNumber: plateNumber,
			IsActive:    isActive,
			Rating:      rating,
			VehicleType: vehicleType,
			IsApproved:  isApproved,
			KTPUrl:      ktpUrl,
			SIMUrl:      simUrl,
			STNKUrl:     stnkUrl,
			Role:        user.Role,
			CreatedAt:   user.CreatedAt,
			UpdatedAt:   user.UpdatedAt,
		}
	} else {
		// For ADMIN and MITRA, return user directly
		responsePayload.Driver = user
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Login berhasil",
		Data:    responsePayload,
	})
}

// GoogleLogin handles oauth/sign-in with Google tokens
func (h *AuthHandler) GoogleLogin(c *gin.Context) {
	var req models.GoogleLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Payload login Google tidak valid",
		})
		return
	}

	ctx := context.Background()
	var user models.User

	// Check if user already exists
	selectQuery := `
	SELECT id, username, email, name, phone, role, COALESCE(profile_picture, ''), created_at, updated_at
	FROM users
	WHERE email = $1;`

	err := h.DB.QueryRow(ctx, selectQuery, req.Email).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.Name,
		&user.Phone,
		&user.Role,
		&user.ProfilePicture,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		// Begin Transaction for Auto-registration
		tx, err := h.DB.Begin(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memproses pendaftaran Google",
			})
			return
		}
		defer tx.Rollback(ctx)

		// Create user
		insertUserQuery := `
		INSERT INTO users (username, email, name, password_hash, phone, role)
		VALUES ($1, $2, $3, 'GOOGLE_AUTH_MOCK', '', 'DRIVER')
		RETURNING id, username, email, name, phone, role, created_at, updated_at;`

		err = tx.QueryRow(ctx, insertUserQuery, req.Email, req.Email, req.Name).Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&user.Name,
			&user.Phone,
			&user.Role,
			&user.CreatedAt,
			&user.UpdatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal membuat user Google",
			})
			return
		}

		// Create profile
		_, err = tx.Exec(ctx, "INSERT INTO driver_profiles (user_id, plate_number, is_active, rating) VALUES ($1, 'Belum diatur', false, 5.00);", user.ID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal membuat profil driver Google",
			})
			return
		}

		err = tx.Commit(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memproses transaksi pendaftaran Google",
			})
			return
		}
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memeriksa data login Google",
		})
		return
	}

	// Generate JWT
	token, err := middleware.GenerateToken(user.ID, user.Email, user.Role, h.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menerbitkan token otentikasi",
		})
		return
	}

	// Fetch plate number and stats for DRIVER response
	var plateNumber string
	var isActive bool
	var rating float64
	_ = h.DB.QueryRow(ctx, "SELECT plate_number, is_active, rating FROM driver_profiles WHERE user_id = $1", user.ID).Scan(&plateNumber, &isActive, &rating)

	flatDriver := models.Driver{
		ID:          user.ID,
		Username:    user.Username,
		Name:        user.Name,
		Email:       user.Email,
		Phone:       user.Phone,
		PlateNumber: plateNumber,
		IsActive:    isActive,
		Rating:      rating,
		Role:        user.Role,
		CreatedAt:   user.CreatedAt,
		UpdatedAt:   user.UpdatedAt,
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Login via Google berhasil",
		Data: models.LoginResponse{
			Token:  token,
			Role:   user.Role,
			Driver: flatDriver,
		},
	})
}
