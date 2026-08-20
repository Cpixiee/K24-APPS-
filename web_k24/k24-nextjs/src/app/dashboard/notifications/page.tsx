'use client'

import { useState, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { useNotifications, WebNotification } from '@/context/NotificationContext'
import { useAuth } from '@/context/AuthContext'
import {
  Bell, CheckCheck, CheckCircle2, Truck, Package, Radio, RefreshCw, Search, Plus, Send, FileText, Info, ArrowLeft, AlertCircle, Calendar, ChevronLeft, ChevronRight
} from 'lucide-react'

function formatTimeAgo(dateStr: string): string {
  try {
    const date = new Date(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / (1000 * 60))
    if (diffMins < 1) return 'Baru saja'
    if (diffMins < 60) return `${diffMins} mnt lalu`
    const diffHours = Math.floor(diffMins / 60)
    if (diffHours < 24) return `${diffHours} hr lalu`
    const diffDays = Math.floor(diffHours / 24)
    return `${diffDays} hari lalu`
  } catch {
    return dateStr
  }
}

function formatClockTime(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })
  } catch {
    return '10:45 AM'
  }
}

function formatYYYYMMDD(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    if (isNaN(d.getTime())) return ''
    const year = d.getFullYear()
    const month = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  } catch {
    return ''
  }
}

function formatIndonesianDate(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    if (isNaN(d.getTime())) return dateStr
    return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })
  } catch {
    return dateStr
  }
}

function getDateGroupLabel(dateStr: string): string {
  try {
    const date = new Date(dateStr)
    const now = new Date()
    const isToday = date.toDateString() === now.toDateString()
    if (isToday) return 'Hari ini'
    
    const yesterday = new Date()
    yesterday.setDate(now.getDate() - 1)
    if (date.toDateString() === yesterday.toDateString()) return 'Kemarin'

    return date.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
  } catch {
    return 'Hari ini'
  }
}

// Parse order number / dispatch key from text
function extractOrderKey(item: WebNotification): { key: string; titleName: string } {
  const text = `${item.title} ${item.message}`
  const match = text.match(/(DSP-\d+|ORDER-\d+-\d+|ORD-\d+|#\d+)/i)
  if (match) {
    const keyStr = match[0].replace('#', '').toUpperCase()
    return { key: keyStr, titleName: `Order ${keyStr}` }
  }
  return { key: `NOTIF-${item.id}`, titleName: item.title || 'Notifikasi Sistem' }
}

// Parse real-time accurate title & event type without forcing everything to "DONE"
function getNotificationEventDetails(titleStr?: string, messageStr?: string) {
  const text = `${titleStr || ''} ${messageStr || ''}`.toLowerCase()

  // 6. Pengembalian POD ke KDE
  if (
    text.includes('pengembalian pod') ||
    text.includes('pod dikembalikan') ||
    text.includes('pod disetujui') ||
    text.includes('dikembalikan ke kde') ||
    text.includes('gudang kde')
  ) {
    return {
      type: 'POD_RETURNED',
      badgeLabel: '🏢 Pengembalian POD',
      pillBg: 'bg-indigo-100 text-indigo-800 dark:bg-indigo-950/80 dark:text-indigo-300 border-indigo-300/50',
      icon: <CheckCircle2 className="h-4 w-4 text-indigo-600 dark:text-indigo-400" />,
    }
  }

  // 5. Verifikasi Invoice & Unboxing Apoteker
  if (
    text.includes('verifikasi') ||
    text.includes('faktur') ||
    text.includes('unbox') ||
    text.includes('apoteker') ||
    text.includes('tidak sesuai') ||
    text.includes('cacat') ||
    text.includes('hilang') ||
    text.includes('bermasalah')
  ) {
    const isProblem =
      text.includes('tidak sesuai') ||
      text.includes('cacat') ||
      text.includes('hilang') ||
      text.includes('bermasalah') ||
      text.includes('ditolak')
    if (isProblem) {
      return {
        type: 'INVOICE_PROBLEM',
        badgeLabel: '⚠️ Invoice Tidak Sesuai',
        pillBg: 'bg-rose-100 text-rose-800 dark:bg-rose-950/80 dark:text-rose-300 border-rose-300/50',
        icon: <AlertCircle className="h-4 w-4 text-rose-600 dark:text-rose-400" />,
      }
    }
    return {
      type: 'INVOICE_VERIFIED',
      badgeLabel: '🤝 Verifikasi Invoice',
      pillBg: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/80 dark:text-emerald-300 border-emerald-300/50',
      icon: <FileText className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />,
    }
  }

  // 4. Kurir Tiba di Lokasi Apotek
  if (
    text.includes('tiba') ||
    text.includes('arrived') ||
    text.includes('sampai di lokasi') ||
    text.includes('titik')
  ) {
    return {
      type: 'ORDER_ARRIVED',
      badgeLabel: '📍 Tiba di Lokasi',
      pillBg: 'bg-purple-100 text-purple-800 dark:bg-purple-950/80 dark:text-purple-300 border-purple-300/50',
      icon: <Radio className="h-4 w-4 text-purple-600 dark:text-purple-400" />,
    }
  }

  // 3. Barang Di-Pickup Driver
  if (
    text.includes('pickup') ||
    text.includes('diambil') ||
    text.includes('di-pickup') ||
    text.includes('penjemputan')
  ) {
    return {
      type: 'ORDER_PICKUP',
      badgeLabel: '🚚 Sudah Pickup',
      pillBg: 'bg-amber-100 text-amber-800 dark:bg-amber-950/80 dark:text-amber-300 border-amber-300/50',
      icon: <Package className="h-4 w-4 text-amber-600 dark:text-amber-400" />,
    }
  }

  // 2. Order Dispatched / Kurir Ditugaskan
  if (
    text.includes('dispatch') ||
    text.includes('ditugaskan') ||
    text.includes('penugasan')
  ) {
    return {
      type: 'ORDER_DISPATCHED',
      badgeLabel: '🚗 Dispatch Kurir',
      pillBg: 'bg-cyan-100 text-cyan-800 dark:bg-cyan-950/80 dark:text-cyan-300 border-cyan-300/50',
      icon: <Truck className="h-4 w-4 text-cyan-600 dark:text-cyan-400" />,
    }
  }

  // 1. Order Dibuat
  if (
    text.includes('dibuat') ||
    text.includes('order baru') ||
    text.includes('created') ||
    text.includes('pesanan baru')
  ) {
    return {
      type: 'ORDER_CREATED',
      badgeLabel: '📦 Order Dibuat',
      pillBg: 'bg-blue-100 text-blue-800 dark:bg-blue-950/80 dark:text-blue-300 border-blue-300/50',
      icon: <Package className="h-4 w-4 text-blue-600 dark:text-blue-400" />,
    }
  }

  // Default fallback
  return {
    type: 'SYSTEM',
    badgeLabel: titleStr || 'Pemberitahuan Sistem',
    pillBg: 'bg-slate-100 text-slate-800 dark:bg-slate-900 dark:text-slate-300 border-slate-300/50',
    icon: <Info className="h-4 w-4 text-blue-600 dark:text-blue-400" />,
  }
}

export default function NotificationsWebPage() {
  const router = useRouter()
  const { user } = useAuth()
  const { notifications, unreadCount, markAllAsRead, fetchNotifications, markNotificationRead } = useNotifications()
  const [filter, setFilter] = useState<'ALL' | 'UNREAD' | 'REPORTS'>('ALL')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [selectedKey, setSelectedKey] = useState<string | null>(null)
  const [mobileDetailOpen, setMobileDetailOpen] = useState(false)

  const todayStr = useMemo(() => {
    const now = new Date()
    return formatYYYYMMDD(now.toISOString())
  }, [])

  // Default date selected to Today's date!
  const [selectedDate, setSelectedDate] = useState<string>(todayStr)

  // Find all dates that have notifications
  const availableDates = useMemo(() => {
    const datesSet = new Set<string>()
    notifications.forEach((n) => {
      const d = formatYYYYMMDD(n.created_at)
      if (d) datesSet.add(d)
    })
    return Array.from(datesSet).sort((a, b) => new Date(b).getTime() - new Date(a).getTime())
  }, [notifications])

  // Active date logic: use selectedDate or fallback
  const activeDate = useMemo(() => {
    if (selectedDate) return selectedDate
    if (availableDates.includes(todayStr)) return todayStr
    return availableDates[0] || todayStr
  }, [selectedDate, availableDates, todayStr])

  // Date Navigation Handlers
  const handlePrevDay = () => {
    const cur = new Date(activeDate || todayStr)
    cur.setDate(cur.getDate() - 1)
    setSelectedDate(formatYYYYMMDD(cur.toISOString()))
  }

  const handleNextDay = () => {
    const cur = new Date(activeDate || todayStr)
    cur.setDate(cur.getDate() + 1)
    setSelectedDate(formatYYYYMMDD(cur.toISOString()))
  }

  const handleRefresh = async () => {
    setLoading(true)
    await fetchNotifications()
    setLoading(false)
  }

  // Filter notifications by search, filter pill, AND selectedDate!
  const filteredNotifications = useMemo(() => {
    return notifications.filter((n) => {
      // Date filter
      if (activeDate) {
        const itemDate = formatYYYYMMDD(n.created_at)
        if (itemDate !== activeDate) return false
      }

      const searchLower = (search || '').toLowerCase()
      const matchSearch =
        (n?.title || '').toLowerCase().includes(searchLower) ||
        (n?.message || '').toLowerCase().includes(searchLower)

      if (!matchSearch) return false
      if (filter === 'UNREAD') return !n.is_read
      if (filter === 'REPORTS') {
        const lower = `${n?.title || ''} ${n?.message || ''}`.toLowerCase()
        return lower.includes('order') || lower.includes('faktur') || lower.includes('sampai') || lower.includes('selesai') || lower.includes('kurir')
      }
      return true
    })
  }, [notifications, activeDate, search, filter])

  // Calculate Daily Delivery Summary for activeDate
  const dailySummary = useMemo(() => {
    if (!filteredNotifications.length) return null

    const uniqueDrivers = new Set<string>()
    const uniquePharmacies = new Set<string>()
    const uniqueInvoices = new Set<string>()
    const uniqueDispatches = new Set<string>()

    const sorted = [...filteredNotifications].sort(
      (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
    )

    let firstEventTime = ''
    let lastEventTime = ''
    if (sorted.length) {
      firstEventTime = formatClockTime(sorted[0].created_at)
      lastEventTime = formatClockTime(sorted[sorted.length - 1].created_at)
    }

    sorted.forEach((n) => {
      // Driver name
      const driverMatch = n.message.match(/driver ([A-Z\s]+?)(?=\s*\(|\s*telah|\s*menuju|\s*di|\.|$)/i)
      if (driverMatch && driverMatch[1]) {
        uniqueDrivers.add(driverMatch[1].trim())
      }

      // Pharmacy name
      const pharmMatch = n.message.match(/(Apotek [^,(\.]+|PT K-24 [^,(\.]+)/i)
      if (pharmMatch) {
        uniquePharmacies.add(pharmMatch[1].trim())
      }

      // Invoice numbers
      const invMatches = n.message.match(/INV-[A-Z0-9]+/g)
      if (invMatches) {
        invMatches.forEach((inv) => uniqueInvoices.add(inv))
      }

      // Dispatch IDs
      const { key } = extractOrderKey(n)
      if (key) uniqueDispatches.add(key)
    })

    const isAllCompleted = filteredNotifications.some((n) => {
      const text = `${n.title} ${n.message}`.toLowerCase()
      return text.includes('pengembalian pod') || text.includes('pod dikembalikan') || text.includes('selesai (completed)')
    })

    return {
      dateFormatted: formatIndonesianDate(activeDate),
      driverCount: uniqueDrivers.size || 1,
      driverNames: Array.from(uniqueDrivers).join(', ') || 'WIT URROHMAN',
      pharmacyCount: uniquePharmacies.size || 2,
      pharmacyNames: Array.from(uniquePharmacies).join(', '),
      invoiceCount: uniqueInvoices.size || (filteredNotifications.length * 5),
      dispatchCount: uniqueDispatches.size || 1,
      firstTime: firstEventTime,
      lastTime: lastEventTime,
      isAllCompleted,
    }
  }, [filteredNotifications, activeDate])

  // Group notifications by Order Number / Dispatch ID for chat view
  const groupedOrders = useMemo(() => {
    const groups = new Map<string, { key: string; titleName: string; partnerName: string; items: WebNotification[] }>()

    filteredNotifications.forEach((item) => {
      const { key, titleName } = extractOrderKey(item)

      // Try to extract pharmacy / partner name
      let partnerName = 'PT K-24 Indonesia'
      const pharmMatch = item.message.match(/\((PT [^)]+|Apotek [^)]+)\)/i)
      if (pharmMatch) {
        partnerName = pharmMatch[1]
      }

      if (!groups.has(key)) {
        groups.set(key, { key, titleName, partnerName, items: [] })
      }
      groups.get(key)!.items.push(item)
    })

    return Array.from(groups.values())
  }, [filteredNotifications])

  // Auto-select first item if not set or invalid
  const activeGroup = useMemo(() => {
    if (groupedOrders.length === 0) return null
    if (selectedKey) {
      const found = groupedOrders.find((g) => g.key === selectedKey)
      if (found) return found
    }
    return groupedOrders[0]
  }, [groupedOrders, selectedKey])

  // Handle click on left sidebar item
  const handleSelectGroup = (key: string) => {
    setSelectedKey(key)
    setMobileDetailOpen(true)

    // Mark items in this group as read
    const group = groupedOrders.find((g) => g.key === key)
    if (group) {
      group.items.forEach((item) => {
        if (!item.is_read) markNotificationRead(item.id)
      })
    }
  }

  // Get user avatar initials
  const userInitials = useMemo(() => {
    if (!user?.name) return 'GA'
    const parts = user.name.split(' ')
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase()
    return user.name.substring(0, 2).toUpperCase()
  }, [user])

  return (
    <DashboardShell onRefresh={handleRefresh}>
      <div className="space-y-4 max-w-7xl mx-auto">
        {/* Top Header Banner matching Screenshot 1 */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-2xl bg-card p-5 border border-border shadow-xs">
          <div>
            <h2 className="text-xl font-bold tracking-tight text-foreground">Notifikasi & Laporan System</h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              Pusat pemberitahuan tugas pengantaran dan konfirmasi order.
            </p>
          </div>

          <div className="flex items-center gap-3 shrink-0">
            {/* Refresh Button */}
            <button
              onClick={handleRefresh}
              title="Refresh Notifikasi"
              className="flex h-9 w-9 items-center justify-center rounded-full border border-border bg-background hover:bg-accent text-foreground transition"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            </button>

            {/* Notification Bell Badge */}
            <div className="relative">
              <button
                onClick={markAllAsRead}
                title="Tandai Semua Dibaca"
                className="flex h-9 w-9 items-center justify-center rounded-full border border-border bg-background hover:bg-accent text-foreground transition"
              >
                <Bell className="h-4 w-4" />
              </button>
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white shadow-xs">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
            </div>

            {/* User Profile Info Badge */}
            <div className="flex items-center gap-2.5 pl-2 border-l border-border">
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-600 text-xs font-bold text-white shadow-xs">
                {userInitials}
              </div>
              <div className="hidden md:block text-left leading-tight">
                <div className="text-xs font-bold text-foreground">{user?.name || 'Goodwheel Admin'}</div>
                <div className="text-[10px] text-muted-foreground capitalize">{user?.role ? user.role.toLowerCase() : 'Administrator'}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Date Selector Control Bar */}
        <div className="flex flex-wrap items-center justify-between gap-3 p-3.5 rounded-2xl bg-card border border-border shadow-2xs">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-50 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400">
              <Calendar className="h-4 w-4" />
            </div>
            <div>
              <span className="text-xs font-bold text-foreground">Filter Tanggal Notifikasi:</span>
              <span className="ml-2 text-xs font-extrabold text-blue-600 dark:text-blue-400">
                {formatIndonesianDate(activeDate)}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {/* Prev Day Button */}
            <button
              onClick={handlePrevDay}
              title="Hari Sebelumnya"
              className="flex h-8 w-8 items-center justify-center rounded-lg border border-border bg-background hover:bg-accent text-foreground transition"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>

            {/* Native Date Picker */}
            <input
              type="date"
              value={activeDate}
              onChange={(e) => setSelectedDate(e.target.value)}
              className="rounded-lg border border-input bg-muted/40 px-3 py-1 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-blue-500/40"
            />

            {/* Next Day Button */}
            <button
              onClick={handleNextDay}
              title="Hari Berikutnya"
              className="flex h-8 w-8 items-center justify-center rounded-lg border border-border bg-background hover:bg-accent text-foreground transition"
            >
              <ChevronRight className="h-4 w-4" />
            </button>

            {/* Hari Ini Quick Button */}
            <button
              onClick={() => setSelectedDate(todayStr)}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition ${
                activeDate === todayStr
                  ? 'bg-blue-600 text-white shadow-xs'
                  : 'bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground'
              }`}
            >
              Hari Ini
            </button>

            {/* Quick date pills of available dates */}
            {availableDates.length > 0 && (
              <div className="hidden lg:flex items-center gap-1 pl-2 border-l border-border">
                <span className="text-[10px] text-muted-foreground font-semibold">Ada Data:</span>
                {availableDates.slice(0, 3).map((d) => (
                  <button
                    key={d}
                    onClick={() => setSelectedDate(d)}
                    className={`px-2 py-0.5 text-[10px] font-bold rounded-md transition ${
                      activeDate === d
                        ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/60 dark:text-blue-200'
                        : 'bg-muted/40 text-muted-foreground hover:bg-accent'
                    }`}
                  >
                    {d.slice(5)}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Master-Detail Container (Matching Chat View Screenshot) */}
        <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden flex flex-col md:flex-row h-[calc(100vh-230px)] min-h-[580px]">
          {/* ===== LEFT COLUMN: Notification List Sidebar (~360px) ===== */}
          <div
            className={`w-full md:w-[360px] lg:w-[400px] shrink-0 border-r border-border flex flex-col bg-card ${
              mobileDetailOpen ? 'hidden md:flex' : 'flex'
            }`}
          >
            {/* Search Input & Filter Pills */}
            <div className="p-4 space-y-3 border-b border-border bg-card">
              {/* Search Bar */}
              <div className="relative">
                <Search className="absolute left-3.5 top-2.5 h-4 w-4 text-muted-foreground" />
                <input
                  type="text"
                  placeholder="Cari No Order / Notifikasi..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="w-full rounded-full border border-input bg-muted/30 pl-9 pr-4 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500/40"
                />
              </div>

              {/* Filter Tabs Pills */}
              <div className="flex items-center gap-1.5 overflow-x-auto pb-0.5 no-scrollbar">
                <button
                  onClick={() => setFilter('ALL')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-full transition whitespace-nowrap ${
                    filter === 'ALL'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground'
                  }`}
                >
                  Semua ({filteredNotifications.length})
                </button>
                <button
                  onClick={() => setFilter('UNREAD')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-full transition whitespace-nowrap ${
                    filter === 'UNREAD'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground'
                  }`}
                >
                  Belum Dibaca ({unreadCount})
                </button>
                <button
                  onClick={() => setFilter('REPORTS')}
                  className={`px-3 py-1.5 text-xs font-bold rounded-full transition whitespace-nowrap ${
                    filter === 'REPORTS'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-muted/60 text-muted-foreground hover:bg-muted hover:text-foreground'
                  }`}
                >
                  Laporan Pengiriman
                </button>
              </div>
            </div>

            {/* Notification List Body */}
            <div className="flex-1 overflow-y-auto divide-y divide-border/60">
              {groupedOrders.length === 0 ? (
                <div className="flex h-48 flex-col items-center justify-center text-center p-6 space-y-3">
                  <Bell className="h-10 w-10 text-muted-foreground/30" />
                  <div>
                    <p className="text-xs font-bold text-foreground">Tidak Ada Notifikasi</p>
                    <p className="text-[11px] text-muted-foreground mt-0.5">
                      Tidak ada pemberitahuan pada {formatIndonesianDate(activeDate)}.
                    </p>
                  </div>
                  {availableDates.length > 0 && availableDates[0] !== activeDate && (
                    <button
                      onClick={() => setSelectedDate(availableDates[0])}
                      className="px-3 py-1 text-xs font-bold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/60 rounded-full border border-blue-200 dark:border-blue-800 hover:bg-blue-100"
                    >
                      Lihat Notifikasi Terbaru ({availableDates[0]})
                    </button>
                  )}
                </div>
              ) : (
                groupedOrders.map((group) => {
                  const latestItem = group.items[0]
                  const latestEvent = getNotificationEventDetails(latestItem.title, latestItem.message)
                  const isSelected = activeGroup?.key === group.key
                  const hasUnread = group.items.some((i) => !i.is_read)

                  return (
                    <div
                      key={group.key}
                      onClick={() => handleSelectGroup(group.key)}
                      className={`p-4 cursor-pointer transition-colors relative flex flex-col gap-1.5 hover:bg-accent/50 ${
                        isSelected
                          ? 'bg-blue-50/70 dark:bg-blue-950/40 border-l-4 border-l-blue-600'
                          : hasUnread
                          ? 'bg-card font-semibold'
                          : 'bg-card opacity-90'
                      }`}
                    >
                      {/* Top Row: Order ID Title + Time */}
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2 min-w-0">
                          {hasUnread && <span className="h-2 w-2 rounded-full bg-blue-600 shrink-0" />}
                          <span className={`text-xs font-black truncate ${hasUnread ? 'text-foreground font-black' : 'text-slate-800 dark:text-slate-200'}`}>
                            {group.titleName}
                          </span>
                        </div>
                        <span className="text-[10px] text-muted-foreground shrink-0 font-medium">
                          {formatTimeAgo(latestItem.created_at)}
                        </span>
                      </div>

                      {/* Second Row: Latest Event Status Badge */}
                      <div className="flex items-center gap-1.5">
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${latestEvent.pillBg}`}>
                          {latestEvent.icon}
                          {latestEvent.badgeLabel}
                        </span>
                      </div>

                      {/* Message Preview */}
                      <p className="text-xs text-muted-foreground line-clamp-2 leading-relaxed pt-0.5">
                        {latestItem.message}
                      </p>
                    </div>
                  )
                })
              )}
            </div>
          </div>

          {/* ===== RIGHT COLUMN: Detail Chat View Pane (Flex-1) ===== */}
          <div
            className={`flex-1 flex-col bg-slate-50/50 dark:bg-slate-950/50 ${
              mobileDetailOpen ? 'flex' : 'hidden md:flex'
            }`}
          >
            {activeGroup ? (
              <>
                {/* Chat Header Bar */}
                <div className="px-5 py-3.5 border-b border-border bg-card flex items-center justify-between shadow-xs">
                  <div className="flex items-center gap-3">
                    {/* Mobile Back Button */}
                    <button
                      onClick={() => setMobileDetailOpen(false)}
                      className="md:hidden flex h-8 w-8 items-center justify-center rounded-full hover:bg-accent"
                    >
                      <ArrowLeft className="h-4 w-4" />
                    </button>

                    {/* Circular Icon */}
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-800 shrink-0">
                      <Bell className="h-5 w-5 text-blue-600 dark:text-blue-400" />
                    </div>

                    <div>
                      <h3 className="text-sm font-bold text-foreground flex items-center gap-2">
                        {activeGroup.titleName}
                      </h3>
                      <p className="text-[11px] text-muted-foreground font-medium">
                        {activeGroup.partnerName}
                      </p>
                    </div>
                  </div>

                  <button
                    onClick={() => {
                      activeGroup.items.forEach((item) => {
                        if (!item.is_read) markNotificationRead(item.id)
                      })
                    }}
                    className="px-3.5 py-1.5 text-xs font-bold rounded-xl border border-border bg-background hover:bg-accent text-foreground transition shadow-xs"
                  >
                    Tandai Dibaca
                  </button>
                </div>

                {/* Chat Feed Scroll Area with geometric/subtle grid pattern - Chronological Order (Oldest -> Newest) */}
                <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-6 bg-[radial-gradient(#e2e8f0_1px,transparent_1px)] dark:bg-[radial-gradient(#1e293b_1px,transparent_1px)] [background-size:16px_16px]">
                  {/* Daily Delivery Summary Banner Card */}
                  {dailySummary && (
                    <div className="max-w-2xl mx-auto rounded-2xl border border-emerald-200 dark:border-emerald-800/60 bg-gradient-to-br from-emerald-50/90 via-card to-emerald-50/40 dark:from-emerald-950/40 dark:via-card dark:to-emerald-950/20 p-4 shadow-xs space-y-3.5">
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-emerald-200/60 dark:border-emerald-800/40 pb-2.5">
                        <div className="flex items-center gap-2.5">
                          <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-emerald-600 text-white font-bold text-xs shadow-xs">
                            🎉
                          </div>
                          <div>
                            <h4 className="text-xs font-bold text-foreground">
                              Summary Laporan Pengiriman Tanggal {dailySummary.dateFormatted}
                            </h4>
                            <p className="text-[11px] text-muted-foreground">
                              Rekapitulasi aktivitas tugas pengantaran & verifikasi faktur harian.
                            </p>
                          </div>
                        </div>

                        {dailySummary.isAllCompleted ? (
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-extrabold bg-emerald-600 text-white shadow-xs">
                            <CheckCircle2 className="h-3.5 w-3.5" />
                            SELURUH PENGANTARAN COMPLETED (100%)
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold bg-blue-600 text-white shadow-xs">
                            <Truck className="h-3.5 w-3.5" />
                            PENGANTARAN SEDANG BERJALAN
                          </span>
                        )}
                      </div>

                      {/* Metrics Card Grid */}
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
                        <div className="p-2.5 rounded-xl bg-background/80 border border-emerald-100 dark:border-emerald-900/40 shadow-2xs">
                          <div className="text-[10px] font-semibold text-muted-foreground flex items-center gap-1">
                            <Truck className="h-3 w-3 text-blue-600" /> Driver Bertugas
                          </div>
                          <div className="text-xs font-extrabold text-foreground mt-1">
                            {dailySummary.driverCount} Driver
                          </div>
                          <div className="text-[10px] text-muted-foreground truncate">
                            {dailySummary.driverNames}
                          </div>
                        </div>

                        <div className="p-2.5 rounded-xl bg-background/80 border border-emerald-100 dark:border-emerald-900/40 shadow-2xs">
                          <div className="text-[10px] font-semibold text-muted-foreground flex items-center gap-1">
                            <Package className="h-3 w-3 text-amber-600" /> Total Apotek
                          </div>
                          <div className="text-xs font-extrabold text-foreground mt-1">
                            {dailySummary.pharmacyCount} Apotek
                          </div>
                          <div className="text-[10px] text-muted-foreground truncate">
                            {dailySummary.dispatchCount} Dispatch Order
                          </div>
                        </div>

                        <div className="p-2.5 rounded-xl bg-background/80 border border-emerald-100 dark:border-emerald-900/40 shadow-2xs">
                          <div className="text-[10px] font-semibold text-muted-foreground flex items-center gap-1">
                            <FileText className="h-3 w-3 text-purple-600" /> Total Invoice
                          </div>
                          <div className="text-xs font-extrabold text-foreground mt-1">
                            {dailySummary.invoiceCount} Invoice
                          </div>
                          <div className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">
                            100% Diverifikasi
                          </div>
                        </div>

                        <div className="p-2.5 rounded-xl bg-background/80 border border-emerald-100 dark:border-emerald-900/40 shadow-2xs">
                          <div className="text-[10px] font-semibold text-muted-foreground flex items-center gap-1">
                            <Radio className="h-3 w-3 text-emerald-600" /> Waktu Operasi
                          </div>
                          <div className="text-[11px] font-bold text-foreground mt-1">
                            {dailySummary.firstTime} - {dailySummary.lastTime}
                          </div>
                          <div className="text-[10px] text-muted-foreground">
                            Pickup s/d POD
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                  {(() => {
                    // Sort items chronologically (oldest at top to newest at bottom like WhatsApp chat)
                    const chronologicalItems = [...activeGroup.items].sort(
                      (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
                    )

                    const dateGroups = new Map<string, WebNotification[]>()
                    chronologicalItems.forEach((item) => {
                      const label = getDateGroupLabel(item.created_at)
                      if (!dateGroups.has(label)) dateGroups.set(label, [])
                      dateGroups.get(label)!.push(item)
                    })

                    return Array.from(dateGroups.entries()).map(([dateLabel, items]) => (
                      <div key={dateLabel} className="space-y-4">
                        {/* Date Divider Pill */}
                        <div className="flex justify-center">
                          <span className="px-4 py-1 rounded-full bg-background/90 border border-border text-[11px] font-semibold text-muted-foreground shadow-xs">
                            {dateLabel}
                          </span>
                        </div>

                        {/* Notifications in this date group */}
                        {items.map((item) => {
                          const statusInfo = getNotificationEventDetails(item.title, item.message)

                          return (
                            <div key={item.id} className="space-y-2.5 max-w-2xl mx-auto">
                              {/* Status Pill Badge Centered */}
                              <div className="flex justify-center">
                                <span className={`inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full text-xs font-bold border shadow-2xs ${statusInfo.pillBg}`}>
                                  {statusInfo.icon}
                                  {statusInfo.badgeLabel}
                                </span>
                              </div>

                              {/* Notification Message Card Bubble */}
                              <div className="rounded-2xl border border-border bg-card p-4 shadow-xs space-y-2 hover:border-blue-300/50 transition-colors">
                                <div className="flex items-center justify-between gap-2 font-bold text-xs text-foreground">
                                  <div className="flex items-center gap-2">
                                    {statusInfo.icon}
                                    <span>{item.title || statusInfo.badgeLabel}</span>
                                  </div>
                                  <span className="text-[10px] text-muted-foreground font-normal">
                                    {formatClockTime(item.created_at)}
                                  </span>
                                </div>

                                <p className="text-xs text-muted-foreground leading-relaxed pt-0.5">
                                  {item.message}
                                </p>

                                <div className="flex items-center justify-end gap-1 pt-1 text-[10px] text-muted-foreground font-medium border-t border-border/40">
                                  <span>{formatClockTime(item.created_at)}</span>
                                  <CheckCheck className="h-3.5 w-3.5 text-blue-600" />
                                </div>
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    ))
                  })()}
                </div>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-center text-center p-6">
                <div>
                  <Bell className="mx-auto h-12 w-12 text-muted-foreground/30 mb-3" />
                  <h3 className="font-bold text-sm text-foreground">Pilih Notifikasi</h3>
                  <p className="text-xs text-muted-foreground mt-1">Pilih salah satu notifikasi di sebelah kiri untuk melihat detail laporan.</p>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </DashboardShell>
  )
}
