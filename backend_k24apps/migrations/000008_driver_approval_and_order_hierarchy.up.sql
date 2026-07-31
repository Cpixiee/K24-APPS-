-- Migration 000008: Driver Approval and Order Hierarchy
-- Adds approval status and documents to driver profiles
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS ktp_url TEXT DEFAULT '';
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS sim_url TEXT DEFAULT '';
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS stnk_url TEXT DEFAULT '';

-- Approve existing drivers
UPDATE driver_profiles SET is_approved = TRUE;

-- Adds parent order number for grouping, plus workflow fields to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS parent_order_number VARCHAR(50);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_photo_url TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_note TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS reject_photo_url TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS reject_note TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS reject_reason VARCHAR(100) DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS reject_approved BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS unboxing_option VARCHAR(50) DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS checked_invoices TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS extra_items_note TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS extra_items_photo_url TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS facture_photo_url TEXT DEFAULT '';

-- Update existing orders parent_order_number
UPDATE orders SET parent_order_number = COALESCE(NULLIF(dispatch_id, ''), REGEXP_REPLACE(order_number, '-[0-9]+$', '')) WHERE parent_order_number IS NULL OR parent_order_number = '';
