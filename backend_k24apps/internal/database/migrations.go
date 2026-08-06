package database

import (
	"context"
	"embed"
	"log"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// RunMigrations reads all *.sql files from the embedded migrations/ directory
// in lexicographic order (000001_*, 000002_*, ...) and executes each one.
// All statements use IF NOT EXISTS / IF EXISTS so re-runs are safe (idempotent).
func RunMigrations(pool *pgxpool.Pool, fs embed.FS) error {
	ctx := context.Background()

	// Ensure schema_migrations tracking table exists
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		);
	`)
	if err != nil {
		return err
	}

	// Read migration directory entries
	entries, err := fs.ReadDir("migrations")
	if err != nil {
		return err
	}

	// Sort to guarantee lexicographic (version) order
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		name := entry.Name()

		// Only process .sql files; skip directories and other files
		if entry.IsDir() || !strings.HasSuffix(name, ".sql") {
			continue
		}

		var alreadyApplied bool
		err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", name).Scan(&alreadyApplied)
		if err == nil && alreadyApplied {
			continue // Skip already applied migrations
		}

		log.Printf("Running migration: %s", name)

		content, err := fs.ReadFile("migrations/" + name)
		if err != nil {
			return err
		}

		if _, err = pool.Exec(ctx, string(content)); err != nil {
			log.Printf("Migration %s failed: %v", name, err)
			return err
		}

		_, _ = pool.Exec(ctx, "INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING", name)
		log.Printf("Migration %s applied successfully.", name)
	}

	log.Println("All database migrations completed.")

	// Run admin seeding after schema is ready
	return SeedAdminUser(pool)
}

// SeedAdminUser seeds the default admin account if it does not already exist.
// Credentials are set via code here — in production use env vars for the initial seed.
func SeedAdminUser(pool *pgxpool.Pool) error {
	ctx := context.Background()
	adminUsername := "goodwheel"
	adminEmail := "goodwheel@k24.com"
	adminPassword := "good123"

	var exists bool
	if err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1)", adminUsername).Scan(&exists); err != nil {
		return err
	}

	if !exists {
		log.Printf("Seeding default admin user '%s'...", adminUsername)

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(adminPassword), bcrypt.DefaultCost)
		if err != nil {
			return err
		}

		_, err = pool.Exec(ctx, `
		INSERT INTO users (username, email, name, password_hash, role, phone)
		VALUES ($1, $2, 'Goodwheel Admin', $3, 'ADMIN', '081122334455');`,
			adminUsername, adminEmail, string(hashedPassword))
		if err != nil {
			return err
		}
		log.Println("Admin user seeded successfully.")
	}

	return nil
}

// SeedMockData seeds sample orders for testing the driver dashboard.
// Safe to call multiple times — uses ON CONFLICT DO NOTHING.
func SeedMockData(pool *pgxpool.Pool, driverID int) {
	ctx := context.Background()

	var count int
	if err := pool.QueryRow(ctx, "SELECT COUNT(*) FROM orders WHERE driver_id = $1", driverID).Scan(&count); err != nil {
		log.Printf("Failed to count orders for seeding: %v", err)
		return
	}

	if count > 0 {
		return // Already seeded
	}

	log.Printf("Seeding mock orders for driver ID: %d...", driverID)

	mockOrders := []struct {
		num, status, pharmacy, pharAddr, delivAddr, customer, phone, summary string
		fee                                                                   float64
		hoursAgo, completedHoursAgo                                           int
	}{
		{"ORD-98721", "PICKING_UP",
			"Apotek K-24 Kaliurang", "Jl. Kaliurang KM 5.5, Yogyakarta",
			"Kost Green View, Room 204, Jl. Pandega Marta No. 12, Sleman",
			"Budi Santoso", "087712345678",
			"Paracetamol 500mg (1 strip), Amoxicillin 500mg (1 strip)", 15000, 0, 0},
		{"ORD-98715", "COMPLETED",
			"Apotek K-24 Gejayan", "Jl. Affandi No. 10, Caturtunggal, Depok, Sleman",
			"Pogung Baru Blok D24, Sleman, Yogyakarta",
			"Rina Wijaya", "081298765432",
			"Vitamin C 1000mg (1 tube), Woods Cough Syrup (1 bottle)", 12000, 2, 1},
		{"ORD-98710", "COMPLETED",
			"Apotek K-24 Kaliurang", "Jl. Kaliurang KM 5.5, Yogyakarta",
			"Perumahan Condongcatur Kav B-12, Sleman",
			"Joko Susilo", "089988887777",
			"Panadol Migraine (2 strips), Salonpas Let (1 pack)", 18000, 4, 3},
	}

	for _, o := range mockOrders {
		if o.completedHoursAgo > 0 {
			_, _ = pool.Exec(ctx, `
			INSERT INTO orders (order_number, driver_id, status, pharmacy_name, pharmacy_address,
				delivery_address, customer_name, customer_phone, medicine_summary, delivery_fee,
				created_at, completed_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
				NOW() - ($11 || ' hours')::interval,
				NOW() - ($12 || ' hours')::interval)
			ON CONFLICT (order_number) DO NOTHING;`,
				o.num, driverID, o.status, o.pharmacy, o.pharAddr,
				o.delivAddr, o.customer, o.phone, o.summary, o.fee,
				o.hoursAgo, o.completedHoursAgo)
		} else {
			_, _ = pool.Exec(ctx, `
			INSERT INTO orders (order_number, driver_id, status, pharmacy_name, pharmacy_address,
				delivery_address, customer_name, customer_phone, medicine_summary, delivery_fee,
				created_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, NOW() - '15 minutes'::interval)
			ON CONFLICT (order_number) DO NOTHING;`,
				o.num, driverID, o.status, o.pharmacy, o.pharAddr,
				o.delivAddr, o.customer, o.phone, o.summary, o.fee)
		}
	}

	// Ensure driver profile exists
	var profileExists bool
	if err := pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM driver_profiles WHERE user_id = $1)", driverID).Scan(&profileExists); err == nil && !profileExists {
		_, _ = pool.Exec(ctx,
			"INSERT INTO driver_profiles (user_id, plate_number, is_active, rating) VALUES ($1, 'AB 1234 CD', false, 5.00) ON CONFLICT DO NOTHING;",
			driverID)
	}

	log.Println("Mock orders and driver profile seeded successfully.")
}

// CheckIfUserIsDriver checks if user has DRIVER role.
func CheckIfUserIsDriver(pool *pgxpool.Pool, userID int) (bool, error) {
	ctx := context.Background()
	var role string
	err := pool.QueryRow(ctx, "SELECT role FROM users WHERE id = $1", userID).Scan(&role)
	if err == pgx.ErrNoRows {
		return false, nil
	} else if err != nil {
		return false, err
	}
	return role == "DRIVER", nil
}
