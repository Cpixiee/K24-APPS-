-- Migration 000001: Core Users & Driver Profiles
-- Runs first — all other tables depend on users

-- Users table (ADMIN, DRIVER, MITRA roles)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL DEFAULT '',
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(50) DEFAULT '',
    role VARCHAR(50) NOT NULL, -- 'ADMIN', 'DRIVER', 'MITRA'
    profile_picture TEXT,
    face_data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Driver profiles (1-to-1 with users WHERE role = 'DRIVER')
CREATE TABLE IF NOT EXISTS driver_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plate_number VARCHAR(50) DEFAULT '',
    is_active BOOLEAN DEFAULT FALSE,
    rating NUMERIC(3,2) DEFAULT 5.00
);

-- Performance indexes for users
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
