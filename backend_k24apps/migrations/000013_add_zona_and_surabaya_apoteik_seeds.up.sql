-- Migration 000013: Add Zona Tariffs to Mitra Profiles and Seed Surabaya/Sidoarjo Pharmacy Zones

-- 1. Add motor zona tariff columns to mitra_profiles
ALTER TABLE mitra_profiles
ADD COLUMN IF NOT EXISTS motor_zona1 NUMERIC(10, 2) DEFAULT 10500.00,
ADD COLUMN IF NOT EXISTS motor_zona2 NUMERIC(10, 2) DEFAULT 17500.00,
ADD COLUMN IF NOT EXISTS motor_zona3 NUMERIC(10, 2) DEFAULT 24500.00;

-- 2. Add zona column to master recipient address book and driver_fee to orders
ALTER TABLE alamat_penerima
ADD COLUMN IF NOT EXISTS zona INTEGER DEFAULT 0;

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS driver_fee NUMERIC(10, 2) DEFAULT 0.00;

-- 3. Seed Surabaya & Sidoarjo Pharmacies with Zones
INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude, zona)
SELECT name, addr, lat, lng, z FROM (
  VALUES
  -- ZONA 1 (20 Apotek)
  ('Apotek K-24 Kutisari Surabaya', 'Jl. Kutisari Sel. No.130, Kutisari, Kec. Tenggilis Mejoyo, Surabaya, Jawa Timur 60291', -7.332500, 112.748200, 1),
  ('Apotek K-24 Jemursari Surabaya', 'Ruko A-6 Jalan Raya Jemursari No. 205 Jemur Wonosari, Sidosermo, Kec. Wonocolo, Surabaya, Jawa Timur 60237', -7.318200, 112.743100, 1),
  ('Apotek K-24 Pandugo Surabaya', 'Jl. Raya Pandugo No.147A, Penjaringan Sari, Kec. Rungkut, Surabaya, Jawa Timur 60297', -7.321100, 112.784500, 1),
  ('Apotek K-24 Klampis Surabaya', 'Ruko Klampis Square, Jl. Klampis Ngasem Gg. Masjid Blok A.9, Klampis Ngasem, Kec. Sukolilo, Surabaya, Jawa Timur 60117', -7.284200, 112.774500, 1),
  ('Apotek K-24 Manyar Surabaya', 'Jl. Raya Manyar No.53 C, Menur Pumpungan, Kec. Sukolilo, Surabaya, Jawa Timur 60116', -7.283100, 112.763200, 1),
  ('Apotek K24 Satelit Nginden', 'Jl. Nginden Intan Utara No.30 Nginden, Jangkungan, Nginden Jangkungan, Kec. Sukolilo, Surabaya, Jawa Timur 60118', -7.300500, 112.765400, 1),
  ('Apotek K-24 Rungkut Asri Surabaya', 'Jl. Rungkut Asri Tengah No.16B, Rungkut Kidul, Kec. Rungkut, Surabaya, Jawa Timur 60293', -7.327800, 112.775600, 1),
  ('Apotek K-24 Rungkut Madya Surabaya', 'Jl. Rungkut Madya No.85, Rungkut Kidul, Kec. Rungkut, Surabaya, Jawa Timur 60298', -7.331200, 112.779100, 1),
  ('Apotek K24 Medokan', 'Jl. Raya Medokan Sawah No.169, Medokan Ayu, Kec. Rungkut, Surabaya, Jawa Timur 60295', -7.329100, 112.791200, 1),
  ('Apotek K-24 Tenggilis Surabaya', 'Jl. Raya Tenggilis Mejoyo No.6 Blk G, Kali Rungkut, Kec. Rungkut, Surabaya, Jawa Timur 60292', -7.320400, 112.761200, 1),
  ('Apotek K-24 Rungkut UPN', 'Jl. Rungkut Madya No.213b, Medokan Ayu, Kec. Rungkut, Surabaya, Jawa Timur 60294', -7.332400, 112.788900, 1),
  ('Apotek K-24 Rungkut Tengah Surabaya', 'Jl. Raya Rungkut Tengah No.24, RT.04/RW.01, Rungkut Tengah, Kec. Gn. Anyar, Surabaya, Jawa Timur 60293', -7.335600, 112.774100, 1),
  ('Apotek K-24 Raya Semampir Surabaya', 'Jl. Semolowaru Tengah I No.70, Semolowaru, Kec. Sukolilo, Surabaya, Jawa Timur 60111', -7.298100, 112.778200, 1),
  ('Apotek K-24 Margorejo Surabaya', 'Jl. Margorejo Indah No.84, Jemur Wonosari, Kec. Wonocolo, Surabaya, Jawa Timur 60238', -7.316700, 112.738100, 1),
  ('Apotek K-24 Tropodo Sidoarjo', 'Jl. Raya Tropodo No.29 C, Tropodo Wetan, Tropodo, Kec. Waru, Kabupaten Sidoarjo, Jawa Timur 61256', -7.351200, 112.768100, 1),
  ('Apotek K24 Rewwin', 'Jl. Brigjend Katamso No.19, Wedoro, Kec. Waru, Kabupaten Sidoarjo, Jawa Timur 61256', -7.352400, 112.748900, 1),
  ('Apotek K-24 Wadung Asri Sidoarjo', 'Jl. Raya Wadung Asri No.63, Wadungasri, Kec. Waru, Kabupaten Sidoarjo, Jawa Timur 61256', -7.348900, 112.771200, 1),
  ('Apotek K-24 Pepelegi Sidoarjo', 'Ruko Pepiland, Jl. Jatisari Besar No.15 Blok B, Legi, Pepelegi, Kec. Waru, Kabupaten Sidoarjo, Jawa Timur 61256', -7.368100, 112.731200, 1),
  ('Apotek K-24 Brigjen Katamso Sidoarjo', 'Jl. Brigjend Katamso No.38B, Mekar Raya Binangun, Janti, Kec. Waru, Kabupaten Sidoarjo, Jawa Timur 61256', -7.355100, 112.741200, 1),
  ('Apotek K-24 Pondok Tjandra Sidoarjo', 'Jl. Raya Taman Asri No.D-41, Tambaksumur, Kec. Waru, Kabupaten Sidoarjo, Jawa Timur 61256', -7.345100, 112.779800, 1),

  -- ZONA 2 (24 Apotek)
  ('Apotek K-24 Mulyosari Surabaya', 'Jl. Raya Mulyosari No.99 B, Kalisari, Kec. Mulyorejo, Surabaya, Jawa Timur 60112', -7.258900, 112.791200, 2),
  ('Apotek K-24 Dharmahusada Surabaya', 'Jl. Prof. DR. Moestopo Jl. Dharmahusada No.121, Mojo, Kec. Gubeng, Surabaya, Jawa Timur 60285', -7.269800, 112.761200, 2),
  ('Apotek K-24 Menanggal Surabaya', 'Jl. Cipta Menanggal Utara No.9, Menanggal, Kec. Gayungan, Surabaya, Jawa Timur 60234', -7.341200, 112.724500, 2),
  ('Apotek K-24 Kebonsari Surabaya', 'Jl. Manunggal Kebonsari No.9A, Kebonsari, Kec. Jambangan, Surabaya, Jawa Timur 60233', -7.338900, 112.718900, 2),
  ('Apotek K24 Merr Kalijudan', 'Jl. Dr. Ir. H. Soekarno No.193 E, RW.1, Kalijudan, Kec. Mulyorejo, Surabaya, Jawa Timur 60114', -7.254100, 112.781200, 2),
  ('Apotek K-24 Ngagel Rejo Surabaya', 'Jl. Ngagel Rejo Kidul No.48, Ngagelrejo, Kec. Wonokromo, Surabaya, Jawa Timur 60245', -7.295100, 112.750100, 2),
  ('Apotek K-24 Pasar Pucang', 'Jl. Pucang Anom No.12-C, Pucang Sewu, Kec. Gubeng, Surabaya, Jawa Timur 60282', -7.280100, 112.756100, 2),
  ('Apotek K-24 Jojoran Surabaya', 'Jl. Raya Menur No.14, Airlangga, Kec. Gubeng, Surabaya, Jawa Timur 60286', -7.275100, 112.761200, 2),
  ('Apotek K-24 Indragiri Surabaya', 'Jl. Indragiri No.9 A No, Darmo, Wonokromo, Surabaya, East Java 60241', -7.291200, 112.731200, 2),
  ('Apotek K-24 Karah Surabaya', 'MPQ9+6GV, Jl. Karah Agung No.44, Karah, Kec. Jambangan, Surabaya, Jawa Timur 60232', -7.311200, 112.721200, 2),
  ('Apotek K-24 Bendul Merisi', 'Jl. Bendul Merisi No.91, Jagir, Kec. Wonokromo, Surabaya, Jawa Timur 60244', -7.305100, 112.741200, 2),
  ('Apotek K-24 Gayungan Surabaya', '003, Jl. Gayung Kebonsari Timur No.43, RW.11, Ketintang, Kec. Gayungan, Surabaya, Jawa Timur 60231', -7.331200, 112.728900, 2),
  ('Apotek K-24 Pasar Pakis Surabaya', 'Jl. Dr. Soetomo No.136, Darmo, Kec. Wonokromo, Surabaya, Jawa Timur 60241', -7.288100, 112.732400, 2),
  ('Apotek K-24 Ketintang Surabaya', 'Jl. Ruko Puri Indah Ketintang No.6, Ketintang, Kec. Gayungan, Surabaya, Jawa Timur 60231', -7.318100, 112.728100, 2),
  ('Apotek K-24 Mayjen Sungkono Surabaya', 'Jl. Mayjen Sungkono No.35, Sawunggaling, Kec. Wonokromo, Surabaya, Jawa Timur 60242', -7.292100, 112.724100, 2),
  ('Apotek K-24 Dharmawangsa Surabaya', 'Jl. Gubeng Airlangga IV No.1 3, Airlangga, Kec. Gubeng, Surabaya, Jawa Timur 60286', -7.271200, 112.758900, 2),
  ('Apotek K-24 Sepanjang Sidoarjo', 'Jl. Raya Bebekan Sepanjang, Bebekan, Kec. Taman, Kabupaten Sidoarjo, Jawa Timur 61257', -7.348100, 112.698100, 2),
  ('Apotek K-24 Betro Sidoarjo', 'Jl. Garuda No.17, Kepuh, Betro, Kec. Sedati, Kabupaten Sidoarjo, Jawa Timur 61253', -7.381200, 112.771200, 2),
  ('Apotek K-24 Sukodono Sidoarjo', 'Jl. Raya Sukodono No.21, Sawo, Sukodono, Kec. Sukodono, Kabupaten Sidoarjo, Jawa Timur 61258', -7.401200, 112.681200, 2),
  ('Apotek K-24 SENOPATI Sidoarjo', 'Ruko Jl. Senopati No.30 Blk F dan G, Kepuh, Betro, Kec. Sedati, Kabupaten Sidoarjo, Jawa Timur 61253', -7.382400, 112.775100, 2),
  ('Apotek K-24 Gadung Wage Sidoarjo', 'Margomulyo Jl. Gadung No.60, Margomulyo, Wage, Kec. Taman, Kabupaten Sidoarjo, Jawa Timur 61257', -7.368100, 112.718100, 2),
  ('Apotek K-24 Sedati Gede Sidoarjo', 'Jl. Raya Sedati Gede No.12, Bono, Sedati Gede, Kec. Sedati, Kabupaten Sidoarjo, Jawa Timur 61253', -7.371200, 112.768100, 2),
  ('Apotek K-24 Citra Harmoni Sidoarjo', 'Perum Citra Harmoni Ruko HCC2, RB-003, Troboso, Trosobo, Kec. Taman, Kabupaten Sidoarjo, Jawa Timur 61259', -7.361200, 112.668100, 2),
  ('Apotek K-24 Candramas Sidoarjo', 'Ruko, Jl. Platinum Residence Jl. Raya Buncitan No.Raya, Tani Tambak, Pepe, Kec. Sedati, Kabupaten Sidoarjo, Jawa Timur 61253', -7.391200, 112.781200, 2),

  -- ZONA 3 (25 Apotek)
  ('Apotek K-24 - Wiyung', 'No.8 Blok A, Ruko, Taman Pd. Indah Jl. Raya Wiyung, Wiyung, Kec. Wiyung, Surabaya, Jawa Timur 60228', -7.311200, 112.689100, 3),
  ('Apotek K-24 Kalibutuh Surabaya', 'Jl. Kalibutuh No.132, Tembok Dukuh, Kec. Bubutan, Surabaya, Jawa Timur 60252', -7.251200, 112.724100, 3),
  ('Apotek K-24 Kedungsari Surabaya', 'Jl. Kedungsari No.31A, Kedungdoro, Wonorejo, Kec. Tegalsari, Surabaya, Jawa Timur 60263', -7.261200, 112.734100, 3),
  ('Apotek K-24 Demak Surabaya', 'Jl. Demak No.274, Jepara, Kec. Bubutan, Surabaya, Jawa Timur 60172', -7.241200, 112.718100, 3),
  ('Apotek K-24 Dukuh Kupang Surabaya', 'Jl. Dukuh Kupang Bar. XVI No.24, Dukuh Kupang, Kec. Dukuhpakis, Surabaya, Jawa Timur 60225', -7.285100, 112.712100, 3),
  ('Apotek K24 Kapasari Surabaya', 'Jl. Kapasari No.112, RT.002/RW.02, Kapasan, Kec. Simokerto, Surabaya, Jawa Timur 60141', -7.248100, 112.751200, 3),
  ('Apotek K-24 Kapas Krampung Surabaya', 'Jl. Kapas Krampung No.220/1, Ploso, Kec. Tambaksari, Surabaya, Jawa Timur 60133', -7.251200, 112.761200, 3),
  ('Apotek K-24 Menganti Surabaya', 'Jl. Raya Menganti No.544, Babatan, Kec. Wiyung, Surabaya, Jawa Timur 60227', -7.318100, 112.678100, 3),
  ('Apotek K-24 Mastrip Surabaya', 'Jl. Raya Mastrip No.840, Warugunung, Kec. Karangpilang, Surabaya, Jawa Timur 60221', -7.348100, 112.671200, 3),
  ('Apotek K-24 Simo Kwagean Surabaya', 'Jl. Simo Kwagean No.74 A, RT.006/RW.14, Petemon, Kec. Sawahan, Surabaya, Jawa Timur 60252', -7.268100, 112.718100, 3),
  ('Apotek K-24 Dukuh Setro Surabaya', 'Dukuh Setro VI No.1, Gading, Kec. Tambaksari, Surabaya, Jawa Timur 60134', -7.241200, 112.771200, 3),
  ('Apotek K-24 Jarak Indah Surabaya', 'Jl. Jarak No.116, Putat Jaya, Kec. Sawahan, Surabaya, Jawa Timur 60255', -7.278100, 112.718100, 3),
  ('Apotek K-24 Dian Istana Surabaya', 'Ruko Soho MoCa Centra, Jl. Raya Dian Istana Tim. No.8 CL 1, Wiyung, Kec. Wiyung, Surabaya, Jawa Timur 60228', -7.301200, 112.681200, 3),
  ('Apotek K-24 Tambak Rejo Surabaya', 'Jl. Tambak Rejo, Tambakrejo, Kec. Simokerto, Surabaya, Jawa Timur 60142', -7.245100, 112.754100, 3),
  ('Apotek K-24 Arjuno Surabaya', 'Jl. Arjuno No.145, Sawahan, Kec. Sawahan, Surabaya, Jawa Timur 60251', -7.261200, 112.728100, 3),
  ('Apotek K-24 Deltasari Sidoarjo', 'Jl. Deltasari Indah Blok AP-12 Waru, Koreksari, Kureksari, Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61256', -7.358100, 112.738100, 3),
  ('Apotek K-24 Jati Sidoarjo', 'Jl. Jati Raya No.34, Babatan, Jati, Kec. Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61226', -7.451200, 112.711200, 3),
  ('Apotek K-24 Wage Sidoarjo', 'Jl. Aryo Bebangah No.244, Dusun Bangah Barat, Wage, Kec. Gedangan, Kabupaten Sidoarjo, Jawa Timur 61254', -7.365100, 112.725100, 3),
  ('Apotek K-24 Citra City', 'Komp. Ruko CItra City Ruko No. 3, Jl. Sarirogo, Sari Rogo, Kec. Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61234', -7.441200, 112.701200, 3),
  ('Apotek K-24 Pondok Jati Sidoarjo', 'Jl. Pd. Jati No.S-23, Pondokjati, Pagerwojo, Kec. Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61226', -7.448100, 112.715100, 3),
  ('Apotek K-24 Buduran Sidoarjo', 'JL Kesatrian Buduran, Blok L1 No. 6, Buduran, Park Royal Regency, Sono, Sidokerto, Kecamatan Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61252', -7.438100, 112.721200, 3),
  ('Apotek K-24 Randu Asri Sidoarjo', 'View Barat, Jl. Taman Tiara Regency Jl. Randu Asri No.25 Blk F1, RT.053/RW.013, Tamantiara, Pagerwojo, Kec. Buduran, Kabupaten Sidoarjo, Jawa Timur 61252', -7.435100, 112.718100, 3),
  ('Apotek K-24 Bluru Sidoarjo', 'Jl. Bluru Kidul No.8, Sidoklumpuk, Sidokumpul, Kec. Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61218', -7.452100, 112.728100, 3),
  ('Apotek K-24 Pahlawan Sidoarjo', 'Jl. Pahlawan, RT.030/RW.006, Rw6, Sidokumpul, Kec. Sidoarjo, Kabupaten Sidoarjo, Jawa Timur 61213', -7.455100, 112.712100, 3),
  ('Apotek K-24 Krian Sidoarjo', 'Jl. Basuki Rahmat No.428, Gesikan, Krian, Kec. Krian, Kabupaten Sidoarjo, Jawa Timur 61262', -7.411200, 112.581200, 3),

  -- ZONA 4 / NON-ZONA SURABAYA & SIDOARJO (19 Apotek - Tarif KM Driver Rp 1.750/KM)
  ('Apotek K24 Manukan Tama', 'Jl. Manukan Tama No.149, Lontar, Kec. Sambikerep, Surabaya, Jawa Timur 60185', -7.262500, 112.673000, 0),
  ('Apotek K-24 Darmo Indah Surabaya', 'Jl. Darmo Indah Tim. No.15, Tandes, Kec. Tandes, Surabaya, Jawa Timur 60187', -7.263800, 112.691400, 0),
  ('Apotek K-24 Pogot Surabaya', 'Jl. Pogot No.86, Tanah Kali Kedinding, Kec. Kenjeran, Surabaya, Jawa Timur 60129', -7.228100, 112.766300, 0),
  ('Apotek K-24 Balongsari Tama Surabaya', 'PMRH+27X, Jl. Balongsari Tama No.22 Blok A3, Balongsari, Kec. Tandes, Surabaya, Jawa Timur 60186', -7.260800, 112.684600, 0),
  ('Apotek K-24 Wonokusumo Surabaya', 'Jl. Tenggumung Wetan, Pegirian, Kec. Semampir, Surabaya, Jawa Timur 60153', -7.221200, 112.756200, 0),
  ('Apotek K-24 Lidah Wetan Surabaya', 'Jl. Raya Lidah Wetan No.886, Lidah Kulon, Kec. Lakarsantri, Surabaya, Jawa Timur 60213', -7.310500, 112.671000, 0),
  ('Apotek K24 Lakarsantri', 'Jl. Lakarsantri No.109, Lakarsantri, Kec. Lakarsantri, Surabaya, Jawa Timur 60211', -7.321800, 112.654700, 0),
  ('Apotek K-24 Sidotopo Wetan Surabaya', 'Jl. Sidotopo Wetan I Luar No.43, Sidotopo Wetan, Kec. Kenjeran, Surabaya, Jawa Timur 60128', -7.234500, 112.768100, 0),
  ('Apotek K-24 Sukomanunggal Surabaya', 'Jl. Sukomanunggal No.41, Sukomanunggal, Kec. Sukomanunggal, Surabaya, Jawa Timur 60188', -7.266200, 112.710200, 0),
  ('Apotek K-24 Lontar Surabaya', 'Lontar, Kec. Sambikerep, Surabaya, Jawa Timur 60216', -7.279800, 112.668500, 0),
  ('Apotek K-24 Kedinding Lor Surabaya', 'Jl. Kedinding Lor No.37, Tanah Kali Kedinding, Kec. Kenjeran, Surabaya, Jawa Timur 60129', -7.219500, 112.768200, 0),
  ('Apotek K-24 Kopelindo 3 Surabaya', 'Jl. Tlk. Nibung No.8, Perak Utara, Kec. Pabean Cantian, Surabaya, Jawa Timur 60165', -7.202300, 112.732800, 0),
  ('Apotek K-24 Bukit Darmo Surabaya', 'Jl. Raya Bukit Darmo 1L, Jl. Bukit Darmo Golf No.1M, Putat Gede, Kec. Sukomanunggal, Surabaya, Jawa Timur 60189', -7.288200, 112.695100, 0),
  ('Apotek K-24 Kupang Jaya Surabaya', 'Ruko Kupang Jaya, Jl. Kupang Jaya AF No.1, Sonokwijenan, Kec. Sukomanunggal, Surabaya, Jawa Timur 60189', -7.278500, 112.705800, 0),
  ('Apotek K-24 Galeria Palma Surabaya', 'Komp. Perum Citraland Surya Palma Galeria Blok RB-1 No.12, Bringin, Kec. Sambikerep, Surabaya, Jawa Timur 60218', -7.284500, 112.641200, 0),
  ('Apotek K-24 Perak Timur Surabaya', 'Jl. Perak Timur No.98, Perak Tim., Kec. Pabean Cantian, Surabaya, Jawa Timur 60164', -7.218500, 112.734800, 0),
  ('Apotek K-24 Sidodadi Sidoarjo', 'Ruko Surya Square & Garden, Jl. Sidodadi, Balumn, Sidodadi, Kec. Candi, Kabupaten Sidoarjo, Jawa Timur 61257', -7.478200, 112.715800, 0),
  ('Apotek K-24 Tulangan Sidoarjo', 'Jl. Raya Kemantren, RT.09/RW.02, Keputran, Kemantren, Kec. Tulangan, Kabupaten Sidoarjo, Jawa Timur 61273', -7.471500, 112.658200, 0),
  ('Apotek K-24 Sidokare Sidoarjo', 'Asri AQ/3, Jl. Kutuk Barat, Perum Sidokare, Sepande, Kec. Candi, Kabupaten Sidoarjo, Jawa Timur 61271', -7.458500, 112.708200, 0),

  -- ZONA 5 / GRESIK (12 Apotek - Tarif KM Driver Rp 1.750/KM)
  ('Apotek K-24 Panglima Sudirman Gresik', 'Jl. Panglima Sudirman No.116, Kramatandap, Gapurosukolilo, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61122', -7.162500, 112.653100, 0),
  ('Apotek K-24 Driyorejo Gresik', 'Jl. Raya Batu Mulia, Paras, Mulung, Kec. Driyorejo, Kabupaten Gresik, Jawa Timur 61177', -7.348200, 112.621500, 0),
  ('Apotek K-24 Gubernur Suryo Gresik', 'Jl. Gubernur Suryo No. 1, Karangpoh, Kemuteran, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61116', -7.164500, 112.656200, 0),
  ('Apotek K-24 Benowo Gresik', 'Jalan Raya Ngasinan No 60195 No.8 Kepatihan, Benowo, Kec. Menganti, Kabupaten Gresik, Jawa Timur 61174', -7.248200, 112.618500, 0),
  ('Apotek K-24 Bungah Gresik', 'Jl. Raya Dukuh RT.22/RW.08 Dukuh, Kaliwot, Bungah, Kec. Bungah, Kabupaten Gresik, Jawa Timur 61152', -7.054200, 112.578200, 0),
  ('Apotek K24 PPS', 'Jl. Raya Permata Suci, Suci, Kec. Manyar, Kabupaten Gresik, Jawa Timur 61151', -7.132500, 112.608500, 0),
  ('Apotek K-24 Dr Sutomo Gresik', 'Jl. Dr. Soetomo No.141, Trate, Kec. Gresik, Kabupaten Gresik, Jawa Timur 61111', -7.158500, 112.651200, 0),
  ('Apotek K-24 Balongpanggang', 'Jl. Raya Balongpanggang No.51A, Wates, Kedungpring, Kec. Balongpanggang, Kabupaten Gresik, Jawa Timur 61173', -7.265200, 112.448500, 0),
  ('Apotek K-24 Giri Gresik', 'Jl. Sunan Prapen No.31, Pedukuhan, Kebomas, Kec. Kebomas, Kabupaten Gresik, Jawa Timur 61124', -7.168500, 112.635800, 0),
  ('Apotek K-24 GKB Gresik', 'Jl. Kalimantan No.74, Wonorejo, Yosowilangun, Kec. Manyar, Kabupaten Gresik, Jawa Timur 61151', -7.141500, 112.612800, 0),
  ('Apotek K-24 GKB Sumatera Gresik', 'Jl. Taman Enggano Dalam No.02 GKB, Setingi, Yosowilangun, Kec. Manyar, Kabupaten Gresik, Jawa Timur 61151', -7.139500, 112.615200, 0),
  ('Apotek K-24 Pasar Menganti Gresik', 'Jl. Raya Menganti Karang Turi Menganti Krajan Gg. 5 No.29, Krajan, Menganti, Kec. Menganti, Kabupaten Gresik, Jawa Timur 61174', -7.312500, 112.589200, 0)
) AS t(name, addr, lat, lng, z)
WHERE NOT EXISTS (
  SELECT 1 FROM alamat_penerima WHERE nama_apotek = t.name
);
