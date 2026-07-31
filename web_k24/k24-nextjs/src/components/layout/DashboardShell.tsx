'use client'

import { useState, useEffect, Suspense } from 'react'
import { cn } from '@/lib/utils'
import Sidebar from '@/components/layout/Sidebar'
import Topbar from '@/components/layout/Topbar'

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
        <main className="p-4 md:p-6 animate-fade-in">
          {children}
        </main>
      </div>
    </div>
  )
}
