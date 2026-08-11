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

export interface ImpersonatedMitra {
  id: number
  name: string
  email: string
  phone?: string
}

interface AuthContextType {
  user: UserData | null
  impersonatedMitra: ImpersonatedMitra | null
  loading: boolean
  error: string | null
  login: (email: string, password: string) => Promise<{ success: boolean; role?: string; error?: string }>
  logout: () => void
  startImpersonation: (mitra: ImpersonatedMitra, token: string) => void
  stopImpersonation: () => void
  isAuthenticated: boolean
  sessionRemainingMinutes: number | null
}

const AuthContext = createContext<AuthContextType | null>(null)

const SESSION_DURATION_MS = 365 * 24 * 60 * 60 * 1000 // Long-lived session valid for 1 year (365 days)

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
      localStorage.removeItem('k24_impersonated_mitra')
      localStorage.removeItem('k24_original_admin')
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

function loadImpersonatedMitra(): ImpersonatedMitra | null {
  try {
    const saved = localStorage.getItem('k24_impersonated_mitra')
    return saved ? JSON.parse(saved) : null
  } catch {
    return null
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<UserData | null>(null)
  const [impersonatedMitra, setImpersonatedMitra] = useState<ImpersonatedMitra | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [hydrated, setHydrated] = useState(false)

  // Hydrate from localStorage on mount (client-side only)
  useEffect(() => {
    const loadedUser = loadUserFromStorage()
    const loadedImpersonated = loadImpersonatedMitra()
    setUser(loadedUser)
    setImpersonatedMitra(loadedImpersonated)
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
        localStorage.removeItem('k24_impersonated_mitra')
        localStorage.removeItem('k24_original_admin')
        setUser(null)
        setImpersonatedMitra(null)
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
      localStorage.removeItem('k24_impersonated_mitra')
      localStorage.removeItem('k24_original_admin')
      localStorage.setItem('k24_token', token)
      localStorage.setItem('k24_user', JSON.stringify(userData))
      localStorage.setItem('k24_login_time', Date.now().toString())
      setUser(userData)
      setImpersonatedMitra(null)
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

  const startImpersonation = useCallback((mitra: ImpersonatedMitra, token: string) => {
    if (user && !impersonatedMitra) {
      localStorage.setItem('k24_original_admin', JSON.stringify({ user, token: localStorage.getItem('k24_token') }))
    }
    const impersonatedUser: UserData = {
      id: mitra.id,
      name: mitra.name,
      email: mitra.email,
      phone: mitra.phone,
      role: 'MITRA',
      token,
    }
    localStorage.setItem('k24_token', token)
    localStorage.setItem('k24_user', JSON.stringify(impersonatedUser))
    localStorage.setItem('k24_impersonated_mitra', JSON.stringify(mitra))
    setUser(impersonatedUser)
    setImpersonatedMitra(mitra)
  }, [user, impersonatedMitra])

  const stopImpersonation = useCallback(() => {
    const orig = localStorage.getItem('k24_original_admin')
    if (orig) {
      try {
        const parsed = JSON.parse(orig)
        localStorage.setItem('k24_token', parsed.token)
        localStorage.setItem('k24_user', JSON.stringify(parsed.user))
        setUser(parsed.user)
      } catch (_) {}
    }
    localStorage.removeItem('k24_impersonated_mitra')
    localStorage.removeItem('k24_original_admin')
    setImpersonatedMitra(null)
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('k24_token')
    localStorage.removeItem('k24_user')
    localStorage.removeItem('k24_login_time')
    localStorage.removeItem('k24_impersonated_mitra')
    localStorage.removeItem('k24_original_admin')
    document.cookie = 'k24_auth=; path=/; max-age=0; SameSite=Lax'
    setUser(null)
    setImpersonatedMitra(null)
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
        impersonatedMitra,
        loading,
        error,
        login,
        logout,
        startImpersonation,
        stopImpersonation,
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
