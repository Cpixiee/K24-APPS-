'use client'

import { useState } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { Download, ShieldCheck, Smartphone, CheckCircle2, ArrowLeft, RefreshCw, FileText, Info, AlertTriangle } from 'lucide-react'

export default function DownloadPage() {
  const [downloading, setDownloading] = useState(false)

  const handleDownload = () => {
    setDownloading(true)
    setTimeout(() => setDownloading(false), 4000)
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col justify-between selection:bg-emerald-500 selection:text-white relative overflow-hidden">
      {/* Background Gradient Orbs */}
      <div className="absolute -top-40 -left-40 w-96 h-96 bg-emerald-600/20 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 -right-40 w-96 h-96 bg-blue-600/20 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -bottom-40 left-1/3 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      {/* Navigation Header */}
      <header className="w-full max-w-5xl mx-auto px-4 sm:px-6 py-6 flex items-center justify-between relative z-10">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-500 to-teal-400 p-0.5 shadow-lg shadow-emerald-500/20">
            <div className="w-full h-full bg-slate-950 rounded-[10px] flex items-center justify-center">
              <Smartphone className="w-5 h-5 text-emerald-400" />
            </div>
          </div>
          <div>
            <span className="text-lg font-bold bg-gradient-to-r from-white via-slate-200 to-slate-400 bg-clip-text text-transparent">
              K-24 LOGISTICS
            </span>
            <span className="block text-[10px] font-semibold text-emerald-400 uppercase tracking-widest">
              Driver Mobile Hub
            </span>
          </div>
        </div>

        <Link
          href="/login"
          className="flex items-center gap-2 text-xs font-semibold text-slate-400 hover:text-white bg-slate-900/80 hover:bg-slate-800 border border-slate-800 rounded-lg px-3.5 py-2 transition-all duration-200 backdrop-blur-md"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          <span>Web Dashboard</span>
        </Link>
      </header>

      {/* Main Container */}
      <main className="w-full max-w-3xl mx-auto px-4 sm:px-6 py-8 relative z-10 flex-1 flex flex-col justify-center">
        {/* Main Card */}
        <div className="bg-slate-900/70 border border-slate-800/80 backdrop-blur-xl rounded-3xl p-6 sm:p-10 shadow-2xl shadow-emerald-950/20 relative overflow-hidden">
          {/* Subtle Top Accent Bar */}
          <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-emerald-500 via-teal-400 to-emerald-600" />

          {/* Status Badge & Header */}
          <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
            <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span>Versi Resmi v1.0.2 Terbaru</span>
            </div>
            <div className="flex items-center gap-1.5 text-xs text-slate-400">
              <ShieldCheck className="w-4 h-4 text-teal-400" />
              <span>Terverifikasi Bebas Virus & Malware</span>
            </div>
          </div>

          <h1 className="text-2xl sm:text-4xl font-extrabold text-white tracking-tight mb-3">
            Download Aplikasi K-24 Driver
          </h1>
          <p className="text-slate-400 text-sm sm:text-base leading-relaxed mb-8">
            Unduh installer resmi APK aplikasi driver K-24 Logistics untuk perangkat Android. Pembaruan ini sudah mencakup stempel watermark foto presisi, alur Tiba di Lokasi, dan perbaikan laporan.
          </p>

          {/* Technical Info Badges */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-8">
            <div className="bg-slate-950/60 border border-slate-800/60 rounded-xl p-3.5">
              <span className="block text-[11px] font-medium text-slate-400 mb-0.5">Ukuran File</span>
              <span className="text-sm font-bold text-slate-200">66.3 MB</span>
            </div>
            <div className="bg-slate-950/60 border border-slate-800/60 rounded-xl p-3.5">
              <span className="block text-[11px] font-medium text-slate-400 mb-0.5">Sistem Operasi</span>
              <span className="text-sm font-bold text-slate-200">Android 7.0+</span>
            </div>
            <div className="col-span-2 sm:col-span-1 bg-slate-950/60 border border-slate-800/60 rounded-xl p-3.5">
              <span className="block text-[11px] font-medium text-slate-400 mb-0.5">Tanggal Rilis</span>
              <span className="text-sm font-bold text-slate-200">15 Agustus 2026</span>
            </div>
          </div>

          {/* Primary Download Button */}
          <div className="mb-10">
            <a
              href="/downloads/k24-driver-latest.apk"
              download="k24-driver-v1.0.2.apk"
              onClick={handleDownload}
              className="group relative flex items-center justify-center gap-3 w-full py-4 px-6 rounded-2xl bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-600 hover:from-emerald-400 hover:to-teal-400 text-slate-950 font-extrabold text-base sm:text-lg shadow-xl shadow-emerald-500/25 hover:shadow-emerald-500/40 hover:-translate-y-0.5 transition-all duration-200 cursor-pointer"
            >
              {downloading ? (
                <>
                  <RefreshCw className="w-6 h-6 animate-spin text-slate-950" />
                  <span>Mengunduh File APK...</span>
                </>
              ) : (
                <>
                  <Download className="w-6 h-6 text-slate-950 group-hover:scale-110 transition-transform duration-200" />
                  <span>Download APK Driver (v1.0.2)</span>
                </>
              )}
            </a>
            <p className="text-center text-[11px] text-slate-400 mt-2.5">
              Tautan unduhan langsung dari server resmi K-24 Logistics (HTTP Direct Stream)
            </p>
          </div>

          {/* Release Notes */}
          <div className="border-t border-slate-800/80 pt-6 mb-8">
            <h2 className="text-sm font-bold text-slate-200 uppercase tracking-wider mb-4 flex items-center gap-2">
              <FileText className="w-4 h-4 text-emerald-400" />
              <span>Fitur Terbaru di Versi 1.0.2</span>
            </h2>
            <ul className="space-y-2.5 text-xs sm:text-sm text-slate-300">
              <li className="flex items-start gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <span><strong className="text-white">Watermark Otomatis:</strong> Setiap foto ber-timestamp presisi WIB, nama driver, & lokasi apotek.</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <span><strong className="text-white">Alur Tiba di Lokasi:</strong> Tombol verifikasi invoice baru aktif setelah mengunggah foto tiba di lokasi apotek.</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <span><strong className="text-white">Foto Serah Terima Paket:</strong> Form upload bukti penerimaan barang langsung ke apoteker.</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <span><strong className="text-white">Invoice Custom Presisi:</strong> Mendukung invoice custom (misal "Barang Susulan") tanpa dummy otomatis.</span>
              </li>
              <li className="flex items-start gap-2.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <span><strong className="text-white">In-App Auto Update:</strong> Notifikasi pembaruan langsung di aplikasi tanpa kirim ZIP manual.</span>
              </li>
            </ul>
          </div>

          {/* Installation Guide */}
          <div className="bg-slate-950/80 border border-slate-800/80 rounded-2xl p-5">
            <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider mb-3 flex items-center gap-2">
              <Info className="w-4 h-4 text-teal-400" />
              <span>Cara Install APK di HP Android (3 Langkah)</span>
            </h3>
            <div className="space-y-3 text-xs text-slate-300">
              <div className="flex gap-3">
                <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">1</span>
                <div>
                  <strong className="text-slate-100 block">Klik tombol "Download APK Driver" di atas.</strong>
                  Jika browser Chrome menampilkan peringatan <em>"Download tidak aman diblokir"</em>, klik titik 3 atau opsi <span className="text-emerald-400 font-semibold">"Tetap Download"</span> (karena ini server privat internal K-24).
                </div>
              </div>
              <div className="flex gap-3">
                <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">2</span>
                <div>
                  <strong className="text-slate-100 block">Buka File APK yang Terdownload.</strong>
                  Jika muncul pop-up keamanan HP, pilih <span className="text-slate-100 underline">Setelan</span> → aktifkan <span className="text-emerald-400 font-semibold">"Izinkan dari sumber ini"</span>.
                </div>
              </div>
              <div className="flex gap-3">
                <span className="w-5 h-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">3</span>
                <div>
                  <strong className="text-slate-100 block">Selesai & Buka Aplikasi!</strong>
                  Klik <span className="text-emerald-400 font-semibold">Install</span>, lalu buka aplikasi K-24 Logistics Driver dan lakukan Login seperti biasa.
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="w-full max-w-5xl mx-auto px-4 sm:px-6 py-6 text-center text-xs text-slate-400 relative z-10">
        <p>© 2026 PT K-24 Indonesia — Official Driver Distribution Platform.</p>
      </footer>
    </div>
  )
}
