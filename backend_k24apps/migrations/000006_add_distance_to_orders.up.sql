-- Migration 000006: Add distance_km to orders
-- Alter orders table to store calculated distance in KM per delivery stop

ALTER TABLE orders ADD COLUMN IF NOT EXISTS distance_km NUMERIC(10,2) DEFAULT 0.0;
