package handlers

import (
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"backend_k24apps/internal/middleware"
	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type SecurityHandler struct {
	DB        *pgxpool.Pool
	JWTSecret string
}

// FaceRegister registers the user's face template/signature
func (h *SecurityHandler) FaceRegister(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Pengguna tidak terotentikasi",
		})
		return
	}
	userID := userIDVal.(int)

	var req models.FaceRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Format data wajah tidak valid",
		})
		return
	}

	ctx := context.Background()
	_, err := h.DB.Exec(ctx, "UPDATE users SET face_data = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", req.FaceData, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menyimpan data verifikasi wajah",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Verifikasi wajah berhasil didaftarkan!",
	})
}

// ChangePassword changes the authenticated user's password
func (h *SecurityHandler) ChangePassword(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Pengguna tidak terotentikasi",
		})
		return
	}
	userID := userIDVal.(int)

	var req models.ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Data sandi baru tidak memenuhi syarat minimum (6 karakter)",
		})
		return
	}

	ctx := context.Background()
	var storedHash string
	err := h.DB.QueryRow(ctx, "SELECT password_hash FROM users WHERE id = $1", userID).Scan(&storedHash)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memuat informasi akun",
		})
		return
	}

	// Verify old password
	err = bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(req.OldPassword))
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Kata sandi lama salah",
		})
		return
	}

	// Hash new password
	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memproses kata sandi baru",
		})
		return
	}

	// Update DB
	_, err = h.DB.Exec(ctx, "UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2", string(newHash), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memperbarui kata sandi",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Kata sandi berhasil diubah!",
	})
}

// FaceLogin authenticates users via their registered face signature
func (h *SecurityHandler) FaceLogin(c *gin.Context) {
	var req models.FaceLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Format data login wajah tidak lengkap",
		})
		return
	}

	ctx := context.Background()
	var user models.User
	var storedFaceData *string

	// Query user by username or email
	query := `
	SELECT id, username, email, name, phone, role, face_data, COALESCE(profile_picture, ''), created_at, updated_at
	FROM users
	WHERE email = $1 OR username = $1;`

	err := h.DB.QueryRow(ctx, query, req.Username).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.Name,
		&user.Phone,
		&user.Role,
		&storedFaceData,
		&user.ProfilePicture,
		&user.CreatedAt,
		&user.UpdatedAt,
	)

	if err == pgx.ErrNoRows {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Status:  "error",
			Message: "Akun dengan email/username tersebut tidak ditemukan",
		})
		return
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal memproses verifikasi wajah",
		})
		return
	}

	// Check if face data is registered
	if storedFaceData == nil || *storedFaceData == "" {
		c.JSON(http.StatusForbidden, models.APIResponse{
			Status:  "error",
			Message: "Metode login wajah belum diaktifkan/didaftarkan untuk akun ini",
		})
		return
	}

	// Verify face data
	// If the incoming face_data is a mock indicating "orang_lain", or does not match the stored signature: fail!
	if req.FaceData == "face_invalid_sig" || req.FaceData != *storedFaceData {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Verifikasi wajah gagal: Wajah tidak cocok dengan yang terdaftar",
		})
		return
	}

	// Face matches! Issue JWT token
	token, err := middleware.GenerateToken(user.ID, user.Email, user.Role, h.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Gagal menerbitkan token otentikasi wajah",
		})
		return
	}

	// Check if driver profile exists if DRIVER role
	var responsePayload models.LoginResponse
	responsePayload.Token = token
	responsePayload.Role = user.Role

	if user.Role == "DRIVER" {
		var plateNumber string
		var isActive bool
		var rating float64

		err = h.DB.QueryRow(ctx,
			"SELECT plate_number, is_active, rating FROM driver_profiles WHERE user_id = $1",
			user.ID,
		).Scan(&plateNumber, &isActive, &rating)

		if err == pgx.ErrNoRows {
			plateNumber = "Belum diatur"
			isActive = false
			rating = 5.00
			_, _ = h.DB.Exec(ctx, "INSERT INTO driver_profiles (user_id, plate_number, is_active, rating) VALUES ($1, $2, $3, $4)", user.ID, plateNumber, isActive, rating)
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{
				Status:  "error",
				Message: "Gagal memuat profil driver",
			})
			return
		}

		responsePayload.Driver = models.Driver{
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
	} else {
		responsePayload.Driver = user
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Verifikasi wajah sukses! Selamat datang kembali.",
		Data:    responsePayload,
	})
}

type UpdateProfileRequest struct {
	Name           string `json:"name" binding:"required"`
	Email          string `json:"email" binding:"required,email"`
	Phone          string `json:"phone"`
	PlateNumber    string `json:"plate_number"`
	ProfilePicture string `json:"profile_picture"`
}

func (h *SecurityHandler) UpdateProfile(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Status:  "error",
			Message: "Pengguna tidak terotentikasi",
		})
		return
	}
	userID := userIDVal.(int)

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Status:  "error",
			Message: "Format data profil tidak valid",
		})
		return
	}

	ctx := context.Background()
	profilePicPath := req.ProfilePicture

	// Check if incoming profile picture is base64 Data URI
	if strings.HasPrefix(req.ProfilePicture, "data:image/") {
		parts := strings.Split(req.ProfilePicture, ";base64,")
		if len(parts) == 2 {
			base64Data := parts[1]
			decodedBytes, err := base64.StdEncoding.DecodeString(base64Data)
			if err != nil {
				log.Printf("[UpdateProfile Base64 Decode Error]: %v", err)
				c.JSON(http.StatusBadRequest, models.APIResponse{
					Status:  "error",
					Message: "Gagal mendecode data gambar base64",
				})
				return
			}

			// Define file path
			uploadsDir := "./uploads/profile_pictures"
			err = os.MkdirAll(uploadsDir, os.ModePerm)
			if err != nil {
				log.Printf("[UpdateProfile Mkdir Error]: %v", err)
				c.JSON(http.StatusInternalServerError, models.APIResponse{
					Status:  "error",
					Message: "Gagal membuat folder penyimpanan gambar",
				})
				return
			}

			// Get file extension from prefix or default to .jpg
			ext := ".jpg"
			if strings.Contains(parts[0], "image/png") {
				ext = ".png"
			} else if strings.Contains(parts[0], "image/gif") {
				ext = ".gif"
			}

			fileName := fmt.Sprintf("user_%d_%d%s", userID, time.Now().UnixNano(), ext)
			filePath := filepath.Join(uploadsDir, fileName)

			// Write to file
			err = os.WriteFile(filePath, decodedBytes, 0644)
			if err != nil {
				log.Printf("[UpdateProfile WriteFile Error]: %v", err)
				c.JSON(http.StatusInternalServerError, models.APIResponse{
					Status:  "error",
					Message: "Gagal menulis file gambar ke penyimpanan",
				})
				return
			}

			// Store relative web path in database
			profilePicPath = "/uploads/profile_pictures/" + fileName
			log.Printf("[UpdateProfile Info]: User %d successfully uploaded profile pic saved at %s", userID, profilePicPath)
		}
	}

	_, err := h.DB.Exec(ctx, "UPDATE users SET name = $1, email = $2, phone = $3, profile_picture = $4, updated_at = CURRENT_TIMESTAMP WHERE id = $5", req.Name, req.Email, req.Phone, profilePicPath, userID)
	if err != nil {
		log.Printf("[UpdateProfile SQL Error]: %v", err)
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Status:  "error",
			Message: "Email sudah terdaftar oleh pengguna lain atau database bermasalah: " + err.Error(),
		})
		return
	}

	if req.PlateNumber != "" {
		_, errPlate := h.DB.Exec(ctx, "UPDATE driver_profiles SET plate_number = $1 WHERE user_id = $2", req.PlateNumber, userID)
		if errPlate != nil {
			log.Printf("[UpdatePlate SQL Error]: %v", errPlate)
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Status:  "success",
		Message: "Profil berhasil diperbarui!",
	})
}
