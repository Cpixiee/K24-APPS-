'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { notificationsAPI } from '@/lib/api'
import { useNotifications, WebNotification } from '@/context/NotificationContext'
import { Bell, CheckCheck, FileText, Truck, CheckCircle2, Package, Radio, ArrowRight, RefreshCw, AlertCircle } from 'lucide-react'

function formatDateTime(dateStr: string): string {
  try {
    const d = new Date(dateStr)
    return d.toLocaleDateString('id-ID', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return dateStr
  }
}

function getNotifBadge(title: string) {
  const lower = (title || '').toLowerCase()
  if (lower.includes('sampai') || lower.includes('tiba') || lower.includes('lokasi')) {
    return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-purple-700 bg-purple-100 dark:bg-purple-950/60 px-2 py-0.5 rounded-full"><Radio className="h-3 w-3" /> Tiba di Lokasi</span>
  }
  if (lower.includes('selesai') || lower.includes('completed') || lower.includes('pod')) {
    return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-100 dark:bg-emerald-950/60 px-2 py-0.5 rounded-full"><CheckCircle2 className="h-3 w-3" /> Order Selesai</span>
  }
  if (lower.includes('dispatch') || lower.includes('tugas') || lower.includes('kurir')) {
    return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-blue-700 bg-blue-100 dark:bg-blue-950/60 px-2 py-0.5 rounded-full"><Truck className="h-3 w-3" /> Pengiriman</span>
  }
  return <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-700 bg-amber-100 dark:bg-amber-950/60 px-2 py-0.5 rounded-full"><Bell className="h-3 w-3" /> Info Sistem</span>
}

export default function NotificationsWebPage() {
  const router = useRouter()
  const { notifications, unreadCount, markAllAsRead, fetchNotifications } = useNotifications()
  const [filter, setFilter] = useState<'ALL' | 'UNREAD' | 'REPORTS'>('ALL')
  const [loading, setLoading] = useState(false)

  const handleRefresh = async () => {
    setLoading(true)
    await fetchNotifications()
    setLoading(false)
  }

  const filtered = notifications.filter((n) => {
    if (filter === 'UNREAD') return !n.is_read
    if (filter === 'REPORTS') {
      const lower = `${n?.title || ''} ${n?.message || ''}`.toLowerCase()
      return lower.includes('order') || lower.includes('faktur') || lower.includes('sampai') || lower.includes('selesai') || lower.includes('kurir')
    }
    return true
  })

  const handleNotificationClick = async (n: WebNotification) => {
    try {
      await notificationsAPI.markRead()
    } catch (_) {}

    // Extract Order ID or Order Number if present
    const text = `${n.title} ${n.message}`
    const match = text.match(/ORD-\d+|#\d+/)
    if (match) {
      const orderIdStr = match[0].replace('#', '')
      router.push(`/dashboard/track-live?orderId=${orderIdStr}`)
    } else {
      router.push('/dashboard/track-live')
    }
  }

  return (
    <div className="space-y-6 pb-12 max-w-5xl mx-auto">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 rounded-2xl bg-gradient-to-r from-slate-900 via-slate-800 to-slate-950 p-6 text-white shadow-xl border border-slate-700">
        <div className="space-y-1">
          <div className="inline-flex items-center gap-2 rounded-lg bg-emerald-500/20 px-3 py-1 text-xs font-bold text-emerald-400 border border-emerald-500/30">
            <Bell className="h-3.5 w-3.5 text-emerald-400" />
            PUSAT PEMBERITAHUAN WEBSITES
          </div>
          <h2 className="text-2xl font-black tracking-tight text-white">Halaman Notifikasi & Laporan Pengiriman</h2>
          <p className="text-xs text-slate-300">
            Daftar lengkap pemberitahuan tugas dispatch, kedatangan paket, dan log konfirmasi pengiriman obat.
          </p>
        </div>

        <div className="flex items-center gap-2">
          {unreadCount > 0 && (
            <button
              onClick={markAllAsRead}
              className="inline-flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2.5 text-xs font-bold text-white hover:bg-emerald-500 transition shadow-lg shadow-emerald-600/30"
            >
              <CheckCheck className="h-4 w-4" />
              Tandai Semua Dibaca
            </button>
          )}
          <button
            onClick={handleRefresh}
            className="inline-flex items-center gap-2 rounded-xl bg-slate-800 px-4 py-2.5 text-xs font-semibold text-white border border-slate-700 hover:bg-slate-700 transition"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center justify-between gap-4 border-b border-border pb-3">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setFilter('ALL')}
            className={`px-4 py-2 text-xs font-bold rounded-xl transition ${filter === 'ALL' ? 'bg-primary text-primary-foreground shadow' : 'bg-muted/60 text-muted-foreground hover:text-foreground'}`}
          >
            Semua ({notifications.length})
          </button>
          <button
            onClick={() => setFilter('UNREAD')}
            className={`px-4 py-2 text-xs font-bold rounded-xl transition ${filter === 'UNREAD' ? 'bg-emerald-600 text-white shadow' : 'bg-muted/60 text-muted-foreground hover:text-foreground'}`}
          >
            Belum Dibaca ({unreadCount})
          </button>
          <button
            onClick={() => setFilter('REPORTS')}
            className={`px-4 py-2 text-xs font-bold rounded-xl transition ${filter === 'REPORTS' ? 'bg-blue-600 text-white shadow' : 'bg-muted/60 text-muted-foreground hover:text-foreground'}`}
          >
            Laporan Pengiriman
          </button>
        </div>

        <Link
          href="/dashboard/track-live"
          className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-600 hover:text-emerald-500 transition"
        >
          <Radio className="h-4 w-4 animate-pulse" />
          Buka Radar Lacak Live
          <ArrowRight className="h-3.5 w-3.5" />
        </Link>
      </div>

      {/* Notifications List */}
      <div className="space-y-3">
        {filtered.length === 0 ? (
          <div className="flex h-64 items-center justify-center rounded-2xl border border-border bg-card text-center p-6">
            <div>
              <Bell className="mx-auto h-12 w-12 text-muted-foreground mb-3" />
              <h3 className="font-bold text-foreground text-sm">Belum Ada Notifikasi Baru</h3>
              <p className="text-xs text-muted-foreground mt-1">Pemberitahuan terkini tentang tugas pengantaran akan muncul di halaman ini.</p>
            </div>
          </div>
        ) : (
          filtered.map((item) => (
            <div
              key={item.id}
              onClick={() => handleNotificationClick(item)}
              className={`group cursor-pointer rounded-2xl border p-4.5 transition-all shadow-sm flex items-start gap-4 ${
                !item.is_read
                  ? 'border-emerald-500/50 bg-emerald-50/40 dark:bg-emerald-950/20 shadow-emerald-500/5'
                  : 'border-border bg-card hover:border-emerald-300/60 hover:bg-accent/40'
              }`}
            >
              <div className={`p-3 rounded-2xl shrink-0 ${!item.is_read ? 'bg-emerald-500 text-white shadow-md' : 'bg-muted text-muted-foreground'}`}>
                <Bell className="h-5 w-5" />
              </div>

              <div className="flex-1 min-w-0 space-y-1">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <h4 className={`text-sm font-bold truncate ${!item.is_read ? 'text-foreground font-black' : 'text-slate-700 dark:text-slate-300'}`}>
                      {item.title}
                    </h4>
                    {!item.is_read && (
                      <span className="h-2 w-2 rounded-full bg-emerald-500 animate-ping" />
                    )}
                  </div>
                  {getNotifBadge(item.title)}
                </div>

                <p className="text-xs text-muted-foreground leading-relaxed">{item.message}</p>

                <div className="flex items-center justify-between pt-2 text-[11px] text-muted-foreground">
                  <span>{formatDateTime(item.created_at)}</span>
                  <span className="font-bold text-emerald-600 group-hover:translate-x-1 transition-transform inline-flex items-center gap-1">
                    Lihat Laporan Detail <ArrowRight className="h-3 w-3" />
                  </span>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
