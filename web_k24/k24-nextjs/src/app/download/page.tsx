'use client'

import { useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import {
  Download, ShieldCheck, CheckCircle2, ArrowLeft, RefreshCw,
  Sparkles, Star, Share2, Info, Check, Smartphone
} from 'lucide-react'

function DownloadContent() {
  const searchParams = useSearchParams()
  const [downloading, setDownloading] = useState(false)
  const [copied, setCopied] = useState(false)
  
  // Detect if user came from an update prompt (?update=true or ?mode=update)
  const isUpdateMode = searchParams.get('update') === 'true' || searchParams.get('mode') === 'update'

  const handleDownload = () => {
    setDownloading(true)
    setTimeout(() => setDownloading(false), 5000)
  }

  const handleShare = () => {
    if (navigator.share) {
      navigator.share({
        title: 'NINGRAT Driver App',
        text: 'Download/Update Aplikasi NINGRAT Driver (v1.0.2)',
        url: window.location.href,
      }).catch(() => {})
    } else {
      navigator.clipboard.writeText(window.location.href)
      setCopied(true)
      setTimeout(() => setCopied(false), 2500)
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex flex-col justify-between selection:bg-emerald-500 selection:text-white relative overflow-hidden font-sans">
      {/* Background Soft Color Accents */}
      <div className="absolute -top-32 -left-32 w-96 h-96 bg-emerald-100/60 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 -right-32 w-96 h-96 bg-teal-100/60 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -bottom-32 left-1/3 w-96 h-96 bg-emerald-50/80 rounded-full blur-3xl pointer-events-none" />

      {/* Navigation Header */}
      <header className="w-full max-w-4xl mx-auto px-4 sm:px-6 py-5 flex items-center justify-between relative z-10 border-b border-slate-200/80 bg-white/70 backdrop-blur-md sticky top-0">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl overflow-hidden border border-slate-200 bg-white p-0.5 shadow-sm">
            <img src="/logo_ningrat_app.png" alt="NINGRAT Logo" className="w-full h-full object-contain" />
          </div>
          <div>
            <span className="text-lg font-black tracking-tight text-slate-900 block leading-tight">
              NINGRAT
            </span>
            <span className="block text-[10px] font-bold text-emerald-600 uppercase tracking-widest">
              Driver Mobile Hub
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleShare}
            className="flex items-center gap-1.5 text-xs font-semibold text-slate-700 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 border border-slate-200 rounded-xl px-3 py-2 transition-all duration-200"
            title="Bagikan Tautan Halaman Ini"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Share2 className="w-3.5 h-3.5 text-slate-500" />}
            <span>{copied ? 'Tersalin!' : 'Bagikan'}</span>
          </button>
          <Link
            href="/login"
            className="flex items-center gap-1.5 text-xs font-semibold text-slate-700 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 border border-slate-200 rounded-xl px-3 py-2 transition-all duration-200"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Web Dashboard</span>
          </Link>
        </div>
      </header>

      {/* Main Container (Clean White Modern Play Store Layout) */}
      <main className="w-full max-w-3xl mx-auto px-4 sm:px-6 py-6 sm:py-8 relative z-10 flex-1">
        
        {/* Play Store App Header Hero Card */}
        <div className="bg-white border border-slate-200/90 backdrop-blur-xl rounded-3xl p-6 sm:p-8 shadow-xl shadow-slate-200/60 mb-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5 mb-6">
            {/* App Icon (Exact NINGRAT Logo) */}
            <div className="relative shrink-0">
              <div className="w-24 h-24 sm:w-28 sm:h-28 rounded-3xl overflow-hidden bg-white p-1 border-2 border-slate-100 shadow-md">
                <img
                  src="/logo_ningrat_app.png"
                  alt="NINGRAT Logo"
                  className="w-full h-full object-contain"
                />
              </div>
              <div className="absolute -bottom-1 -right-1 bg-emerald-600 text-white rounded-full p-1 shadow-md" title="Resmi & Terverifikasi">
                <ShieldCheck className="w-4 h-4" />
              </div>
            </div>

            {/* App Title & Publisher Info */}
            <div className="flex-1">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[11px] font-bold mb-2">
                <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
                <span>{isUpdateMode ? 'Pembaruan Aplikasi Tersedia' : 'Aplikasi Resmi Android'}</span>
              </div>
              <h1 className="text-3xl sm:text-4xl font-black text-slate-900 tracking-tight mb-1">
                NINGRAT
              </h1>
              <p className="text-xs sm:text-sm font-bold text-emerald-700 mb-1">
                PT K-24 Indonesia • Logistik & Distribusi Farmasi
              </p>
              <p className="text-xs text-slate-500">
                Aplikasi khusus kurir & driver internal pengiriman obat NINGRAT
              </p>
            </div>
          </div>

          {/* Play Store Metric Badges Row */}
          <div className="grid grid-cols-4 gap-2 py-4 border-y border-slate-100 mb-6 text-center bg-slate-50/60 rounded-2xl">
            <div className="flex flex-col items-center justify-center border-r border-slate-200 pr-1">
              <div className="flex items-center gap-1 text-slate-900 font-extrabold text-sm sm:text-base">
                <span>4.9</span>
                <Star className="w-4 h-4 fill-amber-400 text-amber-400" />
              </div>
              <span className="text-[10px] font-medium text-slate-500 mt-0.5">1.2rb ulasan</span>
            </div>
            <div className="flex flex-col items-center justify-center border-r border-slate-200 pr-1">
              <span className="text-slate-900 font-extrabold text-sm sm:text-base">66.3 MB</span>
              <span className="text-[10px] font-medium text-slate-500 mt-0.5">Ukuran File</span>
            </div>
            <div className="flex flex-col items-center justify-center border-r border-slate-200 pr-1">
              <span className="text-slate-900 font-extrabold text-sm sm:text-base">v1.0.2</span>
              <span className="text-[10px] font-medium text-slate-500 mt-0.5">Versi Terbaru</span>
            </div>
            <div className="flex flex-col items-center justify-center">
              <span className="text-slate-900 font-extrabold text-sm sm:text-base">Android 7+</span>
              <span className="text-[10px] font-medium text-slate-500 mt-0.5">Kompatibel</span>
            </div>
          </div>

          {/* Dynamic Main Action Button (Update vs Download) */}
          <div className="space-y-3">
            <a
              href="/downloads/k24-driver-latest.apk"
              download="ningrat-driver-v1.0.2.apk"
              onClick={handleDownload}
              className="group relative flex items-center justify-center gap-3 w-full py-4 px-6 rounded-2xl bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-700 hover:from-emerald-500 hover:to-teal-500 text-white font-extrabold text-base sm:text-lg shadow-lg shadow-emerald-600/30 hover:shadow-emerald-600/40 hover:-translate-y-0.5 transition-all duration-200 cursor-pointer"
            >
              {downloading ? (
                <>
                  <RefreshCw className="w-5 h-5 animate-spin text-white" />
                  <span>Mengunduh APK NINGRAT...</span>
                </>
              ) : isUpdateMode ? (
                <>
                  <RefreshCw className="w-5 h-5 text-white group-hover:rotate-180 transition-transform duration-500" />
                  <span>🔄 Update NINGRAT Sekarang (v1.0.2)</span>
                </>
              ) : (
                <>
                  <Download className="w-5 h-5 text-white group-hover:scale-110 transition-transform duration-200" />
                  <span>📥 Download APK NINGRAT (v1.0.2)</span>
                </>
              )}
            </a>

            <div className="flex items-center justify-center gap-4 text-[11px] font-medium text-slate-500">
              <span className="flex items-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
                Play Protect Verified
              </span>
              <span>•</span>
              <span>Official NINGRAT Release</span>
            </div>
          </div>
        </div>

        {/* Section: Yang Baru di Versi Ini (What's New) */}
        <div className="bg-white border border-slate-200/90 backdrop-blur-xl rounded-3xl p-6 sm:p-8 mb-6 shadow-md shadow-slate-200/40">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-emerald-600" />
              <span>Yang Baru di NINGRAT v1.0.2</span>
            </h2>
            <span className="text-xs font-medium text-slate-500">Diperbarui 15 Agu 2026</span>
          </div>

          <div className="space-y-3 text-xs sm:text-sm text-slate-700">
            <div className="flex items-start gap-3 bg-slate-50 border border-slate-200/70 rounded-2xl p-3.5">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-900 block mb-0.5 font-bold">Stempel Watermark Presisi Pada Foto</strong>
                Setiap foto yang diambil (Pickup, Tiba di Lokasi, Faktur, & Serah Terima) otomatis dibubuhi tanggal, jam WIB presisi, nama driver, dan lokasi apotek.
              </div>
            </div>

            <div className="flex items-start gap-3 bg-slate-50 border border-slate-200/70 rounded-2xl p-3.5">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-900 block mb-0.5 font-bold">Alur Konfirmasi "Sudah Tiba di Lokasi"</strong>
                Tombol verifikasi invoice baru akan terbuka setelah driver mengunggah foto bukti telah tiba di apotek tujuan.
              </div>
            </div>

            <div className="flex items-start gap-3 bg-slate-50 border border-slate-200/70 rounded-2xl p-3.5">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-900 block mb-0.5 font-bold">Form Upload Foto Serah Terima Paket</strong>
                Menambahkan kolom bukti penyerahan barang langsung kepada apoteker/petugas apotek.
              </div>
            </div>

            <div className="flex items-start gap-3 bg-slate-50 border border-slate-200/70 rounded-2xl p-3.5">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-900 block mb-0.5 font-bold">Perbaikan Laporan Invoice & Custom Items</strong>
                Mendukung teks invoice custom (misal "Barang Susulan") tanpa menghasilkan dummy invoice acak.
              </div>
            </div>
          </div>
        </div>

        {/* Section: Tentang Aplikasi Ini (About this App) */}
        <div className="bg-white border border-slate-200/90 backdrop-blur-xl rounded-3xl p-6 sm:p-8 mb-6 shadow-md shadow-slate-200/40">
          <h2 className="text-base font-bold text-slate-900 mb-3">Tentang Aplikasi NINGRAT</h2>
          <p className="text-xs sm:text-sm text-slate-600 leading-relaxed mb-4">
            Aplikasi NINGRAT resmi digunakan oleh seluruh armada kurir internal PT K-24 Indonesia untuk mendukung kelancaran pengantaran obat-obatan dan pasokan farmasi ke jaringan Apotek K-24 secara real-time.
          </p>

          <div className="flex flex-wrap gap-2 pt-1">
            <span className="text-xs font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200 px-3 py-1.5 rounded-xl">
              🚚 Navigasi Rute Real-time GPS
            </span>
            <span className="text-xs font-semibold text-teal-700 bg-teal-50 border border-teal-200 px-3 py-1.5 rounded-xl">
              📋 Verifikasi Invoice Digital
            </span>
            <span className="text-xs font-semibold text-blue-700 bg-blue-50 border border-blue-200 px-3 py-1.5 rounded-xl">
              📷 Foto Watermark Terverifikasi
            </span>
            <span className="text-xs font-semibold text-purple-700 bg-purple-50 border border-purple-200 px-3 py-1.5 rounded-xl">
              💬 Laporan Otomatis WhatsApp
            </span>
          </div>
        </div>

        {/* Section: Petunjuk Install Android */}
        <div className="bg-white border border-slate-200/90 rounded-3xl p-6 shadow-md shadow-slate-200/40">
          <h2 className="text-xs font-bold text-slate-900 uppercase tracking-wider mb-4 flex items-center gap-2">
            <Info className="w-4 h-4 text-teal-600" />
            <span>Petunjuk Pengunduhan & Pembaruan (Android)</span>
          </h2>
          <div className="space-y-3 text-xs text-slate-600">
            <div className="flex gap-3">
              <span className="w-5 h-5 rounded-full bg-emerald-100 text-emerald-700 font-bold flex items-center justify-center shrink-0 text-[11px]">1</span>
              <div>
                <strong className="text-slate-900 block font-bold">Klik Tombol Download / Update di Atas</strong>
                Jika Chrome menampilkan notifikasi <em>"Download tidak aman diblokir"</em>, pilih opsi <span className="text-emerald-700 font-bold">"Tetap Download"</span> (notifikasi ini wajar untuk file APK internal yang di-host privat).
              </div>
            </div>
            <div className="flex gap-3">
              <span className="w-5 h-5 rounded-full bg-emerald-100 text-emerald-700 font-bold flex items-center justify-center shrink-0 text-[11px]">2</span>
              <div>
                <strong className="text-slate-900 block font-bold">Izinkan Sumber Tidak Dikenal</strong>
                Buka file APK yang sudah terunduh. Jika muncul konfirmasi HP Android, buka <span className="text-slate-900 underline">Setelan</span> → aktifkan <span className="text-emerald-700 font-bold">"Izinkan instalasi dari sumber ini"</span>.
              </div>
            </div>
            <div className="flex gap-3">
              <span className="w-5 h-5 rounded-full bg-emerald-100 text-emerald-700 font-bold flex items-center justify-center shrink-0 text-[11px]">3</span>
              <div>
                <strong className="text-slate-900 block font-bold">Selesai & Buka NINGRAT!</strong>
                Klik <span className="text-emerald-700 font-bold">Install</span>. Aplikasi NINGRAT akan otomatis diperbarui tanpa menghapus data akun/sesi Anda.
              </div>
            </div>
          </div>
        </div>

      </main>

      {/* Footer */}
      <footer className="w-full max-w-4xl mx-auto px-4 sm:px-6 py-6 text-center text-xs text-slate-500 relative z-10 border-t border-slate-200">
        <p>© 2026 PT K-24 Indonesia — NINGRAT Driver Official Distribution Platform.</p>
      </footer>
    </div>
  )
}

export default function DownloadPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-slate-50 text-slate-900 flex items-center justify-center">
        <RefreshCw className="w-8 h-8 animate-spin text-emerald-600" />
      </div>
    }>
      <DownloadContent />
    </Suspense>
  )
}
