'use client'

import { useState, useRef, useEffect } from 'react'
import { usePathname } from 'next/navigation'
import Link from 'next/link'
import { RefreshCw, Menu, Plus, Bell, Check, CheckCheck, Truck, Package, CheckCircle2, FileText, Radio, ArrowRight } from 'lucide-react'
import { useAuth } from '@/context/AuthContext'
import { useNotifications, WebNotification } from '@/context/NotificationContext'

const TAB_TITLES: Record<string, { title: string; sub: string }> = {
  overview:       { title: 'Ringkasan Dashboard',       sub: 'Status, pertumbuhan, dan logistik pengiriman apotek saat ini.' },
  'track-live':   { title: 'Lacak Live & Radar Pengiriman', sub: 'Pantau posisi kurir, peta rute GPS, dan log status order real-time.' },
  notifications:  { title: 'Notifikasi & Laporan System', sub: 'Pusat pemberitahuan tugas pengantaran dan konfirmasi order.' },
  drivers:        { title: 'Manajemen Driver',          sub: 'Pantau armada pengiriman obat dan detail registrasi kurir.' },
  mitra:          { title: 'Apotek Mitra K-24',         sub: 'Daftar dan kelola lokasi outlet apotek mitra franchise K-24.' },
  'create-order': { title: 'Buat Order Pengiriman',     sub: 'Kirim pesanan kesehatan secara cepat lewat armada K-24.' },
  dispatch:       { title: 'Dispatch Operator (OTMS)',  sub: 'Penugasan kurir driver dan routing manual pengiriman obat.' },
  orders:         { title: 'Daftar Order',              sub: 'Riwayat semua order bulk yang telah dibuat.' },
}

interface TopbarProps {
  onMobileMenuClick?: () => void
  onRefresh?: () => void
  showCreateMitra?: boolean
  onCreateMitra?: () => void
  showCreateForm?: boolean
}

function formatTimeAgo(dateStr: string): string {
  try {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000)
    if (isNaN(diff) || diff < 0) return 'Baru saja'
    if (diff < 60) return 'Baru saja'
    if (diff < 3600) return `${Math.floor(diff / 60)} mnt lalu`
    if (diff < 86400) return `${Math.floor(diff / 3600)} jam lalu`
    return `${Math.floor(diff / 86400)} hr lalu`
  } catch {
    return dateStr
  }
}

function getNotifIcon(title: string) {
  const lower = title.toLowerCase()
  if (lower.includes('dispatch') || lower.includes('tugas')) {
    return <Truck className="h-4 w-4 text-blue-600" />
  }
  if (lower.includes('pickup')) {
    return <Package className="h-4 w-4 text-amber-600" />
  }
  if (lower.includes('selesai') || lower.includes('completed') || lower.includes('done')) {
    return <CheckCircle2 className="h-4 w-4 text-emerald-600" />
  }
  return <FileText className="h-4 w-4 text-purple-600" />
}

export default function Topbar({ onMobileMenuClick, onRefresh, showCreateMitra, onCreateMitra, showCreateForm }: TopbarProps) {
  const pathname = usePathname()
  const { user } = useAuth()
  const { notifications, unreadCount, markAllAsRead, markNotificationRead } = useNotifications()
  const [showNotifMenu, setShowNotifMenu] = useState(false)
  const [filter, setFilter] = useState<'ALL' | 'UNREAD'>('ALL')
  const menuRef = useRef<HTMLDivElement>(null)

  const segment = pathname.split('/').filter(Boolean).pop() || 'overview'
  const tabKey = segment === 'dashboard' ? 'overview' : segment
  const pageInfo = TAB_TITLES[tabKey] || { title: 'Dashboard', sub: '' }

  const initials = user?.name
    ? user.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()
    : 'U'

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setShowNotifMenu(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const filteredNotifs = notifications.filter((n) => {
    if (filter === 'UNREAD') return !n.is_read
    return true
  })

  return (
    <header className="sticky top-0 z-30 flex h-16 shrink-0 items-center gap-3 border-b border-border bg-background/90 px-4 backdrop-blur-xl">
      {/* Mobile menu btn */}
      <button
        onClick={onMobileMenuClick}
        className="lg:hidden flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground hover:bg-accent transition-colors"
      >
        <Menu className="h-5 w-5" />
      </button>

      <div className="hidden lg:block h-6 w-px bg-border" />

      {/* Page title */}
      <div className="flex flex-col flex-1 min-w-0">
        <h1 className="text-sm font-bold truncate">{pageInfo.title}</h1>
        <p className="text-[11px] text-muted-foreground truncate hidden sm:block leading-tight">{pageInfo.sub}</p>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2">
        {/* Create Mitra btn */}
        {showCreateMitra && user?.role === 'ADMIN' && !showCreateForm && (
          <button
            id="create-mitra-btn"
            onClick={onCreateMitra}
            className="hidden sm:flex items-center gap-2 h-9 px-3 rounded-lg bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 transition-colors"
          >
            <Plus className="h-4 w-4" />
            Tambah Mitra
          </button>
        )}

        {onRefresh && (
          <button onClick={onRefresh} title="Refresh Data"
            className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground hover:bg-accent transition-colors">
            <RefreshCw className="h-4 w-4" />
          </button>
        )}

        {/* Notifications Bell */}
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setShowNotifMenu(!showNotifMenu)}
            title="Notifikasi Live"
            className="relative flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground hover:bg-accent transition-colors"
          >
            <Bell className="h-4 w-4" />
            {unreadCount > 0 && (
              <span className="absolute top-1.5 right-1.5 flex h-4 min-w-4 px-1 items-center justify-center rounded-full bg-red-600 text-[10px] font-bold text-white shadow-sm animate-pulse">
                {unreadCount > 9 ? '9+' : unreadCount}
              </span>
            )}
          </button>

          {/* Notification Popover Dropdown */}
          {showNotifMenu && (
            <div className="absolute right-0 mt-2 w-80 sm:w-96 rounded-2xl border border-border bg-background shadow-2xl z-50 overflow-hidden animate-in fade-in slide-in-from-top-2 duration-150">
              {/* Popover Header */}
              <div className="flex items-center justify-between px-4 py-3 border-b border-border bg-muted/40">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold">Notifikasi Logistik</span>
                  {unreadCount > 0 && (
                    <span className="px-2 py-0.5 rounded-full bg-blue-100 text-blue-700 font-bold text-[10px]">
                      {unreadCount} Baru
                    </span>
                  )}
                </div>
                {unreadCount > 0 && (
                  <button
                    onClick={markAllAsRead}
                    className="flex items-center gap-1 text-[11px] font-semibold text-blue-600 hover:text-blue-700 transition-colors"
                  >
                    <CheckCheck className="h-3.5 w-3.5" />
                    Tandai Dibaca
                  </button>
                )}
              </div>

              {/* Filter Tabs */}
              <div className="flex border-b border-border px-3 py-1.5 bg-muted/20 gap-2">
                <button
                  onClick={() => setFilter('ALL')}
                  className={`px-2.5 py-1 rounded-md text-[11px] font-medium transition-colors ${
                    filter === 'ALL' ? 'bg-background shadow-sm text-foreground font-bold' : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  Semua ({notifications.length})
                </button>
                <button
                  onClick={() => setFilter('UNREAD')}
                  className={`px-2.5 py-1 rounded-md text-[11px] font-medium transition-colors ${
                    filter === 'UNREAD' ? 'bg-background shadow-sm text-foreground font-bold' : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  Belum Dibaca ({unreadCount})
                </button>
              </div>

              {/* Notification List */}
              <div className="max-h-80 overflow-y-auto divide-y divide-border">
                {filteredNotifs.length === 0 ? (
                  <div className="flex flex-col items-center justify-center p-8 text-center">
                    <div className="h-10 w-10 rounded-full bg-muted flex items-center justify-center mb-2">
                      <Bell className="h-5 w-5 text-muted-foreground" />
                    </div>
                    <p className="text-xs font-medium text-muted-foreground">Belum ada notifikasi saat ini</p>
                  </div>
                ) : (
                  filteredNotifs.map((n) => (
                    <div
                      key={n.id}
                      onClick={() => {
                        markNotificationRead(n.id)
                        setShowNotifMenu(false)
                      }}
                      className={`p-3.5 flex gap-3 transition-colors cursor-pointer ${
                        !n.is_read ? 'bg-blue-50/40 dark:bg-blue-950/20 font-medium' : 'hover:bg-muted/30'
                      }`}
                    >
                      <div className="flex-shrink-0 mt-0.5 p-2 rounded-xl bg-background border border-border shadow-xs">
                        {getNotifIcon(n.title)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2">
                          <h4 className="text-xs font-bold truncate text-foreground">{n.title}</h4>
                          <span className="text-[10px] text-muted-foreground whitespace-nowrap">
                            {formatTimeAgo(n.created_at)}
                          </span>
                        </div>
                        <p className="text-[11px] text-muted-foreground mt-0.5 line-clamp-2 leading-relaxed">
                          {n.message}
                        </p>
                      </div>
                    </div>
                  ))
                )}
              </div>
              <div className="p-2 border-t border-border bg-accent/20 text-center">
                <Link
                  href="/dashboard/notifications"
                  onClick={() => setShowNotifMenu(false)}
                  className="text-xs font-bold text-emerald-600 hover:text-emerald-500 inline-flex items-center gap-1 transition"
                >
                  Lihat Semua Notifikasi & Laporan <ArrowRight className="h-3 w-3" />
                </Link>
              </div>
            </div>
          )}
        </div>

        <div className="h-5 w-px bg-border mx-1" />

        {/* User */}
        <div className="flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-white font-bold text-xs shadow-sm">
            {initials}
          </div>
          <div className="hidden sm:flex flex-col">
            <span className="text-xs font-semibold leading-none">{user?.name || 'User'}</span>
            <span className="text-[10px] text-muted-foreground leading-none mt-0.5">
              {user?.role === 'ADMIN' ? 'Administrator' : 'Mitra'}
            </span>
          </div>
        </div>
      </div>
    </header>
  )
}
