package models

import (
	"time"
)

// User represents the users table structure
type User struct {
	ID             int       `json:"id"`
	Username       string    `json:"username"`
	Email          string    `json:"email"`
	Name           string    `json:"name"`
	PasswordHash   string    `json:"-"`
	Phone          string    `json:"phone"`
	Role           string    `json:"role"` // 'ADMIN', 'DRIVER', 'MITRA'
	MitraType      string    `json:"mitra_type,omitempty"` // 'K24', 'PRIMAKU'
	ProfilePicture string    `json:"profile_picture"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// Driver represents the combined User and DriverProfile flat JSON for Flutter compatibility
type Driver struct {
	ID             int       `json:"id"`
	Username       string    `json:"username"`
	Name           string    `json:"name"`
	Email          string    `json:"email"`
	Phone          string    `json:"phone"`
	PlateNumber    string    `json:"plate_number"`
	IsActive       bool      `json:"is_active"`
	Rating         float64   `json:"rating"`
	VehicleType    string    `json:"vehicle_type"`
	IsApproved     bool      `json:"is_approved"`
	KTPUrl         string    `json:"ktp_url"`
	SIMUrl         string    `json:"sim_url"`
	STNKUrl        string    `json:"stnk_url"`
	Role           string    `json:"role"`
	ProfilePicture string    `json:"profile_picture"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// Order represents the order table structure
type Order struct {
	ID                  int        `json:"id"`
	OrderNumber         string     `json:"order_number"`
	ParentOrderNumber   string     `json:"parent_order_number,omitempty"`
	DriverID            *int       `json:"driver_id,omitempty"`
	MitraID             *int       `json:"mitra_id,omitempty"`
	DispatchID          string     `json:"dispatch_id,omitempty"`
	DriverName          string     `json:"driver_name,omitempty"`
	Status              string     `json:"status"` // 'PENDING', 'WAITING_FOR_PICKUP', 'ON_DELIVERY', 'COMPLETED', 'CANCELLED'
	PharmacyName        string     `json:"pharmacy_name"`
	PharmacyAddress     string     `json:"pharmacy_address"`
	DeliveryAddress     string     `json:"delivery_address"`
	CustomerName        string     `json:"customer_name"`
	CustomerPhone       string     `json:"customer_phone"`
	MedicineSummary     string     `json:"medicine_summary"`
	DeliveryFee         float64    `json:"delivery_fee"`
	DistanceKM          float64    `json:"distance_km"`
	PickupPhotoUrl      string     `json:"pickup_photo_url"`
	PickupNote          string     `json:"pickup_note"`
	RejectPhotoUrl      string     `json:"reject_photo_url"`
	RejectNote          string     `json:"reject_note"`
	RejectReason        string     `json:"reject_reason"`
	RejectApproved      bool       `json:"reject_approved"`
	UnboxingOption      string     `json:"unboxing_option"`
	CheckedInvoices     string     `json:"checked_invoices"`
	ExtraItemsNote      string     `json:"extra_items_note"`
	ExtraItemsPhotoUrl  string     `json:"extra_items_photo_url"`
	FacturePhotoUrl     string     `json:"facture_photo_url"`
	SignaturePhotoUrl    string     `json:"signature_photo_url"`
	PODSignaturePhotoUrl string     `json:"pod_signature_photo_url"`
	CreatedAt           time.Time  `json:"created_at"`
	CompletedAt         *time.Time `json:"completed_at,omitempty"`
	PharmacyLat         float64    `json:"pharmacy_lat,omitempty"`
	PharmacyLng         float64    `json:"pharmacy_lng,omitempty"`
	CustomerLat         float64    `json:"customer_lat,omitempty"`
	CustomerLng         float64    `json:"customer_lng,omitempty"`
}

// Notification represents a driver notification database record
type Notification struct {
	ID        int       `json:"id"`
	DriverID  int       `json:"driver_id"`
	Title     string    `json:"title"`
	Message   string    `json:"message"`
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

// Stats holds aggregated driver stats for the dashboard
type Stats struct {
	TodayEarnings float64 `json:"today_earnings"`
	TodayOrders   int     `json:"today_orders"`
	TotalEarnings float64 `json:"total_earnings"`
	TotalOrders   int     `json:"total_orders"`
}

// DashboardData represents the consolidated response to prevent multiple API roundtrips
type DashboardData struct {
	Driver       Driver   `json:"driver"`
	Stats        Stats    `json:"stats"`
	ActiveOrder  *Order   `json:"active_order,omitempty"`
	ActiveOrders []Order  `json:"active_orders"`
	RecentOrders []Order  `json:"recent_orders"`
}

// APIResponse is the standard wrapper for all API responses
type APIResponse struct {
	Status  string      `json:"status"`            // "success" or "error"
	Message string      `json:"message,omitempty"` // User-friendly message
	Data    interface{} `json:"data,omitempty"`    // Dynamic payload data
}

// RegisterRequest holds registration inputs (backward compatible with original Flutter UI)
type RegisterRequest struct {
	Name        string `json:"name" binding:"required"`
	Email       string `json:"email" binding:"required,email"`
	Phone       string `json:"phone" binding:"required"`
	PlateNumber string `json:"plate_number" binding:"required"`
	Password    string `json:"password" binding:"required,min=6"`
	VehicleType string `json:"vehicle_type" binding:"required"`
	KTPText     string `json:"ktp_url"`
	SIMText     string `json:"sim_url"`
	STNKText    string `json:"stnk_url"`
}

// LoginRequest holds unified login inputs (can be email or username)
type LoginRequest struct {
	Email    string `json:"email" binding:"required"` // Can act as email or username
	Password string `json:"password" binding:"required"`
}

// GoogleLoginRequest holds inputs for Google Authentication
type GoogleLoginRequest struct {
	IDToken string `json:"id_token" binding:"required"`
	Email   string `json:"email" binding:"required,email"`
	Name    string `json:"name" binding:"required"`
}

// ToggleActiveRequest holds active status toggle payload
type ToggleActiveRequest struct {
	IsActive bool `json:"is_active"`
}

// LoginResponse contains driver/user info and authorization token
type LoginResponse struct {
	Token  string      `json:"token"`
	Role   string      `json:"role"`
	Driver interface{} `json:"driver"` // Can contain Driver struct or User struct
}

// AdminStats holds statistics for the admin dashboard
type AdminStats struct {
	TotalDrivers    int `json:"total_drivers"`
	TotalMitra      int `json:"total_mitra"`
	TotalOrders     int `json:"total_orders"`
	TotalInvoices   int `json:"total_invoices"`
	PendingDispatch int `json:"pending_dispatch"`
	ActiveDispatch  int `json:"active_dispatch"`
	CompletedOrders int `json:"completed_orders"`
	CancelledOrders int `json:"cancelled_orders"`
	OnlineDrivers   int `json:"online_drivers"`
}

// CreateMitraRequest holds inputs for registering a partner (mitra)
type CreateMitraRequest struct {
	Username      string   `json:"username" binding:"required"`
	Email         string   `json:"email" binding:"required,email"`
	Name          string   `json:"name" binding:"required"`
	Phone         string   `json:"phone" binding:"required"`
	Password      string   `json:"password" binding:"required,min=6"`
	PicName       string   `json:"pic_name" binding:"required"`
	PicNik        string   `json:"pic_nik" binding:"required"`
	AlamatLengkap string   `json:"alamat_lengkap" binding:"required"`
	PickupName    string   `json:"pickup_name" binding:"required"`
	PickupLat     float64  `json:"pickup_lat" binding:"required"`
	PickupLong    float64  `json:"pickup_long" binding:"required"`
	MitraType     string   `json:"mitra_type"` // 'K24' or 'PRIMAKU'
	
	// Motor Configuration
	MotorDimensi *float64 `json:"motor_dimensi"`
	MotorKm      *float64 `json:"motor_km"`
	MotorTitik   *float64 `json:"motor_titik"`
	MotorBerat   *float64 `json:"motor_berat"`
	
	// Mobil Configuration
	MobilDimensi *float64 `json:"mobil_dimensi"`
	MobilKm      *float64 `json:"mobil_km"`
	MobilTitik   *float64 `json:"mobil_titik"`
	MobilBerat   *float64 `json:"mobil_berat"`
	MobilLumpsum *float64 `json:"mobil_lumpsum"`
}

type FaceRegisterRequest struct {
	FaceData string `json:"face_data" binding:"required"`
}

type FaceLoginRequest struct {
	Username string `json:"username" binding:"required"`
	FaceData string `json:"face_data" binding:"required"`
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

// CreateOrderRequest holds inputs for creating a new pharmacy order
type CreateOrderRequest struct {
	PharmacyName    string  `json:"pharmacy_name" binding:"required"`
	PharmacyAddress string  `json:"pharmacy_address" binding:"required"`
	DeliveryAddress string  `json:"delivery_address" binding:"required"`
	CustomerName    string  `json:"customer_name" binding:"required"`
	CustomerPhone   string  `json:"customer_phone" binding:"required"`
	MedicineSummary string  `json:"medicine_summary" binding:"required"`
	DeliveryFee     float64 `json:"delivery_fee" binding:"required,gt=0"`
}

type MitraProfileResponse struct {
	UserID        int      `json:"user_id"`
	Name          string   `json:"name"`
	AlamatLengkap string   `json:"alamat_lengkap"`
	PickupName    string   `json:"pickup_name"`
	PickupLat     float64  `json:"pickup_lat"`
	PickupLong    float64  `json:"pickup_long"`
	
	// Motor Configuration
	MotorDimensi *float64 `json:"motor_dimensi"`
	MotorKm      *float64 `json:"motor_km"`
	MotorTitik   *float64 `json:"motor_titik"`
	MotorBerat   *float64 `json:"motor_berat"`
	
	// Mobil Configuration
	MobilDimensi *float64 `json:"mobil_dimensi"`
	MobilKm      *float64 `json:"mobil_km"`
	MobilTitik   *float64 `json:"mobil_titik"`
	MobilBerat   *float64 `json:"mobil_berat"`
	MobilLumpsum *float64 `json:"mobil_lumpsum"`
}

type Recipient struct {
	ID            int     `json:"id"`
	NamaApotek    string  `json:"nama_apotek"`
	AlamatLengkap string  `json:"alamat_lengkap"`
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
}

type CalculateOrderRequest struct {
	Armada   string               `json:"armada" binding:"required"`
	RateType string               `json:"rate_type" binding:"required"`
	Items    []CalculateOrderItem `json:"items" binding:"required"`
}

type CalculateOrderItem struct {
	NamaApotek    string   `json:"nama_apotek" binding:"required"`
	AlamatLengkap string   `json:"alamat_lengkap" binding:"required"`
	KubikAktual   *float64 `json:"kubik_aktual"`
	BeratAktual   *float64 `json:"berat_aktual"`
	JumlahInvoice int      `json:"jumlah_invoice"`
}

type CalculateOrderResponse struct {
	Items      []CalculatedItemResult `json:"items"`
	TotalPrice float64                `json:"total_price"`
}

type CalculatedItemResult struct {
	NamaApotek    string  `json:"nama_apotek"`
	AlamatLengkap string  `json:"alamat_lengkap"`
	JarakKm       float64 `json:"jarak_km"`
	Price         float64 `json:"price"`
	Warning       string  `json:"warning,omitempty"`
}

type CreateBulkOrdersRequest struct {
	Armada   string               `json:"armada" binding:"required"`
	RateType string               `json:"rate_type" binding:"required"`
	Items    []BulkOrderItemInput `json:"items" binding:"required"`
}

type BulkOrderItemInput struct {
	NamaApotek    string   `json:"nama_apotek" binding:"required"`
	AlamatLengkap string   `json:"alamat_lengkap" binding:"required"`
	Latitude      float64  `json:"latitude"`
	Longitude     float64  `json:"longitude"`
	KubikAktual   *float64 `json:"kubik_aktual"`
	BeratAktual   *float64 `json:"berat_aktual"`
	Invoices      []string `json:"invoices"`
}

// PendingDispatchOrder represents order rows waiting for dispatch
type PendingDispatchOrder struct {
	ID              int       `json:"id"`
	OrderNumber     string    `json:"order_number"`
	MitraID         int       `json:"mitra_id"`
	MitraName       string    `json:"mitra_name"`
	PharmacyName    string    `json:"pharmacy_name"`
	PharmacyAddress string    `json:"pharmacy_address"`
	DeliveryAddress string    `json:"delivery_address"`
	CustomerName    string    `json:"customer_name"`
	CustomerPhone   string    `json:"customer_phone"`
	Invoices        []string  `json:"invoices"`
	Armada          string    `json:"armada"`
	RateType        string    `json:"rate_type"`
	DeliveryFee     float64   `json:"delivery_fee"`
	CreatedAt       time.Time `json:"created_at"`
}

// PendingDispatchBatch represents a grouped bulk order (e.g. ORD-000001) containing multiple stops
type PendingDispatchBatch struct {
	DispatchID string                `json:"dispatch_id"`
	MitraID    int                   `json:"mitra_id"`
	MitraName  string                `json:"mitra_name"`
	Armada     string                `json:"armada"`
	RateType   string                `json:"rate_type"`
	CreatedAt  time.Time             `json:"created_at"`
	Stops      []PendingDispatchStop `json:"stops"`
}

// PendingDispatchStop represents a single recipient delivery destination within a batch
type PendingDispatchStop struct {
	ID              int      `json:"id"`
	OrderNumber     string   `json:"order_number"`
	CustomerName    string   `json:"customer_name"`
	DeliveryAddress string   `json:"delivery_address"`
	Invoices        []string `json:"invoices"`
	DeliveryFee     float64  `json:"delivery_fee"`
	Lat             float64  `json:"lat"`
	Lng             float64  `json:"lng"`
}

// CreateDispatchGroupRequest represents payload from Admin to dispatch single/bulk orders
type CreateDispatchGroupRequest struct {
	OrderIDs []int `json:"order_ids" binding:"required,min=1"`
	DriverID int   `json:"driver_id" binding:"required"`
	Sequence []int `json:"sequence" binding:"required,min=1"`
}

