-- Migration 000005: Create Dispatch Tables & Alter Driver Profiles
-- Adds vehicle type to drivers, dispatch groups, and order routing details

-- 1. Alter driver_profiles to support vehicle type (motor/mobil)
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(50) DEFAULT 'motor';

-- 2. Create dispatch_groups table
CREATE TABLE IF NOT EXISTS dispatch_groups (
    id SERIAL PRIMARY KEY,
    dispatch_number VARCHAR(50) UNIQUE NOT NULL,
    driver_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PICKING_UP', -- 'PICKING_UP', 'DELIVERING', 'COMPLETED', 'CANCELLED'
    total_distance_km NUMERIC(10,2) NOT NULL DEFAULT 0.0,
    total_argo NUMERIC(10,2) NOT NULL DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_dispatch_groups_driver ON dispatch_groups(driver_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_groups_num ON dispatch_groups(dispatch_number);

-- 3. Create dispatch_id_detail (order sequence within dispatch groups)
CREATE TABLE IF NOT EXISTS dispatch_id_detail (
    id SERIAL PRIMARY KEY,
    dispatch_group_id INTEGER REFERENCES dispatch_groups(id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    sequence_number INTEGER NOT NULL,
    status_pengantaran VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'DELIVERING', 'COMPLETED'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_dispatch_detail_group ON dispatch_id_detail(dispatch_group_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_detail_order ON dispatch_id_detail(order_id);
CREATE INDEX IF NOT EXISTS idx_dispatch_detail_seq ON dispatch_id_detail(sequence_number);
