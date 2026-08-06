package main

import (
	"context"
	"embed"
	"log"
	"net"
	"net/http"
	"strings"
	"time"

	"backend_k24apps/internal/config"
	"backend_k24apps/internal/database"
	"backend_k24apps/internal/handlers"
	"backend_k24apps/internal/middleware"
	"github.com/gin-gonic/gin"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

func main() {
	// 1. Load configuration
	cfg := config.LoadConfig()

	// 2. Connect to database
	dbPool, err := database.ConnectDB(cfg)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer dbPool.Close()

	// 3. Run database migrations
	err = database.RunMigrations(dbPool, migrationFiles)
	if err != nil {
		log.Fatalf("Database migrations failed: %v", err)
	}

	// 4. Set up Gin router
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()

	// Add Logger, Recovery, and CORS middlewares
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(middleware.CORSMiddleware(cfg.CORSOrigin))

	// Initialize handlers
	authHandler := &handlers.AuthHandler{
		DB:        dbPool,
		JWTSecret: cfg.JWTSecret,
	}
	dashboardHandler := &handlers.DashboardHandler{
		DB: dbPool,
	}
	adminHandler := &handlers.AdminHandler{
		DB: dbPool,
	}
	securityHandler := &handlers.SecurityHandler{
		DB:        dbPool,
		JWTSecret: cfg.JWTSecret,
	}
	notificationHandler := &handlers.NotificationHandler{
		DB: dbPool,
	}

	// 5. Serve uploaded profile pictures statically
	r.Static("/uploads", "./uploads")

	// 6. Define routes
	api := r.Group("/api")
	{
		// Health check
		api.GET("/health", func(c *gin.Context) {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()

			dbStatus := "connected"
			if err := dbPool.Ping(ctx); err != nil {
				dbStatus = "disconnected"
			}

			c.JSON(http.StatusOK, gin.H{
				"status": "healthy",
				"time":   time.Now().Format(time.RFC3339),
				"db":     dbStatus,
				"lan_ip": getLocalIP(),
			})
		})

		// Public authentication routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			// Rate-limit login to 5 attempts/minute per IP
			auth.POST("/login", middleware.LoginRateLimitMiddleware(), authHandler.Login)
			auth.POST("/google", authHandler.GoogleLogin)
			auth.POST("/face-login", securityHandler.FaceLogin)
		}

		// Public Pharmacist unboxing & K24 POD verification routes
		api.GET("/public/orders/:id", adminHandler.GetPublicOrderDetail)
		api.POST("/public/orders/:id/unbox", adminHandler.UnboxOrder)
		api.POST("/public/orders/:id/wait-unbox", adminHandler.WaitUnboxOrder)
		api.POST("/public/orders/:id/start-unbox", adminHandler.StartUnboxOrder)
		api.POST("/public/orders/:id/approve-pod", adminHandler.PublicApprovePOD)
		api.POST("/public/orders/:id/pod-complete", adminHandler.CompletePODOrder)

		// Protected driver routes
		driver := api.Group("/driver")
		driver.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			driver.GET("/dashboard", dashboardHandler.GetDashboard)
			driver.POST("/toggle-active", dashboardHandler.ToggleActive)
			driver.POST("/orders/:id/complete", dashboardHandler.CompleteOrder)
			driver.POST("/orders/:id/pickup", adminHandler.UpdateOrderPickup)
			driver.POST("/orders/:id/reject", adminHandler.UpdateOrderReject)
			driver.POST("/orders/:id/facture", adminHandler.UpdateOrderFacture)
			driver.POST("/orders/:id/pod-complete", adminHandler.CompletePODOrder)
			driver.GET("/notifications", notificationHandler.GetNotifications)
			driver.POST("/notifications/read", notificationHandler.MarkNotificationsRead)
		}

		// Protected user security routes
		userSec := api.Group("/user")
		userSec.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			userSec.POST("/face-register", securityHandler.FaceRegister)
			userSec.POST("/change-password", securityHandler.ChangePassword)
			userSec.POST("/update-profile", securityHandler.UpdateProfile)
		}

		// Shared protected notification routes (Admin, Mitra, Driver)
		notifGroup := api.Group("/notifications")
		notifGroup.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		{
			notifGroup.GET("", notificationHandler.GetNotifications)
			notifGroup.POST("/read", notificationHandler.MarkNotificationsRead)
		}

		// Protected admin + mitra routes
		admin := api.Group("/admin")
		admin.Use(middleware.AuthMiddleware(cfg.JWTSecret))
		admin.Use(func(c *gin.Context) {
			roleVal, exists := c.Get("role")
			if !exists || (roleVal.(string) != "ADMIN" && roleVal.(string) != "MITRA") {
				c.JSON(http.StatusForbidden, gin.H{
					"status":  "error",
					"message": "Akses ditolak: Hanya Admin atau Mitra yang diizinkan",
				})
				c.Abort()
				return
			}
			c.Next()
		})
		{
			admin.GET("/stats", adminHandler.GetAdminStats)
			admin.GET("/drivers", adminHandler.GetDrivers)
			admin.GET("/drivers/:id/document", adminHandler.GetDriverDocument)
			admin.POST("/drivers/:id/approve", adminHandler.ApproveDriver)
			admin.POST("/drivers/:id/reject", adminHandler.RejectDriver)
			admin.GET("/mitra", adminHandler.GetMitra)
			admin.POST("/mitra", adminHandler.CreateMitra)
			admin.POST("/orders", adminHandler.CreateOrder)
			admin.GET("/mitra/profile", adminHandler.GetMitraProfile)
			admin.GET("/recipients", adminHandler.GetRecipients)
			admin.POST("/orders/calculate", adminHandler.CalculateOrderPrice)
			admin.POST("/orders/bulk", adminHandler.CreateBulkOrders)
			admin.GET("/orders", adminHandler.GetOrders)
			admin.GET("/orders/invoices-flat", adminHandler.GetFlatInvoices)
			admin.GET("/orders/:dispatch_id", adminHandler.GetOrderDetail)
			admin.POST("/orders/:id/approve-reject", adminHandler.AdminApproveReject)
			admin.POST("/orders/:id/approve-facture", adminHandler.AdminApproveFacture)
			admin.GET("/dispatch/orders", adminHandler.GetPendingDispatchOrders)
			admin.GET("/dispatch/drivers", adminHandler.GetDispatchDrivers)
			admin.POST("/dispatch", adminHandler.CreateDispatchGroup)
		}
	}

	// 7. Start server
	log.Printf("K24 Driver Backend Server started on port %s (CORS: %s)", cfg.Port, cfg.CORSOrigin)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}

func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}
	for _, address := range addrs {
		if ipnet, ok := address.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				ipStr := ipnet.IP.String()
				if strings.HasPrefix(ipStr, "192.168.") || strings.HasPrefix(ipStr, "172.16.") || strings.HasPrefix(ipStr, "172.20.") || strings.HasPrefix(ipStr, "172.31.") || strings.HasPrefix(ipStr, "10.") {
					return ipStr
				}
			}
		}
	}
	return ""
}
