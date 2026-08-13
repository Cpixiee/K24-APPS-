'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import {
  FileText, Calendar, AlertTriangle, ShieldAlert,
  Printer, CheckCircle2, Clock, Truck, User, Search, RefreshCw
} from 'lucide-react'

interface FlatInvoiceRow {
  invoice_no: string
  nama_apotek: string
  driver_name: string
  driver_phone?: string
  driver_plate?: string
  vehicle_type?: string
  status: string // "DONE", "MISSING", "PENDING"
  catatan: string // "Done" or custom reason note
  created_at: string
  dispatch_id: string
  reject_reason?: string
  reject_note?: string
  extra_items_note?: string
  unboxing_option?: string
  pickup_note?: string
}

export default function CatatanKhususPage() {
  const [invoices, setInvoices] = useState<FlatInvoiceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [selectedDate, setSelectedDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  )

  const fetchInvoices = useCallback(async () => {
    setLoading(true)
    try {
      const res = await adminAPI.getFlatInvoices(selectedDate)
      const raw = res.data?.data ?? res.data
      if (Array.isArray(raw)) {
        setInvoices(raw)
      } else {
        setInvoices([])
      }
    } catch {
      toast.error('Gagal memuat data catatan khusus.')
      setInvoices([])
    } finally {
      setLoading(false)
    }
  }, [selectedDate])

  useEffect(() => {
    fetchInvoices()
  }, [fetchInvoices])

  // Filter ONLY invoices that have an EXPLICIT discrepancy / problem reported during verification
  const safeInvoices = Array.isArray(invoices) ? invoices : []
  
  const problematicInvoices = useMemo(() => {
    return safeInvoices.filter((item) => {
      // Date match check
      if (selectedDate) {
        const itemDate = new Date(item.created_at).toISOString().split('T')[0]
        if (itemDate !== selectedDate) return false
      }

      // Search match
      if (search) {
        const query = search.toLowerCase()
        const matchSearch =
          (item.invoice_no || '').toLowerCase().includes(query) ||
          (item.nama_apotek || '').toLowerCase().includes(query) ||
          (item.driver_name || '').toLowerCase().includes(query) ||
          (item.catatan || '').toLowerCase().includes(query)
        if (!matchSearch) return false
      }

      // Problem conditions: Status is MISSING/REJECTED or has custom discrepancy notes
      const isMissing = item.status === 'MISSING' || item.status === 'REJECTED'
      const hasReasonNotes = !!(item.reject_reason || item.reject_note || item.extra_items_note || item.pickup_note)
      const hasCustomCatatan = !!(
        item.catatan &&
        item.catatan !== 'Done' &&
        item.catatan !== 'Belum diperiksa' &&
        item.catatan !== 'Completed' &&
        item.catatan !== 'PENDING'
      )

      // EXCLUDE PENDING ("Belum Diperiksa") and clean DONE ("Diverifikasi Apoteker")
      return isMissing || hasReasonNotes || hasCustomCatatan
    })
  }, [safeInvoices, selectedDate, search])

  // Computed KPI stats
  const totalCases = problematicInvoices.length
  const totalApotekTerdampak = Array.from(new Set(problematicInvoices.map(i => i.nama_apotek))).length
  const totalDriverTerkait = Array.from(new Set(problematicInvoices.map(i => i.driver_name))).length

  const handlePrint = () => {
    window.print()
  }

  return (
    <DashboardShell>
      {/* ─── CSS PRINT STYLES ─── */}
      <style jsx global>{`
        @media print {
          body {
            background: white !important;
            color: black !important;
          }
          nav, sidebar, header, button, input, .no-print {
            display: none !important;
          }
          .print-container {
            width: 100% !important;
            margin: 0 !important;
            padding: 0 !important;
            box-shadow: none !important;
            border: none !important;
          }
          table {
            border: 1px solid #ccc !important;
          }
          th, td {
            border: 1px solid #ddd !important;
            padding: 6px !important;
          }
        }
      `}</style>

      <div className="space-y-6 max-w-7xl mx-auto print-container">
        
        {/* ─── PAGE HEADER ─── */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-card border border-border p-6 rounded-2xl shadow-xs">
          <div>
            <h1 className="font-black text-xl tracking-tight text-foreground flex items-center gap-2.5">
              <ShieldAlert className="h-6 w-6 text-amber-600 dark:text-amber-400" />
              Catatan Khusus Invoice & Barang Bermasalah
            </h1>
            <p className="text-xs text-muted-foreground mt-1">
              Rekapitulasi resmi berkas faktur, selisih barang, dan verifikasi khusus yang dilaporkan oleh driver/apoteker.
            </p>
          </div>

          <div className="flex items-center gap-3 no-print">
            <button
              onClick={fetchInvoices}
              disabled={loading}
              className="inline-flex items-center gap-1.5 text-xs font-bold text-muted-foreground hover:text-foreground bg-muted/40 hover:bg-muted px-3.5 py-2 rounded-xl transition-all border border-border"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
              Refresh Data
            </button>
            <button
              onClick={handlePrint}
              className="inline-flex items-center gap-2 text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 px-4 py-2 rounded-xl transition-all shadow-xs cursor-pointer"
            >
              <Printer className="h-4 w-4" />
              Cetak / Export PDF
            </button>
          </div>
        </div>

        {/* ─── FILTERS & DATE SELECTOR ─── */}
        <div className="bg-card border border-border p-4 rounded-2xl shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-4 no-print">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 bg-muted/40 border border-border px-3 py-1.5 rounded-xl">
              <Calendar className="h-4 w-4 text-blue-600 dark:text-blue-400" />
              <span className="text-xs font-bold text-foreground">Pilih Tanggal:</span>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="bg-transparent text-xs font-bold text-foreground focus:outline-none cursor-pointer"
              />
            </div>
            {selectedDate && (
              <span className="text-xs text-muted-foreground">
                Menampilkan laporan untuk tanggal <strong className="text-foreground font-mono">{selectedDate}</strong>
              </span>
            )}
          </div>

          <div className="relative w-full sm:w-64">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Cari invoice / apotek / driver..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full text-xs font-medium pl-9 pr-4 py-2 rounded-xl bg-background border border-border focus:outline-none focus:ring-2 focus:ring-blue-500/20"
            />
          </div>
        </div>

        {/* ─── KPI SUMMARY CARDS ─── */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          
          {/* Card 1: Total Case Bermasalah */}
          <div className="bg-amber-50/50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/50 p-5 rounded-2xl shadow-2xs">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-bold text-amber-800 dark:text-amber-300 uppercase tracking-wider">
                Total Case Bermasalah
              </span>
              <AlertTriangle className="h-5 w-5 text-amber-600 dark:text-amber-400" />
            </div>
            <div className="font-black text-3xl text-amber-700 dark:text-amber-300">
              {totalCases}
            </div>
            <p className="text-[11px] text-amber-700/80 dark:text-amber-400/80 mt-1">
              Invoice hilang, selisih barang, atau rusak
            </p>
          </div>

          {/* Card 2: Apotek Terdampak */}
          <div className="bg-blue-50/50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-900/50 p-5 rounded-2xl shadow-2xs">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-bold text-blue-800 dark:text-blue-300 uppercase tracking-wider">
                Apotek Terdampak
              </span>
              <FileText className="h-5 w-5 text-blue-600 dark:text-blue-400" />
            </div>
            <div className="font-black text-3xl text-blue-700 dark:text-blue-300">
              {totalApotekTerdampak}
            </div>
            <p className="text-[11px] text-blue-700/80 dark:text-blue-400/80 mt-1">
              Titik tujuan apotek yang terkendala
            </p>
          </div>

          {/* Card 3: Driver Terkait */}
          <div className="bg-purple-50/50 dark:bg-purple-950/20 border border-purple-200 dark:border-purple-900/50 p-5 rounded-2xl shadow-2xs">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-bold text-purple-800 dark:text-purple-300 uppercase tracking-wider">
                Driver Terkait
              </span>
              <Truck className="h-5 w-5 text-purple-600 dark:text-purple-400" />
            </div>
            <div className="font-black text-3xl text-purple-700 dark:text-purple-300">
              {totalDriverTerkait}
            </div>
            <p className="text-[11px] text-purple-700/80 dark:text-purple-400/80 mt-1">
              Kurir penanggung jawab pengiriman
            </p>
          </div>

        </div>

        {/* ─── TABLE REPORT SECTION ─── */}
        <div className="bg-card border border-border rounded-2xl p-5 shadow-xs overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-muted/40 text-[11px] font-bold uppercase tracking-wider text-muted-foreground border-b border-border">
                  <th className="py-3.5 px-4">NO. INVOICE / DISPATCH</th>
                  <th className="py-3.5 px-4">APOTEK PENERIMA</th>
                  <th className="py-3.5 px-4">DRIVER PENANGGUNG JAWAB</th>
                  <th className="py-3.5 px-4">KATEGORI MASALAH</th>
                  <th className="py-3.5 px-4">DETAIL CATATAN / KETERANGAN UNBOXING</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border font-medium">
                {loading ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-muted-foreground">
                      Memuat data catatan khusus...
                    </td>
                  </tr>
                ) : problematicInvoices.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-12 text-center text-muted-foreground">
                      <div className="flex flex-col items-center justify-center space-y-2">
                        <CheckCircle2 className="h-10 w-10 text-emerald-500/60 mb-1" />
                        <p className="font-bold text-sm text-foreground">
                          Tidak Ada Catatan Invoice Bermasalah Hari Ini 🎉
                        </p>
                        <p className="text-xs text-muted-foreground max-w-md text-center">
                          Seluruh faktur logistik saat ini dalam status pengiriman normal (Belum Diperiksa / Berjalan Lancar). Catatan khusus hanya akan terisi apabila driver atau apoteker melaporkan adanya selisih barang, barang rusak, atau kendala verifikasi.
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  problematicInvoices.map((item, idx) => (
                    <tr key={`${item.invoice_no}-${idx}`} className="hover:bg-muted/30 transition-colors">
                      
                      {/* NO INVOICE / DISPATCH */}
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-blue-600 dark:text-blue-400 font-mono">
                          #{item.invoice_no}
                        </div>
                        <div className="text-[10px] text-muted-foreground font-mono mt-0.5">
                          DSP: #{item.dispatch_id || '-'}
                        </div>
                      </td>

                      {/* APOTEK PENERIMA */}
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-foreground">{item.nama_apotek}</div>
                      </td>

                      {/* DRIVER */}
                      <td className="py-3.5 px-4">
                        <div className="font-bold text-foreground">{item.driver_name || '-'}</div>
                        {item.driver_phone && (
                          <div className="text-[10px] text-muted-foreground font-mono">{item.driver_phone}</div>
                        )}
                        {item.driver_plate && (
                          <span className="text-[9px] font-mono px-1.5 py-0.5 rounded bg-muted text-muted-foreground mt-0.5 inline-block">
                            {item.driver_plate} ({item.vehicle_type || 'MOTOR'})
                          </span>
                        )}
                      </td>

                      {/* KATEGORI MASALAH */}
                      <td className="py-3.5 px-4">
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-red-50 text-red-700 dark:bg-red-950/60 dark:text-red-300 border border-red-200 dark:border-red-900/50 text-[10px] font-bold">
                          <AlertTriangle className="h-3 w-3 text-red-600" />
                          {item.status === 'MISSING' ? 'Barang Hilang / Kurang' :
                           item.status === 'REJECTED' ? 'Ditolak Apoteker' :
                           'Kendala Verifikasi'}
                        </span>
                      </td>

                      {/* DETAIL CATATAN / KETERANGAN */}
                      <td className="py-3.5 px-4">
                        <div className="space-y-1">
                          <p className="text-foreground font-bold">
                            {item.catatan || 'Ada catatan verifikasi khusus'}
                          </p>
                          {item.reject_reason && (
                            <p className="text-[11px] text-red-600 dark:text-red-400">
                              <strong>Alasan Penolakan:</strong> {item.reject_reason} ({item.reject_note || '-'})
                            </p>
                          )}
                          {item.extra_items_note && (
                            <p className="text-[11px] text-amber-600 dark:text-amber-400">
                              <strong>Catatan Barang Lebih/Kurang:</strong> {item.extra_items_note}
                            </p>
                          )}
                          {item.unboxing_option && (
                            <span className="text-[9.5px] font-bold px-2 py-0.5 rounded bg-muted text-muted-foreground inline-block">
                              Verifikasi: {item.unboxing_option}
                            </span>
                          )}
                        </div>
                      </td>

                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </DashboardShell>
  )
}
