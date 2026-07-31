'use client'

import { createContext, useContext, useEffect, useState, ReactNode, useCallback, useRef } from 'react'
import { notificationsAPI } from '@/lib/api'
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
      setNotifications(list)

      // Detect new incoming notifications and trigger toast
      const newIds = new Set(list.map((n) => n.id))
      if (!isInitialLoadRef.current) {
        list.forEach((n) => {
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
      // Ignore background errors
    } finally {
      setLoading(false)
    }
  }, [user])

  useEffect(() => {
    if (!user) return
    fetchNotifications()

    // Poll every 5 seconds for real-time web notifications
    const interval = setInterval(fetchNotifications, 5000)
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

export const useNotifications = () => {
  const ctx = useContext(NotificationContext)
  if (!ctx) throw new Error('useNotifications must be used inside NotificationProvider')
  return ctx
}
