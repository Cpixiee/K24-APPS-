'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import { Search, AlertCircle, ArrowRight, ArrowLeft, ArrowUp, ArrowDown, Truck, Loader2, CheckCircle, GripVertical, Layers } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Stop {
  id: number
  order_number: string
  customer_name: string
  delivery_address: string
  armada?: string
  rate_type?: string
  mitra_name?: string
  mitra_id?: number
  parent_order_number?: string
  dispatch_id?: string
  lat?: number
  lng?: number
}

interface DispatchCard {
  id: string
  title: string
  stops: Stop[]
}

interface Batch {
  dispatch_id: string
  mitra_name: string
  mitra_id: number
  armada: string
  rate_type: string
  stops: Stop[]
}

interface Driver {
  id: number
  name: string
  username: string
  plate_number?: string
  is_active: boolean
  vehicle_type?: string
}

export default function DispatchPage() {
  const [step, setStep] = useState(0)
  const [batches, setBatches] = useState<Batch[]>([])
  const [loadingOrders, setLoadingOrders] = useState(true)
  const [selectedStopIds, setSelectedStopIds] = useState<number[]>([])
  const [mitraFilter, setMitraFilter] = useState('ALL')
  const [armadaFilter, setArmadaFilter] = useState<'ALL' | 'MOTOR' | 'MOBIL'>('ALL')
  const [searchQuery, setSearchQuery] = useState('')

  const [cards, setCards] = useState<DispatchCard[]>([])

  const [drivers, setDrivers] = useState<Driver[]>([])
  const [loadingDrivers, setLoadingDrivers] = useState(false)
  const [selectedDriver, setSelectedDriver] = useState<Driver | null>(null)
  const [driverSearch, setDriverSearch] = useState('')
  const [driverVehicleTab, setDriverVehicleTab] = useState<'ALL' | 'MOTOR' | 'MOBIL'>('ALL')

  const [sequence, setSequence] = useState<Stop[]>([])
  const [submitting, setSubmitting] = useState(false)

  const fetchPending = useCallback(async () => {
    setLoadingOrders(true)
    try {
      const res = await adminAPI.getPendingDispatchOrders()
      setBatches(res.data.data || res.data || [])
    } catch { toast.error('Gagal mengambil daftar order menunggu dispatch') }
    finally { setLoadingOrders(false) }
  }, [])

  useEffect(() => { fetchPending() }, [fetchPending])

  // Flatten batches to individual stops
  const allStops = useMemo(() => {
    const stops: Stop[] = []
    batches.forEach((b) => {
      ;(b.stops || []).forEach((s) => {
        stops.push({
          ...s,
          armada: b.armada,
          rate_type: b.rate_type,
          mitra_name: b.mitra_name,
          mitra_id: b.mitra_id,
          dispatch_id: b.dispatch_id,
        })
      })
    })
    return stops
  }, [batches])

  const filteredStops = useMemo(() => {
    return allStops.filter((s) => {
      const matchMitra = mitraFilter === 'ALL' || s.mitra_name === mitraFilter
      const matchArmada = armadaFilter === 'ALL' || s.armada?.toUpperCase() === armadaFilter
      const q = searchQuery.toLowerCase()
      const matchSearch =
        s.order_number?.toLowerCase().includes(q) ||
        s.customer_name?.toLowerCase().includes(q) ||
        s.delivery_address?.toLowerCase().includes(q) ||
        s.dispatch_id?.toLowerCase().includes(q)
      return matchMitra && matchArmada && matchSearch
    })
  }, [allStops, mitraFilter, armadaFilter, searchQuery])

  // ─── Proximity Clustering ───────────────────────────────────────────
  // Haversine formula: distance in km between two lat/lng points
  const haversineKm = (lat1: number, lng1: number, lat2: number, lng2: number): number => {
    const R = 6371
    const dLat = ((lat2 - lat1) * Math.PI) / 180
    const dLng = ((lng2 - lng1) * Math.PI) / 180
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2)
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  }

  // Group stops into clusters of max `maxSize` by nearest-neighbor proximity.
  // Stops with no coordinates (lat=0, lng=0) are bucketed by parent_order_number instead.
  const clusterByProximity = (stops: Stop[], maxSize = 4): Stop[][] => {
    const withCoords = stops.filter((s) => (s.lat ?? 0) !== 0 || (s.lng ?? 0) !== 0)
    const noCoords = stops.filter((s) => (s.lat ?? 0) === 0 && (s.lng ?? 0) === 0)

    const clusters: Stop[][] = []
    const assigned = new Set<number>()

    for (let i = 0; i < withCoords.length; i++) {
      const seed = withCoords[i]
      if (assigned.has(seed.id)) continue

      const cluster: Stop[] = [seed]
      assigned.add(seed.id)

      // Build a sorted list of unassigned neighbours by distance from seed
      const neighbours = withCoords
        .filter((s) => !assigned.has(s.id))
        .map((s) => ({ stop: s, dist: haversineKm(seed.lat!, seed.lng!, s.lat!, s.lng!) }))
        .sort((a, b) => a.dist - b.dist)

      for (const { stop } of neighbours) {
        if (cluster.length >= maxSize) break
        if (!assigned.has(stop.id)) {
          cluster.push(stop)
          assigned.add(stop.id)
        }
      }
      clusters.push(cluster)
    }

    // Fallback: group no-coord stops by parent_order_number, max maxSize each
    const noCoordGroups = new Map<string, Stop[]>()
    noCoords.forEach((s) => {
      const key = s.parent_order_number || s.order_number
      if (!noCoordGroups.has(key)) noCoordGroups.set(key, [])
      noCoordGroups.get(key)!.push(s)
    })
    noCoordGroups.forEach((group) => {
      for (let i = 0; i < group.length; i += maxSize) {
        clusters.push(group.slice(i, i + maxSize))
      }
    })

    return clusters
  }

  // Re-generate default cards using proximity clustering
  useEffect(() => {
    if (filteredStops.length === 0) {
      setCards([])
      return
    }

    const clusters = clusterByProximity(filteredStops, 4)
    const newCards: DispatchCard[] = clusters.map((cluster, idx) => {
      const armadaTag = cluster[0]?.armada?.toUpperCase() === 'MOBIL' ? '🚗 MOBIL' : '🛵 MOTOR'
      return {
        id: `card-cluster-${idx}-${cluster[0]?.id}`,
        title: `Card Cluster #${idx + 1} (${armadaTag} — ${cluster.length} Alamat)`,
        stops: cluster,
      }
    })
    setCards(newCards)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filteredStops])

  const filteredDrivers = useMemo(() => {
    const q = driverSearch.toLowerCase()
    return drivers.filter((d) => {
      const matchSearch = d.name?.toLowerCase().includes(q) || d.username?.toLowerCase().includes(q) || (d.plate_number || '').toLowerCase().includes(q)
      const matchTab = driverVehicleTab === 'ALL' || d.vehicle_type?.toUpperCase() === driverVehicleTab
      return matchSearch && matchTab
    })
  }, [drivers, driverSearch, driverVehicleTab])

  const uniqueMitras = useMemo(() => ['ALL', ...Array.from(new Set(allStops.map((s) => s.mitra_name).filter(Boolean)))], [allStops])

  const selectedInfo = useMemo(() => {
    if (selectedStopIds.length === 0) return { isValid: true, armada: null, stops: [] as Stop[] }
    const sel = allStops.filter((s) => selectedStopIds.includes(s.id))
    const firstArmada = sel[0]?.armada
    const allSame = sel.every((s) => s.armada === firstArmada)
    return { isValid: allSame, armada: firstArmada, stops: sel }
  }, [selectedStopIds, allStops])

  const handleToggleStop = (id: number) => {
    setSelectedStopIds((p) => p.includes(id) ? p.filter((x) => x !== id) : [...p, id])
  }

  const handleToggleCard = (cardStops: Stop[]) => {
    const cardIds = cardStops.map((s) => s.id)
    const allSelected = cardIds.every((id) => selectedStopIds.includes(id))
    if (allSelected) {
      // Unselect all stops in card
      setSelectedStopIds((p) => p.filter((id) => !cardIds.includes(id)))
    } else {
      // Select all stops in card
      setSelectedStopIds((p) => Array.from(new Set([...p, ...cardIds])))
    }
  }

  const handleSelectAllStops = (checked: boolean) => {
    if (checked) {
      const types = new Set(filteredStops.map((s) => s.armada))
      if (types.size > 1) toast.warning('Perhatian: Terdapat pesanan dengan armada berbeda dalam filter saat ini.')
      setSelectedStopIds(filteredStops.map((s) => s.id))
    } else {
      setSelectedStopIds([])
    }
  }

  // Drag and drop handlers
  const handleDragStart = (e: React.DragEvent, stopId: number, cardId: string) => {
    e.dataTransfer.setData('application/json', JSON.stringify({ stopId, sourceCardId: cardId }))
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
  }

  const handleDrop = (e: React.DragEvent, targetCardId: string) => {
    e.preventDefault()
    try {
      const dataStr = e.dataTransfer.getData('application/json')
      if (!dataStr) return
      const { stopId, sourceCardId } = JSON.parse(dataStr) as { stopId: number; sourceCardId: string }
      if (sourceCardId === targetCardId) return

      let movedStop: Stop | null = null

      setCards((prevCards) => {
        const next = prevCards.map((card) => {
          if (card.id === sourceCardId) {
            movedStop = card.stops.find((s) => s.id === stopId) || null
            return { ...card, stops: card.stops.filter((s) => s.id !== stopId) }
          }
          return card
        })

        if (!movedStop) return prevCards

        return next.map((card) => {
          if (card.id === targetCardId) {
            return { ...card, stops: [...card.stops, movedStop!] }
          }
          return card
        })
      })

      toast.info('Alamat berhasil dipindahkan ke Card rute baru')
    } catch (_) {}
  }

  const handleProceedToDriver = async () => {
    if (selectedStopIds.length === 0) { toast.warning('Pilih minimal 1 alamat tujuan untuk di-dispatch.'); return }
    if (!selectedInfo.isValid) { toast.error('Armada pesanan yang dipilih harus seragam (Motor atau Mobil saja).'); return }
    setLoadingDrivers(true)
    setStep(1)
    setSelectedDriver(null)
    // Reset tab to match selected order armada
    setDriverVehicleTab((selectedInfo.armada?.toUpperCase() as 'MOTOR' | 'MOBIL') || 'ALL')
    try {
      // Load ALL drivers — client-side tab filter handles MOTOR/MOBIL separation
      const [motorRes, mobilRes] = await Promise.all([
        adminAPI.getDispatchDrivers('motor'),
        adminAPI.getDispatchDrivers('mobil'),
      ])
      const motorDrivers = (motorRes.data.data || motorRes.data || []) as Driver[]
      const mobilDrivers = (mobilRes.data.data || mobilRes.data || []) as Driver[]
      // Merge, deduplicate by ID
      const combined = [...motorDrivers]
      for (const d of mobilDrivers) {
        if (!combined.find((x) => x.id === d.id)) combined.push(d)
      }
      setDrivers(combined)
    } catch { toast.error('Gagal mengambil daftar driver.') }
    finally { setLoadingDrivers(false) }
  }

  const handleProceedToSequence = (driver: Driver) => {
    setSelectedDriver(driver)
    setSequence(selectedInfo.stops)
    if (selectedInfo.stops.length <= 1) {
      executeDispatch(selectedInfo.stops, driver.id)
    } else {
      setStep(2)
    }
  }

  const moveItem = (index: number, dir: number) => {
    const next = index + dir
    if (next < 0 || next >= sequence.length) return
    const arr = [...sequence]
    ;[arr[index], arr[next]] = [arr[next], arr[index]]
    setSequence(arr)
  }

  const executeDispatch = async (finalSeq: Stop[], driverId: number) => {
    setSubmitting(true)
    try {
      const ids = finalSeq.map((s) => s.id)
      await adminAPI.createDispatchGroup({ order_ids: ids, driver_id: driverId, sequence: ids })
      toast.success('Dispatch berhasil diselesaikan!')
      setSelectedStopIds([]); setSelectedDriver(null); setSequence([]); setStep(0)
      fetchPending()
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string } } }
      toast.error(axiosErr.response?.data?.message || 'Gagal mengeksekusi dispatching')
    } finally { setSubmitting(false) }
  }

  const inputClass = 'h-10 w-full rounded-lg border border-border bg-background px-3 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 text-foreground'

  return (
    <DashboardShell onRefresh={step === 0 ? fetchPending : undefined}>
      <div className="mb-6">
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Dispatch Operator (OTMS)</h1>
        <p className="text-sm text-muted-foreground mt-1">Penugasan kurir driver dan routing manual pengiriman obat sekuensial.</p>
      </div>

      {/* Step indicator */}
      <div className="flex items-center gap-3 mb-8">
        {['Pilih Card / Alamat Order', 'Pilih Driver', 'Urutan Rute'].map((label, i) => (
          <div key={i} className={`flex items-center gap-2 ${i < 2 ? 'flex-1' : ''}`}>
            <div className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold ${step >= i ? 'bg-blue-600 text-white' : 'bg-muted text-muted-foreground'}`}>{i + 1}</div>
            <span className={`text-xs font-medium hidden sm:block ${step >= i ? 'text-foreground' : 'text-muted-foreground'}`}>{label}</span>
            {i < 2 && <div className={`flex-1 h-px ${step > i ? 'bg-blue-600' : 'bg-border'}`} />}
          </div>
        ))}
      </div>

      {/* ─── STEP 0: Address Selection ─── */}
      {step === 0 && (
        <div>
          {!selectedInfo.isValid && (
            <div className="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 dark:bg-red-950/20 p-4 mb-4 text-red-700 dark:text-red-400 text-sm">
              <AlertCircle className="h-5 w-5 flex-shrink-0" />
              <span><strong>Peringatan:</strong> Alamat yang dipilih memiliki tipe armada berbeda. Samakan jenis armada (Motor saja atau Mobil saja).</span>
            </div>
          )}

          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
            <h2 className="font-semibold text-foreground">Grouping Card Alamat Menunggu Dispatch</h2>
            <button
              disabled={selectedStopIds.length === 0 || !selectedInfo.isValid}
              onClick={handleProceedToDriver}
              className="flex items-center gap-2 h-10 px-5 rounded-lg bg-gradient-to-r from-blue-600 to-slate-700 text-white text-sm font-medium hover:from-blue-700 hover:to-slate-800 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"
            >
              Dispatch {selectedStopIds.length > 0 ? `(${selectedStopIds.length} Alamat)` : 'Item Terpilih'}
              <ArrowRight className="h-4 w-4" />
            </button>
          </div>

          {/* Armada Tabs: [ Semua Armada ] | [ 🛵 MOTOR ] | [ 🚗 MOBIL ] */}
          <div className="flex items-center gap-2 mb-4 bg-muted/40 p-1.5 rounded-2xl border border-border">
            <button
              onClick={() => setArmadaFilter('ALL')}
              className={cn(
                'flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2',
                armadaFilter === 'ALL'
                  ? 'bg-white dark:bg-card text-foreground shadow-sm border border-border'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <Layers className="h-3.5 w-3.5" />
              Semua Armada ({allStops.length})
            </button>
            <button
              onClick={() => setArmadaFilter('MOTOR')}
              className={cn(
                'flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2',
                armadaFilter === 'MOTOR'
                  ? 'bg-amber-500 text-white shadow-sm shadow-amber-500/20'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              🛵 MOTOR ({allStops.filter((s) => s.armada?.toUpperCase() === 'MOTOR').length})
            </button>
            <button
              onClick={() => setArmadaFilter('MOBIL')}
              className={cn(
                'flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2',
                armadaFilter === 'MOBIL'
                  ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/20'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              🚗 MOBIL ({allStops.filter((s) => s.armada?.toUpperCase() === 'MOBIL').length})
            </button>
          </div>

          {/* Filter bar */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 rounded-2xl border border-border bg-card p-4 shadow-sm mb-5">
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">Filter Mitra Apotek</label>
              <select value={mitraFilter} onChange={(e) => setMitraFilter(e.target.value)} className={inputClass}>
                {uniqueMitras.map((m) => <option key={m} value={m}>{m === 'ALL' ? 'Semua Mitra' : m}</option>)}
              </select>
            </div>
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">Cari ID / Alamat / Apotek</label>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <input type="text" className={`${inputClass} pl-9`} placeholder="Cari..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} />
              </div>
            </div>
          </div>

          {loadingOrders ? (
            <div className="flex flex-col items-center justify-center py-16 gap-3">
              <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
              <p className="text-sm text-muted-foreground">Memuat daftar order...</p>
            </div>
          ) : filteredStops.length === 0 ? (
            <div className="flex flex-col items-center justify-center rounded-2xl border border-border bg-card py-16 gap-3">
              <CheckCircle className="h-10 w-10 text-emerald-500 animate-bounce" />
              <h3 className="font-semibold text-foreground">Tidak Ada Order Menunggu Dispatch</h3>
              <p className="text-sm text-muted-foreground">Semua titik alamat pengiriman sudah ter-dispatch ke driver.</p>
            </div>
          ) : (
            <div className="space-y-6">
              {/* Select all bar */}
              <div className="flex items-center justify-between px-1 bg-muted/30 p-3 rounded-xl border border-border">
                <div className="flex items-center gap-2">
                  <input type="checkbox" id="select-all"
                    checked={selectedStopIds.length === filteredStops.length && filteredStops.length > 0}
                    onChange={(e) => handleSelectAllStops(e.target.checked)}
                    className="h-4 w-4 rounded border-border accent-blue-600 cursor-pointer" />
                  <label htmlFor="select-all" className="text-sm font-semibold cursor-pointer text-foreground">
                    Pilih Semua ({filteredStops.length} Alamat di {cards.length} Card Cluster)
                  </label>
                </div>
                <span className="text-xs text-muted-foreground hidden sm:block">Tips: Tarik & lepas (Drag & Drop) item alamat untuk pindah Card rute</span>
              </div>

              {/* Render Cards Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                {cards.map((card) => {
                  const cardStopIds = card.stops.map((s) => s.id)
                  const isCardFullySelected = cardStopIds.length > 0 && cardStopIds.every((id) => selectedStopIds.includes(id))
                  const isCardPartiallySelected = cardStopIds.some((id) => selectedStopIds.includes(id)) && !isCardFullySelected

                  return (
                    <div
                      key={card.id}
                      onDragOver={handleDragOver}
                      onDrop={(e) => handleDrop(e, card.id)}
                      className={`rounded-2xl border transition-all duration-200 ${
                        isCardFullySelected
                          ? 'border-blue-500/60 bg-blue-50/20 dark:bg-blue-950/10 shadow-md ring-1 ring-blue-500/20'
                          : 'border-border bg-card shadow-sm hover:border-border/80'
                      }`}
                    >
                      {/* Card Header */}
                      <div className="flex items-center justify-between p-4 border-b border-border bg-muted/20 rounded-t-2xl">
                        <div className="flex items-center gap-3">
                          <input
                            type="checkbox"
                            checked={isCardFullySelected}
                            ref={(el) => { if (el) el.indeterminate = isCardPartiallySelected }}
                            onChange={() => handleToggleCard(card.stops)}
                            className="h-4 w-4 rounded border-border accent-blue-600 cursor-pointer"
                          />
                          <div className="flex items-center gap-2">
                            <Layers className="h-4 w-4 text-blue-600" />
                            <h3 className="font-bold text-sm text-foreground">{card.title}</h3>
                          </div>
                        </div>
                        <span className="rounded-full bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-300 px-2.5 py-0.5 text-xs font-bold">
                          {card.stops.length} Alamat
                        </span>
                      </div>

                      {/* Card Items (Stops) */}
                      <div className="p-3 space-y-2.5 min-h-[100px]">
                        {card.stops.length === 0 ? (
                          <div className="flex items-center justify-center py-6 text-xs text-muted-foreground border-2 border-dashed border-border rounded-xl">
                            Drag & drop alamat ke card ini
                          </div>
                        ) : (
                          card.stops.map((stop) => {
                            const isStopSelected = selectedStopIds.includes(stop.id)
                            return (
                              <div
                                key={stop.id}
                                draggable
                                onDragStart={(e) => handleDragStart(e, stop.id, card.id)}
                                className={`group flex items-start gap-3 p-3 rounded-xl border transition-all cursor-grab active:cursor-grabbing ${
                                  isStopSelected
                                    ? 'border-blue-500/50 bg-blue-50/60 dark:bg-blue-950/20 shadow-sm'
                                    : 'border-border bg-background hover:border-blue-500/30'
                                }`}
                                onClick={() => handleToggleStop(stop.id)}
                              >
                                <div className="mt-1 text-muted-foreground/40 group-hover:text-muted-foreground transition-colors cursor-grab">
                                  <GripVertical className="h-4 w-4" />
                                </div>
                                <input
                                  type="checkbox"
                                  checked={isStopSelected}
                                  onChange={() => handleToggleStop(stop.id)}
                                  onClick={(e) => e.stopPropagation()}
                                  className="mt-1 h-4 w-4 rounded border-border accent-blue-600 cursor-pointer"
                                />
                                <div className="flex-1 min-w-0">
                                  <div className="flex flex-wrap items-center gap-1.5 mb-1">
                                    <code className="text-xs font-mono font-extrabold text-blue-600">{stop.order_number}</code>
                                    <span className="rounded-full bg-muted px-2 py-0.5 text-[10px] font-semibold text-foreground">{stop.mitra_name}</span>
                                    <span className={`rounded-full px-2 py-0.5 text-[10px] font-bold ${
                                      stop.armada === 'motor'
                                        ? 'bg-amber-50 text-amber-700 dark:bg-amber-950/20 dark:text-amber-400'
                                        : 'bg-blue-50 text-blue-700 dark:bg-blue-950/20 dark:text-blue-400'
                                    }`}>{stop.armada?.toUpperCase()}</span>
                                  </div>
                                  <div className="flex flex-col gap-0.5">
                                    <p className="text-xs font-bold text-foreground truncate">{stop.customer_name}</p>
                                    <p className="text-[11px] text-muted-foreground line-clamp-1">{stop.delivery_address}</p>
                                  </div>
                                </div>
                              </div>
                            )
                          })
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ─── STEP 1: Pilih Driver ─── */}
      {step === 1 && (
        <div>
          <div className="flex items-center gap-4 mb-5">
            <button onClick={() => setStep(0)} className="flex items-center gap-2 h-9 px-3 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors text-foreground">
              <ArrowLeft className="h-4 w-4" /> Kembali
            </button>
            <div>
              <h2 className="font-semibold text-foreground">Pilih Driver Armada</h2>
              <p className="text-xs text-muted-foreground">Armada: {selectedInfo.armada?.toUpperCase()} • {selectedStopIds.length} Alamat Terpilih</p>
            </div>
          </div>

          {/* Armada Tabs */}
          <div className="flex items-center gap-2 mb-4 bg-muted/40 p-1.5 rounded-2xl border border-border">
            <button
              onClick={() => setDriverVehicleTab('ALL')}
              className={cn(
                'flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2',
                driverVehicleTab === 'ALL'
                  ? 'bg-white dark:bg-card text-foreground shadow-sm border border-border'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <Layers className="h-3.5 w-3.5" />
              Semua ({drivers.length})
            </button>
            <button
              onClick={() => setDriverVehicleTab('MOTOR')}
              className={cn(
                'flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2',
                driverVehicleTab === 'MOTOR'
                  ? 'bg-amber-500 text-white shadow-sm shadow-amber-500/20'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              🛵 MOTOR ({drivers.filter((d) => d.vehicle_type?.toUpperCase() === 'MOTOR').length})
            </button>
            <button
              onClick={() => setDriverVehicleTab('MOBIL')}
              className={cn(
                'flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2',
                driverVehicleTab === 'MOBIL'
                  ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/20'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              🚗 MOBIL ({drivers.filter((d) => d.vehicle_type?.toUpperCase() === 'MOBIL').length})
            </button>
          </div>

          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input type="text" className={`${inputClass} pl-9 max-w-md`} placeholder="Cari driver..." value={driverSearch} onChange={(e) => setDriverSearch(e.target.value)} />
          </div>

          {loadingDrivers ? (
            <div className="flex items-center justify-center py-12">
              <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
            </div>
          ) : filteredDrivers.length === 0 ? (
            <div className="flex flex-col items-center py-12 gap-3 rounded-2xl border border-border bg-card">
              <Truck className="h-10 w-10 text-muted-foreground/40" />
              <p className="text-sm text-muted-foreground">Tidak ada driver aktif untuk armada {selectedInfo.armada}.</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {filteredDrivers.map((d) => (
                <button
                  key={d.id}
                  onClick={() => handleProceedToSequence(d)}
                  className="flex items-center gap-4 p-4 rounded-2xl border border-border bg-card hover:border-blue-500/50 hover:bg-blue-50/30 dark:hover:bg-blue-950/10 transition-all text-left"
                >
                  <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-blue-100 to-slate-100 text-blue-700 font-bold text-lg dark:from-blue-900/30 dark:to-slate-900/30 dark:text-blue-300 flex-shrink-0">
                    {d.name?.[0]?.toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold truncate text-foreground">{d.name}</p>
                    <p className="text-xs text-muted-foreground">{d.plate_number || 'Tidak Ada Plat'}</p>
                    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold mt-1 ${d.is_active ? 'bg-emerald-50 text-emerald-700' : 'bg-muted text-muted-foreground'}`}>
                      <span className={`h-1.5 w-1.5 rounded-full ${d.is_active ? 'bg-emerald-500 animate-pulse' : 'bg-muted-foreground'}`} />
                      {d.is_active ? 'Ready' : 'Offline'}
                    </span>
                  </div>
                  <ArrowRight className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ─── STEP 2: Urutan Rute ─── */}
      {step === 2 && (
        <div>
          <div className="flex items-center gap-4 mb-5">
            <button onClick={() => setStep(1)} className="flex items-center gap-2 h-9 px-3 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors text-foreground">
              <ArrowLeft className="h-4 w-4" /> Kembali
            </button>
            <div>
              <h2 className="font-semibold text-foreground">Atur Urutan Rute</h2>
              <p className="text-xs text-muted-foreground">Driver: <strong>{selectedDriver?.name}</strong> • Atur urutan rute pengantaran sekuensial</p>
            </div>
          </div>

          <div className="space-y-2 mb-6">
            {sequence.map((stop, idx) => (
              <div key={stop.id} className="flex items-center gap-3 p-4 rounded-2xl border border-border bg-card">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-white text-sm font-bold flex-shrink-0">{idx + 1}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold truncate text-foreground">{stop.customer_name}</p>
                  <p className="text-xs text-muted-foreground truncate">{stop.delivery_address}</p>
                </div>
                <div className="flex gap-1">
                  <button onClick={() => moveItem(idx, -1)} disabled={idx === 0} className="h-8 w-8 rounded-lg border border-border flex items-center justify-center hover:bg-accent disabled:opacity-30 transition-colors text-foreground">
                    <ArrowUp className="h-3 w-3" />
                  </button>
                  <button onClick={() => moveItem(idx, 1)} disabled={idx === sequence.length - 1} className="h-8 w-8 rounded-lg border border-border flex items-center justify-center hover:bg-accent disabled:opacity-30 transition-colors text-foreground">
                    <ArrowDown className="h-3 w-3" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="flex justify-end">
            <button
              disabled={submitting}
              onClick={() => executeDispatch(sequence, selectedDriver!.id)}
              className="flex items-center gap-2 h-11 px-8 rounded-lg bg-gradient-to-r from-blue-600 to-slate-700 text-white font-medium hover:from-blue-700 hover:to-slate-800 transition-all disabled:opacity-70 shadow-sm"
            >
              {submitting ? <><Loader2 className="h-4 w-4 animate-spin" /> Memproses...</> : <>Konfirmasi & Dispatch <CheckCircle className="h-4 w-4" /></>}
            </button>
          </div>
        </div>
      )}
    </DashboardShell>
  )
}
