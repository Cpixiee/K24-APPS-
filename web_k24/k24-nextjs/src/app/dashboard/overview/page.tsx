'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { useAuth } from '@/context/AuthContext'
import { toast } from 'sonner'
import {
  ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip
} from 'recharts'
import {
  Truck, Store, ShoppingBag, AlertCircle, ShieldAlert, CheckCircle, CheckCircle2,
  TrendingUp, TrendingDown, Activity, MapPin, User, Compass, CreditCard,
  Phone, Download, Printer, Map, Calendar, Navigation, Filter, Clock,
  MoreVertical, ChevronLeft, ChevronRight, Bell, RotateCw, ChevronDown, Check,
  FileText, Receipt, PackageCheck, FileCheck, ArrowRight, Layers
} from 'lucide-react'

interface Stats {
  total_drivers: number
  total_mitra: number
  total_orders: number
  total_invoices?: number
  pending_dispatch: number
  active_dispatch: number
  completed_orders: number
  cancelled_orders: number
  online_drivers: number
}

interface Driver {
  id: number
  name: string
  vehicle_type?: string
  is_active: boolean
}

interface OrderSummary {
  dispatch_id: string
  mitra_id: number
  mitra_name: string
  created_at: string
  stop_count: number
  total_fee: number
  status: string
  is_dispatched: boolean
  driver_name: string
  driver_phone?: string
  addresses?: string
  pharmacy_names?: string
  checked_invoices?: string
  medicine_summaries?: string
}

interface FlatInvoiceRow {
  invoice_no: string
  nama_apotek: string
  driver_name: string
  status: string
  catatan: string
  created_at: string
  dispatch_id: string
}

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  WAITING_FOR_PICKUP: { label: 'Waiting Pickup', color: 'bg-amber-50 text-amber-700 dark:bg-amber-950/20 dark:text-amber-400 border border-amber-200/60' },
  READY_FOR_PICKUP_FACTURE: { label: 'Facture Pending', color: 'bg-indigo-50 text-indigo-700 dark:bg-indigo-950/20 dark:text-indigo-400 border border-indigo-200/60' },
  PICKING_UP: { label: 'Picking Up', color: 'bg-amber-50 text-amber-700 dark:bg-amber-950/20 dark:text-amber-400 border border-amber-200/60' },
  DELIVERING: { label: 'Delivering', color: 'bg-blue-50 text-blue-700 dark:bg-blue-950/20 dark:text-blue-400 border border-blue-200/60' },
  COMPLETED: { label: 'Completed', color: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400 border border-emerald-200/60' },
  CANCELLED: { label: 'Cancelled', color: 'bg-rose-50 text-rose-700 dark:bg-rose-950/20 dark:text-rose-400 border border-rose-200/60' },
}

const formatRp = (n?: number) => n != null ? `Rp ${n.toLocaleString('id-ID')}` : '-'

export default function OverviewPage() {
  const router = useRouter()
  const { user, impersonatedMitra } = useAuth()
  const isMitra = user?.role === 'MITRA' || !!impersonatedMitra

  const [stats, setStats] = useState<Stats | null>(null)
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [orders, setOrders] = useState<OrderSummary[]>([])
  const [invoices, setInvoices] = useState<FlatInvoiceRow[]>([])
  const [loading, setLoading] = useState(true)
  const [periodFilter, setPeriodFilter] = useState<'all' | 'day' | 'week' | 'month' | 'year'>('all')

  const fetchData = useCallback(async () => {
    setLoading(true)
    try {
      const [statsRes, driversRes, ordersRes, invoicesRes] = await Promise.all([
        adminAPI.getStats(),
        adminAPI.getDrivers(),
        adminAPI.getOrders(),
        adminAPI.getFlatInvoices(),
      ])
      setStats(statsRes.data.data || statsRes.data)
      setDrivers(driversRes.data.data || driversRes.data || [])
      setOrders(ordersRes.data.data || ordersRes.data || [])
      
      const rawInvoices = invoicesRes.data?.data ?? invoicesRes.data
      setInvoices(Array.isArray(rawInvoices) ? rawInvoices : [])
    } catch {
      toast.error('Gagal memuat data ringkasan.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { fetchData() }, [fetchData])

  // Filter items by date period
  const filterByPeriod = useCallback(<T extends { created_at?: string }>(items: T[]) => {
    if (periodFilter === 'all') return items
    const now = new Date()
    return items.filter((item) => {
      if (!item.created_at) return true
      const d = new Date(item.created_at)
      if (periodFilter === 'day') {
        return d.toDateString() === now.toDateString()
      }
      if (periodFilter === 'week') {
        const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
        return d >= oneWeekAgo
      }
      if (periodFilter === 'month') {
        return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
      }
      if (periodFilter === 'year') {
        return d.getFullYear() === now.getFullYear()
      }
      return true
    })
  }, [periodFilter])

  const filteredOrders = useMemo(() => filterByPeriod(orders), [orders, filterByPeriod])
  const filteredInvoices = useMemo(() => filterByPeriod(invoices), [invoices, filterByPeriod])

  // Leaflet Map Initialization
  useEffect(() => {
    if (typeof window === 'undefined' || loading) return

    let mapInstance: any
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    document.head.appendChild(link)

    import('leaflet').then((L) => {
      const mapContainer = document.getElementById('map-container')
      if (!mapContainer) return

      // Center around Jakarta/Bekasi
      mapInstance = L.map('map-container', {
        zoomControl: false,
        attributionControl: false
      }).setView([-6.2582, 106.8834], 11)

      // CARTO Voyager map tiles
      L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        maxZoom: 19
      }).addTo(mapInstance)

      // Custom Tailwind-styled divIcons
      const hubIcon = L.divIcon({
        html: `<div class="h-6 w-6 rounded-full bg-blue-600 border-2 border-white flex items-center justify-center text-white shadow-lg ring-4 ring-blue-500/20"><span class="h-1.5 w-1.5 rounded-full bg-white animate-ping"></span></div>`,
        className: '',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })

      const apotekIcon = L.divIcon({
        html: `<div class="h-6 w-6 rounded-full bg-emerald-500 border-2 border-white flex items-center justify-center text-white shadow-lg"><svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.54 20.193 4 14.993 4 10a8 8 0 0 1 16 0z"/><circle cx="12" cy="10" r="3"/></svg></div>`,
        className: '',
        iconSize: [24, 24],
        iconAnchor: [12, 12]
      })

      const driverIcon = L.divIcon({
        html: `<div class="h-7 w-7 rounded-full bg-blue-600 border-2 border-white flex items-center justify-center text-white shadow-xl ring-4 ring-blue-500/30"><svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="rotate-45"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg></div>`,
        className: '',
        iconSize: [28, 28],
        iconAnchor: [14, 14]
      })

      // Add Hub Marker (K-24 Mitra Hub)
      const hubLat = -6.2582
      const hubLng = 106.8534
      L.marker([hubLat, hubLng], { icon: hubIcon }).addTo(mapInstance)
        .bindPopup('<b class="text-xs">K-24 Mitra Hub</b>')

      // Mock coordinates for stops based on seeded addresses
      const destinations = [
        { name: 'Apotek K-24 Veteran Bekasi', lat: -6.248332, lng: 106.997232 },
        { name: 'Apotek K-24 Pondok Gede', lat: -6.291244, lng: 106.904839 },
        { name: 'Apotek K-24 Condet', lat: -6.289123, lng: 106.853245 },
        { name: 'Apotek K-24 Tebet', lat: -6.229123, lng: 106.850987 }
      ]

      // Draw markers and route lines
      destinations.forEach((dest) => {
        L.marker([dest.lat, dest.lng], { icon: apotekIcon }).addTo(mapInstance)
          .bindPopup(`<span class="text-xs font-bold">${dest.name}</span>`)

        L.polyline([
          [hubLat, hubLng],
          [dest.lat, dest.lng]
        ], {
          color: '#3b82f6',
          weight: 2,
          opacity: 0.6,
          dashArray: '5, 8'
        }).addTo(mapInstance)
      })

      const driversPositions = [
        { lat: -6.2530, lng: 106.9200 },
        { lat: -6.2750, lng: 106.8780 }
      ]

      driversPositions.forEach((pos) => {
        L.marker([pos.lat, pos.lng], { icon: driverIcon }).addTo(mapInstance)
      })
    })

    return () => {
      if (mapInstance) {
        mapInstance.remove()
      }
      document.head.removeChild(link)
    }
  }, [loading])

  const totalOrders = filteredOrders.length || stats?.total_orders || 0
  const totalDrivers = stats?.total_drivers || 0
  const totalMitra = stats?.total_mitra || 0
  const totalInvoices = filteredInvoices.length || (totalOrders > 0 ? totalOrders * 2 : 0)
  const pendingDispatch = filteredOrders.filter(o => !o.is_dispatched || o.status === 'WAITING_FOR_PICKUP').length
  const activeDispatch = filteredOrders.filter(o => o.status === 'DELIVERING' || o.status === 'PICKING_UP' || o.status === 'READY_FOR_PICKUP_FACTURE').length
  const completedOrders = filteredOrders.filter(o => o.status === 'COMPLETED').length
  const cancelledOrders = filteredOrders.filter(o => o.status === 'CANCELLED').length

  const getPct = (val: number) => totalOrders === 0 ? 0 : Math.round((val / totalOrders) * 100)

  // Distinct KPI cards: Admin gets (Total Driver, Total Invoice, Total Mitra, Perlu Dispatch)
  // Mitra gets (Total Order, Total Invoice, Sedang Dikirim, Selesai Diantar)
  const kpiCards = isMitra ? [
    { title: 'Total Order', value: totalOrders, icon: ShoppingBag, subtitle: 'Total titik alamat order', growth: 15.3, positive: true },
    { title: 'Total Invoice', value: totalInvoices, icon: FileText, subtitle: 'Total lembar invoice', growth: 12.4, positive: true },
    { title: 'Sedang Dikirim', value: activeDispatch, icon: Truck, subtitle: 'Dalam pengantaran', growth: 8.5, positive: true },
    { title: 'Selesai Diantar', value: completedOrders, icon: CheckCircle2, subtitle: 'Telah diterima apotek', growth: 95.0, positive: true },
  ] : [
    { title: 'Total Driver', value: totalDrivers, icon: Truck, subtitle: 'Aktif saat ini', growth: 8.2, positive: true },
    { title: 'Total Invoice', value: totalInvoices, icon: FileText, subtitle: 'Total lembar invoice', growth: 12.4, positive: true },
    { title: 'Total Mitra', value: totalMitra, icon: Store, subtitle: 'Apotek mitra terdaftar', growth: 15.3, positive: true },
    { title: 'Perlu Dispatch', value: pendingDispatch, icon: AlertCircle, subtitle: 'Menunggu penugasan', isLive: true },
  ]

  const pieData = [
    { name: 'Menunggu Dispatch', value: pendingDispatch, color: '#f59e0b' },
    { name: 'Sedang Dikirim', value: activeDispatch, color: '#3b82f6' },
    { name: 'Selesai Diantar', value: completedOrders, color: '#10b981' },
    { name: 'Dibatalkan / Retur', value: cancelledOrders, color: '#ef4444' },
  ]
  const hasPieData = pendingDispatch > 0 || activeDispatch > 0 || completedOrders > 0 || cancelledOrders > 0
  const pieDataWithFallback = hasPieData
    ? pieData.filter(d => d.value > 0)
    : [{ name: 'Tidak Ada Order', value: 1, color: '#e2e8f0' }]

  const performanceData = [
    { name: '8 Jul', selesai: 1, dikirim: 3 },
    { name: '9 Jul', selesai: 2, dikirim: 3 },
    { name: '10 Jul', selesai: 4, dikirim: 6 },
    { name: '11 Jul', selesai: 6, dikirim: 8 },
    { name: '12 Jul', selesai: 3, dikirim: 5 },
    { name: '13 Jul', selesai: 4, dikirim: 5 },
    { name: '14 Jul', selesai: 2, dikirim: 4 },
  ]

  return (
    <DashboardShell onRefresh={fetchData}>
      {/* Ringkasan Dashboard Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Ringkasan Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Status, pertumbuhan, dan logistik pengiriman apotek saat ini.</p>
        </div>
        
        <div className="flex items-center gap-2 bg-card border border-border px-3 py-1.5 rounded-xl self-start md:self-auto shadow-xs text-xs font-semibold text-foreground">
          <Calendar className="h-4 w-4 text-blue-600 dark:text-blue-400 shrink-0" />
          <span className="text-muted-foreground hidden sm:inline">Periode:</span>
          <select
            value={periodFilter}
            onChange={(e) => setPeriodFilter(e.target.value as any)}
            className="bg-transparent outline-none cursor-pointer font-bold text-foreground pr-1"
          >
            <option value="all">Semua Waktu</option>
            <option value="day">Hari Ini (Daily)</option>
            <option value="week">Minggu Ini (Weekly)</option>
            <option value="month">Bulan Ini (Monthly)</option>
            <option value="year">Tahun Ini (Yearly)</option>
          </select>
        </div>
      </div>

      {/* ─── KPI Stats Row (Total Driver, Mitra Apotek, Total Invoice, Perlu Dispatch) ─── */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-8">
        {kpiCards.map((card) => {
          const Icon = card.icon
          return (
            <div key={card.title} className="rounded-2xl border border-border bg-card p-5 shadow-sm flex items-center justify-between hover:shadow-md transition-shadow">
              <div className="flex items-center gap-4">
                <div className="flex h-12 w-12 items-center justify-center rounded-full bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 shrink-0">
                  <Icon className="h-6 w-6" />
                </div>
                <div>
                  <p className="text-xs text-muted-foreground font-semibold">{card.title}</p>
                  <h4 className="text-2xl font-extrabold text-foreground mt-0.5">
                    {loading ? <span className="animate-pulse">...</span> : card.value}
                  </h4>
                  <p className="text-[10px] text-muted-foreground mt-0.5">{card.subtitle}</p>
                </div>
              </div>
              <div>
                {card.isLive ? (
                  <span className="inline-flex items-center gap-1 rounded-full bg-orange-50 text-orange-700 dark:bg-orange-950/20 dark:text-orange-400 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider">
                    <span className="h-1.5 w-1.5 rounded-full bg-orange-500 animate-pulse" />
                    Live
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 rounded-full bg-emerald-50 text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400 px-2 py-0.5 text-[10px] font-bold">
                    <TrendingUp className="h-3 w-3" />
                    +{card.growth}%
                  </span>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {/* ─── Detail Pengantaran Logistik (Delivery Cards) Section ─── */}
      <div className="mb-8">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
          <div>
            <h3 className="font-extrabold text-lg tracking-tight text-foreground flex items-center gap-2">
              <PackageCheck className="h-5 w-5 text-blue-600 dark:text-blue-400" />
              Detail Pengantaran Logistik
            </h3>
            <p className="text-xs text-muted-foreground mt-0.5">Rincian status pengantaran, lokasi apotek, dan verifikasi invoice real-time.</p>
          </div>
          <button
            onClick={() => router.push('/dashboard/detail-pengantaran')}
            className="inline-flex items-center gap-2 text-xs font-bold text-blue-600 hover:text-blue-700 dark:text-blue-400 border border-blue-200 dark:border-blue-900/60 bg-blue-50/50 hover:bg-blue-100/50 dark:bg-blue-950/20 px-3.5 py-2 rounded-xl transition-all shadow-xs cursor-pointer"
          >
            <span>Detail Pengantaran</span>
            <ArrowRight className="h-3.5 w-3.5" />
          </button>
        </div>

        <div className="bg-card border border-border rounded-2xl p-5 shadow-xs overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-muted/40 text-[11px] font-bold uppercase tracking-wider text-muted-foreground border-b border-border">
                  <th className="py-3.5 px-4">INVOICE</th>
                  <th className="py-3.5 px-4">APOTEK</th>
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
                    <td colSpan={7} className="py-8 text-center text-muted-foreground">
                      Memuat data pengantaran...
                    </td>
                  </tr>
                ) : invoices.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="py-8 text-center text-muted-foreground">
                      Belum ada data detail pengantaran.
                    </td>
                  </tr>
                ) : (
                  invoices.slice(0, 10).map((row, idx) => {
                    const isAman = row.status === 'DONE'
                    const isMissing = row.status === 'MISSING'

                    return (
                      <tr key={`${row.invoice_no}-${idx}`} className="hover:bg-muted/30 transition-colors">
                        {/* INVOICE */}
                        <td className="py-3.5 px-4 font-bold text-blue-600 dark:text-blue-400">
                          #{row.invoice_no}
                        </td>

                        {/* APOTEK */}
                        <td className="py-3.5 px-4">
                          <div className="font-bold text-foreground">{row.nama_apotek}</div>
                          <span className="text-[10px] text-muted-foreground">{row.dispatch_id || '-'}</span>
                        </td>

                        {/* DRIVER */}
                        <td className="py-3.5 px-4">
                          <div className="flex items-center gap-2">
                            <div className="h-6 w-6 rounded-full bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-300 flex items-center justify-center text-[10px] font-bold">
                              {row.driver_name ? row.driver_name[0].toUpperCase() : 'D'}
                            </div>
                            <span className="font-semibold text-foreground">{row.driver_name || 'Belum di-assign'}</span>
                          </div>
                        </td>

                        {/* JAM PICKUP */}
                        <td className="py-3.5 px-4 text-muted-foreground">
                          <div className="font-semibold text-foreground">
                            {new Date(row.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}
                          </div>
                          <span className="text-[10px]">
                            {new Date(row.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}
                          </span>
                        </td>

                        {/* JAM SELESAI */}
                        <td className="py-3.5 px-4 text-muted-foreground">
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
                        <td className="py-3.5 px-4">
                          {isAman ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-900/50 text-[10px] font-bold">
                              <CheckCircle2 className="h-3 w-3" />
                              Aman
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-red-50 text-red-700 dark:bg-red-950/40 dark:text-red-400 border border-red-200 dark:border-red-900/50 text-[10px] font-bold">
                              <AlertCircle className="h-3 w-3" />
                              Bermasalah
                            </span>
                          )}
                        </td>

                        {/* CATATAN INVOICE */}
                        <td className="py-3.5 px-4 text-right">
                          {isAman ? (
                            <span className="inline-block px-2 py-0.5 rounded-md bg-emerald-100/70 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 text-[11px] font-semibold">
                              {row.catatan || 'Done'}
                            </span>
                          ) : (
                            <span className="inline-block px-2 py-0.5 rounded-md bg-red-100/80 text-red-900 dark:bg-red-950/80 dark:text-red-200 text-[11px] font-semibold max-w-[180px] truncate" title={row.catatan}>
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
        </div>
      </div>

      {/* ─── Operational Maps & Status Charts Section ─── */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 mb-6">
        {/* Column 1: Status Pengiriman Logistik */}
        <div className="lg:col-span-6 bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex justify-between items-center gap-4 mb-1">
              <h3 className="font-bold text-base text-foreground">Status Pengiriman Logistik</h3>
              <div className="relative">
                <select className="h-8 rounded-lg border border-border bg-background pl-3 pr-8 text-xs font-semibold outline-none appearance-none cursor-pointer">
                  <option>Semua Armada</option>
                </select>
                <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 h-3 w-3 text-muted-foreground" />
              </div>
            </div>
            <p className="text-xs text-muted-foreground mb-6">Matriks status pengiriman sub-order apotek mitra secara real-time.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-center">
            {/* Doughnut Chart */}
            <div className="md:col-span-5 relative flex items-center justify-center h-[160px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={pieDataWithFallback}
                    innerRadius={50}
                    outerRadius={68}
                    paddingAngle={hasPieData ? 3 : 0}
                    dataKey="value"
                  >
                    {pieDataWithFallback.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
              <div className="absolute text-center">
                <p className="text-[9px] text-muted-foreground font-bold uppercase tracking-wider leading-none">Total</p>
                <p className="text-2xl font-black text-foreground mt-0.5 leading-none">{totalOrders}</p>
                <p className="text-[9px] text-muted-foreground font-bold uppercase tracking-wider mt-0.5 leading-none">Order</p>
              </div>
            </div>

            {/* Doughnut Progress Legends */}
            <div className="md:col-span-7 space-y-3.5">
              {[
                { label: 'Menunggu Dispatch', val: pendingDispatch, pct: getPct(pendingDispatch), color: 'bg-amber-500' },
                { label: 'Sedang Dikirim', val: activeDispatch, pct: getPct(activeDispatch), color: 'bg-blue-500' },
                { label: 'Selesai Diantar', val: completedOrders, pct: getPct(completedOrders), color: 'bg-emerald-500' },
                { label: 'Dibatalkan / Retur', val: cancelledOrders, pct: getPct(cancelledOrders), color: 'bg-red-500' },
              ].map((item) => (
                <div key={item.label} className="space-y-1">
                  <div className="flex items-center justify-between text-[11px] font-bold">
                    <span className="flex items-center gap-2">
                      <span className={`h-2 w-2 rounded-full ${item.color}`} />
                      <span className="text-muted-foreground">{item.label}</span>
                    </span>
                    <div className="flex items-center gap-3">
                      <span className="text-foreground">{item.val} Order</span>
                      <span className="text-muted-foreground w-6 text-right">{item.pct}%</span>
                    </div>
                  </div>
                  <div className="h-1.5 w-full rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                    <div className={`h-full rounded-full ${item.color}`} style={{ width: `${item.pct}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Column 2: Peta Operasional Pengiriman */}
        <div className="lg:col-span-6 bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col">
          <div className="flex justify-between items-center mb-1">
            <h3 className="font-bold text-base text-foreground">Peta Operasional Pengiriman</h3>
            <button
              onClick={() => router.push('/dashboard/orders')}
              className="inline-flex items-center gap-1.5 text-xs font-semibold text-blue-600 hover:text-blue-500 border border-blue-200 dark:border-blue-900/60 hover:bg-blue-50 px-3 py-1.5 rounded-lg transition-colors bg-white dark:bg-slate-950"
            >
              <Map className="h-3.5 w-3.5" /> Lihat Semua
            </button>
          </div>
          <p className="text-xs text-muted-foreground mb-4">Visualisasi pergerakan driver dan lokasi pengiriman saat ini.</p>

          <div className="relative w-full h-[200px] rounded-xl border border-border overflow-hidden shadow-inner flex-1 bg-slate-50 dark:bg-slate-900/30">
            <div id="map-container" className="absolute inset-0 w-full h-full z-0" />

            <div className="absolute right-3 top-3 bottom-3 w-[150px] bg-white/95 dark:bg-slate-950/95 backdrop-blur-sm rounded-xl border border-border/80 p-3 shadow-md flex flex-col overflow-hidden z-[1000]">
              <p className="text-[9px] font-bold text-foreground uppercase tracking-wider mb-2">Driver Aktif</p>
              <div className="space-y-2 flex-1 overflow-y-auto pr-0.5 dashboard-scroll">
                {drivers.slice(0, 4).map((drv) => (
                  <div key={drv.id} className="flex items-center gap-1.5 text-[9px]">
                    <div className="h-5 w-5 rounded-full bg-blue-50 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400 font-bold flex items-center justify-center shrink-0">
                      {drv.name[0].toUpperCase()}
                    </div>
                    <div className="min-w-0">
                      <p className="font-bold truncate text-foreground leading-tight">{drv.name}</p>
                      <p className="text-[8px] text-muted-foreground flex items-center gap-0.5 mt-0.5">
                        <span className={`h-1 w-1 rounded-full ${drv.is_active ? 'bg-emerald-500 animate-pulse' : 'bg-slate-400'}`} />
                        {drv.is_active ? 'Sedang Kirim' : 'Ready'}
                      </p>
                    </div>
                  </div>
                ))}
                {drivers.length === 0 && (
                  <p className="text-[8px] text-muted-foreground text-center py-4">Tidak ada driver</p>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ─── Bottom Section Grid ─── */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Column 1: Performa Pengiriman Line Chart */}
        <div className="lg:col-span-5 bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex justify-between items-center gap-4 mb-1">
              <h3 className="font-bold text-base text-foreground">Performa Pengiriman</h3>
              <div className="relative">
                <select className="h-8 rounded-lg border border-border bg-background pl-3 pr-8 text-xs font-semibold outline-none appearance-none cursor-pointer">
                  <option>7 Hari Terakhir</option>
                </select>
                <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 h-3 w-3 text-muted-foreground" />
              </div>
            </div>
            <p className="text-xs text-muted-foreground mb-4">Perbandingan order dalam 7 hari terakhir.</p>
          </div>

          <div className="h-[200px] w-full mt-2">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={performanceData} margin={{ top: 5, right: 5, left: -25, bottom: 5 }}>
                <CartesianGrid strokeDasharray="3 3" strokeOpacity={0.1} />
                <XAxis dataKey="name" stroke="#888888" fontSize={9} tickLine={false} axisLine={false} />
                <YAxis stroke="#888888" fontSize={9} tickLine={false} axisLine={false} />
                <Tooltip contentStyle={{ background: 'hsl(var(--card))', border: '1px solid hsl(var(--border))', borderRadius: '8px', fontSize: '10px' }} />
                <Line type="monotone" dataKey="selesai" stroke="#10b981" strokeWidth={2} dot={{ r: 2 }} activeDot={{ r: 4 }} name="Order Selesai" />
                <Line type="monotone" dataKey="dikirim" stroke="#3b82f6" strokeWidth={2} dot={{ r: 2 }} activeDot={{ r: 4 }} name="Order Dikirim" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Column 2: Ringkasan Order Table */}
        <div className="lg:col-span-7 bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between">
          <div>
            <div className="flex justify-between items-center gap-4 mb-1">
              <h3 className="font-bold text-base text-foreground">Order Terbaru</h3>
              <button
                onClick={() => router.push('/dashboard/orders')}
                className="inline-flex items-center gap-1.5 text-xs font-semibold text-blue-600 hover:text-blue-500 border border-blue-200 dark:border-blue-900/60 hover:bg-blue-50 px-3 py-1.5 rounded-lg transition-colors bg-white dark:bg-slate-950"
              >
                Lihat Semua
              </button>
            </div>
            <p className="text-xs text-muted-foreground mb-4">Daftar order terbaru yang sedang diproses.</p>
          </div>

          <div className="overflow-x-auto overflow-hidden rounded-xl border border-border shadow-sm mb-4">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-border bg-muted/40 font-bold text-muted-foreground">
                  <th className="px-4 py-2.5">DISPATCH ID</th>
                  <th className="px-4 py-2.5">STATUS</th>
                  <th className="px-4 py-2.5">DRIVER</th>
                  <th className="px-4 py-2.5">ALAMAT</th>
                  <th className="px-4 py-2.5">DIBUAT</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {orders.slice(0, 2).map((o) => {
                  const sc = STATUS_CONFIG[o.status] || { label: o.status, color: 'bg-muted text-muted-foreground' }
                  return (
                    <tr key={o.dispatch_id} className="hover:bg-muted/10 transition-colors">
                      <td className="px-4 py-3 font-bold text-blue-600 font-mono">{o.dispatch_id}</td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold ${sc.color}`}>
                          <span className="h-1 w-1 rounded-full bg-current" />
                          {sc.label}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <div className="h-6 w-6 rounded-full bg-blue-100 dark:bg-blue-950 text-blue-600 dark:text-blue-400 font-bold text-[10px] flex items-center justify-center shrink-0">
                            {o.driver_name ? o.driver_name[0].toUpperCase() : 'U'}
                          </div>
                          <span className="font-semibold">{o.driver_name || 'Unassigned'}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-col gap-0.5 max-w-[160px]">
                          <span className="truncate text-muted-foreground" title={o.addresses}>{o.addresses || '—'}</span>
                          <span className="text-[8px] font-bold text-slate-500 uppercase">{o.stop_count} Titik</span>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground whitespace-nowrap">
                        <div className="flex flex-col text-[10px]">
                          <span>{new Date(o.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}</span>
                          <span className="text-[8px] mt-0.5">{new Date(o.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })} WIB</span>
                        </div>
                      </td>
                    </tr>
                  )
                })}
                {orders.length === 0 && (
                  <tr>
                    <td colSpan={5} className="text-center py-6 text-muted-foreground italic">Tidak ada order saat ini.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex items-center justify-between text-[10px] text-muted-foreground font-semibold px-1">
            <span>Menampilkan {Math.min(orders.length, 2)} dari {orders.length} order</span>
            <div className="flex items-center gap-2">
              <button className="h-6 w-6 flex items-center justify-center rounded border border-border bg-card text-muted-foreground disabled:opacity-50" disabled>
                <ChevronLeft className="h-3.5 w-3.5" />
              </button>
              <button className="h-6 w-6 flex items-center justify-center rounded border border-blue-500 bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400 font-bold">
                1
              </button>
              <button className="h-6 w-6 flex items-center justify-center rounded border border-border bg-card text-muted-foreground disabled:opacity-50" disabled>
                <ChevronRight className="h-3.5 w-3.5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </DashboardShell>
  )
}
