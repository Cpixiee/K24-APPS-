-- Migration 000015: Add Driver Live Location Tracking
-- Adds columns to driver_profiles to store real-time GPS location updates from the mobile app

ALTER TABLE driver_profiles 
ADD COLUMN IF NOT EXISTS current_lat NUMERIC(10, 7) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS current_lng NUMERIC(10, 7) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS last_location_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Index for fast location querying by driver_id and date
CREATE INDEX IF NOT EXISTS idx_driver_profiles_location ON driver_profiles(user_id, last_location_update DESC);
