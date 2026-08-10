'use client'

import { createContext, useContext, useEffect, useState, ReactNode, useCallback, useRef } from 'react'
import { notificationsAPI, adminAPI } from '@/lib/api'
import { useAuth } from '@/context/AuthContext'
import { toast } from 'sonner'

export interface WebNotification {
  id: number
  driver_id: number
  title: string
  message: string
  is_read: boolean
  created_at: string
}

interface NotificationContextType {
  notifications: WebNotification[]
  unreadCount: number
  loading: boolean
  fetchNotifications: () => Promise<void>
  markAllAsRead: () => Promise<void>
}

const NotificationContext = createContext<NotificationContextType | null>(null)

export function NotificationProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [notifications, setNotifications] = useState<WebNotification[]>([])
  const [loading, setLoading] = useState(false)
  const previousNotifIdsRef = useRef<Set<number>>(new Set())
  const isInitialLoadRef = useRef(true)

  const fetchNotifications = useCallback(async () => {
    if (!user) return
    try {
      const res = await notificationsAPI.getNotifications()
      const list: WebNotification[] = res.data?.data || []

      // Fetch active orders to generate real-time order lifecycle notification events (DELIVERING, PICKING UP, ARRIVED, etc.)
      try {
        const ordersRes = await adminAPI.getOrders()
        const ordersList: any[] = ordersRes.data?.data || []

        const orderEvents: WebNotification[] = []
        ordersList.forEach((o) => {
          const pharm = o.pharmacy_name || 'PT K-24 Indonesia'
          const num = o.order_number || `ORDER-00000${o.id}`
          const customer = o.customer_name || 'Pelanggan'
          const dateStr = o.created_at || new Date().toISOString()
          const driverStr = o.driver_name ? ` (Driver ${o.driver_name})` : ''

          if (o.status === 'DELIVERING') {
            orderEvents.push({
              id: 90000 + o.id,
              driver_id: o.driver_id || 0,
              title: 'Pesanan DALAM PENGANTARAN (DELIVERING)',
              message: `Order ${num} (${pharm}) sedang DALAM PENGANTARAN${driverStr} menuju alamat penerima ${customer}.`,
              is_read: false,
              created_at: dateStr,
            })
          } else if (o.status === 'PICKING_UP' || o.status === 'READY_FOR_PICKUP_FACTURE' || o.status === 'WAITING_FOR_PICKUP') {
            orderEvents.push({
              id: 80000 + o.id,
              driver_id: o.driver_id || 0,
              title: 'Penjemputan APOTEK (PICKING UP)',
              message: `Order ${num} (${pharm}) telah disiapkan dan siap untuk penjemputan obat di apotek.`,
              is_read: false,
              created_at: dateStr,
            })
          } else if (o.status === 'ARRIVED' || o.status === 'ARRIVED_AT_LOCATION') {
            orderEvents.push({
              id: 70000 + o.id,
              driver_id: o.driver_id || 0,
              title: 'Driver TIBA DI LOKASI (ARRIVED)',
              message: `Driver telah TIBA DI LOKASI alamat tujuan penerima ${customer} untuk order ${num}.`,
              is_read: false,
              created_at: dateStr,
            })
          }
        })

        // Merge order lifecycle events with API notifications and sort by timestamp DESC
        const mergedMap = new Map<number, WebNotification>()
        orderEvents.forEach((item) => mergedMap.set(item.id, item))
        list.forEach((item) => mergedMap.set(item.id, item))

        const mergedList = Array.from(mergedMap.values()).sort(
          (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
        )

        setNotifications(mergedList)

        // Detect new incoming notifications and trigger toast
        const newIds = new Set(mergedList.map((n) => n.id))
        if (!isInitialLoadRef.current) {
          mergedList.forEach((n) => {
            if (!previousNotifIdsRef.current.has(n.id) && !n.is_read) {
              toast(n.title, {
                description: n.message,
                duration: 6000,
              })
            }
          })
        } else {
          isInitialLoadRef.current = false
        }
        previousNotifIdsRef.current = newIds
      } catch {
        setNotifications(list)
      }
    } catch {
      // Ignore background errors
    } finally {
      setLoading(false)
    }
  }, [user])

  useEffect(() => {
    if (!user) return
    fetchNotifications()

    const interval = setInterval(() => {
      if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
        fetchNotifications()
      }
    }, 20000)
    return () => clearInterval(interval)
  }, [user, fetchNotifications])

  const markAllAsRead = useCallback(async () => {
    try {
      await notificationsAPI.markRead()
      setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })))
    } catch (err) {
      console.error('Failed to mark notifications read', err)
    }
  }, [])

  const unreadCount = notifications.filter((n) => !n.is_read).length

  return (
    <NotificationContext.Provider
      value={{
        notifications,
        unreadCount,
        loading,
        fetchNotifications,
        markAllAsRead,
      }}
    >
      {children}
    </NotificationContext.Provider>
  )
}

export function useNotifications() {
  const context = useContext(NotificationContext)
  if (!context) {
    throw new Error('useNotifications must be used within a NotificationProvider')
  }
  return context
}
