'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { notificationsAPI } from '@/lib/api'
import { useNotifications, WebNotification } from '@/context/NotificationContext'
import {
  Bell, CheckCheck, CheckCircle2, Truck, Package, Radio, RefreshCw, ChevronDown, Search
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

function getNotificationTheme(titleStr: string, messageStr: string) {
  const text = `${titleStr || ''} ${messageStr || ''}`.toLowerCase()

  if (text.includes('selesai') || text.includes('completed') || text.includes('done') || text.includes('pod')) {
    return {
      title: titleStr.includes('DONE') || titleStr.includes('COMPLETED') ? titleStr : 'Pesanan SELESAI (DONE)',
      icon: <CheckCircle2 className="h-5 w-5 text-emerald-600 dark:text-emerald-400" />,
      circleBg: 'border-2 border-emerald-600 bg-emerald-50 dark:bg-emerald-950/50',
    }
  }
  if (text.includes('pengantaran') || text.includes('delivering') || text.includes('kurir jalan') || text.includes('antar')) {
    return {
      title: titleStr.includes('DELIVERING') ? titleStr : 'Pesanan DALAM PENGANTARAN (DELIVERING)',
      icon: <Truck className="h-5 w-5 text-blue-600 dark:text-blue-400" />,
      circleBg: 'border-2 border-blue-600 bg-blue-50 dark:bg-blue-950/50',
    }
  }
  if (text.includes('penjemputan') || text.includes('pickup') || text.includes('tugas') || text.includes('faktur')) {
    return {
      title: titleStr.includes('PICKUP') || titleStr.includes('PENJEMPUTAN') ? titleStr : 'Penjemputan APOTEK (PICKING UP)',
      icon: <Package className="h-5 w-5 text-amber-600 dark:text-amber-400" />,
      circleBg: 'border-2 border-amber-600 bg-amber-50 dark:bg-amber-950/50',
    }
  }
  if (text.includes('tiba') || text.includes('lokasi') || text.includes('arrived')) {
    return {
      title: titleStr.includes('ARRIVED') || titleStr.includes('TIBA') ? titleStr : 'Driver TIBA DI LOKASI (ARRIVED)',
      icon: <Radio className="h-5 w-5 text-purple-600 dark:text-purple-400" />,
      circleBg: 'border-2 border-purple-600 bg-purple-50 dark:bg-purple-950/50',
    }
  }

  return {
    title: titleStr || 'Pemberitahuan Sistem',
    icon: <Bell className="h-5 w-5 text-emerald-600 dark:text-emerald-400" />,
    circleBg: 'border-2 border-emerald-600 bg-emerald-50 dark:bg-emerald-950/50',
  }
}

export default function NotificationsWebPage() {
  const router = useRouter()
  const { notifications, unreadCount, markAllAsRead, fetchNotifications } = useNotifications()
  const [filter, setFilter] = useState<'ALL' | 'UNREAD' | 'REPORTS'>('ALL')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [visibleCount, setVisibleCount] = useState(6)

  const handleRefresh = async () => {
    setLoading(true)
    await fetchNotifications()
    setLoading(false)
  }

  const filtered = notifications.filter((n) => {
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

  const visibleNotifications = filtered.slice(0, visibleCount)
  const hasMore = filtered.length > visibleCount

  const handleNotificationClick = async (n: WebNotification) => {
    try {
      await notificationsAPI.markRead()
    } catch (_) {}

    const text = `${n.title} ${n.message}`
    const match = text.match(/DSP-\d+|ORD-\d+|#\d+/)
    if (match) {
      const dispatchIdStr = match[0].replace('#', '')
      router.push(`/dashboard/dispatch/${dispatchIdStr}/tracking`)
    }
  }

  return (
    <DashboardShell onRefresh={handleRefresh}>
      <div className="space-y-6 max-w-5xl mx-auto">
        {/* Top Header Banner */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 rounded-2xl bg-card p-6 border border-border shadow-sm">
          <div className="space-y-1">
            <div className="inline-flex items-center gap-2 rounded-lg bg-emerald-50 dark:bg-emerald-950/40 px-3 py-1 text-xs font-bold text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
              <Bell className="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" />
              PUSAT PEMBERITAHUAN WEBSITES
            </div>
            <h2 className="text-2xl font-bold tracking-tight text-foreground">Halaman Notifikasi & Laporan Pengiriman</h2>
            <p className="text-xs text-muted-foreground">
              Laporan terkini penjemputan apotek, pengantaran kurir jalan, dan status penyelesaian order.
            </p>
          </div>

          <div className="flex items-center gap-2">
            {unreadCount > 0 && (
              <button
                onClick={markAllAsRead}
                className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white hover:bg-emerald-500 transition shadow-sm"
              >
                <CheckCheck className="h-4 w-4" />
                Tandai Semua Dibaca
              </button>
            )}
            <button
              onClick={handleRefresh}
              className="inline-flex items-center gap-2 rounded-xl bg-background px-4 py-2.5 text-xs font-semibold text-foreground border border-border hover:bg-accent transition"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </div>

        {/* Search & Filter Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-3">
          <div className="flex items-center gap-2 overflow-x-auto">
            <button
              onClick={() => setFilter('ALL')}
              className={`px-4 py-2 text-xs font-bold rounded-xl transition ${filter === 'ALL' ? 'bg-primary text-primary-foreground shadow-sm' : 'bg-muted/60 text-muted-foreground hover:text-foreground'}`}
            >
              Semua ({notifications.length})
            </button>
            <button
              onClick={() => setFilter('UNREAD')}
              className={`px-4 py-2 text-xs font-bold rounded-xl transition ${filter === 'UNREAD' ? 'bg-emerald-600 text-white shadow-sm' : 'bg-muted/60 text-muted-foreground hover:text-foreground'}`}
            >
              Belum Dibaca ({unreadCount})
            </button>
            <button
              onClick={() => setFilter('REPORTS')}
              className={`px-4 py-2 text-xs font-bold rounded-xl transition ${filter === 'REPORTS' ? 'bg-blue-600 text-white shadow-sm' : 'bg-muted/60 text-muted-foreground hover:text-foreground'}`}
            >
              Laporan Pengiriman
            </button>
          </div>

          <div className="relative min-w-[240px]">
            <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-muted-foreground" />
            <input
              type="text"
              placeholder="Cari No Order / Notifikasi..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full rounded-xl border border-input bg-background pl-8 pr-3 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500/50"
            />
          </div>
        </div>

        {/* Main Container Card (Clean White Modern Theme matching Screenshot 2) */}
        <div className="rounded-2xl border border-border bg-card p-4 sm:p-6 shadow-sm space-y-4">
          {visibleNotifications.length === 0 ? (
            <div className="flex h-64 items-center justify-center text-center p-6">
              <div>
                <Bell className="mx-auto h-12 w-12 text-muted-foreground/40 mb-3" />
                <h3 className="font-bold text-foreground text-sm">Belum Ada Notifikasi Baru</h3>
                <p className="text-xs text-muted-foreground mt-1">Pemberitahuan terkini tentang tugas pengantaran akan muncul di halaman ini.</p>
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              {visibleNotifications.map((item) => {
                const theme = getNotificationTheme(item.title, item.message)
                const isUnread = !item.is_read

                return (
                  <div
                    key={item.id}
                    onClick={() => handleNotificationClick(item)}
                    className={`group cursor-pointer rounded-2xl border border-border p-4 transition-all flex items-start gap-4 hover:border-emerald-500/50 hover:bg-accent/40 ${
                      isUnread
                        ? 'border-l-4 border-l-emerald-600 bg-emerald-50/20 dark:bg-emerald-950/20 shadow-sm'
                        : 'bg-card'
                    }`}
                  >
                    {/* Status Circle Icon */}
                    <div className={`flex h-10 w-10 items-center justify-center rounded-full shrink-0 ${theme.circleBg}`}>
                      {theme.icon}
                    </div>

                    {/* Notification Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-2 mb-1">
                        <h4 className={`text-sm font-bold truncate ${isUnread ? 'text-foreground font-black' : 'text-slate-700 dark:text-slate-300'}`}>
                          {theme.title}
                        </h4>
                        <span className={`text-xs font-semibold shrink-0 ${isUnread ? 'text-emerald-600 dark:text-emerald-400 font-bold' : 'text-muted-foreground'}`}>
                          {formatTimeAgo(item.created_at)}
                        </span>
                      </div>

                      <p className="text-xs text-muted-foreground leading-relaxed">
                        {item.message}
                      </p>
                    </div>
                  </div>
                )
              })}
            </div>
          )}

          {/* Load More Button ("Muat Lebih Banyak") */}
          {hasMore && (
            <div className="pt-2 text-center border-t border-border/40">
              <button
                onClick={() => setVisibleCount((prev) => prev + 6)}
                className="inline-flex items-center justify-center gap-2 w-full py-3 text-xs font-bold text-slate-700 dark:text-slate-300 hover:text-emerald-600 dark:hover:text-emerald-400 transition"
              >
                <ChevronDown className="h-4 w-4 text-slate-500" />
                Muat Lebih Banyak
              </button>
            </div>
          )}
        </div>
      </div>
    </DashboardShell>
  )
}
