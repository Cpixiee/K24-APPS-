-- Migration 000010: Add mitra_type to mitra_profiles table
ALTER TABLE mitra_profiles ADD COLUMN IF NOT EXISTS mitra_type VARCHAR(50) NOT NULL DEFAULT 'K24';
