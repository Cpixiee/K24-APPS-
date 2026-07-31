-- Migration 000011: Add signature photo columns for unboxing and POD return
ALTER TABLE orders ADD COLUMN IF NOT EXISTS signature_photo_url TEXT DEFAULT '';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pod_signature_photo_url TEXT DEFAULT '';
