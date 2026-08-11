-- Migration 000019: Seed Apotek K-24 locations across Jabodetabek (Jakarta, Bekasi, Tangerang, Bogor, Depok)

DELETE FROM alamat_penerima 
WHERE nama_apotek ILIKE '%Apotek K-24%' OR nama_apotek ILIKE '%APOTEK K-24%';

INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude, zona)
VALUES
  -- ─── JAKARTA PUSAT ───
  ('Apotek K-24 Salemba', 'Jl. Salemba Raya No. 42, Senen, Jakarta Pusat', -6.195000, 106.851000, 0),
  ('Apotek K-24 Cempaka Putih', 'Jl. Cempaka Putih Raya No. 108, Cempaka Putih, Jakarta Pusat', -6.178500, 106.872500, 0),
  ('Apotek K-24 Tanah Abang', 'Jl. KH Mas Mansyur No. 25, Tanah Abang, Jakarta Pusat', -6.192000, 106.814000, 0),

  -- ─── JAKARTA BARAT ───
  ('Apotek K-24 Puri Kembangan', 'Jl. Puri Kembangan No.8B, RT.1/RW.8, Kembangan Selatan, Kembangan, Jakarta Barat 11610', -6.186500, 106.746000, 0),
  ('APOTEK K-24 PURI KEMBANGAN (CV. AKS PURI)', 'Jl. Raya Kembangan 8B Kembangan Selatan Kembangan Jakarta Barat', -6.186500, 106.746000, 0),
  ('Apotek K-24 Kosambi Kresek', 'Jl. Kresek Raya No. 7B, RT 009 RW 015, Duri Kosambi, Cengkareng, Jakarta Barat 11750', -6.173800, 106.712500, 0),
  ('APOTEK K-24 KOSAMBI KRESEK (PT. MEDIKA PRIMA PHARMA)', 'Jl. Kresek Raya No. 7B, RT 009 RW 015, Duri Kosambi, Cengkareng, Jakarta Barat', -6.173800, 106.712500, 0),
  ('Apotek K-24 Tanjung Duren', 'Jl. Tanjung Duren Raya No. 431B, Grogol Petamburan, Jakarta Barat', -6.171234, 106.782123, 0),
  ('Apotek K-24 Meruya', 'Jl. Meruya Utara No. 18, Kembangan, Jakarta Barat', -6.192500, 106.738000, 0),
  ('Apotek K-24 Palmerah', 'Jl. Palmerah Barat No. 52, Palmerah, Jakarta Barat', -6.208500, 106.791500, 0),
  ('Apotek K-24 Pesanggrahan', 'Jl. Pesanggrahan No.35B, Meruya Utara, Jakarta Barat', -6.198123, 106.741234, 0),

  -- ─── JAKARTA TIMUR ───
  ('Apotek K-24 Matraman', 'Jl. Matraman Raya No.32C, Kebon Manggis, Matraman, Jakarta Timur 13150', -6.2019957, 106.8551888, 0),
  ('Apotek K-24 Rawamangun', 'Jl. Pemuda No. 73, Rawamangun, Pulogadung, Jakarta Timur', -6.192800, 106.883500, 0),
  ('Apotek K-24 Duren Sawit', 'Jl. Raden Inten II No. 8, Duren Sawit, Jakarta Timur', -6.231500, 106.918000, 0),
  ('Apotek K-24 Kramat Jati', 'Jl. Raya Bogor KM 19 No. 4, Kramat Jati, Jakarta Timur', -6.275000, 106.868000, 0),
  ('Apotek K-24 Kalimalang', 'Jl. Raya Kalimalang No. 12B, Duren Sawit, Jakarta Timur', -6.248500, 106.905000, 0),

  -- ─── JAKARTA SELATAN ───
  ('Apotek K-24 Kebayoran Lama', 'Jl. Kebayoran Lama No. 14, Kebayoran Lama, Jakarta Selatan', -6.228000, 106.779000, 0),
  ('Apotek K-24 Tebet Raya', 'Jl. Tebet Raya No. 54, Tebet, Jakarta Selatan', -6.226500, 106.848000, 0),
  ('Apotek K-24 Pasar Minggu', 'Jl. Raya Pasar Minggu No. 28, Pasar Minggu, Jakarta Selatan', -6.281000, 106.842000, 0),
  ('Apotek K-24 Cilandak', 'Jl. Cilandak KKO No. 15, Pasar Minggu, Jakarta Selatan', -6.302500, 106.815000, 0),
  ('Apotek K-24 Mampang', 'Jl. Mampang Prapatan Raya No. 88, Mampang Prapatan, Jakarta Selatan', -6.248000, 106.827000, 0),

  -- ─── JAKARTA UTARA ───
  ('Apotek K-24 Kelapa Gading', 'Jl. Boulevard Raya Blok QJ1 No. 12, Kelapa Gading, Jakarta Utara', -6.155000, 106.908000, 0),
  ('Apotek K-24 Sunter Permai', 'Jl. Sunter Permai Raya No. 8, Tanjung Priok, Jakarta Utara', -6.138000, 106.865000, 0),
  ('Apotek K-24 Pluit', 'Jl. Pluit Karang Raya No. 45, Penjaringan, Jakarta Utara', -6.118500, 106.788000, 0),

  -- ─── TANGERANG & TANGERANG SELATAN ───
  ('Apotek K-24 Karawaci Tangerang', 'Jl. Karawaci Baru No. 15, Karawaci, Kota Tangerang', -6.198000, 106.618000, 0),
  ('Apotek K-24 Ciledug Tangerang', 'Jl. HOS Cokroaminoto No. 88, Ciledug, Kota Tangerang', -6.235000, 106.712000, 0),
  ('Apotek K-24 Bintaro Utama', 'Jl. Bintaro Utama 3A Blok DC No. 2, Pondok Aren, Tangerang Selatan', -6.278000, 106.745000, 0),
  ('Apotek K-24 BSD City Serpong', 'Jl. Letnan Sutopo Ruko BSD Sektor 1.2, Serpong, Tangerang Selatan', -6.301500, 106.685000, 0),
  ('Apotek K-24 Pamulang Tangerang Selatan', 'Jl. Siliwangi No. 12, Pamulang, Tangerang Selatan', -6.348000, 106.742000, 0),
  ('Apotek K-24 Alam Sutera Tangerang', 'Jl. Alam Sutera Boulevard Ruko Jalur Sutera, Pinang, Kota Tangerang', -6.224000, 106.653000, 0),
  ('Apotek K-24 Ciputat', 'Jl. Ir H. Juanda No. 65, Ciputat, Tangerang Selatan', -6.312000, 106.758000, 0),
  ('Apotek K-24 Gading Serpong', 'Jl. Gading Serpong Boulevard Blok AA4 No. 18, Kelapa Dua, Tangerang', -6.241000, 106.628000, 0),

  -- ─── BEKASI ───
  ('Apotek K-24 Bekasi Timur', 'Jl. Ir. H. Juanda No. 112, Bekasi Timur, Kota Bekasi', -6.243500, 107.005000, 0),
  ('Apotek K-24 Harapan Indah Bekasi', 'Jl. Harapan Indah Boulevard Ruko Sentra Niaga, Medan Satria, Kota Bekasi', -6.182000, 106.975000, 0),
  ('Apotek K-24 Jatiwaringin Bekasi', 'Jl. Raya Jatiwaringin No. 45, Pondok Gede, Kota Bekasi', -6.261000, 106.912000, 0),
  ('Apotek K-24 Pekayon Bekasi', 'Jl. Raya Pekayon No. 8, Bekasi Selatan, Kota Bekasi', -6.262500, 106.985000, 0),
  ('Apotek K-24 Cikarang Bekasi', 'Jl. Raya Cikarang - Cibarusah No. 22, Cikarang Selatan, Kabupaten Bekasi', -6.325000, 107.148000, 0),
  ('Apotek K-24 Pondok Gede Bekasi', 'Jl. Raya Pondok Gede No. 18, Pondok Gede, Kota Bekasi', -6.285000, 106.908000, 0),
  ('Apotek K-24 Summarecon Bekasi', 'Jl. Boulevard Ahmad Yani Ruko Sinpasa, Bekasi Utara, Kota Bekasi', -6.223000, 107.001000, 0),
  ('Apotek K-24 Tambun Bekasi', 'Jl. Sultan Hasanudin No. 55, Tambun Selatan, Kabupaten Bekasi', -6.260000, 107.058000, 0),

  -- ─── BOGOR & DEPOK ───
  ('Apotek K-24 Pajajaran Bogor', 'Jl. Pajajaran No. 84, Bogor Utara, Kota Bogor', -6.582000, 106.808000, 0),
  ('Apotek K-24 Cibinong Bogor', 'Jl. Raya Jakarta-Bogor KM 46, Cibinong, Kabupaten Bogor', -6.485000, 106.852000, 0),
  ('Apotek K-24 Warung Buntu Bogor', 'Jl. Siliwangi No. 42, Bogor Timur, Kota Bogor', -6.608000, 106.812000, 0),
  ('Apotek K-24 Tajur Bogor', 'Jl. Raya Tajur No. 118, Bogor Selatan, Kota Bogor', -6.632000, 106.835000, 0),
  ('Apotek K-24 Margonda Depok', 'Jl. Margonda Raya No. 240, Beji, Kota Depok', -6.378000, 106.831000, 0),
  ('Apotek K-24 Sawangan Depok', 'Jl. Raya Sawangan No. 15, Pancoran Mas, Kota Depok', -6.395000, 106.805000, 0),
  ('Apotek K-24 Cimanggis Depok', 'Jl. Raya Bogor KM 30, Cimanggis, Kota Depok', -6.362000, 106.865000, 0),
  ('Apotek K-24 Cinere Depok', 'Jl. Cinere Raya No. 34, Cinere, Kota Depok', -6.325000, 106.782000, 0);
