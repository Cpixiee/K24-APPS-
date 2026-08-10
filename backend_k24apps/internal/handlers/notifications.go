package handlers

import (
	"context"
	"net/http"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type NotificationHandler struct {
	DB *pgxpool.Pool
}

type QueryExecutor interface {
	Exec(context.Context, string, ...interface{}) (pgconn.CommandTag, error)
}

// CreateNotification helper to insert a notification for a user or driver
func CreateNotification(ctx context.Context, exec QueryExecutor, userID *int, driverID *int, title string, message string) {
	if exec == nil {
		return
	}
	_, _ = exec.Exec(ctx,
		`INSERT INTO notifications (user_id, driver_id, title, message) VALUES ($1, $2, $3, $4)`,
		userID, driverID, title, message,
	)
}

// NotifyAdmins helper to broadcast a notification to all Admin users
func NotifyAdmins(ctx context.Context, db *pgxpool.Pool, title string, message string) {
	if db == nil {
		return
	}
	rows, err := db.Query(ctx, "SELECT id FROM users WHERE role = 'ADMIN'")
	if err != nil {
		return
	}
	defer rows.Close()

	var adminIDs []int
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err == nil {
			adminIDs = append(adminIDs, id)
		}
	}

	for _, adminID := range adminIDs {
		adminIDCopy := adminID
		CreateNotification(ctx, db, &adminIDCopy, nil, title, message)
	}
}

// GetNotifications returns notifications list for the logged-in user (Admin, Mitra, or Driver)
func (h *NotificationHandler) GetNotifications(c *gin.Context) {
	var uid int
	if val, exists := c.Get("user_id"); exists {
		uid = val.(int)
	} else if val, exists := c.Get("driver_id"); exists {
		uid = val.(int)
	} else {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Status: "error", Message: "Pengguna tidak terautentikasi"})
		return
	}

	ctx := context.Background()
	rows, err := h.DB.Query(ctx,
		`SELECT id, COALESCE(user_id, driver_id, 0) as user_id, title, message, is_read, created_at 
		 FROM notifications 
		 WHERE user_id = $1 OR driver_id = $1 
		 ORDER BY created_at DESC 
		 LIMIT 50`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal mengambil notifikasi: " + err.Error()})
		return
	}
	defer rows.Close()

	notifications := []models.Notification{}
	for rows.Next() {
		var n models.Notification
		err := rows.Scan(&n.ID, &n.DriverID, &n.Title, &n.Message, &n.IsRead, &n.CreatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal membaca notifikasi: " + err.Error()})
			return
		}
		notifications = append(notifications, n)
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Data: notifications})
}

// MarkNotificationsRead marks all notifications for logged-in user as read
func (h *NotificationHandler) MarkNotificationsRead(c *gin.Context) {
	var uid int
	if val, exists := c.Get("user_id"); exists {
		uid = val.(int)
	} else if val, exists := c.Get("driver_id"); exists {
		uid = val.(int)
	} else {
		c.JSON(http.StatusUnauthorized, models.APIResponse{Status: "error", Message: "Pengguna tidak terautentikasi"})
		return
	}

	ctx := context.Background()
	var err error
	if uid > 0 {
		_, err = h.DB.Exec(ctx,
			`UPDATE notifications 
			 SET is_read = TRUE 
			 WHERE user_id = $1 OR driver_id = $1 OR user_id IS NULL OR driver_id IS NULL`, uid)
	} else {
		_, err = h.DB.Exec(ctx, `UPDATE notifications SET is_read = TRUE`)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{Status: "error", Message: "Gagal menandai notifikasi: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Status: "success", Message: "Semua notifikasi berhasil ditandai dibaca"})
}
