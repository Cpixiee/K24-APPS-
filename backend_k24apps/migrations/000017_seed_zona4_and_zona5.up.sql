-- Migration 000017: Seed & Update Zona 4 (Surabaya/Sidoarjo) and Zona 5 (Gresik/Sidoarjo) Pharmacies

-- 1. Update existing Zona 4 Pharmacies to zona = 4
UPDATE alamat_penerima SET zona = 4 WHERE nama_apotek IN (
  'Apotek K24 Manukan Tama', 'Apotek K-24 Manukan Tama', 'Apotek K-24 Darmo Indah Surabaya',
  'Apotek K-24 Pogot Surabaya', 'Apotek K-24 Balongsari Tama Surabaya', 'Apotek K-24 Wonokusumo Surabaya',
  'Apotek K-24 Lidah Wetan Surabaya', 'Apotek K24 Lakarsantri', 'Apotek K-24 Lakarsantri',
  'Apotek K-24 Sidotopo Wetan Surabaya', 'Apotek K-24 Sukomanunggal Surabaya', 'Apotek K-24 Lontar Surabaya',
  'Apotek K-24 Kedinding Lor Surabaya', 'Apotek K-24 Kopelindo 3 Surabaya', 'Apotek K-24 Bukit Darmo Surabaya',
  'Apotek K-24 Kupang Jaya Surabaya', 'Apotek K-24 Galeria Palma Surabaya', 'Apotek K-24 Perak Timur Surabaya',
  'Apotek K-24 Sidodadi Sidoarjo', 'Apotek K-24 Sidokare Sidoarjo'
);

-- 2. Insert any missing ZONA 4 Pharmacies
INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude, zona)
SELECT t.name, t.addr, t.lat, t.lng, 4 FROM (
  VALUES
  ('Apotek K24 Manukan Tama', 'Jl. Manukan Tama No.149, Lontar, Kec. Sambikerep, Surabaya, Jawa Timur 60185', -7.262500, 112.673000),
  ('Apotek K-24 Darmo Indah Surabaya', 'Jl. Darmo Indah Tim. No.15, Tandes, Kec. Tandes, Surabaya, Jawa Timur 60187', -7.263800, 112.691400),
  ('Apotek K-24 Pogot Surabaya', 'Jl. Pogot No.86, Tanah Kali Kedinding, Kec. Kenjeran, Surabaya, Jawa Timur 60129', -7.228100, 112.766300),
  ('Apotek K-24 Balongsari Tama Surabaya', 'PMRH+27X, Jl. Balongsari Tama No.22 Blok A3, Balongsari, Kec. Tandes, Surabaya, Jawa Timur 60186', -7.260800, 112.684600),
  ('Apotek K-24 Wonokusumo Surabaya', 'Jl. Tenggumung Wetan, Pegirian, Kec. Semampir, Surabaya, Jawa Timur 60153', -7.221200, 112.756200),
  ('Apotek K-24 Lidah Wetan Surabaya', 'Jl. Raya Lidah Wetan No.886, Lidah Kulon, Kec. Lakarsantri, Surabaya, Jawa Timur 60213', -7.310500, 112.671000),
  ('Apotek K24 Lakarsantri', 'Jl. Lakarsantri No.109, Lakarsantri, Kec. Lakarsantri, Surabaya, Jawa Timur 60211', -7.321800, 112.654700),
  ('Apotek K-24 Sidotopo Wetan Surabaya', 'Jl. Sidotopo Wetan I Luar No.43, Sidotopo Wetan, Kec. Kenjeran, Surabaya, Jawa Timur 60128', -7.234500, 112.768100),
  ('Apotek K-24 Sukomanunggal Surabaya', 'Jl. Sukomanunggal No.41, Sukomanunggal, Kec. Sukomanunggal, Surabaya, Jawa Timur 60188', -7.266200, 112.710200),
  ('Apotek K-24 Lontar Surabaya', 'Lontar, Kec. Sambikerep, Surabaya, Jawa Timur 60216', -7.279800, 112.668500),
  ('Apotek K-24 Kedinding Lor Surabaya', 'Jl. Kedinding Lor No.37, Tanah Kali Kedinding, Kec. Kenjeran, Surabaya, Jawa Timur 60129', -7.219500, 112.768200),
  ('Apotek K-24 Kopelindo 3 Surabaya', 'Jl. Tlk. Nibung No.8, Perak Utara, Kec. Pabean Cantian, Surabaya, Jawa Timur 60165', -7.202300, 112.732800),
  ('Apotek K-24 Bukit Darmo Surabaya', 'Jl. Raya Bukit Darmo 1L, Jl. Bukit Darmo Golf No.1M, Putat Gede, Kec. Sukomanunggal, Surabaya, Jawa Timur 60189', -7.288200, 112.695100),
  ('Apotek K-24 Kupang Jaya Surabaya', 'Ruko Kupang Jaya, Jl. Kupang Jaya AF No.1, Sonokwijenan, Kec. Sukomanunggal, Surabaya, Jawa Timur 60189', -7.278500, 112.705800),
  ('Apotek K-24 Galeria Palma Surabaya', 'Komp. Perum Citraland Surya Palma Galeria Blok RB-1 No.12, Bringin, Kec. Sambikerep, Surabaya, Jawa Timur 60218', -7.284500, 112.641200),
  ('Apotek K-24 Perak Timur Surabaya', 'Jl. Perak Timur No.98, Perak Tim., Kec. Pabean Cantian, Surabaya, Jawa Timur 60164', -7.218500, 112.734800),
  ('Apotek K-24 Sidodadi Sidoarjo', 'Ruko Surya Square & Garden, Jl. Sidodadi, Balumn, Sidodadi, Kec. Candi, Kabupaten Sidoarjo, Jawa Timur 61257', -7.478200, 112.715800),
  ('Apotek K-24 Sidokare Sidoarjo', 'Asri AQ/3, Jl. Kutuk Barat, Perum Sidokare, Sepande, Kec. Candi, Kabupaten Sidoarjo, Jawa Timur 61271', -7.458500, 112.708200)
) AS t(name, addr, lat, lng)
WHERE NOT EXISTS (
  SELECT 1 FROM alamat_penerima WHERE nama_apotek = t.name
);

-- 3. Update existing Zona 5 Pharmacies to zona = 5
UPDATE alamat_penerima SET zona = 5 WHERE nama_apotek IN (
  'Apotek K-24 Tulangan Sidoarjo', 'Apotek K-24 Krian Sidoarjo', 'Apotek K-24 Panglima Sudirman Gresik',
  'Apotek K-24 Driyorejo Gresik', 'Apotek K-24 Gubernur Suryo Gresik', 'Apotek K-24 Benowo Gresik',
  'Apotek K-24 Bungah Gresik', 'Apotek K24 PPS', 'Apotek K-24 PPS', 'Apotek K-24 Dr Sutomo Gresik',
  'Apotek K-24 Balongpanggang', 'Apotek K-24 Giri Gresik', 'Apotek K-24 GKB Gresik',
  'Apotek K-24 GKB Sumatera Gresik', 'Apotek K-24 Pasar Menganti Gresik'
);

-- 4. Insert any missing ZONA 5 Pharmacies
INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude, zona)
SELECT t.name, t.addr, t.lat, t.lng, 5 FROM (
  VALUES
  ('Apotek K-24 Tulangan Sidoarjo', 'Jl. Raya Kemantren, RT.09/RW.02, Keputran, Kemantren, Kec. Tulangan, Kabupaten Sidoarjo, Jawa Timur 61273', -7.471500, 112.658200),
  ('Apotek K-24 Krian Sidoarjo', 'Jl. Basuki Rahmat No.428, Gesikan, Krian, Kec. Krian, Kabupaten Sidoarjo, Jawa Timur 61262', -7.411200, 112.581200),
  ('Apotek K-24 Panglima Sudirman Gresik', 'Jl. Panglima Sudirman No.116, Kramatandap, Gapurosukolilo, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61122', -7.162500, 112.653100),
  ('Apotek K-24 Driyorejo Gresik', 'Jl. Raya Batu Mulia, Paras, Mulung, Kec. Driyorejo, Kabupaten Gresik, Jawa Timur 61177', -7.348200, 112.621500),
  ('Apotek K-24 Gubernur Suryo Gresik', 'Jl. Gubernur Suryo No. 1, Karangpoh, Kemuteran, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61116', -7.164500, 112.656200),
  ('Apotek K-24 Benowo Gresik', 'Jalan Raya Ngasinan No 60195 No.8 Kepatihan, Benowo, Kec. Menganti, Kabupaten Gresik, Jawa Timur 61174', -7.248200, 112.618500),
  ('Apotek K-24 Bungah Gresik', 'Jl. Raya Dukuh RT.22/RW.08 Dukuh, Kaliwot, Bungah, Kec. Bungah, Kabupaten Gresik, Jawa Timur 61152', -7.054200, 112.578200),
  ('Apotek K24 PPS', 'Jl. Raya Permata Suci, Suci, Kec. Manyar, Kabupaten Gresik, Jawa Timur 61151', -7.132500, 112.608500),
  ('Apotek K-24 Dr Sutomo Gresik', 'Jl. Dr. Soetomo No.141, Trate, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61111', -7.158500, 112.651200),
  ('Apotek K-24 Balongpanggang', 'Jl. Raya Balongpanggang No.51A, Wates, Kedungpring, Kec. Balongpanggang, Kabupaten Gresik, Jawa Timur 61173', -7.265200, 112.448500),
  ('Apotek K-24 Giri Gresik', 'Jl. Sunan Prapen No.31, Pedukuhan, Kebomas, Kec. Kebomas, Kabupaten Gresik, Jawa Timur 61124', -7.168500, 112.635800),
  ('Apotek K-24 GKB Gresik', 'Jl. Kalimantan No.74, Wonorejo, Yosowilangun, Kec. Manyar, Kabupaten Gresik, Jawa Timur 61151', -7.141500, 112.612800),
  ('Apotek K-24 GKB Sumatera Gresik', 'Jl. Taman Enggano Dalam No.02 GKB, Setingi, Yosowilangun, Kec. Manyar, Kabupaten Gresik, Jawa Timur 61151', -7.139500, 112.615200),
  ('Apotek K-24 Pasar Menganti Gresik', 'Jl. Raya Menganti Karang Turi Menganti Krajan Gg. 5 No.29, Krajan, Menganti, Kec. Menganti, Kabupaten Gresik, Jawa Timur 61174', -7.312500, 112.589200)
) AS t(name, addr, lat, lng)
WHERE NOT EXISTS (
  SELECT 1 FROM alamat_penerima WHERE nama_apotek = t.name
);
