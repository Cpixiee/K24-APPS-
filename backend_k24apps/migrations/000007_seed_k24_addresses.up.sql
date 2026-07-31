-- Migration 000007: Seed K-24 Pharmacy Addresses database in Indonesia
-- Pre-populates alamat_penerima table with realistic K24 outlets, addresses, and coordinates

INSERT INTO alamat_penerima (nama_apotek, alamat_lengkap, latitude, longitude)
SELECT name, addr, lat, lng FROM (
  VALUES
  ('Apotek K-24 Veteran Bekasi', 'JL. Raya Veteran No. 34 Keluarahan Marga Jaya-Bekasi Selatan', -6.248332, 106.997232),
  ('Apotek K-24 Pondok Gede', 'Jl. Raya Pondok Gede No.69 Rt.005 RW.012 Lubang Buaya-Cipayung-Jakarta', -6.291244, 106.904839),
  ('Apotek K-24 Perjuangan Bekasi', 'Jl. Raya Perjuangan No. 66, Bekasi Utara', -6.219812, 107.001923),
  ('Apotek K-24 Poris Indah Tangerang', 'RUKO PORIS PARADISE BLOK C-2 NO.9 RT. 002/010 KEL. PORISGAGA, Tangerang', -6.177242, 106.666928),
  ('Apotek K-24 Kemakmuran Raya Depok', 'Jl. Kemakmuran Raya No. 9 C, Kel. Mekar Jaya, Kec. Sukma Jaya, Depok', -6.398129, 106.837821),
  ('Apotek K-24 Condet', 'Jl. Raya Condet No. 103 A, RT 004/003, Jakarta Timur', -6.289123, 106.853245),
  ('Apotek K-24 Bintang Farma Bekasi', 'JL. KINCAN RAYA NO. 17C. RT/RW. 01/07, JATIBENING, PONDOK GEDE', -6.258212, 106.953456),
  ('Apotek K-24 Tebet', 'jl. Tebet timur dalam rayano.71, Tebet, Jakarta Selatan', -6.229123, 106.850987),
  ('Apotek K-24 Pondok Pinang', 'JL. CIPUTAT RAYA NO.17CPONDOK PINANG KEBAYORAN LAMA JAKARTA SELATAN', -6.269123, 106.778123),
  ('Apotek K-24 Merpati Ciputat', 'RUKO MERPATI RESIDENCE KAV 1, Ciputat, Tangerang Selatan', -6.301234, 106.721234),
  ('Apotek K-24 Cempaka Putih', 'Jl. Cempaka Putih Raya No. 104 B, Jakarta Pusat', -6.182123, 106.865432),
  ('Apotek K-24 Rawamangun', 'Jl. Balai Pustaka Timur No. 16, Rawamangun, Jakarta Timur', -6.194321, 106.890123),
  ('Apotek K-24 Matraman', 'Jl. Matraman Raya No.34-36 RT. RW. Kel. Kebon Manggis Kec. Matraman, Jakarta Timur', -6.211234, 106.859123),
  ('Apotek K-24 Mall Of Indonesia', 'Jl. Boulevard Barat Raya Blok I No. 8, Kelapa Gading, Jakarta Utara', -6.151234, 106.891234),
  ('Apotek K-24 Raya Hankam', 'Raya Hankam no. 380 RT.005 RW.005 Jati Murni Pondok Melati Kota Bekasi', -6.321234, 106.921234),
  ('Apotek K-24 Gunung Sahari', 'Jl. Gunung Sahari Raya Blok A2 No. 13, Jakarta Pusat', -6.141234, 106.837123),
  ('Apotek K-24 Puloribung', 'TAMAN WISMA ASRI B.31 NO 26 RT 005 RW.017 KEL. TELUK PUCUNG KEC, Bekasi', -6.211234, 107.018123),
  ('Apotek K-24 Wisma Kentjana', 'Jl. Kalisari Raya II No.5/6, RT.013/01, Kelurahan Pekayon, Kecamatan Pasar Rebo, Jakarta Timur', -6.331234, 106.861234),
  ('Apotek K-24 Graha Raya Tangerang', 'KOMPLEK GRAHA BINTARO, JL. GRAHA RAYA BLOK G-10 NO. 2A, TANGERANG', -6.241234, 106.691234),
  ('Apotek K-24 Pisangan Baru', 'JL. PISANGAN BARU TENGAH NO.16, JAKARTA TIMUR', -6.208123, 106.868123),
  ('Apotek K-24 Cililitan Besar', 'JL. CILILITAN BESAR NO. 72-D, RT/RW 007/01, KRAMAT JATI, JAKARTA TIMUR', -6.262123, 106.871234),
  ('Apotek K-24 Rempoa Tangerang', 'JL. PAHLAWAN NO. 99, REMPOA, CIPUTAT, TANGERANG', -6.271234, 106.762123),
  ('Apotek K-24 Raden Saleh', 'JL. RADEN SALEH RAYA NO. 39 G, CIKINI MENTENG JAKARTA PUSAT', -6.189123, 106.839123),
  ('Apotek K-24 Rawasari', 'JL. RAWASARI SELATAN NO C3B JAKARTA PUSAT', -6.188123, 106.872123),
  ('Apotek K-24 Pesanggrahan', 'Jl. Pesanggrahan No.35B, Rt.009 Rw.005, Meruya Utara-Jakarta Barat', -6.198123, 106.741234),
  ('Apotek K-24 Cileungsi Bogor', 'JL. RAYA CILEUNGSI - JONGGOL KM.2, CILEUNGSI, BOGOR 16820', -6.402123, 106.961234),
  ('Apotek K-24 Letda Nasir Bogor', 'Jl. Letda Natsir, Bojong Kulur, Kec. Gn. Putri, Bogor, Jawa Barat 16969', -6.319876, 106.971234),
  ('Apotek K-24 Tanjung Duren', 'Jl. Tanjung Duren Raya No. 431 B, Jakarta Barat', -6.171234, 106.782123),
  ('Apotek K-24 Cilangkap', 'Ruko Cilangkap Indah R65. Jl. Raya Cilangkap No. 55 RT 007/004 Cilangkap, Jakarta Timur', -6.329876, 106.901234),
  ('Apotek K-24 Cipete', 'JL. CIPETE RAYA NO. 55, RT/RW 006/04, KEL. CIPETE SELATAN, KEC. CILANDAK, Jakarta Selatan', -6.273211, 106.804321),
  ('Apotek K-24 Bintaro Sektor 9', 'Senayan Utama Bintaro Jaya Sektor 9 HJ 2 No. 2 RT.004 RW.015 Pondok Pucung, Tangerang Selatan', -6.282123, 106.711234),
  ('Apotek K-24 Bangka Raya', 'Jalan Bangka Raya No. 40 D, Kemang, Jakarta Selatan', -6.249123, 106.819123),
  ('Apotek K-24 Jatiasih Bekasi', 'Jl. Raya Pasar Rebo No.1, RT/RW 5 / 4 Kel. Jati Rasa, Kec. Jatiasih, BEKASI 17424', -6.309123, 106.969123),
  ('Apotek K-24 Anggrek Cikarang', 'Cikarang Baru, Jl. Anggrek No.23, Mekarmukti, Kec. Cikarang Utara, Kabupaten Bekasi', -6.291234, 107.151234),
  ('Apotek K-24 Percetakan Negara II', 'Jl. Percetakan Negara II Blok J No. 14 RT. 2 RW. 3 Kel. Johar Baru, Jakarta Pusat', -6.188234, 106.852345),
  ('Apotek K-24 Cikarang Pasir Sari', 'Kp. Tegal Gede Rt 44256 Desa Pasir Sari Cikarang Selatan Kab. Bekasi', -6.311234, 107.131234),
  ('Apotek K-24 Pekayon Bekasi', 'Jl. Raya Pekayon No. 55 RT.003 Pekayon Jaya, Bekasi Selatan', -6.261234, 106.981234),
  ('Apotek K-24 Kramat Jaya', 'Jl. Kramat Jaya No. 22 Blok A-7 RT.006 RW.017 Tugu Utara Koja Jakarta Utara', -6.128123, 106.911234),
  ('Apotek K-24 Taman Galaxy Bekasi', 'KOMPLEKS TAMAN GALAXY INDAH, JL. TAMAN GALAXY RAYA BLOK A-38 KABUPATEN BEKASI', -6.269123, 106.971234),
  ('Apotek K-24 Lapangan Tembak', 'JL. LAPANGAN TEMBAK NO. RT.002 RW.007 KEL. KELAPADUA WETAN KEC. PASAR REBO, Jakarta Timur', -6.341234, 106.881234),
  ('Apotek K-24 Satelit Mutiara Gading 3', 'RUKO PALAZZO BLOK C-2 NO. 17-19 VILLA MUTIARA GADING 3 BABELAN BEKASI', -6.189876, 107.019876)
) AS t(name, addr, lat, lng)
WHERE NOT EXISTS (
  SELECT 1 FROM alamat_penerima WHERE nama_apotek = t.name
);
