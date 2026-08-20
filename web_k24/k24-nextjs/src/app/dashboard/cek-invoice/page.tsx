'use client'

import { useState, useEffect, useMemo } from 'react'
import { useAuth } from '@/context/AuthContext'
import { apiClient } from '@/lib/api'
import DashboardShell from '@/components/layout/DashboardShell'
import {
  Search, FileText, CheckCircle2, Clock, Truck, MapPin, X,
  ExternalLink, Building2, User, Phone, Calendar, Eye, ZoomIn,
  ShieldCheck, AlertCircle, AlertTriangle, ChevronRight, Filter, RefreshCw
} from 'lucide-react'

interface InvoiceItem {
  parent_order_number: string
  order_number: string
  medicine_summary: string
  checked_invoices: string
  delivery_address: string
  driver_name: string
  driver_phone: string
  driver_plate: string
  vehicle_type: string
  created_at: string
  status: string
  dispatch_id: string
  customer_name: string
  pharmacy_name?: string
  reject_reason: string
  reject_note: string
  extra_items_note: string
  unboxing_option: string
  pickup_note: string
  arrived_photo_url?: string
  facture_photo_url?: string
  signature_photo_url?: string
  pod_signature_photo_url?: string
  handover_photo_url?: string
  arrived_note?: string
}

export default function CekInvoicePage() {
  const { user } = useAuth()
  const [loading, setLoading] = useState(true)
  const [invoices, setInvoices] = useState<InvoiceItem[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedStatus, setSelectedStatus] = useState<string>('ALL')
  const [selectedInvoice, setSelectedInvoice] = useState<InvoiceItem | null>(null)
  const [lightboxImage, setLightboxImage] = useState<string | null>(null)

  const fetchInvoices = async () => {
    setLoading(true)
    try {
      const res = await apiClient.get('/admin/orders/invoices-flat')
      if (res.data && res.data.data && Array.isArray(res.data.data)) {
        setInvoices(res.data.data)
      }
    } catch (e) {
      console.error('Failed fetching flat invoices:', e)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchInvoices()
  }, [])

  // Safely format all types of photo URLs (Data URI, raw Base64 starting with /9j/ or iVBOR, or HTTP/uploads path)
  const formatFullPhotoUrl = (url?: string): string => {
    if (!url) return ''
    const str = url.trim()
    if (!str) return ''

    if (str.startsWith('data:image/') || str.startsWith('data:')) {
      return str
    }
    if (str.startsWith('/9j/') || str.startsWith('iVBORw0KGgo') || str.startsWith('PHN2Zw') || (str.length > 200 && !str.startsWith('http') && !str.startsWith('/uploads'))) {
      return `data:image/jpeg;base64,${str}`
    }
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str
    }
    if (str.startsWith('/uploads/')) {
      return `/api${str}`
    }
    if (str.startsWith('uploads/')) {
      return `/api/${str}`
    }
    if (str.startsWith('/api/')) {
      return str
    }
    return `/api/uploads/${str.replace(/^\//, '')}`
  }

  // Filter invoices by search query & status
  const filteredInvoices = useMemo(() => {
    return invoices.filter((item) => {
      // Status filter
      if (selectedStatus === 'VERIFIED') {
        const isVerified = item.status === 'READY_FOR_PICKUP_FACTURE' || item.status === 'COMPLETED' || item.unboxing_option === 'UNBOXING'
        if (!isVerified) return false
      } else if (selectedStatus === 'WAITING') {
        const isWaiting = item.unboxing_option === 'WAITING_FOR_UNBOXING' || item.status === 'PENDING'
        if (!isWaiting) return false
      } else if (selectedStatus === 'DELIVERING') {
        const isDelivering = item.status === 'DELIVERING' || item.status === 'PICKING_UP' || item.status === 'ASSIGNED'
        if (!isDelivering) return false
      }

      // Search query filter
      if (!searchQuery.trim()) return true
      const q = searchQuery.toLowerCase().trim()
      return (
        item.order_number.toLowerCase().includes(q) ||
        item.parent_order_number.toLowerCase().includes(q) ||
        item.dispatch_id.toLowerCase().includes(q) ||
        item.customer_name.toLowerCase().includes(q) ||
        (item.pharmacy_name && item.pharmacy_name.toLowerCase().includes(q)) ||
        item.delivery_address.toLowerCase().includes(q) ||
        item.driver_name.toLowerCase().includes(q) ||
        item.checked_invoices.toLowerCase().includes(q) ||
        item.medicine_summary.toLowerCase().includes(q)
      )
    })
  }, [invoices, searchQuery, selectedStatus])

  // Stats calculation
  const stats = useMemo(() => {
    let total = invoices.length
    let verified = 0
    let delayed = 0
    let delivering = 0

    invoices.forEach((o) => {
      if (o.status === 'READY_FOR_PICKUP_FACTURE' || o.status === 'COMPLETED' || o.unboxing_option === 'UNBOXING') {
        verified++
      } else if (o.unboxing_option === 'WAITING_FOR_UNBOXING') {
        delayed++
      } else {
        delivering++
      }
    })

    return { total, verified, delayed, delivering }
  }, [invoices])

  const getStatusBadge = (item: InvoiceItem) => {
    if (item.status === 'COMPLETED') {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-300">
          <CheckCircle2 className="w-3.5 h-3.5" /> SELESAI (POD COMPLETE)
        </span>
      )
    }
    if (item.status === 'READY_FOR_PICKUP_FACTURE' || item.unboxing_option === 'UNBOXING') {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-green-100 text-green-800 border border-green-300">
          <ShieldCheck className="w-3.5 h-3.5" /> INVOICE TERVERIFIKASI
        </span>
      )
    }
    if (item.unboxing_option === 'WAITING_FOR_UNBOXING') {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-300">
          <Clock className="w-3.5 h-3.5" /> TUNDA UNBOXING
        </span>
      )
    }
    return (
      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-blue-100 text-blue-800 border border-blue-300">
        <Truck className="w-3.5 h-3.5" /> DALAM PROSES
      </span>
    )
  }

  // Extract all photo URLs from an invoice item
  const getItemPhotos = (item: InvoiceItem) => {
    const photos: { title: string; url: string }[] = []
    
    // Facture Photos
    if (item.facture_photo_url) {
      let urls: string[] = []
      if (item.facture_photo_url.includes('|||')) {
        urls = item.facture_photo_url.split('|||')
      } else if (item.facture_photo_url.includes(';')) {
        urls = item.facture_photo_url.split(';')
      } else {
        urls = [item.facture_photo_url]
      }
      urls.filter(u => u.trim()).forEach((u, idx) => {
        photos.push({
          title: urls.length > 1 ? `Foto Faktur Fisik #${idx + 1}` : 'Foto Faktur Fisik',
          url: formatFullPhotoUrl(u)
        })
      })
    }

    // Arrived / Serah Terima Photo
    if (item.arrived_photo_url) {
      photos.push({ title: 'Foto Bukti Tiba di Lokasi', url: formatFullPhotoUrl(item.arrived_photo_url) })
    }
    if (item.handover_photo_url) {
      photos.push({ title: 'Foto Bukti Serah Terima Paket', url: formatFullPhotoUrl(item.handover_photo_url) })
    }

    // Digital Signatures
    if (item.signature_photo_url) {
      photos.push({ title: 'Tanda Tangan Digital Apoteker', url: formatFullPhotoUrl(item.signature_photo_url) })
    }
    if (item.pod_signature_photo_url) {
      photos.push({ title: 'Tanda Tangan Digital POD (Gudang K-24)', url: formatFullPhotoUrl(item.pod_signature_photo_url) })
    }

    return photos.filter(p => p.url !== '')
  }

  return (
    <DashboardShell onRefresh={fetchInvoices}>
      <div className="space-y-6 max-w-7xl mx-auto">
        {/* Header Banner */}
        <div className="bg-gradient-to-r from-emerald-700 via-green-600 to-teal-700 rounded-3xl p-6 text-white shadow-xl relative overflow-hidden">
          <div className="absolute right-0 top-0 translate-x-8 -translate-y-8 opacity-10 pointer-events-none">
            <Search className="w-80 h-80 text-white" />
          </div>
          <div className="relative z-10 space-y-3">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/20 backdrop-blur-md text-xs font-semibold">
              <Search className="w-3.5 h-3.5 text-yellow-300" />
              <span>Pemeriksaan Invoice & Bukti Serah Terima Logistik</span>
            </div>
            <h1 className="text-3xl font-extrabold tracking-tight">Cek Invoice & Pengantaran</h1>
            <p className="text-green-100 text-sm max-w-2xl leading-relaxed">
              Cari dan periksa detail invoice, foto bukti faktur fisik, serah terima paket, tanda tangan digital apoteker, dan rincian pengantaran rute K-24 secara instan.
            </p>
          </div>
        </div>

        {/* KPI Stats Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
            <div className="p-3 bg-emerald-50 rounded-xl text-emerald-600">
              <FileText className="w-6 h-6" />
            </div>
            <div>
              <p className="text-xs text-slate-500 font-medium">Total Invoice Terdata</p>
              <h3 className="text-2xl font-black text-slate-800">{stats.total}</h3>
            </div>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
            <div className="p-3 bg-green-50 rounded-xl text-green-600">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <p className="text-xs text-slate-500 font-medium">Verified / Unboxed</p>
              <h3 className="text-2xl font-black text-green-700">{stats.verified}</h3>
            </div>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
            <div className="p-3 bg-amber-50 rounded-xl text-amber-600">
              <Clock className="w-6 h-6" />
            </div>
            <div>
              <p className="text-xs text-slate-500 font-medium">Tunda Unboxing</p>
              <h3 className="text-2xl font-black text-amber-700">{stats.delayed}</h3>
            </div>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
            <div className="p-3 bg-blue-50 rounded-xl text-blue-600">
              <Truck className="w-6 h-6" />
            </div>
            <div>
              <p className="text-xs text-slate-500 font-medium">Dalam Proses</p>
              <h3 className="text-2xl font-black text-blue-700">{stats.delivering}</h3>
            </div>
          </div>
        </div>

        {/* Main Search & Filter Control Card */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-4">
          <div className="flex flex-col md:flex-row items-center gap-4">
            {/* Giant Search Bar */}
            <div className="relative flex-1 w-full">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cari berdasarkan No Invoice / No Order / Nama Apotek / Driver / Nama Obat..."
                className="w-full pl-12 pr-10 py-3.5 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:bg-white transition-all font-medium"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-slate-400 hover:text-slate-600 rounded-lg"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>

            <button
              onClick={fetchInvoices}
              disabled={loading}
              className="flex items-center gap-2 px-4 py-3 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-sm font-semibold transition-all shrink-0"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              <span>Refresh Data</span>
            </button>
          </div>

          {/* Filter Tab Chips */}
          <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-slate-100">
            <span className="text-xs font-semibold text-slate-500 mr-2 flex items-center gap-1">
              <Filter className="w-3.5 h-3.5" /> Filter Status:
            </span>
            {[
              { id: 'ALL', label: `Semua (${stats.total})` },
              { id: 'VERIFIED', label: `Terverifikasi (${stats.verified})` },
              { id: 'WAITING', label: `Tunda Unboxing (${stats.delayed})` },
              { id: 'DELIVERING', label: `Dalam Proses (${stats.delivering})` },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setSelectedStatus(tab.id)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all ${
                  selectedStatus === tab.id
                    ? 'bg-emerald-600 text-white shadow-sm'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* Invoice List Container */}
        <div className="space-y-4">
          {loading ? (
            <div className="bg-white rounded-2xl p-12 border border-slate-200 text-center space-y-3">
              <RefreshCw className="w-8 h-8 text-emerald-600 animate-spin mx-auto" />
              <p className="text-sm font-semibold text-slate-600">Memuat data invoice dan bukti pengantaran...</p>
            </div>
          ) : filteredInvoices.length === 0 ? (
            <div className="bg-white rounded-2xl p-12 border border-slate-200 text-center space-y-3">
              <AlertCircle className="w-10 h-10 text-slate-300 mx-auto" />
              <h3 className="text-base font-bold text-slate-700">Tidak ada invoice ditemukan</h3>
              <p className="text-xs text-slate-500 max-w-md mx-auto">
                Tidak ditemukan data invoice yang sesuai dengan pencarian &quot;{searchQuery}&quot;. Silakan coba kata kunci atau filter lain.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-4">
              {filteredInvoices.map((item, index) => {
                const photos = getItemPhotos(item)
                const invListText = item.checked_invoices.trim() || item.medicine_summary.trim()

                return (
                  <div
                    key={`${item.order_number}-${index}`}
                    className="bg-white rounded-2xl border border-slate-200 hover:border-emerald-500/50 shadow-sm hover:shadow-md transition-all p-5 space-y-4"
                  >
                    {/* Card Header Row */}
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
                      <div className="flex items-center gap-3">
                        <div className="p-2.5 bg-emerald-50 text-emerald-700 rounded-xl font-bold text-sm">
                          #{index + 1}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <h3 className="font-extrabold text-slate-800 text-base">
                              {item.order_number}
                            </h3>
                            {item.dispatch_id && (
                              <span className="px-2.5 py-0.5 rounded-lg bg-blue-50 text-blue-700 text-xs font-semibold border border-blue-200">
                                {item.dispatch_id}
                              </span>
                            )}
                          </div>
                          <p className="text-xs text-slate-400 font-medium">
                            Dibuat pada: {new Date(item.created_at).toLocaleString('id-ID')}
                          </p>
                        </div>
                      </div>

                      <div>{getStatusBadge(item)}</div>
                    </div>

                    {/* Card Main Info Grid */}
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
                      {/* Destination Address */}
                      <div className="space-y-1 bg-slate-50 p-3.5 rounded-xl border border-slate-100">
                        <p className="font-bold text-slate-700 flex items-center gap-1.5">
                          <Building2 className="w-3.5 h-3.5 text-emerald-600" />
                          <span>Tujuan Pengantaran / Apotek</span>
                        </p>
                        <p className="font-semibold text-slate-800 text-sm">
                          {item.customer_name || item.pharmacy_name || 'Pelanggan K-24'}
                        </p>
                        <p className="text-slate-500 flex items-start gap-1">
                          <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0 mt-0.5" />
                          <span>{item.delivery_address}</span>
                        </p>
                      </div>

                      {/* Driver Info */}
                      <div className="space-y-1 bg-slate-50 p-3.5 rounded-xl border border-slate-100">
                        <p className="font-bold text-slate-700 flex items-center gap-1.5">
                          <Truck className="w-3.5 h-3.5 text-blue-600" />
                          <span>Driver / Kurir Pengantar</span>
                        </p>
                        <p className="font-semibold text-slate-800 text-sm">
                          {item.driver_name || 'Belum Ditugaskan'}
                        </p>
                        <p className="text-slate-500 flex items-center gap-2">
                          <span>📱 {item.driver_phone || '-'}</span>
                          {item.driver_plate && (
                            <span className="px-1.5 py-0.5 bg-slate-200 text-slate-700 rounded text-[10px] font-bold">
                              {item.driver_plate}
                            </span>
                          )}
                        </p>
                      </div>

                      {/* Invoice & Items Summary */}
                      <div className="space-y-1 bg-slate-50 p-3.5 rounded-xl border border-slate-100">
                        <p className="font-bold text-slate-700 flex items-center gap-1.5">
                          <FileText className="w-3.5 h-3.5 text-purple-600" />
                          <span>Rincian Invoice Terverifikasi</span>
                        </p>
                        <p className="text-slate-700 line-clamp-2 leading-relaxed">
                          {invListText || 'Invoice dalam proses verifikasi'}
                        </p>
                        {item.extra_items_note && (
                          <p className="text-amber-700 font-semibold text-[11px] bg-amber-50 p-1.5 rounded border border-amber-200">
                            Catatan: {item.extra_items_note}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Photo Thumbnails Row */}
                    <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
                      <div className="flex items-center gap-2 overflow-x-auto py-1">
                        {photos.length === 0 ? (
                          <span className="text-xs text-slate-400 italic">Belum ada foto bukti diunggah</span>
                        ) : (
                          photos.map((p, pIdx) => (
                            <button
                              key={pIdx}
                              onClick={() => setLightboxImage(p.url)}
                              className="relative group border border-slate-200 rounded-lg overflow-hidden bg-slate-100 hover:border-emerald-500 transition-all shrink-0"
                              title={p.title}
                            >
                              <img
                                src={p.url}
                                alt={p.title}
                                className="w-14 h-14 object-cover group-hover:scale-105 transition-transform"
                                onError={(e) => {
                                  (e.target as HTMLImageElement).src = 'https://placehold.co/100x100?text=Gambar'
                                }}
                              />
                              <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                                <ZoomIn className="w-4 h-4 text-white" />
                              </div>
                            </button>
                          ))
                        )}
                      </div>

                      <button
                        onClick={() => setSelectedInvoice(item)}
                        className="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold transition-all shadow-sm shrink-0"
                      >
                        <Eye className="w-4 h-4" />
                        <span>Lihat Detail & Bukti Foto</span>
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>

        {/* DETAIL MODAL INSPECTION */}
        {selectedInvoice && (
          <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
            <div className="bg-white rounded-3xl max-w-3xl w-full max-h-[90vh] overflow-y-auto shadow-2xl border border-slate-100 space-y-6 p-6 relative">
              {/* Modal Header */}
              <div className="flex items-center justify-between pb-4 border-b border-slate-100 sticky top-0 bg-white z-10">
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-xl font-extrabold text-slate-800">
                      Detail Invoice {selectedInvoice.order_number}
                    </h2>
                    {getStatusBadge(selectedInvoice)}
                  </div>
                  <p className="text-xs text-slate-500">
                    Batch Dispatch: {selectedInvoice.dispatch_id || selectedInvoice.parent_order_number}
                  </p>
                </div>
                <button
                  onClick={() => setSelectedInvoice(null)}
                  className="p-2 hover:bg-slate-100 text-slate-400 hover:text-slate-700 rounded-full transition-all"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Destination & Driver Grid */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
                <div className="p-4 bg-emerald-50/50 rounded-2xl border border-emerald-100 space-y-1.5">
                  <p className="font-bold text-emerald-800 text-sm flex items-center gap-1.5">
                    <Building2 className="w-4 h-4 text-emerald-600" />
                    <span>Lokasi Apotek / Alamat Tujuan</span>
                  </p>
                  <p className="font-extrabold text-slate-800 text-sm">
                    {selectedInvoice.customer_name || selectedInvoice.pharmacy_name}
                  </p>
                  <p className="text-slate-600 leading-relaxed">{selectedInvoice.delivery_address}</p>
                </div>

                <div className="p-4 bg-blue-50/50 rounded-2xl border border-blue-100 space-y-1.5">
                  <p className="font-bold text-blue-800 text-sm flex items-center gap-1.5">
                    <Truck className="w-4 h-4 text-blue-600" />
                    <span>Informasi Kurir Driver</span>
                  </p>
                  <p className="font-extrabold text-slate-800 text-sm">{selectedInvoice.driver_name || 'Driver'}</p>
                  <p className="text-slate-600">No. HP: {selectedInvoice.driver_phone || '-'}</p>
                  <p className="text-slate-600">Armada / Nopol: {selectedInvoice.driver_plate || '-'} ({selectedInvoice.vehicle_type})</p>
                </div>
              </div>

              {/* Verified Invoice Details */}
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-2 text-xs">
                <p className="font-bold text-slate-800 text-sm flex items-center gap-1.5">
                  <FileText className="w-4 h-4 text-purple-600" />
                  <span>Rincian Barang & Invoice Terverifikasi</span>
                </p>
                <div className="p-3 bg-white rounded-xl border border-slate-200 font-mono text-slate-800 leading-relaxed whitespace-pre-wrap">
                  {selectedInvoice.checked_invoices || selectedInvoice.medicine_summary || 'Tidak ada catatan khusus'}
                </div>
                {selectedInvoice.extra_items_note && (
                  <p className="text-amber-800 bg-amber-50 p-2.5 rounded-xl border border-amber-200 font-semibold">
                    Catatan Cacat / Ketidaksesuaian: {selectedInvoice.extra_items_note}
                  </p>
                )}
              </div>

              {/* Photo Gallery Grid */}
              <div className="space-y-3">
                <h3 className="font-bold text-slate-800 text-sm flex items-center gap-1.5">
                  <ZoomIn className="w-4 h-4 text-emerald-600" />
                  <span>Galeri Bukti Foto & Tanda Tangan Digital</span>
                </h3>

                {getItemPhotos(selectedInvoice).length === 0 ? (
                  <p className="text-xs text-slate-400 italic">Belum ada foto bukti yang diunggah untuk order ini.</p>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {getItemPhotos(selectedInvoice).map((photo, pIdx) => {
                      return (
                        <div key={pIdx} className="p-3 bg-slate-50 rounded-2xl border border-slate-200 space-y-2">
                          <p className="text-xs font-bold text-slate-700">{photo.title}</p>
                          <div
                            onClick={() => setLightboxImage(photo.url)}
                            className="relative h-48 rounded-xl overflow-hidden border border-slate-300 bg-black cursor-pointer group"
                          >
                            <img
                              src={photo.url}
                              alt={photo.title}
                              className="w-full h-full object-contain group-hover:scale-105 transition-transform"
                            />
                            <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                              <span className="px-3 py-1.5 bg-white/90 text-slate-800 text-xs font-bold rounded-lg shadow">
                                Klik untuk Perbesar 🔍
                              </span>
                            </div>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>

              {/* Modal Footer */}
              <div className="pt-4 border-t border-slate-100 flex justify-end">
                <button
                  onClick={() => setSelectedInvoice(null)}
                  className="px-5 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-all"
                >
                  Tutup Detail
                </button>
              </div>
            </div>
          </div>
        )}

        {/* FULLSCREEN LIGHTBOX PREVIEW */}
        {lightboxImage && (
          <div
            className="fixed inset-0 z-[100] bg-black/90 backdrop-blur-md flex items-center justify-center p-4"
            onClick={() => setLightboxImage(null)}
          >
            <button
              onClick={() => setLightboxImage(null)}
              className="absolute top-6 right-6 p-3 bg-white/10 hover:bg-white/20 text-white rounded-full transition-all"
            >
              <X className="w-6 h-6" />
            </button>
            <img
              src={lightboxImage}
              alt="Preview Bukti Foto"
              className="max-w-full max-h-[90vh] object-contain rounded-xl shadow-2xl"
              onClick={(e) => e.stopPropagation()}
            />
          </div>
        )}
      </div>
    </DashboardShell>
  )
}
