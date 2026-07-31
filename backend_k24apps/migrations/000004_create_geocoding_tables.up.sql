-- Migration 000004: Geocoding & Route Cache Tables
-- Depends on: (none — standalone lookup tables)

-- Master recipient address book (autocomplete source + geocode cache)
CREATE TABLE IF NOT EXISTS alamat_penerima (
    id SERIAL PRIMARY KEY,
    nama_apotek VARCHAR(255) NOT NULL,
    alamat_lengkap TEXT NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_alamat_penerima_name ON alamat_penerima(nama_apotek);
CREATE INDEX IF NOT EXISTS idx_alamat_penerima_addr ON alamat_penerima(alamat_lengkap);

-- Route distance cache (avoids repeated geocoding API calls)
-- Stores computed driving distances between two coordinate pairs
CREATE TABLE IF NOT EXISTS route_cache (
    id SERIAL PRIMARY KEY,
    origin_lat NUMERIC(10, 7) NOT NULL,
    origin_long NUMERIC(10, 7) NOT NULL,
    dest_lat NUMERIC(10, 7) NOT NULL,
    dest_long NUMERIC(10, 7) NOT NULL,
    distance_km NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_route_cache_coords ON route_cache(origin_lat, origin_long, dest_lat, dest_long);
