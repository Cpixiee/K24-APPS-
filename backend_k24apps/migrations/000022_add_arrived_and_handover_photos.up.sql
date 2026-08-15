-- Migration 000022: Add arrived at location and handover photo columns to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS arrived_photo_url TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS arrived_note TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS handover_photo_url TEXT DEFAULT '';
