-- Migration 000020: Add Driver Suspension Columns
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMP WITH TIME ZONE;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS suspend_reason TEXT DEFAULT '';
