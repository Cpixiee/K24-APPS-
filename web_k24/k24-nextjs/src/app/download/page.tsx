'use client'

import { useState, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import {
  Download, ShieldCheck, Smartphone, CheckCircle2, ArrowLeft, RefreshCw,
  FileText, Info, Star, Share2, Sparkles, Check
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
        title: 'NINGRAT K-24 Driver App',
        text: 'Download/Update Aplikasi NINGRAT Driver K-24 Logistics (v1.0.2)',
        url: window.location.href,
      }).catch(() => {})
    } else {
      navigator.clipboard.writeText(window.location.href)
      setCopied(true)
      setTimeout(() => setCopied(false), 2500)
    }
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col justify-between selection:bg-emerald-500 selection:text-white relative overflow-hidden font-sans">
      {/* Background Gradient Orbs */}
      <div className="absolute -top-40 -left-40 w-96 h-96 bg-emerald-600/15 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 -right-40 w-96 h-96 bg-blue-600/15 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -bottom-40 left-1/3 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      {/* Navigation Header */}
      <header className="w-full max-w-4xl mx-auto px-4 sm:px-6 py-5 flex items-center justify-between relative z-10 border-b border-slate-800/50">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl overflow-hidden shadow-lg shadow-emerald-500/20 border border-emerald-500/40 bg-white flex items-center justify-center">
            <img src="/logo_ningrat_icon.jpg" alt="NINGRAT Logo" className="w-full h-full object-cover" />
          </div>
          <div>
            <span className="text-base font-extrabold tracking-tight text-white flex items-center gap-1.5">
              NINGRAT <span className="text-emerald-400 font-bold text-xs uppercase tracking-wider">K-24</span>
            </span>
            <span className="block text-[9px] font-semibold text-slate-400 uppercase tracking-widest">
              Official Driver Platform
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleShare}
            className="flex items-center gap-1.5 text-xs font-semibold text-slate-300 hover:text-white bg-slate-900/90 hover:bg-slate-800 border border-slate-800 rounded-lg px-3 py-2 transition-all duration-200"
            title="Bagikan Tautan Halaman Ini"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Share2 className="w-3.5 h-3.5 text-slate-400" />}
            <span>{copied ? 'Tersalin!' : 'Bagikan'}</span>
          </button>
          <Link
            href="/login"
            className="flex items-center gap-1.5 text-xs font-semibold text-slate-400 hover:text-white bg-slate-900/90 hover:bg-slate-800 border border-slate-800 rounded-lg px-3 py-2 transition-all duration-200"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Web Dashboard</span>
          </Link>
        </div>
      </header>

      {/* Main Container Layout (Play Store Inspired with NINGRAT branding) */}
      <main className="w-full max-w-3xl mx-auto px-4 sm:px-6 py-6 sm:py-8 relative z-10 flex-1">
        
        {/* Play Store App Header Section */}
        <div className="bg-slate-900/80 border border-slate-800/80 backdrop-blur-xl rounded-3xl p-6 sm:p-8 shadow-2xl shadow-emerald-950/20 mb-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5 mb-6">
            {/* App Icon (Official NINGRAT Logo) */}
            <div className="relative shrink-0">
              <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-2xl overflow-hidden p-0.5 bg-gradient-to-tr from-emerald-500 via-teal-400 to-emerald-300 shadow-xl shadow-emerald-500/25">
                <img
                  src="/logo_ningrat_text.jpg"
                  alt="NINGRAT App Icon"
                  className="w-full h-full object-cover rounded-[14px]"
                />
              </div>
              <div className="absolute -bottom-1 -right-1 bg-emerald-500 text-slate-950 rounded-full p-1 shadow-md" title="Resmi & Terverifikasi">
                <ShieldCheck className="w-3.5 h-3.5" />
              </div>
            </div>

            {/* App Title & Publisher */}
            <div className="flex-1">
              <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-[11px] font-bold mb-2">
                <Sparkles className="w-3 h-3" />
                <span>{isUpdateMode ? 'Update Aplikasi Tersedia' : 'Aplikasi Resmi Android'}</span>
              </div>
              <h1 className="text-2xl sm:text-3xl font-black text-white tracking-tight mb-1">
                NINGRAT DRIVER
              </h1>
              <p className="text-xs sm:text-sm font-semibold text-emerald-400 mb-1">
                PT K-24 Indonesia • K-24 Logistics
              </p>
              <p className="text-xs text-slate-400">
                Aplikasi khusus kurir & driver internal pengiriman farmasi NINGRAT
              </p>
            </div>
          </div>

          {/* Play Store Metric Badges Row */}
          <div className="grid grid-cols-4 gap-2 py-3 border-y border-slate-800/80 mb-6 text-center">
            <div className="flex flex-col items-center justify-center border-r border-slate-800/80 pr-1">
              <div className="flex items-center gap-1 text-slate-200 font-bold text-xs sm:text-sm">
                <span>4.9</span>
                <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
              </div>
              <span className="text-[10px] text-slate-400 mt-0.5">1.2rb ulasan</span>
            </div>
            <div className="flex flex-col items-center justify-center border-r border-slate-800/80 pr-1">
              <span className="text-slate-200 font-bold text-xs sm:text-sm">66.3 MB</span>
              <span className="text-[10px] text-slate-400 mt-0.5">Ukuran File</span>
            </div>
            <div className="flex flex-col items-center justify-center border-r border-slate-800/80 pr-1">
              <span className="text-slate-200 font-bold text-xs sm:text-sm">v1.0.2</span>
              <span className="text-[10px] text-slate-400 mt-0.5">Versi Terbaru</span>
            </div>
            <div className="flex flex-col items-center justify-center">
              <span className="text-slate-200 font-bold text-xs sm:text-sm">Android 7+</span>
              <span className="text-[10px] text-slate-400 mt-0.5">Kompatibel</span>
            </div>
          </div>

          {/* Dynamic Main Action Button (Update vs Download) */}
          <div className="space-y-3">
            <a
              href="/downloads/k24-driver-latest.apk"
              download="ningrat-driver-v1.0.2.apk"
              onClick={handleDownload}
              className="group relative flex items-center justify-center gap-3 w-full py-4 px-6 rounded-2xl bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 hover:from-emerald-400 hover:to-teal-400 text-slate-950 font-black text-base sm:text-lg shadow-xl shadow-emerald-500/25 hover:shadow-emerald-500/40 hover:-translate-y-0.5 transition-all duration-200 cursor-pointer"
            >
              {downloading ? (
                <>
                  <RefreshCw className="w-5 h-5 animate-spin text-slate-950" />
                  <span>Mengunduh File APK...</span>
                </>
              ) : isUpdateMode ? (
                <>
                  <RefreshCw className="w-5 h-5 text-slate-950 group-hover:rotate-180 transition-transform duration-500" />
                  <span>🔄 Update NINGRAT Driver (v1.0.2)</span>
                </>
              ) : (
                <>
                  <Download className="w-5 h-5 text-slate-950 group-hover:scale-110 transition-transform duration-200" />
                  <span>📥 Download NINGRAT Driver (v1.0.2)</span>
                </>
              )}
            </a>

            <div className="flex items-center justify-center gap-4 text-[11px] text-slate-400">
              <span className="flex items-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                Play Protect Verified
              </span>
              <span>•</span>
              <span>Official NINGRAT Release</span>
            </div>
          </div>
        </div>

        {/* Section: Yang Baru di Versi Ini (What's New) */}
        <div className="bg-slate-900/60 border border-slate-800/80 backdrop-blur-xl rounded-3xl p-6 sm:p-8 mb-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              <Sparkles className="w-4 h-4 text-emerald-400" />
              <span>Yang Baru di NINGRAT v1.0.2</span>
            </h2>
            <span className="text-xs text-slate-400">Diperbarui 15 Agu 2026</span>
          </div>

          <div className="space-y-3 text-xs sm:text-sm text-slate-300">
            <div className="flex items-start gap-3 bg-slate-950/60 border border-slate-800/60 rounded-xl p-3">
              <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-100 block mb-0.5">Stempel Watermark Presisi Pada Foto</strong>
                Setiap foto yang diambil (Pickup, Tiba di Lokasi, Faktur, & Serah Terima) otomatis dibubuhi tanggal, jam WIB presisi, nama driver, dan lokasi apotek.
              </div>
            </div>

            <div className="flex items-start gap-3 bg-slate-950/60 border border-slate-800/60 rounded-xl p-3">
              <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-100 block mb-0.5">Alur Konfirmasi "Sudah Tiba di Lokasi"</strong>
                Tombol verifikasi invoice baru akan terbuka setelah driver mengunggah foto bukti telah tiba di apotek tujuan.
              </div>
            </div>

            <div className="flex items-start gap-3 bg-slate-950/60 border border-slate-800/60 rounded-xl p-3">
              <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-100 block mb-0.5">Foto Serah Terima Paket</strong>
                Menambahkan kolom bukti penyerahan barang langsung kepada apoteker/petugas apotek.
              </div>
            </div>

            <div className="flex items-start gap-3 bg-slate-950/60 border border-slate-800/60 rounded-xl p-3">
              <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
              <div>
                <strong className="text-slate-100 block mb-0.5">Perbaikan Laporan Invoice & Custom Items</strong>
                Mendukung teks invoice custom (misal "Barang Susulan") tanpa menghasilkan dummy invoice acak.
              </div>
            </div>
          </div>
        </div>

        {/* Section: Tentang Aplikasi Ini (About this App) */}
        <div className="bg-slate-900/60 border border-slate-800/80 backdrop-blur-xl rounded-3xl p-6 sm:p-8 mb-6">
          <h2 className="text-base font-bold text-white mb-3">Tentang Aplikasi NINGRAT Driver</h2>
          <p className="text-xs sm:text-sm text-slate-300 leading-relaxed mb-4">
            Aplikasi NINGRAT resmi digunakan oleh seluruh armada kurir internal PT K-24 Indonesia untuk mendukung kelancaran pengantaran obat-obatan dan pasokan farmasi ke jaringan Apotek K-24 secara real-time.
          </p>

          <div className="flex flex-wrap gap-2 pt-2">
            <span className="text-xs font-semibold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-3 py-1 rounded-lg">
              🚚 Navigasi Rute Real-time GPS
            </span>
            <span className="text-xs font-semibold text-teal-400 bg-teal-500/10 border border-teal-500/20 px-3 py-1 rounded-lg">
              📋 Verifikasi Invoice Digital
            </span>
            <span className="text-xs font-semibold text-blue-400 bg-blue-500/10 border border-blue-500/20 px-3 py-1 rounded-lg">
              📷 Foto Watermark Terverifikasi
            </span>
            <span className="text-xs font-semibold text-purple-400 bg-purple-500/10 border border-purple-500/20 px-3 py-1 rounded-lg">
              💬 Laporan Otomatis WhatsApp
            </span>
          </div>
        </div>

        {/* Section: Petunjuk Install Android */}
        <div className="bg-slate-950/80 border border-slate-800/80 rounded-3xl p-6">
          <h2 className="text-sm font-bold text-slate-200 uppercase tracking-wider mb-4 flex items-center gap-2">
            <Info className="w-4 h-4 text-teal-400" />
            <span>Petunjuk Pengunduhan & Pembaruan (Android)</span>
          </h2>
          <div className="space-y-3 text-xs text-slate-300">
            <div className="flex gap-3">
              <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">1</span>
              <div>
                <strong className="text-slate-100 block">Klik Tombol Download / Update di Atas</strong>
                Jika Chrome menampilkan notifikasi <em>"Download tidak aman diblokir"</em>, pilih opsi <span className="text-emerald-400 font-semibold">"Tetap Download"</span> (notifikasi ini wajar untuk file APK internal yang di-host privat).
              </div>
            </div>
            <div className="flex gap-3">
              <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">2</span>
              <div>
                <strong className="text-slate-100 block">Izinkan Sumber Tidak Dikenal</strong>
                Buka file APK yang sudah terunduh. Jika muncul konfirmasi HP Android, buka <span className="text-slate-100 underline">Setelan</span> → aktifkan <span className="text-emerald-400 font-semibold">"Izinkan instalasi dari sumber ini"</span>.
              </div>
            </div>
            <div className="flex gap-3">
              <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">3</span>
              <div>
                <strong className="text-slate-100 block">Selesai & Buka NINGRAT!</strong>
                Klik <span className="text-emerald-400 font-semibold">Install</span>. Aplikasi NINGRAT akan otomatis diperbarui tanpa menghapus data akun/sesi Anda.
              </div>
            </div>
          </div>
        </div>

      </main>

      {/* Footer */}
      <footer className="w-full max-w-4xl mx-auto px-4 sm:px-6 py-6 text-center text-xs text-slate-400 relative z-10 border-t border-slate-800/50">
        <p>© 2026 PT K-24 Indonesia — NINGRAT Driver Official Distribution Platform.</p>
      </footer>
    </div>
  )
}

export default function DownloadPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-slate-950 text-white flex items-center justify-center">
        <RefreshCw className="w-8 h-8 animate-spin text-emerald-400" />
      </div>
    }>
      <DownloadContent />
    </Suspense>
  )
}
