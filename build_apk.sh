#!/bin/bash

# Hentikan eksekusi jika terjadi error
set -e

echo "=================================================="
echo "🧹  MEMBERSIHKAN OUTPUT APK SEBELUMNYA..."
echo "=================================================="

# Menghapus folder outputs APK lama agar tidak menumpuk memori (cache kompilasi gradle tetap utuh agar build cepat)
if [ -d "build/app/outputs/flutter-apk" ]; then
  rm -rf build/app/outputs/flutter-apk
  echo "✓ Output APK lama berhasil dibersihkan."
else
  echo "✓ Folder output sudah bersih."
fi

echo ""
echo "=================================================="
echo "🚀  MEMULAI BUILD UNIVERSAL APK (KOMPATIBEL SEMUA HP)..."
echo "=================================================="

# Menjalankan build universal APK yang kompatibel di semua HP
flutter build apk --release

echo ""
echo "=================================================="
echo "🎉  BUILD SELESAI DENGAN SUKSES!"
echo "=================================================="
echo "File APK Universal yang siap dikirim ke HP Anda:"
echo ""

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
  # Menampilkan info file APK universal beserta ukurannya
  ls -lh build/app/outputs/flutter-apk/app-release.apk
fi
echo ""
echo "Lokasi Folder APK: build/app/outputs/flutter-apk/"
echo "=================================================="
