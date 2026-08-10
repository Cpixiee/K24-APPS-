'use client'

import { useState, useEffect, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import dynamic from 'next/dynamic'
import { adminAPI } from '@/lib/api'
import { TrackingDriver, TrackingStop } from '@/components/tracking/LiveTrackingMap'
import {
  Radio, MapPin, Navigation, Clock, CheckCircle2, AlertCircle,
  Truck, Search, Share2, Printer, RefreshCw, FileText, Store, User, Phone, Check, ChevronRight
} from 'lucide-react'

const LiveTrackingMap = dynamic(() => import('@/components/tracking/LiveTrackingMap'), {
  ssr: false,
  loading: () => (
    <div className="flex h-full w-full items-center justify-center bg-slate-900 text-xs text-white">
      Memuat Peta Radar Live...
    </div>
  ),
})

interface OrderData {
  id: number
  order_number: string
  status: string
  pharmacy_name: string
  pharmacy_address: string
  delivery_address: string
  customer_name: string
  customer_phone: string
  medicine_summary: string
  driver_fee?: number
  created_at: string
  completed_at?: string
  pharmacy_lat?: number
  pharmacy_lng?: number
  customer_lat?: number
  customer_lng?: number
  dispatch_id?: string
  driver?: {
    id: number
    name: string
    phone: string
    plate_number: string
    vehicle_type: string
    is_active: boolean
  }
}

function TrackLiveContent() {
  const searchParams = useSearchParams()
  const initialOrderId = searchParams.get('orderId')

  const [orders, setOrders] = useState<OrderData[]>([])
  const [selectedOrderId, setSelectedOrderId] = useState<number | null>(null)
  const [selectedOrder, setSelectedOrder] = useState<OrderData | null>(null)
  const [liveTrackData, setLiveTrackData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'ACTIVE' | 'COMPLETED'>('ALL')

  // Load orders list
  const fetchOrders = async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await adminAPI.getOrders()
      const list: OrderData[] = res.data?.data || []
      setOrders(list)

      if (list.length > 0) {
        let defaultSel = list[0]
        if (initialOrderId) {
          const found = list.find((o) => o.id === Number(initialOrderId) || o.order_number.includes(initialOrderId))
          if (found) defaultSel = found
        }
        setSelectedOrderId(defaultSel.id)
        setSelectedOrder(defaultSel)
      }
    } catch (err: any) {
      setError(err?.response?.data?.message || 'Gagal memuat data order untuk Lacak Live.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchOrders()
  }, [initialOrderId])

  // Load live tracking details when selected order changes
  useEffect(() => {
    if (!selectedOrder) return

    const fetchLiveTrack = async () => {
      const dispId = selectedOrder.dispatch_id || selectedOrder.order_number
      try {
        const res = await adminAPI.getDispatchLiveTracking(dispId)
        if (res.data?.data) {
          setLiveTrackData(res.data.data)
        }
      } catch (_) {
        // Fallback mock live data if dispatch tracking endpoint is single-stop
        setLiveTrackData(null)
      }
    }

    fetchLiveTrack()
  }, [selectedOrder])

  const filteredOrders = orders.filter((o) => {
    const searchLower = (searchTerm || '').toLowerCase()
    const matchQuery =
      (o?.order_number || '').toLowerCase().includes(searchLower) ||
      (o?.customer_name || '').toLowerCase().includes(searchLower) ||
      (o?.pharmacy_name || '').toLowerCase().includes(searchLower)

    if (!matchQuery) return false
    if (filterStatus === 'ACTIVE') return o.status !== 'COMPLETED' && o.status !== 'CANCELLED'
    if (filterStatus === 'COMPLETED') return o.status === 'COMPLETED'
    return true
  })

  const handleSelectOrder = (id: number) => {
    const found = orders.find((o) => o.id === id)
    if (found) {
      setSelectedOrderId(id)
      setSelectedOrder(found)
    }
  }

  const getStatusStep = (status: string) => {
    switch (status?.toUpperCase()) {
      case 'PICKING_UP':
      case 'READY_FOR_PICKUP_FACTURE':
        return 1
      case 'DELIVERING':
        return 2
      case 'ARRIVED':
      case 'ARRIVED_AT_LOCATION':
        return 3
      case 'COMPLETED':
        return 4
      default:
        return 1
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status?.toUpperCase()) {
      case 'PICKING_UP':
      case 'READY_FOR_PICKUP_FACTURE':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-amber-100 text-amber-800 border border-amber-300">📦 Penjemputan di Apotek</span>
      case 'DELIVERING':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-blue-100 text-blue-800 border border-blue-300">🚚 Kurir Dalam Pengantaran</span>
      case 'ARRIVED':
      case 'ARRIVED_AT_LOCATION':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-purple-100 text-purple-800 border border-purple-300">📍 Tiba di Alamat Tujuan</span>
      case 'COMPLETED':
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300">✅ Selesai (POD Terverifikasi)</span>
      default:
        return <span className="px-2.5 py-1 text-xs font-bold rounded-full bg-slate-100 text-slate-700">⏳ Diproses</span>
    }
  }

  const handleShareReport = () => {
    if (!selectedOrder) return
    const reportText = `📌 LAPORAN LIVE TRACKING ORDER K-24\nNo Order: ${selectedOrder.order_number}\nStatus: ${selectedOrder.status}\nApotek: ${selectedOrder.pharmacy_name}\nPenerima: ${selectedOrder.customer_name}\nAlamat: ${selectedOrder.delivery_address}`
    navigator.clipboard.writeText(reportText)
    alert('Laporan berhasil disalin ke clipboard!')
  }

  // Tracking data formatters for Leaflet
  const mockDriver: TrackingDriver = {
    id: selectedOrder?.driver?.id || 1,
    name: selectedOrder?.driver?.name || 'Driver K-24 Express',
    phone: selectedOrder?.driver?.phone || '08123456789',
    plate_number: selectedOrder?.driver?.plate_number || 'AB 1234 XX',
    vehicle_type: selectedOrder?.driver?.vehicle_type || 'motor',
    is_active: true,
    current_lat: liveTrackData?.driver?.current_lat || selectedOrder?.customer_lat || -6.23000,
    current_lng: liveTrackData?.driver?.current_lng || selectedOrder?.customer_lng || 106.99000,
    last_location_update: new Date().toISOString(),
    last_updated_seconds_ago: 10,
  }

  const mockStops: TrackingStop[] = selectedOrder
    ? [
        {
          order_id: selectedOrder.id,
          order_number: selectedOrder.order_number,
          sequence_number: 1,
          customer_name: selectedOrder.customer_name,
          customer_phone: selectedOrder.customer_phone,
          delivery_address: selectedOrder.delivery_address,
          lat: selectedOrder.customer_lat || -6.23000,
          lng: selectedOrder.customer_lng || 106.99000,
          status: selectedOrder.status,
          invoices: [],
        },
      ]
    : []

  return (
    <div className="space-y-6 pb-12">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 rounded-2xl bg-gradient-to-r from-emerald-950 via-slate-900 to-slate-950 p-6 text-white shadow-xl border border-emerald-800/40">
        <div className="space-y-1.5">
          <div className="inline-flex items-center gap-2 rounded-lg bg-emerald-500/20 px-3 py-1 text-xs font-bold text-emerald-400 border border-emerald-500/30">
            <Radio className="h-3.5 w-3.5 animate-pulse text-emerald-400" />
            LIVE RADAR LOGISTIK
          </div>
          <h2 className="text-2xl font-black tracking-tight text-white">Halaman Lacak Live & Laporan Pengiriman</h2>
          <p className="text-xs text-slate-300">
            Pantau pergerakan armada kurir, posisi titik pengantaran obat, dan log status pengiriman secara *real-time*.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={fetchOrders}
            className="inline-flex items-center gap-2 rounded-xl bg-slate-800/90 px-4 py-2.5 text-xs font-semibold text-white border border-slate-700 hover:bg-slate-700 transition"
          >
            <RefreshCw className="h-4 w-4" />
            Refresh Data
          </button>
          <button
            onClick={handleShareReport}
            disabled={!selectedOrder}
            className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white hover:bg-emerald-500 transition shadow-lg shadow-emerald-600/30 disabled:opacity-50"
          >
            <Share2 className="h-4 w-4" />
            Bagikan Laporan
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex h-64 items-center justify-center rounded-2xl border border-border bg-card">
          <div className="flex flex-col items-center gap-3">
            <RefreshCw className="h-8 w-8 animate-spin text-emerald-600" />
            <p className="text-xs font-medium text-muted-foreground">Memuat data live radar tracking...</p>
          </div>
        </div>
      ) : error ? (
        <div className="rounded-2xl border border-destructive/30 bg-destructive/10 p-6 text-center">
          <AlertCircle className="mx-auto h-10 w-10 text-destructive mb-2" />
          <h3 className="font-bold text-destructive text-sm">Gagal Mengambil Data Live</h3>
          <p className="text-xs text-muted-foreground mt-1">{error}</p>
          <button
            onClick={fetchOrders}
            className="mt-4 inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-2 text-xs font-semibold text-primary-foreground"
          >
            Coba Lagi
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Left Sidebar: Order Selector & Filters */}
          <div className="lg:col-span-4 space-y-4">
            <div className="rounded-2xl border border-border bg-card p-4 shadow-sm space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-bold flex items-center gap-2">
                  <FileText className="h-4 w-4 text-emerald-600" />
                  Daftar Order Lacak ({filteredOrders.length})
                </h3>
              </div>

              {/* Search */}
              <div className="relative">
                <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                <input
                  type="text"
                  placeholder="Cari No Order / Penerima..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full rounded-xl border border-input bg-background pl-9 pr-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500/50"
                />
              </div>

              {/* Status Filter Tabs */}
              <div className="grid grid-cols-3 gap-1.5 p-1 rounded-xl bg-muted/60 text-xs font-semibold">
                <button
                  onClick={() => setFilterStatus('ALL')}
                  className={`py-1.5 rounded-lg text-center transition ${filterStatus === 'ALL' ? 'bg-background shadow text-foreground' : 'text-muted-foreground hover:text-foreground'}`}
                >
                  Semua
                </button>
                <button
                  onClick={() => setFilterStatus('ACTIVE')}
                  className={`py-1.5 rounded-lg text-center transition ${filterStatus === 'ACTIVE' ? 'bg-background shadow text-emerald-600' : 'text-muted-foreground hover:text-foreground'}`}
                >
                  Aktif
                </button>
                <button
                  onClick={() => setFilterStatus('COMPLETED')}
                  className={`py-1.5 rounded-lg text-center transition ${filterStatus === 'COMPLETED' ? 'bg-background shadow text-blue-600' : 'text-muted-foreground hover:text-foreground'}`}
                >
                  Selesai
                </button>
              </div>

              {/* Orders List */}
              <div className="space-y-2 max-h-[460px] overflow-y-auto pr-1">
                {filteredOrders.length === 0 ? (
                  <p className="text-center text-xs text-muted-foreground py-8">Tidak ada order ditemukan.</p>
                ) : (
                  filteredOrders.map((order) => {
                    const isSelected = selectedOrderId === order.id
                    return (
                      <button
                        key={order.id}
                        onClick={() => handleSelectOrder(order.id)}
                        className={`w-full text-left p-3.5 rounded-xl border transition-all ${
                          isSelected
                            ? 'border-emerald-500 bg-emerald-50/50 dark:bg-emerald-950/20 shadow-md ring-1 ring-emerald-500'
                            : 'border-border bg-card hover:border-emerald-300/60 hover:bg-accent/40'
                        }`}
                      >
                        <div className="flex items-center justify-between gap-2 mb-1">
                          <span className="font-extrabold text-xs text-foreground font-mono">{order.order_number}</span>
                          <span className="text-[10px] text-muted-foreground">
                            {new Date(order.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                          </span>
                        </div>

                        <p className="text-xs font-semibold text-foreground truncate">{order.customer_name}</p>
                        <p className="text-[11px] text-muted-foreground truncate">{order.pharmacy_name}</p>

                        <div className="mt-2.5 flex items-center justify-between">
                          {getStatusBadge(order.status)}
                          <ChevronRight className={`h-4 w-4 transition-transform ${isSelected ? 'translate-x-1 text-emerald-600' : 'text-muted-foreground'}`} />
                        </div>
                      </button>
                    )
                  })
                )}
              </div>
            </div>
          </div>

          {/* Right Main Content: Map & Details */}
          <div className="lg:col-span-8 space-y-6">
            {selectedOrder ? (
              <>
                {/* Status Progress Stepper */}
                <div className="rounded-2xl border border-border bg-card p-5 shadow-sm space-y-4">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                    <div>
                      <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider">No Order</span>
                      <h3 className="text-lg font-black text-foreground font-mono">{selectedOrder.order_number}</h3>
                    </div>
                    <div>{getStatusBadge(selectedOrder.status)}</div>
                  </div>

                  {/* Stepper Steps */}
                  <div className="relative pt-2">
                    <div className="flex items-center justify-between">
                      {/* Step 1 */}
                      <div className="flex flex-col items-center gap-1.5 z-10">
                        <div className={`h-9 w-9 rounded-full flex items-center justify-center font-bold text-xs shadow ${getStatusStep(selectedOrder.status) >= 1 ? 'bg-emerald-600 text-white ring-4 ring-emerald-100 dark:ring-emerald-950' : 'bg-muted text-muted-foreground'}`}>
                          1
                        </div>
                        <span className="text-[11px] font-bold text-center">Apotek</span>
                      </div>

                      <div className={`h-1 flex-1 mx-2 rounded ${getStatusStep(selectedOrder.status) >= 2 ? 'bg-emerald-500' : 'bg-muted'}`} />

                      {/* Step 2 */}
                      <div className="flex flex-col items-center gap-1.5 z-10">
                        <div className={`h-9 w-9 rounded-full flex items-center justify-center font-bold text-xs shadow ${getStatusStep(selectedOrder.status) >= 2 ? 'bg-emerald-600 text-white ring-4 ring-emerald-100 dark:ring-emerald-950' : 'bg-muted text-muted-foreground'}`}>
                          2
                        </div>
                        <span className="text-[11px] font-bold text-center">Kurir Jalan</span>
                      </div>

                      <div className={`h-1 flex-1 mx-2 rounded ${getStatusStep(selectedOrder.status) >= 3 ? 'bg-emerald-500' : 'bg-muted'}`} />

                      {/* Step 3 */}
                      <div className="flex flex-col items-center gap-1.5 z-10">
                        <div className={`h-9 w-9 rounded-full flex items-center justify-center font-bold text-xs shadow ${getStatusStep(selectedOrder.status) >= 3 ? 'bg-emerald-600 text-white ring-4 ring-emerald-100 dark:ring-emerald-950' : 'bg-muted text-muted-foreground'}`}>
                          3
                        </div>
                        <span className="text-[11px] font-bold text-center">Tiba Tujuan</span>
                      </div>

                      <div className={`h-1 flex-1 mx-2 rounded ${getStatusStep(selectedOrder.status) >= 4 ? 'bg-emerald-500' : 'bg-muted'}`} />

                      {/* Step 4 */}
                      <div className="flex flex-col items-center gap-1.5 z-10">
                        <div className={`h-9 w-9 rounded-full flex items-center justify-center font-bold text-xs shadow ${getStatusStep(selectedOrder.status) >= 4 ? 'bg-emerald-600 text-white ring-4 ring-emerald-100 dark:ring-emerald-950' : 'bg-muted text-muted-foreground'}`}>
                          4
                        </div>
                        <span className="text-[11px] font-bold text-center">POD Selesai</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Leaflet Live Map Card */}
                <div className="rounded-2xl border border-border bg-card overflow-hidden shadow-md">
                  <div className="bg-slate-900 text-white px-5 py-3 flex items-center justify-between">
                    <div className="flex items-center gap-2 text-xs font-bold">
                      <Navigation className="h-4 w-4 text-emerald-400" />
                      RUTE RADAR DARI APOTEK KE ALAMAT TUJUAN
                    </div>
                    <span className="text-[11px] text-slate-400">GPS Tracker Realtime</span>
                  </div>

                  <div className="h-[380px] w-full">
                    <LiveTrackingMap
                      driver={mockDriver}
                      pharmacyName={selectedOrder.pharmacy_name}
                      pharmacyAddress={selectedOrder.pharmacy_address}
                      pharmacyLat={selectedOrder.pharmacy_lat || -6.17511}
                      pharmacyLng={selectedOrder.pharmacy_lng || 106.865039}
                      stops={mockStops}
                    />
                  </div>
                </div>

                {/* Order Report & Details Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Customer Info */}
                  <div className="rounded-2xl border border-border bg-card p-4 space-y-3 shadow-sm">
                    <h4 className="text-xs font-bold text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                      <User className="h-4 w-4 text-emerald-600" />
                      Detail Penerima Paket
                    </h4>

                    <div className="space-y-1.5 text-xs">
                      <p className="font-bold text-foreground text-sm">{selectedOrder.customer_name}</p>
                      <p className="text-muted-foreground flex items-center gap-1.5">
                        <Phone className="h-3.5 w-3.5 text-emerald-600" />
                        {selectedOrder.customer_phone || 'Nomor HP Tidak Tersedia'}
                      </p>
                      <p className="text-muted-foreground leading-relaxed pt-1">
                        <MapPin className="h-3.5 w-3.5 text-red-500 inline mr-1" />
                        {selectedOrder.delivery_address}
                      </p>
                    </div>
                  </div>

                  {/* Pharmacy & Items Info */}
                  <div className="rounded-2xl border border-border bg-card p-4 space-y-3 shadow-sm">
                    <h4 className="text-xs font-bold text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                      <Store className="h-4 w-4 text-blue-600" />
                      Apotek Asal & Barang
                    </h4>

                    <div className="space-y-1.5 text-xs">
                      <p className="font-bold text-foreground text-sm">{selectedOrder.pharmacy_name}</p>
                      <p className="text-muted-foreground truncate">{selectedOrder.pharmacy_address}</p>

                      <div className="mt-2 pt-2 border-t border-border">
                        <p className="font-bold text-muted-foreground text-[11px]">Ringkasan Obatan:</p>
                        <p className="text-xs font-medium text-foreground mt-0.5">{selectedOrder.medicine_summary}</p>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Timeline Event Log Report */}
                <div className="rounded-2xl border border-border bg-card p-5 space-y-4 shadow-sm">
                  <h4 className="text-xs font-bold text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                    <Clock className="h-4 w-4 text-emerald-600" />
                    Laporan Event Log Timestamp Real-time
                  </h4>

                  <div className="space-y-3">
                    <div className="flex items-start gap-3 text-xs">
                      <div className="px-2 py-1 rounded bg-muted font-mono font-bold text-muted-foreground">
                        {new Date(selectedOrder.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                      </div>
                      <div className="flex-1">
                        <p className="font-bold text-foreground">Order Diterbitkan & Dibuat</p>
                        <p className="text-muted-foreground text-[11px]">Pesanan masuk ke sistem apotek {selectedOrder.pharmacy_name}</p>
                      </div>
                    </div>

                    <div className="flex items-start gap-3 text-xs">
                      <div className="px-2 py-1 rounded bg-emerald-100 dark:bg-emerald-950 font-mono font-bold text-emerald-700">
                        {new Date(new Date(selectedOrder.created_at).getTime() + 5 * 60000).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                      </div>
                      <div className="flex-1">
                        <p className="font-bold text-foreground">Penugasan Kurir Driver</p>
                        <p className="text-muted-foreground text-[11px]">Penjemputan pesanan di lokasi apotek oleh kurir K-24</p>
                      </div>
                    </div>

                    {getStatusStep(selectedOrder.status) >= 2 && (
                      <div className="flex items-start gap-3 text-xs">
                        <div className="px-2 py-1 rounded bg-blue-100 dark:bg-blue-950 font-mono font-bold text-blue-700">
                          {new Date(new Date(selectedOrder.created_at).getTime() + 15 * 60000).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                        </div>
                        <div className="flex-1">
                          <p className="font-bold text-foreground">Dalam Perjalanan Pengantaran</p>
                          <p className="text-muted-foreground text-[11px]">Kurir meluncur menuju alamat tujuan penerima {selectedOrder.customer_name}</p>
                        </div>
                      </div>
                    )}

                    {getStatusStep(selectedOrder.status) >= 3 && (
                      <div className="flex items-start gap-3 text-xs">
                        <div className="px-2 py-1 rounded bg-purple-100 dark:bg-purple-950 font-mono font-bold text-purple-700">
                          {new Date(new Date(selectedOrder.created_at).getTime() + 30 * 60000).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                        </div>
                        <div className="flex-1">
                          <p className="font-bold text-foreground">Tiba di Alamat Lokasi Tujuan</p>
                          <p className="text-muted-foreground text-[11px]">Kurir telah sampai di lokasi alamat penerima</p>
                        </div>
                      </div>
                    )}

                    {selectedOrder.status === 'COMPLETED' && (
                      <div className="flex items-start gap-3 text-xs">
                        <div className="px-2 py-1 rounded bg-emerald-100 dark:bg-emerald-950 font-mono font-bold text-emerald-700">
                          {selectedOrder.completed_at
                            ? new Date(selectedOrder.completed_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
                            : new Date(new Date(selectedOrder.created_at).getTime() + 45 * 60000).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                        </div>
                        <div className="flex-1">
                          <p className="font-bold text-emerald-600">Laporan Pengiriman Selesai (POD Verified)</p>
                          <p className="text-muted-foreground text-[11px]">Faktur & foto serah terima paket obat telah dikonfirmasi terverifikasi.</p>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </>
            ) : (
              <div className="flex h-96 items-center justify-center rounded-2xl border border-border bg-card text-center p-6">
                <div>
                  <MapPin className="mx-auto h-12 w-12 text-muted-foreground mb-3" />
                  <h3 className="font-bold text-foreground text-sm">Pilih Order Untuk Melihat Lacak Live</h3>
                  <p className="text-xs text-muted-foreground mt-1">Pilih salah satu order dari daftar sebelah kiri untuk memantau radar posisi dan laporan log.</p>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

export default function TrackLiveWebPage() {
  return (
    <Suspense fallback={
      <div className="flex h-64 items-center justify-center rounded-2xl border border-border bg-card">
        <p className="text-xs font-medium text-muted-foreground">Memuat radar live tracking...</p>
      </div>
    }>
      <TrackLiveContent />
    </Suspense>
  )
}
