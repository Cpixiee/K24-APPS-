-- Migration 000014: Performance Optimization Indexes
-- Adds composite indexes to eliminate full table scans on dashboard, dispatch, address lookup, and notification queries

-- 1. Composite index for (nama_apotek, alamat_lengkap)
CREATE INDEX IF NOT EXISTS idx_alamat_penerima_lookup ON alamat_penerima (nama_apotek, alamat_lengkap);

-- 2. Composite index for orders matching customer & delivery address
CREATE INDEX IF NOT EXISTS idx_orders_customer_delivery ON orders (customer_name, delivery_address);

-- 3. Composite index for orders querying driver active and completed status ordered by date
CREATE INDEX IF NOT EXISTS idx_orders_driver_status_date ON orders (driver_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_driver_completed ON orders (driver_id, completed_at DESC);

-- 4. Index for route_cache latitude & longitude range queries
CREATE INDEX IF NOT EXISTS idx_route_cache_origin ON route_cache (origin_lat, origin_long);
CREATE INDEX IF NOT EXISTS idx_route_cache_dest ON route_cache (dest_lat, dest_long);

-- 5. Composite index for notifications user/driver lookup ordered by creation time
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_driver_created ON notifications (driver_id, created_at DESC);

-- 6. Indexes for users role & driver profiles approval status
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_approved ON driver_profiles(user_id, is_approved);
