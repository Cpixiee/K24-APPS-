'use client'

import { useState, useEffect, useCallback } from 'react'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import {
  Search, Calendar, AlertTriangle, CheckCircle2, FileText,
  ChevronLeft, ChevronRight, X, ChevronDown, Clock, ShieldAlert,
  MapPin, User, Check, RefreshCw, ArrowUpDown, ArrowUp, ArrowDown
} from 'lucide-react'

interface FlatInvoiceRow {
  invoice_no: string
  nama_apotek: string
  driver_name: string
  status: string // "DONE", "MISSING", "PENDING"
  catatan: string // "Done" or custom reason note
  created_at: string
  dispatch_id: string
}

type SortField = 'invoice_no' | 'nama_apotek' | 'created_at'
type SortOrder = 'asc' | 'desc'

export default function DetailPengantaranPage() {
  const [invoices, setInvoices] = useState<FlatInvoiceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('ALL')

  // Sorting State (Defaults to invoice_no ascending)
  const [sortField, setSortField] = useState<SortField>('invoice_no')
  const [sortOrder, setSortOrder] = useState<SortOrder>('asc')

  // Date Picker State (Defaults to empty string to fetch all invoices across all dates)
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

  // Filtered invoices list with array safety check
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
      return item.status === 'MISSING' || item.status === 'PENDING'
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
  const missingCount = safeInvoices.filter((i) => i.status === 'MISSING').length
  const pendingCount = safeInvoices.filter((i) => i.status === 'PENDING').length

  // Format date display for header
  const dateFormatted = selectedDate
    ? new Date(selectedDate).toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })
    : 'Semua Tanggal'

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
          <div className="h-12 w-12 rounded-2xl bg-red-100 dark:bg-red-900/40 flex items-center justify-center shrink-0">
            <AlertTriangle className="h-6 w-6 text-red-600 dark:text-red-400 animate-pulse" />
          </div>
        </div>

        {/* Card 2: Total Alamat / Order */}
        <div className="bg-card border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between hover:shadow-md transition-shadow">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <div className="h-8 w-8 rounded-xl bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 flex items-center justify-center">
                <MapPin className="h-4 w-4" />
              </div>
              <span className="text-xs font-semibold text-muted-foreground">Total Alamat / Order</span>
            </div>
            <h3 className="text-3xl font-black text-foreground mt-2">
              {loading ? '...' : totalAddressCount.toLocaleString('id-ID')}
            </h3>
            <p className="text-[11px] text-muted-foreground mt-1">Titik lokasi apotek penerima</p>
          </div>
        </div>

        {/* Card 3: Total Invoice */}
        <div className="bg-card border border-border rounded-2xl p-5 shadow-xs flex items-center justify-between hover:shadow-md transition-shadow">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <div className="h-8 w-8 rounded-xl bg-purple-50 dark:bg-purple-950/40 text-purple-600 dark:text-purple-400 flex items-center justify-center">
                <FileText className="h-4 w-4" />
              </div>
              <span className="text-xs font-semibold text-muted-foreground">Total Invoice</span>
            </div>
            <h3 className="text-3xl font-black text-foreground mt-2">
              {loading ? '...' : totalInvoicesCount.toLocaleString('id-ID')}
            </h3>
            <p className="text-[11px] text-muted-foreground mt-1">Total lembar invoice terdaftar</p>
          </div>
        </div>
      </div>

      {/* ─── Real-Time Monitoring Table Card ─── */}
      <div className="bg-card border border-border rounded-2xl p-6 shadow-xs">
        {/* Table Controls Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
          <div>
            <h3 className="font-bold text-lg text-foreground flex items-center gap-2">
              Monitoring Real-Time
            </h3>
            <p className="text-xs text-muted-foreground mt-0.5">
              Daftar rincian logistik pengantaran dan status invoice per item.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            {/* Search Input */}
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
                className="w-full bg-background border border-border rounded-xl pl-9 pr-4 py-2 text-xs text-foreground placeholder:text-muted-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500"
              />
            </div>

            {/* Sort Dropdown */}
            <select
              value={`${sortField}-${sortOrder}`}
              onChange={(e) => {
                const [field, order] = e.target.value.split('-') as [SortField, SortOrder]
                setSortField(field)
                setSortOrder(order)
              }}
              className="bg-background border border-border rounded-xl px-3.5 py-2 text-xs font-semibold text-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500"
            >
              <option value="invoice_no-asc">Urutkan: Invoice (Ascending)</option>
              <option value="invoice_no-desc">Urutkan: Invoice (Descending)</option>
              <option value="nama_apotek-asc">Urutkan: Apotek (A - Z)</option>
              <option value="nama_apotek-desc">Urutkan: Apotek (Z - A)</option>
            </select>

            {/* Status Filter Dropdown */}
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value)
                setCurrentPage(1)
              }}
              className="bg-background border border-border rounded-xl px-3.5 py-2 text-xs font-semibold text-foreground focus:outline-hidden focus:ring-2 focus:ring-blue-500"
            >
              <option value="ALL">Semua Status</option>
              <option value="AMAN">🟢 Aman (Done)</option>
              <option value="BERMASALAH">🔴 Bermasalah / Error</option>
            </select>

            <button
              onClick={fetchInvoices}
              className="p-2 border border-border rounded-xl hover:bg-muted text-muted-foreground hover:text-foreground transition-colors"
              title="Refresh Data"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        {/* Table Content */}
        <div className="overflow-x-auto rounded-xl border border-border">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-muted/40 text-[11px] font-bold uppercase tracking-wider text-muted-foreground border-b border-border">
                {/* Clickable INVOICE Sort Header */}
                <th
                  onClick={() => handleSort('invoice_no')}
                  className="py-3.5 px-4 cursor-pointer hover:bg-muted/60 transition-colors select-none group"
                  title="Klik untuk mengurutkan berdasarkan nomor invoice"
                >
                  <div className="flex items-center gap-1.5">
                    <span className={sortField === 'invoice_no' ? 'text-blue-600 dark:text-blue-400 font-extrabold' : ''}>INVOICE</span>
                    {sortField === 'invoice_no' ? (
                      sortOrder === 'asc' ? (
                        <ArrowUp className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />
                      ) : (
                        <ArrowDown className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />
                      )
                    ) : (
                      <ArrowUpDown className="h-3.5 w-3.5 text-muted-foreground/50 group-hover:text-muted-foreground" />
                    )}
                  </div>
                </th>

                {/* Clickable APOTEK Sort Header */}
                <th
                  onClick={() => handleSort('nama_apotek')}
                  className="py-3.5 px-4 cursor-pointer hover:bg-muted/60 transition-colors select-none group"
                  title="Klik untuk mengurutkan berdasarkan nama apotek"
                >
                  <div className="flex items-center gap-1.5">
                    <span className={sortField === 'nama_apotek' ? 'text-blue-600 dark:text-blue-400 font-extrabold' : ''}>APOTEK</span>
                    {sortField === 'nama_apotek' ? (
                      sortOrder === 'asc' ? (
                        <ArrowUp className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />
                      ) : (
                        <ArrowDown className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />
                      )
                    ) : (
                      <ArrowUpDown className="h-3.5 w-3.5 text-muted-foreground/50 group-hover:text-muted-foreground" />
                    )}
                  </div>
                </th>

                <th className="py-3.5 px-4">DRIVER</th>
                <th className="py-3.5 px-4">JAM PICKUP</th>
                <th className="py-3.5 px-4">JAM SELESAI</th>
                <th className="py-3.5 px-4">STATUS</th>
                <th className="py-3.5 px-4 text-right">CATATAN INVOICE</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border text-xs font-medium">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-muted-foreground">
                    <div className="flex flex-col items-center gap-2">
                      <RefreshCw className="h-6 w-6 animate-spin text-blue-600" />
                      <span>Memuat data invoice...</span>
                    </div>
                  </td>
                </tr>
              ) : paginatedInvoices.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-muted-foreground">
                    Tidak ada data invoice yang sesuai.
                  </td>
                </tr>
              ) : (
                paginatedInvoices.map((row, idx) => {
                  const isAman = row.status === 'DONE'
                  const isMissing = row.status === 'MISSING'

                  return (
                    <tr key={`${row.invoice_no}-${idx}`} className="hover:bg-muted/30 transition-colors">
                      {/* INVOICE */}
                      <td className="py-4 px-4 font-bold text-blue-600 dark:text-blue-400">
                        #{row.invoice_no}
                      </td>

                      {/* APOTEK */}
                      <td className="py-4 px-4">
                        <div className="font-bold text-foreground">{row.nama_apotek}</div>
                        <span className="text-[10px] text-muted-foreground">{row.dispatch_id || '-'}</span>
                      </td>

                      {/* DRIVER */}
                      <td className="py-4 px-4">
                        <div className="flex items-center gap-2">
                          <div className="h-7 w-7 rounded-full bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-300 flex items-center justify-center text-[10px] font-bold">
                            {row.driver_name ? row.driver_name.slice(0, 2).toUpperCase() : 'DR'}
                          </div>
                          <span className="font-semibold text-foreground">{row.driver_name || 'Belum di-assign'}</span>
                        </div>
                      </td>

                      {/* JAM PICKUP */}
                      <td className="py-4 px-4 text-muted-foreground">
                        <div className="font-semibold text-foreground">
                          {new Date(row.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                        </div>
                        <span className="text-[10px]">
                          {new Date(row.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}
                        </span>
                      </td>

                      {/* JAM SELESAI */}
                      <td className="py-4 px-4 text-muted-foreground">
                        {isAman ? (
                          <div>
                            <div className="font-semibold text-emerald-600 dark:text-emerald-400">Selesai</div>
                            <span className="text-[10px]">Verifikasi Apoteker</span>
                          </div>
                        ) : isMissing ? (
                          <div>
                            <div className="font-semibold text-red-600 dark:text-red-400">Bermasalah</div>
                            <span className="text-[10px]">Invoice Retur / Hilang</span>
                          </div>
                        ) : (
                          <span className="text-muted-foreground italic">Proses Delivery</span>
                        )}
                      </td>

                      {/* STATUS */}
                      <td className="py-4 px-4">
                        {isAman ? (
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-900/50 text-[11px] font-bold">
                            <CheckCircle2 className="h-3.5 w-3.5" />
                            Aman
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-red-50 text-red-700 dark:bg-red-950/40 dark:text-red-400 border border-red-200 dark:border-red-900/50 text-[11px] font-bold">
                            <AlertTriangle className="h-3.5 w-3.5" />
                            Bermasalah
                          </span>
                        )}
                      </td>

                      {/* CATATAN INVOICE */}
                      <td className="py-4 px-4 text-right">
                        {isAman ? (
                          <span className="inline-block px-2.5 py-1 rounded-lg bg-emerald-100/70 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 text-xs font-semibold">
                            {row.catatan || 'Done'}
                          </span>
                        ) : (
                          <span className="inline-block px-2.5 py-1 rounded-lg bg-red-100/80 text-red-900 dark:bg-red-950/80 dark:text-red-200 text-xs font-semibold max-w-[200px] truncate" title={row.catatan}>
                            {row.catatan || 'Ada barang hilang / beda'}
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

        {/* Table Pagination Footer */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mt-6 text-xs text-muted-foreground">
          <div>
            Menampilkan <span className="font-bold text-foreground">{paginatedInvoices.length > 0 ? (currentPage - 1) * itemsPerPage + 1 : 0}</span>-
            <span className="font-bold text-foreground">{Math.min(currentPage * itemsPerPage, totalItems)}</span> dari{' '}
            <span className="font-bold text-foreground">{totalItems}</span> invoice
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
              disabled={currentPage === 1}
              className="p-2 border border-border rounded-xl disabled:opacity-40 hover:bg-muted transition-colors cursor-pointer"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>

            {Array.from({ length: totalPages }, (_, i) => i + 1)
              .slice(Math.max(0, currentPage - 3), Math.min(totalPages, currentPage + 2))
              .map((page) => (
                <button
                  key={page}
                  onClick={() => setCurrentPage(page)}
                  className={`h-8 w-8 rounded-xl font-bold transition-all cursor-pointer ${
                    currentPage === page
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'hover:bg-muted text-foreground'
                  }`}
                >
                  {page}
                </button>
              ))}

            <button
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
              disabled={currentPage === totalPages}
              className="p-2 border border-border rounded-xl disabled:opacity-40 hover:bg-muted transition-colors cursor-pointer"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </DashboardShell>
  )
}
