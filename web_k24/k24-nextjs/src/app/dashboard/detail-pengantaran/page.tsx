'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import {
  Search, Calendar, AlertTriangle, CheckCircle2, FileText,
  ChevronLeft, ChevronRight, X, ChevronDown, Clock, ShieldAlert,
  MapPin, User, Check, RefreshCw, ArrowUpDown, ArrowUp, ArrowDown,
  Printer, ClipboardList, Phone, Truck
} from 'lucide-react'

interface FlatInvoiceRow {
  invoice_no: string
  nama_apotek: string
  driver_name: string
  driver_phone?: string
  driver_plate?: string
  vehicle_type?: string
  status: string // "DONE", "MISSING", "PENDING", "REJECTED"
  catatan: string // "Done" or custom reason note
  created_at: string
  dispatch_id: string
  reject_reason?: string
  reject_note?: string
  extra_items_note?: string
  unboxing_option?: string
  pickup_note?: string
}

type SortField = 'invoice_no' | 'nama_apotek' | 'created_at'
type SortOrder = 'asc' | 'desc'

export default function DetailPengantaranPage() {
  const router = useRouter()
  const [invoices, setInvoices] = useState<FlatInvoiceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('ALL')

  // Sorting State
  const [sortField, setSortField] = useState<SortField>('invoice_no')
  const [sortOrder, setSortOrder] = useState<SortOrder>('asc')

  // Date Picker State
  const [selectedDate, setSelectedDate] = useState<string>('')
  const [showDatePickerModal, setShowDatePickerModal] = useState(false)

  // Pagination State
  const [currentPage, setCurrentPage] = useState(1)
  const itemsPerPage = 10

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')
    } else {
      setSortField(field)
      setSortOrder('asc')
    }
  }

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
      toast.error('Gagal memuat data detail pengantaran.')
      setInvoices([])
    } finally {
      setLoading(false)
    }
  }, [selectedDate])

  useEffect(() => {
    fetchInvoices()
  }, [fetchInvoices])

  // Filtered invoices list
  const safeInvoices = Array.isArray(invoices) ? invoices : []
  const filteredInvoices = safeInvoices.filter((item) => {
    const matchesSearch =
      (item.invoice_no || '').toLowerCase().includes(search.toLowerCase()) ||
      (item.nama_apotek || '').toLowerCase().includes(search.toLowerCase()) ||
      (item.driver_name || '').toLowerCase().includes(search.toLowerCase()) ||
      (item.catatan || '').toLowerCase().includes(search.toLowerCase())

    if (!matchesSearch) return false

    if (statusFilter === 'AMAN') {
      return item.status === 'DONE'
    } else if (statusFilter === 'BERMASALAH') {
      return item.status === 'MISSING' || item.status === 'PENDING' || item.status === 'REJECTED'
    }
    return true
  })

  // Sorted invoices list
  const sortedInvoices = [...filteredInvoices].sort((a, b) => {
    const valA = (a[sortField] || '').toString().trim()
    const valB = (b[sortField] || '').toString().trim()

    if (sortField === 'invoice_no') {
      const numA = parseInt(valA.replace(/\D/g, ''), 10)
      const numB = parseInt(valB.replace(/\D/g, ''), 10)
      if (!isNaN(numA) && !isNaN(numB)) {
        return sortOrder === 'asc' ? numA - numB : numB - numA
      }
    }

    return sortOrder === 'asc'
      ? valA.localeCompare(valB, 'id', { sensitivity: 'base' })
      : valB.localeCompare(valA, 'id', { sensitivity: 'base' })
  })

  // Pagination calculation
  const totalItems = sortedInvoices.length
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1
  const paginatedInvoices = sortedInvoices.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  )

  // Computed KPI Counts
  const totalInvoicesCount = safeInvoices.length
  const totalAddressCount = Array.from(new Set(safeInvoices.map((i) => i.nama_apotek))).length
  const missingCount = safeInvoices.filter((i) => i.status === 'MISSING' || i.status === 'REJECTED').length
  const pendingCount = safeInvoices.filter((i) => i.status === 'PENDING').length

  // Format date display for header
  const dateFormatted = selectedDate
    ? new Date(selectedDate).toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })
    : 'Hari Ini'

  return (
    <DashboardShell onRefresh={fetchInvoices}>
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Detail Pengantaran</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Ringkasan operasional tanggal <span className="font-semibold text-foreground">{dateFormatted}</span>
          </p>
        </div>

        {/* Action Buttons Group (Date Selector + Dedicated Page Button) */}
        <div className="flex flex-wrap items-center gap-3">
          
          {/* 📋 Button Buka Halaman Catatan Khusus */}
          <button
            onClick={() => router.push('/dashboard/catatan-khusus')}
            className="flex items-center gap-2 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-600 hover:to-amber-700 text-white px-4 py-2.5 rounded-xl shadow-sm text-xs font-bold transition-all cursor-pointer"
          >
            <ShieldAlert className="h-4 w-4" />
            <span>Buka Halaman Catatan Khusus</span>
            {missingCount > 0 && (
              <span className="ml-1 px-1.5 py-0.5 bg-white text-amber-700 rounded-full text-[10px] font-black animate-pulse">
                {missingCount}
              </span>
            )}
          </button>

          {/* 📅 Interactive Date Selector */}
          <div className="relative">
            <button
              onClick={() => setShowDatePickerModal(true)}
              className="flex items-center gap-2 bg-card hover:bg-muted/50 border border-border px-4 py-2.5 rounded-xl shadow-xs text-xs font-semibold text-foreground transition-all cursor-pointer"
            >
              <Calendar className="h-4 w-4 text-blue-600 dark:text-blue-400" />
              <span>{dateFormatted}</span>
              <ChevronDown className="h-4 w-4 text-muted-foreground ml-1" />
            </button>

            {/* Date Picker Modal */}
            {showDatePickerModal && (
              <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4">
                <div className="bg-card border border-border rounded-2xl p-6 w-full max-w-sm shadow-xl animate-in fade-in zoom-in duration-200">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-base font-bold text-foreground flex items-center gap-2">
                      <Calendar className="h-5 w-5 text-blue-600" />
                      Pilih Tanggal Pengantaran
                    </h3>
                    <button
                      onClick={() => setShowDatePickerModal(false)}
                      className="p-1 rounded-lg text-muted-foreground hover:bg-muted"
                    >
                      <X className="h-5 w-5" />
                    </button>
                  </div>

                  <div className="space-y-4">
                    <div>
                      <label className="text-xs font-semibold text-muted-foreground mb-1.5 block">
                        Tanggal Operasional
                      </label>
                      <input
                        type="date"
                        value={selectedDate}
                        onChange={(e) => {
                          setSelectedDate(e.target.value)
                          setCurrentPage(1)
                        }}
                        className="w-full bg-background border border-border rounded-xl px-3.5 py-2.5 text-sm text-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500"
                      />
                    </div>

                    <div className="flex justify-between items-center pt-2">
                      <button
                        onClick={() => {
                          setSelectedDate('')
                          setCurrentPage(1)
                          setShowDatePickerModal(false)
                        }}
                        className="px-3 py-2 text-xs font-semibold text-blue-600 hover:text-blue-700 dark:text-blue-400"
                      >
                        Semua Tanggal
                      </button>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => {
                            setSelectedDate(new Date().toISOString().split('T')[0])
                            setCurrentPage(1)
                          }}
                          className="px-3 py-2 text-xs font-semibold text-muted-foreground hover:text-foreground"
                        >
                          Hari Ini
                        </button>
                        <button
                          onClick={() => setShowDatePickerModal(false)}
                          className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-xs font-semibold shadow-xs"
                        >
                          Terapkan
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ─── Top Cards Section (3 Cards) ─── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5 mb-8">
        {/* Card 1: Critical Alert Card */}
        <div className="bg-red-50/60 dark:bg-red-950/20 border border-red-200 dark:border-red-900/50 rounded-2xl p-5 shadow-xs flex items-center justify-between">
          <div>
            <span className="text-[10px] font-extrabold uppercase tracking-wider text-red-600 dark:text-red-400 block mb-1">
              PERHATIAN KRITIS
            </span>
            <h4 className="text-base font-bold text-red-950 dark:text-red-200">
              Status Operasional Bermasalah
            </h4>
            <div className="flex items-center gap-6 mt-3">
              <div>
                <span className="text-2xl font-black text-red-600 dark:text-red-400">
                  {missingCount.toString().padStart(2, '0')}
                </span>
                <p className="text-[11px] text-red-700 dark:text-red-300 font-medium">Invoice Error / Hilang</p>
              </div>
              <div className="h-8 w-px bg-red-200 dark:bg-red-900/60" />
              <div>
                <span className="text-2xl font-black text-red-600 dark:text-red-400">
                  {pendingCount.toString().padStart(2, '0')}
                </span>
                <p className="text-[11px] text-red-700 dark:text-red-300 font-medium">Belum Verifikasi</p>
              </div>
            </div>
          </div>

          <div className="h-12 w-12 rounded-2xl bg-red-100 dark:bg-red-900/40 flex items-center justify-center text-red-600 dark:text-red-400 shrink-0">
            <AlertTriangle className="h-6 w-6" />
          </div>
        </div>

        {/* Card 2: Total Addresses */}
        <div className="bg-card border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <MapPin className="h-4 w-4 text-blue-500" />
              <span className="text-xs font-semibold text-muted-foreground">Total Alamat / Order</span>
            </div>
            <span className="text-3xl font-black text-foreground">{totalAddressCount}</span>
            <p className="text-[11px] text-muted-foreground mt-1 font-medium">Titik lokasi apotek penerima</p>
          </div>
        </div>

        {/* Card 3: Total Invoices */}
        <div className="bg-card border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <FileText className="h-4 w-4 text-purple-500" />
              <span className="text-xs font-semibold text-muted-foreground">Total Invoice</span>
            </div>
            <span className="text-3xl font-black text-foreground">{totalInvoicesCount}</span>
            <p className="text-[11px] text-muted-foreground mt-1 font-medium">Total lembar invoice terdaftar</p>
          </div>
        </div>
      </div>

      {/* ─── Real-Time Monitoring Table Section ─── */}
      <div className="bg-card border border-border rounded-2xl shadow-xs overflow-hidden">
        {/* Table Controls (Search, Sort, Filters) */}
        <div className="p-5 border-b border-border flex flex-col md:flex-row md:items-center justify-between gap-4 bg-muted/10">
          <div>
            <h3 className="text-base font-bold text-foreground">Monitoring Real-Time</h3>
            <p className="text-xs text-muted-foreground mt-0.5">
              Daftar rincian logistik pengantaran dan status invoice per item.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {/* Search input */}
            <div className="relative min-w-[240px]">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <input
                type="text"
                placeholder="Cari Invoice, Apotek, atau Driver..."
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value)
                  setCurrentPage(1)
                }}
                className="w-full bg-background border border-border rounded-xl pl-9 pr-4 py-2 text-xs text-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500"
              />
            </div>

            {/* Sort Selector Dropdown */}
            <div className="relative">
              <select
                value={`${sortField}-${sortOrder}`}
                onChange={(e) => {
                  const [field, order] = e.target.value.split('-') as [SortField, SortOrder]
                  setSortField(field)
                  setSortOrder(order)
                }}
                className="bg-background border border-border rounded-xl px-3 py-2 text-xs font-semibold text-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500 appearance-none pr-8 cursor-pointer"
              >
                <option value="invoice_no-asc">Urutkan: Invoice (Ascending)</option>
                <option value="invoice_no-desc">Urutkan: Invoice (Descending)</option>
                <option value="nama_apotek-asc">Urutkan: Apotek (A - Z)</option>
                <option value="nama_apotek-desc">Urutkan: Apotek (Z - A)</option>
                <option value="created_at-desc">Urutkan: Terbaru</option>
                <option value="created_at-asc">Urutkan: Terlama</option>
              </select>
              <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
            </div>

            {/* Status Filter */}
            <div className="relative">
              <select
                value={statusFilter}
                onChange={(e) => {
                  setStatusFilter(e.target.value)
                  setCurrentPage(1)
                }}
                className="bg-background border border-border rounded-xl px-3 py-2 text-xs font-semibold text-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500 appearance-none pr-8 cursor-pointer"
              >
                <option value="ALL">Semua Status</option>
                <option value="AMAN">Aman (Verified)</option>
                <option value="BERMASALAH">Bermasalah (Missing/Pending)</option>
              </select>
              <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
            </div>

            <button
              onClick={fetchInvoices}
              className="p-2 border border-border bg-background hover:bg-muted rounded-xl text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
              title="Refresh Data"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        {/* Table Content */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-muted-foreground uppercase font-bold tracking-wider">
                <th
                  onClick={() => handleSort('invoice_no')}
                  className="px-5 py-3.5 cursor-pointer hover:text-foreground transition-colors"
                >
                  <div className="flex items-center gap-1.5">
                    <span>INVOICE</span>
                    {sortField === 'invoice_no' ? (
                      sortOrder === 'asc' ? <ArrowUp className="h-3 w-3 text-blue-600" /> : <ArrowDown className="h-3 w-3 text-blue-600" />
                    ) : (
                      <ArrowUpDown className="h-3 w-3 text-muted-foreground/50" />
                    )}
                  </div>
                </th>

                <th
                  onClick={() => handleSort('nama_apotek')}
                  className="px-5 py-3.5 cursor-pointer hover:text-foreground transition-colors"
                >
                  <div className="flex items-center gap-1.5">
                    <span>APOTEK</span>
                    {sortField === 'nama_apotek' ? (
                      sortOrder === 'asc' ? <ArrowUp className="h-3 w-3 text-blue-600" /> : <ArrowDown className="h-3 w-3 text-blue-600" />
                    ) : (
                      <ArrowUpDown className="h-3 w-3 text-muted-foreground/50" />
                    )}
                  </div>
                </th>

                <th className="px-5 py-3.5">DRIVER</th>
                <th className="px-5 py-3.5">JAM PICKUP</th>
                <th className="px-5 py-3.5">JAM SELESAI</th>
                <th className="px-5 py-3.5">STATUS</th>
                <th className="px-5 py-3.5">CATATAN INVOICE</th>
              </tr>
            </thead>

            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-muted-foreground">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <RefreshCw className="h-6 w-6 animate-spin text-blue-600" />
                      <p className="font-semibold text-xs">Memuat detail pengantaran...</p>
                    </div>
                  </td>
                </tr>
              ) : paginatedInvoices.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-muted-foreground">
                    <div className="flex flex-col items-center justify-center gap-2">
                      <FileText className="h-8 w-8 text-muted-foreground/40" />
                      <p className="font-semibold text-xs">Tidak ada data invoice pengantaran ditemukan.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedInvoices.map((row, idx) => {
                  const isDone = row.status === 'DONE'
                  const isMissing = row.status === 'MISSING'

                  return (
                    <tr key={idx} className="hover:bg-muted/20 transition-colors">
                      {/* Invoice No */}
                      <td className="px-5 py-4 font-mono font-bold text-blue-600 dark:text-blue-400">
                        #{row.invoice_no}
                      </td>

                      {/* Apotek */}
                      <td className="px-5 py-4">
                        <p className="font-semibold text-foreground text-xs">{row.nama_apotek}</p>
                        <span className="text-[10px] text-muted-foreground block mt-0.5">Tujuan Pengiriman</span>
                      </td>

                      {/* Driver */}
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-2">
                          <div className="h-7 w-7 rounded-full bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300 flex items-center justify-center font-bold text-[10px] shrink-0">
                            {row.driver_name ? row.driver_name.slice(0, 2).toUpperCase() : 'DR'}
                          </div>
                          <div>
                            <p className="font-semibold text-foreground text-xs">{row.driver_name || 'Belum di-assign'}</p>
                            {row.driver_phone && <p className="text-[10px] text-muted-foreground">{row.driver_phone}</p>}
                          </div>
                        </div>
                      </td>

                      {/* Jam Pickup */}
                      <td className="px-5 py-4 text-muted-foreground">
                        <span className="font-medium text-foreground block">
                          {new Date(row.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                        </span>
                        <span className="text-[10px] text-muted-foreground">
                          {new Date(row.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}
                        </span>
                      </td>

                      {/* Jam Selesai */}
                      <td className="px-5 py-4 text-muted-foreground">
                        {isDone ? (
                          <div className="font-semibold text-emerald-600 dark:text-emerald-400">
                            <span>Selesai</span>
                            <span className="block text-[10px] text-muted-foreground font-normal">Kembali ke K-24</span>
                          </div>
                        ) : row.status === 'DONE' || row.catatan === 'Done' ? (
                          <div className="font-semibold text-teal-600 dark:text-teal-400">
                            <span>Diverifikasi Apoteker</span>
                            <span className="block text-[10px] text-muted-foreground font-normal">Proses Pengembalian Kurir</span>
                          </div>
                        ) : isMissing ? (
                          <div className="font-semibold text-red-600 dark:text-red-400">
                            <span>Bermasalah</span>
                            <span className="block text-[10px] text-muted-foreground font-normal">Invoice Retur / Hilang</span>
                          </div>
                        ) : (
                          <span className="text-xs italic text-muted-foreground">Proses Delivery</span>
                        )}
                      </td>

                      {/* Status Badge */}
                      <td className="px-5 py-4">
                        {isDone ? (
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-100 border border-emerald-300 dark:bg-emerald-950/50 dark:border-emerald-800 px-2.5 py-1 text-[11px] font-bold text-emerald-800 dark:text-emerald-300">
                            <CheckCircle2 className="h-3.5 w-3.5 text-emerald-600" /> Done (Selesai)
                          </span>
                        ) : row.status === 'DONE' || row.catatan === 'Done' ? (
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-teal-50 border border-teal-200 dark:bg-teal-950/40 dark:border-teal-900/50 px-2.5 py-1 text-[11px] font-bold text-teal-700 dark:text-teal-400">
                            <CheckCircle2 className="h-3.5 w-3.5 text-teal-600" /> Diverifikasi Apoteker
                          </span>
                        ) : isMissing ? (
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-red-50 border border-red-200 dark:bg-red-950/30 dark:border-red-900/40 px-2.5 py-1 text-[11px] font-bold text-red-700 dark:text-red-400">
                            <ShieldAlert className="h-3.5 w-3.5 text-red-600" /> Bermasalah
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-50 border border-amber-200 dark:bg-amber-950/30 dark:border-amber-900/40 px-2.5 py-1 text-[11px] font-bold text-amber-700 dark:text-amber-400">
                            <Clock className="h-3.5 w-3.5 text-amber-600" /> Belum Diperiksa
                          </span>
                        )}
                      </td>

                      {/* Catatan Invoice */}
                      <td className="px-5 py-4">
                        {isDone || row.status === 'DONE' || row.catatan === 'Done' ? (
                          <span className="inline-block text-[11px] font-bold px-2 py-0.5 rounded-md text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/30">
                            {row.catatan || 'Done'}
                          </span>
                        ) : isMissing ? (
                          <span className="inline-block text-[11px] font-bold px-2 py-0.5 rounded-md text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-950/30">
                            {row.catatan || 'Retur / Hilang'}
                          </span>
                        ) : (
                          <span className="inline-block text-[11px] font-semibold px-2 py-0.5 rounded-md text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-950/30">
                            {row.catatan || 'Belum diperiksa'}
                          </span>
                        )}
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="p-4 border-t border-border flex flex-col sm:flex-row items-center justify-between gap-3 bg-muted/10">
          <p className="text-xs text-muted-foreground">
            Menampilkan <span className="font-semibold text-foreground">{paginatedInvoices.length}</span> dari{' '}
            <span className="font-semibold text-foreground">{totalItems}</span> invoice
          </p>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage((prev) => Math.max(prev - 1, 1))}
              disabled={currentPage === 1}
              className="p-1.5 rounded-lg border border-border bg-background text-foreground hover:bg-muted disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>

            <span className="text-xs font-semibold text-foreground px-2">
              Halaman {currentPage} dari {totalPages}
            </span>

            <button
              onClick={() => setCurrentPage((prev) => Math.min(prev + 1, totalPages))}
              disabled={currentPage === totalPages}
              className="p-1.5 rounded-lg border border-border bg-background text-foreground hover:bg-muted disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </DashboardShell>
  )
}
