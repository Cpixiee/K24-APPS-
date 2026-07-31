-- Migration 000003: Mitra Profiles Table
-- Depends on: users (000001)

-- Mitra profiles (1-to-1 with users WHERE role = 'MITRA')
-- Stores pickup location and per-armada pricing configurations
CREATE TABLE IF NOT EXISTS mitra_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    pic_name VARCHAR(255) NOT NULL DEFAULT '',      -- Person-in-charge name
    pic_nik VARCHAR(50) NOT NULL DEFAULT '',         -- Person-in-charge national ID
    alamat_lengkap TEXT NOT NULL DEFAULT '',
    pickup_name VARCHAR(255) NOT NULL DEFAULT '',    -- Display name of pickup location
    pickup_lat NUMERIC(10, 7) NOT NULL DEFAULT 0.0,
    pickup_long NUMERIC(10, 7) NOT NULL DEFAULT 0.0,

    -- Motor (motorcycle) tariff components
    motor_dimensi NUMERIC(10, 2) DEFAULT NULL,       -- Rate per dm³ (cubic)
    motor_km NUMERIC(10, 2) DEFAULT NULL,            -- Rate per kilometer
    motor_titik NUMERIC(10, 2) DEFAULT NULL,         -- Flat rate per delivery stop
    motor_berat NUMERIC(10, 2) DEFAULT NULL,         -- Rate per kilogram

    -- Mobil (car) tariff components
    mobil_dimensi NUMERIC(10, 2) DEFAULT NULL,
    mobil_km NUMERIC(10, 2) DEFAULT NULL,
    mobil_titik NUMERIC(10, 2) DEFAULT NULL,
    mobil_berat NUMERIC(10, 2) DEFAULT NULL,
    mobil_lumpsum NUMERIC(10, 2) DEFAULT NULL        -- Flat per-trip rate (car only)
);
