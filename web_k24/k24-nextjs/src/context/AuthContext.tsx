'use client'

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react'
import { authAPI } from '@/lib/api'

interface UserData {
  id: number
  name: string
  email: string
  username?: string
  phone?: string
  role: 'ADMIN' | 'MITRA' | 'DRIVER'
  token: string
  profile_picture?: string
  vehicle_type?: string
  plate_number?: string
  is_active?: boolean
  rating?: number
}

interface AuthContextType {
  user: UserData | null
  loading: boolean
  error: string | null
  login: (email: string, password: string) => Promise<{ success: boolean; role?: string; error?: string }>
  logout: () => void
  isAuthenticated: boolean
  sessionRemainingMinutes: number | null
}

const AuthContext = createContext<AuthContextType | null>(null)

const SESSION_DURATION_MS = 8 * 60 * 60 * 1000 // 8 hours

function isSessionExpired(): boolean {
  try {
    const loginTime = localStorage.getItem('k24_login_time')
    if (!loginTime) return true
    return Date.now() - parseInt(loginTime, 10) > SESSION_DURATION_MS
  } catch {
    return true
  }
}

function loadUserFromStorage(): UserData | null {
  try {
    if (isSessionExpired()) {
      localStorage.removeItem('k24_token')
      localStorage.removeItem('k24_user')
      localStorage.removeItem('k24_login_time')
      return null
    }
    const saved = localStorage.getItem('k24_user')
    if (!saved) return null
    const parsed = JSON.parse(saved) as UserData
    if (parsed.role === 'DRIVER') {
      localStorage.removeItem('k24_token')
      localStorage.removeItem('k24_user')
      localStorage.removeItem('k24_login_time')
      return null
    }
    return parsed
  } catch {
    return null
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<UserData | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [hydrated, setHydrated] = useState(false)

  // Hydrate from localStorage on mount (client-side only)
  useEffect(() => {
    const loadedUser = loadUserFromStorage()
    setUser(loadedUser)
    setHydrated(true)
    if (!loadedUser && window.location.pathname.startsWith('/dashboard')) {
      document.cookie = 'k24_auth=; path=/; max-age=0; SameSite=Lax'
      window.location.href = '/login'
    }
  }, [])

  // Periodically check session expiry every 60 seconds
  useEffect(() => {
    if (!user) return
    const interval = setInterval(() => {
      if (isSessionExpired()) {
        localStorage.removeItem('k24_token')
        localStorage.removeItem('k24_user')
        localStorage.removeItem('k24_login_time')
        setUser(null)
        window.location.href = '/login'
      }
    }, 60_000)
    return () => clearInterval(interval)
  }, [user])

  const login = useCallback(async (email: string, password: string) => {
    setLoading(true)
    setError(null)
    try {
      const res = await authAPI.login(email, password)
      const { token, role, driver } = res.data.data
      
      if (role === 'DRIVER') {
        throw new Error('Akses ditolak: Hanya Admin atau Mitra yang diizinkan masuk ke dashboard web.')
      }

      const userData: UserData = { ...driver, role, token }
      localStorage.setItem('k24_token', token)
      localStorage.setItem('k24_user', JSON.stringify(userData))
      localStorage.setItem('k24_login_time', Date.now().toString())
      setUser(userData)
      return { success: true, role }
    } catch (err: any) {
      let msg = 'Email atau password yang Anda masukkan salah.'
      if (err?.response?.data?.message) {
        msg = err.response.data.message
      } else if (err?.message) {
        msg = err.message
      }
      setError(msg)
      return { success: false, error: msg }
    } finally {
      setLoading(false)
    }
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('k24_token')
    localStorage.removeItem('k24_user')
    localStorage.removeItem('k24_login_time')
    document.cookie = 'k24_auth=; path=/; max-age=0; SameSite=Lax'
    setUser(null)
    window.location.href = '/login'
  }, [])

  const sessionRemainingMinutes = user
    ? Math.max(
        0,
        Math.floor(
          (SESSION_DURATION_MS - (Date.now() - parseInt(localStorage.getItem('k24_login_time') || '0', 10))) / 60_000
        )
      )
    : null

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        error,
        login,
        logout,
        isAuthenticated: !!user,
        sessionRemainingMinutes,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
