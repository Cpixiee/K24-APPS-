'use client'

import { useState, useEffect, useCallback, use } from 'react'
import Link from 'next/link'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import LiveTrackingMap, { TrackingDriver, TrackingStop } from '@/components/tracking/LiveTrackingMap'
import { ArrowLeft, RefreshCw, Navigation, Truck, MapPin, CheckCircle2, Clock, ShieldCheck, AlertCircle } from 'lucide-react'

interface TrackingData {
  dispatch_number: string
  status: string
  total_distance_km: number
  total_argo: number
  driver: TrackingDriver
  pharmacy_name: string
  pharmacy_address: string
  pharmacy_lat: number
  pharmacy_lng: number
  stops: TrackingStop[]
}

export default function DispatchTrackingPage({ params }: { params: Promise<{ dispatchId: string }> }) {
  const { dispatchId } = use(params)

  const [data, setData] = useState<TrackingData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date())
  const [formattedTime, setFormattedTime] = useState<string>('')

  useEffect(() => {
    setFormattedTime(lastUpdated.toLocaleTimeString('id-ID'))
  }, [lastUpdated])

  const fetchTracking = useCallback(async (isInitial = false) => {
    if (isInitial) setLoading(true)
    setError(null)
    try {
      const res = await adminAPI.getDispatchLiveTracking(dispatchId)
      if (res.data?.data) {
        setData(res.data.data)
        const now = new Date()
        setLastUpdated(now)
        setFormattedTime(now.toLocaleTimeString('id-ID'))
      }
    } catch (err: any) {
      console.error('[fetchTracking Error]:', err)
      setError(err.response?.data?.message || err.message || 'Gagal memuat data live tracking.')
    } finally {
      setLoading(false)
    }
  }, [dispatchId])

  useEffect(() => {
    fetchTracking(true)

    // Poll live location every 15 seconds while tab is active
    const interval = setInterval(() => {
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
        fetchTracking(false)
      }
    }, 15000)

    return () => clearInterval(interval)
  }, [fetchTracking])

  return (
    <DashboardShell onRefresh={() => fetchTracking(true)}>
      <div className="mb-6 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link
            href="/dashboard/dispatch"
            className="h-9 w-9 rounded-xl border border-border bg-background hover:bg-accent flex items-center justify-center text-foreground transition-colors shrink-0"
          >
            <ArrowLeft className="h-4 w-4" />
          </Link>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-bold tracking-tight text-foreground">Live Tracking Driver</h1>
              <span className="font-mono text-xs px-2.5 py-0.5 rounded-full bg-blue-100 dark:bg-blue-950/40 text-blue-700 dark:text-blue-300 font-bold border border-blue-200 dark:border-blue-900">
                {dispatchId}
              </span>
            </div>
            <p className="text-xs text-muted-foreground mt-0.5">
              Pantau lokasi live driver & status 10+ titik antar secara real-time.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3 self-start md:self-auto">
          <div className="text-right text-xs text-muted-foreground hidden sm:block">
            <span>Auto update: <strong className="text-emerald-600 dark:text-emerald-400">Setiap 15s</strong></span>
            <span className="block text-[10px]">{formattedTime ? `Terakhir: ${formattedTime}` : ''}</span>
          </div>
          <button
            onClick={() => fetchTracking(false)}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-xl border border-border bg-background hover:bg-accent text-foreground transition-colors"
          >
            <RefreshCw className="h-3.5 w-3.5" /> Refresh
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3">
          <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
          <p className="text-sm text-muted-foreground">Memuat peta live tracking...</p>
        </div>
      ) : error || !data ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-border bg-card py-16 gap-3 text-center p-6">
          <AlertCircle className="h-10 w-10 text-red-500" />
          <h3 className="font-semibold text-foreground">Data Live Tracking Tidak Tersedia</h3>
          <p className="text-sm text-muted-foreground max-w-md">{error || 'Pesanan belum memiliki driver atau belum di-dispatch.'}</p>
        </div>
      ) : (
        <div className="space-y-6">
          {/* Driver & Batch Summary Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Driver Live Info */}
            <div className="rounded-2xl border border-border bg-card p-4 shadow-sm flex items-center gap-4">
              <div className="h-12 w-12 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 text-white flex items-center justify-center text-xl shrink-0 shadow-md">
                {data.driver.vehicle_type === 'mobil' ? '🚗' : '🏍️'}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between gap-1">
                  <h3 className="font-bold text-foreground truncate">{data.driver.name}</h3>
                  <span className="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" /> Live
                  </span>
                </div>
                <p className="text-xs font-mono text-muted-foreground">{data.driver.plate_number || 'Plat Kendaraan'}</p>
                <div className="flex items-center gap-2 mt-1 text-[11px] text-muted-foreground">
                  <span>📞 {data.driver.phone}</span>
                </div>
              </div>
            </div>

            {/* Pickup Pharmacy Info */}
            <div className="rounded-2xl border border-border bg-card p-4 shadow-sm flex items-center gap-4">
              <div className="h-12 w-12 rounded-xl bg-emerald-100 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-400 flex items-center justify-center text-xl shrink-0">
                🏥
              </div>
              <div className="flex-1 min-w-0">
                <span className="text-[10px] uppercase font-bold tracking-wider text-emerald-600 dark:text-emerald-400">Apotek Pengirim</span>
                <h3 className="font-bold text-foreground truncate text-xs mt-0.5">{data.pharmacy_name}</h3>
                <p className="text-[11px] text-muted-foreground truncate">{data.pharmacy_address}</p>
              </div>
            </div>

            {/* Delivery Stats */}
            <div className="rounded-2xl border border-border bg-card p-4 shadow-sm flex items-center justify-center text-center">
              <div>
                <span className="text-xs text-muted-foreground block">Total Titik Antar</span>
                <span className="text-lg font-bold text-foreground">{data.stops.length} Alamat</span>
              </div>
            </div>
          </div>

          {/* Interactive Live Map */}
          <LiveTrackingMap
            driver={data.driver}
            pharmacyName={data.pharmacy_name}
            pharmacyAddress={data.pharmacy_address}
            pharmacyLat={data.pharmacy_lat}
            pharmacyLng={data.pharmacy_lng}
            stops={data.stops}
          />

          {/* Sequential Stops Timeline List */}
          <div className="rounded-2xl border border-border bg-card p-6 shadow-sm">
            <h3 className="font-bold text-foreground mb-4 flex items-center gap-2">
              <Navigation className="h-4 w-4 text-blue-500" />
              Rincian Urutan Pengantaran ({data.stops.length} Titik Antar)
            </h3>

            <div className="space-y-4">
              {data.stops.map((stop, idx) => {
                const isCompleted = stop.status === 'COMPLETED'
                const isDelivering = stop.status === 'DELIVERING' || stop.status === 'PICKING_UP'

                return (
                  <div
                    key={stop.order_id}
                    className={`flex items-start gap-4 p-4 rounded-xl border transition-all ${
                      isDelivering
                        ? 'border-blue-500/50 bg-blue-50/50 dark:bg-blue-950/20 shadow-sm'
                        : isCompleted
                        ? 'border-emerald-200 dark:border-emerald-900/40 bg-emerald-50/30 dark:bg-emerald-950/10'
                        : 'border-border bg-background/50'
                    }`}
                  >
                    <div
                      className={`flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold shrink-0 text-white ${
                        isCompleted
                          ? 'bg-emerald-500'
                          : isDelivering
                          ? 'bg-blue-600 ring-4 ring-blue-100 dark:ring-blue-900/40'
                          : 'bg-slate-500'
                      }`}
                    >
                      {stop.sequence_number || idx + 1}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
                        <h4 className="font-bold text-sm text-foreground truncate">{stop.customer_name}</h4>
                        <span
                          className={`self-start sm:self-auto text-[10px] font-bold px-2.5 py-0.5 rounded-full ${
                            isCompleted
                              ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300'
                              : isDelivering
                              ? 'bg-blue-100 text-blue-800 dark:bg-blue-950/40 dark:text-blue-300 animate-pulse'
                              : 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'
                          }`}
                        >
                          {isCompleted ? '✓ Selesai Terantar' : isDelivering ? '🚚 Sedang Diantar' : '⏳ Menunggu Queue'}
                        </span>
                      </div>

                      <p className="text-xs text-muted-foreground mt-1 flex items-start gap-1">
                        <MapPin className="h-3.5 w-3.5 text-muted-foreground shrink-0 mt-0.5" />
                        {stop.delivery_address}
                      </p>

                      {stop.invoices && stop.invoices.length > 0 && (
                        <div className="mt-2 flex flex-wrap items-center gap-1.5">
                          <span className="text-[10px] font-semibold text-muted-foreground">Faktur:</span>
                          {stop.invoices.map((inv, i) => (
                            <span key={i} className="font-mono text-[10px] bg-muted px-2 py-0.5 rounded border border-border text-foreground">
                              {inv}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      )}
    </DashboardShell>
  )
}
