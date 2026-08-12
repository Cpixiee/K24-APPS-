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
  markNotificationRead: (id: number) => void
}

const NotificationContext = createContext<NotificationContextType | null>(null)

function getStableId(str: string): number {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i)
    hash |= 0
  }
  return Math.abs(hash) % 100000
}

export function NotificationProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [notifications, setNotifications] = useState<WebNotification[]>([])
  const [loading, setLoading] = useState(false)
  const previousNotifIdsRef = useRef<Set<number>>(new Set())
  const isInitialLoadRef = useRef(true)

  const fetchNotifications = useCallback(async () => {
    if (!user) return

    // Get locally persisted read notification IDs and global read timestamp
    let savedReadSet = new Set<number>()
    let allReadUntilTime = 0
    try {
      if (typeof window !== 'undefined') {
        const stored = localStorage.getItem('k24_read_notifications')
        if (stored) {
          const readIdsArr: number[] = JSON.parse(stored)
          savedReadSet = new Set(readIdsArr)
        }
        const untilStr = localStorage.getItem('k24_all_read_until')
        if (untilStr) {
          allReadUntilTime = new Date(untilStr).getTime()
        }
      }
    } catch (_) {}

    try {
      const res = await notificationsAPI.getNotifications()
      const list: WebNotification[] = res.data?.data || []

      // Fetch active orders to generate real-time order lifecycle notification events
      try {
        const ordersRes = await adminAPI.getOrders()
        const ordersList: any[] = ordersRes.data?.data || []

        // Group orders by dispatch/batch key to calculate [Completed/Total] batch progress
        const groupMap = new Map<string, any[]>()
        ordersList.forEach((o) => {
          const key = o?.dispatch_id || o?.parent_order_number || o?.order_number || 'ORDER'
          if (!groupMap.has(key)) groupMap.set(key, [])
          groupMap.get(key)!.push(o)
        })

        const orderEvents: WebNotification[] = []

        groupMap.forEach((orders, dispatchKey) => {
          const totalCount = orders.length
          const completedCount = orders.filter((o) => o?.status === 'COMPLETED' || o?.status === 'DELIVERED').length
          const deliveringCount = orders.filter((o) => o?.status === 'DELIVERING' || o?.status === 'ON_DELIVERY').length
          const rawId = getStableId(dispatchKey)
          const firstOrder = orders[0]
          const pharm = firstOrder?.pharmacy_name || 'PT K-24 Indonesia'
          const dateStr = firstOrder?.created_at || new Date().toISOString()
          const driverStr = firstOrder?.driver_name ? ` (Driver ${firstOrder.driver_name})` : ''

          if (totalCount > 1) {
            // Multi-address batch dispatch tracking notification!
            if (completedCount > 0 && completedCount < totalCount) {
              const lastDone = orders.find((o) => o?.status === 'COMPLETED' || o?.status === 'DELIVERED')
              const doneAddr = lastDone?.delivery_address || lastDone?.customer_name || 'Alamat Penerima'
              const doneOrderNum = lastDone?.order_number || dispatchKey
              const remaining = totalCount - completedCount
              orderEvents.push({
                id: 95000 + rawId,
                driver_id: firstOrder?.driver_id || 0,
                title: `Progress [${completedCount}/${totalCount}] Order Selesai`,
                message: `[${completedCount}/${totalCount}] Order ${doneOrderNum} di ${doneAddr} telah SELESAI. Sisa ${remaining} alamat lagi dalam pengantaran${driverStr}.`,
                is_read: false,
                created_at: dateStr,
              })
            } else if (completedCount === totalCount) {
              orderEvents.push({
                id: 96000 + rawId,
                driver_id: firstOrder?.driver_id || 0,
                title: `Pengantaran [${totalCount}/${totalCount}] Alamat SELESAI`,
                message: `Seluruh ${totalCount} alamat pengantaran untuk Order ${dispatchKey} (${pharm}) telah SELESAI (COMPLETED)${driverStr}.`,
                is_read: false,
                created_at: dateStr,
              })
            } else if (deliveringCount > 0) {
              orderEvents.push({
                id: 90000 + rawId,
                driver_id: firstOrder?.driver_id || 0,
                title: `Batch [0/${totalCount}] DALAM PENGANTARAN`,
                message: `Order ${dispatchKey} (${pharm}) dengan ${totalCount} alamat pengantaran sedang DALAM PENGANTARAN${driverStr}.`,
                is_read: false,
                created_at: dateStr,
              })
            }
          } else {
            // Single order logic
            const o = firstOrder
            const num = o?.order_number || dispatchKey
            const customer = o?.customer_name || 'Pelanggan'
            if (o?.status === 'DELIVERING') {
              orderEvents.push({
                id: 90000 + rawId,
                driver_id: o?.driver_id || 0,
                title: 'Pesanan DALAM PENGANTARAN (DELIVERING)',
                message: `Order ${num} (${pharm}) sedang DALAM PENGANTARAN${driverStr} menuju alamat penerima ${customer}.`,
                is_read: false,
                created_at: dateStr,
              })
            } else if (o?.status === 'PICKING_UP' || o?.status === 'READY_FOR_PICKUP_FACTURE' || o?.status === 'WAITING_FOR_PICKUP') {
              orderEvents.push({
                id: 80000 + rawId,
                driver_id: o?.driver_id || 0,
                title: 'Penjemputan APOTEK (PICKING UP)',
                message: `Order ${num} (${pharm}) telah disiapkan dan siap untuk penjemputan obat di apotek.`,
                is_read: false,
                created_at: dateStr,
              })
            }
          }
        })

        // Merge order lifecycle events with API notifications
        const mergedMap = new Map<number, WebNotification>()
        orderEvents.forEach((item) => mergedMap.set(item.id, item))
        list.forEach((item) => mergedMap.set(item.id, item))

        const mergedList = Array.from(mergedMap.values())
          .map((item) => {
            const itemTime = new Date(item.created_at).getTime()
            if (savedReadSet.has(item.id) || (allReadUntilTime > 0 && itemTime <= allReadUntilTime)) {
              return { ...item, is_read: true }
            }
            return item
          })
          .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())

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
        const updatedList = list.map((item) => {
          const itemTime = new Date(item.created_at).getTime()
          if (savedReadSet.has(item.id) || (allReadUntilTime > 0 && itemTime <= allReadUntilTime)) {
            return { ...item, is_read: true }
          }
          return item
        })
        setNotifications(updatedList)
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

  const markNotificationRead = useCallback((id: number) => {
    try {
      notificationsAPI.markRead()
    } catch (_) {}

    try {
      if (typeof window !== 'undefined') {
        const stored = localStorage.getItem('k24_read_notifications')
        const readIds: number[] = stored ? JSON.parse(stored) : []
        if (!readIds.includes(id)) {
          readIds.push(id)
          localStorage.setItem('k24_read_notifications', JSON.stringify(readIds))
        }
      }
    } catch (_) {}

    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
    )
  }, [])

  const markAllAsRead = useCallback(async () => {
    try {
      await notificationsAPI.markRead()
    } catch (err) {
      console.error('Failed to mark notifications read', err)
    }

    try {
      if (typeof window !== 'undefined') {
        const allIds = notifications.map((n) => n.id)
        const stored = localStorage.getItem('k24_read_notifications')
        const readIds: number[] = stored ? JSON.parse(stored) : []
        const merged = Array.from(new Set([...readIds, ...allIds]))
        localStorage.setItem('k24_read_notifications', JSON.stringify(merged))
        localStorage.setItem('k24_all_read_until', new Date().toISOString())
      }
    } catch (_) {}

    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })))
  }, [notifications])

  const unreadCount = notifications.filter((n) => !n.is_read).length

  return (
    <NotificationContext.Provider
      value={{
        notifications,
        unreadCount,
        loading,
        fetchNotifications,
        markAllAsRead,
        markNotificationRead,
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
