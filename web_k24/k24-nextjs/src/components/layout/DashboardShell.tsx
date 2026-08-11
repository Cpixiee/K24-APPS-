'use client'

import { useState, useEffect, Suspense } from 'react'
import { cn } from '@/lib/utils'
import Sidebar from '@/components/layout/Sidebar'
import Topbar from '@/components/layout/Topbar'

import { useAuth } from '@/context/AuthContext'
import { LogOut } from 'lucide-react'
import { toast } from 'sonner'

interface DashboardShellProps {
  children: React.ReactNode
  onRefresh?: () => void
  showCreateMitra?: boolean
  onCreateMitra?: () => void
  showCreateForm?: boolean
}

export default function DashboardShell({
  children,
  onRefresh,
  showCreateMitra,
  onCreateMitra,
  showCreateForm,
}: DashboardShellProps) {
  const { impersonatedMitra, stopImpersonation } = useAuth()
  const [isCollapsed, setIsCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [mounted, setMounted] = useState(false)

  // Persist sidebar state across page changes/refreshes
  useEffect(() => {
    const stored = localStorage.getItem('sidebar-collapsed')
    if (stored !== null) {
      setIsCollapsed(stored === 'true')
    }
    // Enable transitions after the initial render to prevent transitions on mount/navigation
    const timer = setTimeout(() => {
      setMounted(true)
    }, 50)
    return () => clearTimeout(timer)
  }, [])

  const handleSetCollapsed = (val: boolean) => {
    setIsCollapsed(val)
    localStorage.setItem('sidebar-collapsed', String(val))
  }

  return (
    <div className="min-h-screen bg-background">
      <Suspense fallback={<div className="w-16 lg:w-64 bg-sidebar border-r border-sidebar-border" />}>
        <Sidebar
          isCollapsed={isCollapsed}
          setIsCollapsed={handleSetCollapsed}
          mobileOpen={mobileOpen}
          setMobileOpen={setMobileOpen}
        />
      </Suspense>

      {/* Main content shifts right based on sidebar width */}
      <div
        className={cn(
          mounted ? 'transition-all duration-300' : 'transition-none',
          isCollapsed ? 'lg:pl-16' : 'lg:pl-64'
        )}
      >
        <Topbar
          onMobileMenuClick={() => setMobileOpen(true)}
          onRefresh={onRefresh}
          showCreateMitra={showCreateMitra}
          onCreateMitra={onCreateMitra}
          showCreateForm={showCreateForm}
        />
        {impersonatedMitra && (
          <div className="bg-gradient-to-r from-blue-600 via-indigo-600 to-blue-700 text-white px-4 py-2.5 shadow-md flex items-center justify-between gap-4 text-xs font-medium border-b border-blue-400/30">
            <div className="flex items-center gap-2 overflow-hidden">
              <span className="flex h-2 w-2 rounded-full bg-emerald-400 animate-pulse shrink-0" />
              <span className="font-bold uppercase tracking-wider text-[10px] bg-white/20 px-2 py-0.5 rounded text-white shrink-0">
                Remote Akses Mitra
              </span>
              <span className="truncate">
                Anda sedang mengakses akun <strong>{impersonatedMitra.name}</strong> ({impersonatedMitra.email}). Semua order yang dibuat akan terdaftar atas nama Mitra ini.
              </span>
            </div>
            <button
              type="button"
              onClick={() => {
                stopImpersonation()
                toast.success('Berhasil keluar dari mode Remote Akses Mitra.')
              }}
              className="shrink-0 flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 hover:bg-white/20 text-white font-bold transition-all border border-white/20 text-xs shadow-sm hover:scale-105 active:scale-95"
            >
              <LogOut className="h-3.5 w-3.5" />
              <span>Keluar Remote Akses</span>
            </button>
          </div>
        )}
        <main className="p-4 md:p-6 animate-fade-in">
          {children}
        </main>
      </div>
    </div>
  )
}
