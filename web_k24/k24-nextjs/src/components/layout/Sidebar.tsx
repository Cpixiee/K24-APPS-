'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname, useRouter, useSearchParams } from 'next/navigation'
import { useAuth } from '@/context/AuthContext'
import { cn } from '@/lib/utils'
import {
  BarChart3, Truck, Store, ShoppingBag, FileText,
  LogOut, Compass, Package, ChevronLeft, ChevronRight, X, Bell, CheckCircle2, ShieldAlert, Download
} from 'lucide-react'

interface SubNavItem {
  key: string
  label: string
  href: string
}

interface NavItem {
  key: string
  label: string
  icon: React.ElementType
  href: string
  roles?: ('ADMIN' | 'MITRA')[]
  children?: SubNavItem[]
}

const NAV_ITEMS: NavItem[] = [
  { key: 'overview',           label: 'Ringkasan',           icon: BarChart3,   href: '/dashboard/overview' },
  { key: 'notifications',      label: 'Notifikasi & Laporan',icon: Bell,        href: '/dashboard/notifications' },
  { key: 'detail-pengantaran', label: 'Detail Pengantaran',  icon: Package,     href: '/dashboard/detail-pengantaran' },
  { key: 'catatan-khusus',     label: 'Catatan Khusus',      icon: ShieldAlert, href: '/dashboard/catatan-khusus' },
  {
    key: 'drivers',
    label: 'Kelola Driver',
    icon: Truck,
    href: '/dashboard/drivers',
    roles: ['ADMIN'],
    children: [
      { key: 'drivers-list', label: 'Daftar Driver', href: '/dashboard/drivers?tab=approved' },
      { key: 'drivers-approval', label: 'Approval Pendaftaran Kurir', href: '/dashboard/drivers?tab=unapproved' },
    ]
  },
  { key: 'mitra',         label: 'Mitra',            icon: Store,       href: '/dashboard/mitra',        roles: ['ADMIN'] },
  { key: 'dispatch',      label: 'Dispatch Operator',icon: Compass,     href: '/dashboard/dispatch',     roles: ['ADMIN'] },
  { key: 'create-order',  label: 'Buat Order Baru',  icon: ShoppingBag, href: '/dashboard/create-order', roles: ['MITRA'] },
  { key: 'orders',        label: 'Daftar Order',     icon: FileText,    href: '/dashboard/orders' },
]

interface SidebarProps {
  isCollapsed: boolean
  setIsCollapsed: (v: boolean) => void
  mobileOpen?: boolean
  setMobileOpen?: (v: boolean) => void
}

export default function Sidebar({ isCollapsed, setIsCollapsed, mobileOpen, setMobileOpen }: SidebarProps) {
  const { user, logout, impersonatedMitra } = useAuth()
  const isMitraSkin = user?.role === 'MITRA' || !!impersonatedMitra
  const pathname = usePathname()
  const router = useRouter()
  const searchParams = useSearchParams()
  const tabParam = searchParams.get('tab')
  const [mounted, setMounted] = useState(false)
  const [expandedMenus, setExpandedMenus] = useState<Record<string, boolean>>({})

  // Disable transition on initial load to prevent closing animation on transition
  useEffect(() => {
    const timer = setTimeout(() => {
      setMounted(true)
    }, 50)
    return () => clearTimeout(timer)
  }, [])

  // Automatically expand parent if a child is active on load
  useEffect(() => {
    const activeParents: Record<string, boolean> = {}
    NAV_ITEMS.forEach(item => {
      if (item.children) {
        const hasActiveChild = item.children.some(child => {
          const url = new URL(child.href, 'http://localhost')
          const childPath = url.pathname
          const childTab = url.searchParams.get('tab')
          if (pathname !== childPath) return false
          if (childTab) return tabParam === childTab
          return !tabParam || tabParam === 'approved'
        })
        if (hasActiveChild) {
          activeParents[item.key] = true
        }
      }
    })
    setExpandedMenus(prev => ({ ...prev, ...activeParents }))
  }, [pathname, tabParam])

  const visibleItems = NAV_ITEMS.filter((item) => {
    if (!mounted) return !item.roles
    if (!item.roles) return true
    return user?.role ? item.roles.includes(user.role as 'ADMIN' | 'MITRA') : false
  })

  const isChildActive = (childHref: string) => {
    const url = new URL(childHref, 'http://localhost')
    const childPath = url.pathname
    const childTab = url.searchParams.get('tab')
    
    if (pathname !== childPath) return false
    if (childTab) return tabParam === childTab
    return !tabParam || tabParam === 'approved'
  }

  const isParentActive = (item: NavItem) => {
    if (item.children) {
      return item.children.some(child => isChildActive(child.href))
    }
    return pathname === item.href
  }

  const handleLogout = () => {
    logout()
  }

  const initials = user?.name
    ? user.name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase()
    : 'U'

  return (
    <>
      {/* Backdrop for mobile */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 lg:hidden"
          onClick={() => setMobileOpen?.(false)}
        />
      )}

      {/* Sidebar — K-24 Skin responsive */}
      <aside
        className={cn(
          'fixed inset-y-0 left-0 z-50 flex flex-col bg-sidebar border-r border-sidebar-border',
          mounted ? 'transition-all duration-300' : 'transition-none',
          isCollapsed ? 'w-16' : 'w-64',
          'lg:translate-x-0',
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        {/* ─── Brand ─── */}
        <div className={cn(
          'flex items-center border-b border-sidebar-border shrink-0',
          isCollapsed ? 'h-16 justify-center px-2' : 'h-16 justify-between px-4'
        )}>
          {!isCollapsed && (
            <Link href="/dashboard/overview" className="flex items-center gap-2.5">
              {isMitraSkin ? (
                <>
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white shadow-sm overflow-hidden p-0.5 border border-emerald-300 dark:border-emerald-800 shrink-0">
                    <img src="/logo_k24.png" alt="Apotek K-24 Logo" className="h-full w-full object-contain" />
                  </div>
                  <div className="flex flex-col">
                    <div className="flex items-center gap-1">
                      <span className="text-sm font-black tracking-tight text-foreground leading-none">APOTEK K-24</span>
                      <span className="px-1 py-0.2 text-[8px] font-black bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300 rounded border border-emerald-300 dark:border-emerald-800">
                        MITRA
                      </span>
                    </div>
                    <span className="text-[9px] font-bold uppercase tracking-wider text-muted-foreground mt-0.5">Apoteknya Indonesia</span>
                  </div>
                </>
              ) : (
                <>
                  <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-white shadow-sm overflow-hidden p-0.5 border border-border">
                    <img src="/logo_ningrat_icon.jpg" alt="NINGRAT Logo" className="h-full w-full object-contain" />
                  </div>
                  <div className="flex flex-col">
                    <span className="text-sm font-extrabold tracking-wide text-foreground leading-none">NINGRAT</span>
                    <span className="text-[9px] font-bold uppercase tracking-widest text-muted-foreground mt-0.5">Management System</span>
                  </div>
                </>
              )}
            </Link>
          )}

          {isCollapsed && (
            isMitraSkin ? (
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white shadow-sm overflow-hidden p-0.5 border border-emerald-300 dark:border-emerald-800 shrink-0">
                <img src="/logo_k24.png" alt="Apotek K-24 Logo" className="h-full w-full object-contain" />
              </div>
            ) : (
              <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-white shadow-sm overflow-hidden p-0.5 border border-border">
                <img src="/logo_ningrat_icon.jpg" alt="NINGRAT Logo" className="h-full w-full object-contain" />
              </div>
            )
          )}

          {/* Desktop collapse toggle */}
          <button
            onClick={() => setIsCollapsed(!isCollapsed)}
            className={cn(
              'hidden lg:flex h-6 w-6 items-center justify-center rounded-md text-muted-foreground hover:text-foreground hover:bg-sidebar-accent transition-colors',
              isCollapsed && 'absolute -right-3 top-5 h-6 w-6 rounded-full border border-sidebar-border bg-sidebar shadow-sm'
            )}
          >
            {isCollapsed ? <ChevronRight className="h-3 w-3" /> : <ChevronLeft className="h-3 w-3" />}
          </button>

          {/* Mobile close */}
          {!isCollapsed && (
            <button onClick={() => setMobileOpen?.(false)} className="lg:hidden text-muted-foreground hover:text-foreground">
              <X className="h-4 w-4" />
            </button>
          )}
        </div>

        {/* ─── User Info ─── */}
        {!isCollapsed && (
          <div className="px-4 py-3 border-b border-sidebar-border shrink-0">
            <div className="flex items-center gap-3">
              <div 
                suppressHydrationWarning 
                className={cn(
                  "flex h-9 w-9 items-center justify-center rounded-xl font-bold text-sm flex-shrink-0 border shadow-xs",
                  isMitraSkin
                    ? "bg-emerald-600 text-white border-emerald-500 ring-2 ring-red-500/30"
                    : "bg-blue-50 border-blue-200/60 text-blue-600 dark:bg-blue-950/20 dark:text-blue-400"
                )}
              >
                {initials}
              </div>
              <div className="flex-1 min-w-0">
                <p suppressHydrationWarning className="text-sm font-bold text-foreground truncate flex items-center gap-1">
                  {user?.name || 'Apotek K-24'}
                  {isMitraSkin && <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500 shrink-0" />}
                </p>
                <p suppressHydrationWarning className="text-xs text-muted-foreground truncate">
                  {isMitraSkin ? 'Apotek Mitra K-24 (Franchise)' : user?.role === 'ADMIN' ? 'Hub Manager' : 'Staff'}
                </p>
              </div>
            </div>
          </div>
        )}

        {/* ─── Nav ─── */}
        <nav className="flex-1 overflow-y-auto py-3 px-2 space-y-0.5 dashboard-scroll">
          {!isCollapsed && (
            <p className="px-2 mb-2 text-[10px] font-semibold uppercase tracking-widest text-muted-foreground">Menu</p>
          )}
          {visibleItems.map((item) => {
            const hasChildren = item.children && item.children.length > 0
            const active = isParentActive(item)
            const Icon = item.icon
            const isExpanded = expandedMenus[item.key]

            const toggleExpand = (e: React.MouseEvent) => {
              if (hasChildren) {
                if (isCollapsed) {
                  router.push(item.href)
                } else {
                  e.preventDefault()
                  setExpandedMenus(prev => ({
                    ...prev,
                    [item.key]: !prev[item.key]
                  }))
                }
              }
            }

            return (
              <div key={item.key} className="space-y-1">
                {hasChildren ? (
                  <button
                    onClick={toggleExpand}
                    title={isCollapsed ? item.label : undefined}
                    className={cn(
                      'w-full group relative flex items-center justify-between rounded-lg px-2.5 py-2 text-sm font-medium transition-all duration-150',
                      active
                        ? 'bg-blue-50/60 text-blue-600 dark:bg-blue-950/10 dark:text-blue-400'
                        : 'text-muted-foreground hover:bg-sidebar-accent hover:text-foreground',
                      isCollapsed && 'justify-center px-0'
                    )}
                  >
                    <div className="flex items-center gap-3">
                      {active && !isCollapsed && (
                        <div className="absolute left-0 top-1/2 h-5 w-0.5 -translate-y-1/2 rounded-r-full bg-blue-500" />
                      )}
                      <Icon className={cn('h-4 w-4 flex-shrink-0', active ? 'text-blue-600 dark:text-blue-400' : 'text-muted-foreground group-hover:text-foreground')} />
                      {!isCollapsed && <span>{item.label}</span>}
                    </div>
                    {!isCollapsed && (
                      <ChevronRight
                        className={cn(
                          'h-3.5 w-3.5 text-muted-foreground transition-transform duration-200',
                          isExpanded && 'transform rotate-90 text-blue-600 dark:text-blue-400'
                        )}
                      />
                    )}
                  </button>
                ) : (
                  <Link
                    href={item.href}
                    title={isCollapsed ? item.label : undefined}
                    className={cn(
                      'group relative flex items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-medium transition-all duration-150',
                      active
                        ? 'bg-blue-50 text-blue-600 dark:bg-blue-950/20 dark:text-blue-400'
                        : 'text-muted-foreground hover:bg-sidebar-accent hover:text-foreground',
                      isCollapsed && 'justify-center px-0'
                    )}
                  >
                    {active && (
                      <div className="absolute left-0 top-1/2 h-5 w-0.5 -translate-y-1/2 rounded-r-full bg-blue-500" />
                    )}
                    <Icon className={cn('h-4 w-4 flex-shrink-0', active ? 'text-blue-600 dark:text-blue-400' : 'text-muted-foreground group-hover:text-foreground')} />
                    {!isCollapsed && <span>{item.label}</span>}
                  </Link>
                )}

                {hasChildren && isExpanded && !isCollapsed && (
                  <div className="pl-9 pr-1 py-1 space-y-1 border-l border-sidebar-border ml-4.5 animate-in slide-in-from-top-1 duration-150">
                    {item.children!.map((child) => {
                      const childActive = isChildActive(child.href)
                      return (
                        <Link
                          key={child.key}
                          href={child.href}
                          className={cn(
                            'block rounded-md px-3 py-1.5 text-xs font-medium transition-colors',
                            childActive
                              ? 'text-blue-600 bg-blue-50/40 dark:text-blue-400 dark:bg-blue-950/5 font-semibold'
                              : 'text-muted-foreground hover:text-foreground hover:bg-sidebar-accent/50'
                          )}
                        >
                          {child.label}
                        </Link>
                      )
                    })}
                  </div>
                )}
              </div>
            )
          })}
        </nav>

        {/* ─── APK Download & Logout ─── */}
        <div className="p-2 border-t border-sidebar-border shrink-0 space-y-1">
          <a
            href="/downloads/k24-driver-latest.apk"
            download="k24-driver-latest.apk"
            target="_blank"
            rel="noopener noreferrer"
            title={isCollapsed ? 'Download APK Driver' : undefined}
            className={cn(
              'flex w-full items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-semibold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 dark:bg-emerald-950/30 dark:text-emerald-400 dark:hover:bg-emerald-950/50 transition-colors',
              isCollapsed && 'justify-center px-0'
            )}
          >
            <Download className="h-4 w-4 flex-shrink-0 text-emerald-600 dark:text-emerald-400" />
            {!isCollapsed && <span>Download APK Driver</span>}
          </a>
          <button
            onClick={handleLogout}
            title={isCollapsed ? 'Keluar Sesi' : undefined}
            className={cn(
              'flex w-full items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-medium text-muted-foreground hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950/20 dark:hover:text-red-400 transition-colors',
              isCollapsed && 'justify-center px-0'
            )}
          >
            <LogOut className="h-4 w-4 flex-shrink-0" />
            {!isCollapsed && 'Keluar Sesi'}
          </button>
        </div>
      </aside>
    </>
  )
}
