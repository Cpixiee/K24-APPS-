-- Migration 000018: Clear outdated route cache and seed exact Jakarta pharmacy coordinates

-- 1. Wipe cached route distances so fresh precise road distances are computed
TRUNCATE TABLE route_cache;

-- 2. Ensure PT K-24 Indonesia Cabang Jakarta (Matraman) has precise pickup coordinates
UPDATE mitra_profiles
SET pickup_lat = -6.2019957,
    pickup_long = 106.8551888,
    pickup_name = 'PT K-24 Indonesia Cabang Jakarta (Gudang K-24)',
    alamat_lengkap = 'Jl. Matraman Raya No.32C, RT.2/RW.1, Kebon Manggis, Matraman, Jakarta Timur 13150'
WHERE user_id IN (SELECT id FROM users WHERE role = 'MITRA' AND (name ILIKE '%Jakarta%' OR username ILIKE '%jakarta%'));

-- 3. Delete existing records if present to avoid duplication
DELETE FROM alamat_penerima WHERE nama_apotek ILIKE '%Puri Kembangan%' OR nama_apotek ILIKE '%Kosambi Kresek%';

-- 4. Seed exact coordinates for Jakarta pharmacies (Puri Kembangan, Kosambi, etc.)
INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude, zona)
VALUES
  ('Apotek K-24 Puri Kembangan', 'Jl. Puri Kembangan No.8B, RT.1/RW.8, Kembangan Selatan, Kembangan, Jakarta Barat 11610', -6.186500, 106.746000, 0),
  ('APOTEK K-24 PURI KEMBANGAN (CV. AKS PURI)', 'Jl. Raya Kembangan 8B Kembangan Selatan Kembangan Jakarta Barat', -6.186500, 106.746000, 0),
  ('Apotek K-24 Kosambi Kresek', 'Jl. Kresek Raya No. 7B, RT 009 RW 015, Duri Kosambi, Cengkareng, Jakarta Barat 11750', -6.173800, 106.712500, 0),
  ('APOTEK K-24 KOSAMBI KRESEK (PT. MEDIKA PRIMA PHARMA)', 'Jl. Kresek Raya No. 7B, RT 009 RW 015, Duri Kosambi, Cengkareng, Jakarta Barat', -6.173800, 106.712500, 0);
