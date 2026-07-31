'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/context/AuthContext'
import { toast } from 'sonner'
import { Eye, EyeOff, Loader2, Package, AlertCircle } from 'lucide-react'

export default function LoginPage() {
  const { login, isAuthenticated, user } = useAuth()
  const router = useRouter()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && user) {
      const dest = user.role === 'MITRA' ? '/dashboard/create-order' : '/dashboard/overview'
      router.replace(dest)
    }
  }, [isAuthenticated, user, router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setErrorMessage(null)
    if (!email.trim() || !password.trim()) {
      const errText = 'Email dan password wajib diisi.'
      setErrorMessage(errText)
      toast.error('Gagal Masuk', {
        description: errText,
      })
      return
    }
    setIsLoading(true)
    const result = await login(email, password)
    setIsLoading(false)

    if (result.success) {
      // Set lightweight cookie for middleware
      document.cookie = 'k24_auth=1; path=/; max-age=28800; SameSite=Lax'
      toast.success('Berhasil Masuk!', {
        description: 'Selamat datang kembali di K-24 Logistics.',
      })
      const dest = result.role === 'MITRA' ? '/dashboard/create-order' : '/dashboard/overview'
      router.push(dest)
    } else {
      const errorMsg = result.error || 'Email atau password yang Anda masukkan salah.'
      setErrorMessage(errorMsg)
      toast.error('Login Gagal', {
        description: errorMsg,
        duration: 5000,
      })
    }
  }

  return (
    <div className="min-h-screen w-full flex flex-col md:flex-row bg-[#F7F9FB] text-[#191C1E] antialiased selection:bg-blue-600 selection:text-white font-sans">
      {/* ─── Left Panel: Functional Zone (60% Desktop) ─── */}
      <div className="w-full md:w-[60%] flex flex-col bg-white relative z-10 min-h-screen p-6 md:p-12 lg:p-16">
        {/* Header / Logo */}
        <div className="flex items-center space-x-3 mb-10 md:mb-20">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#2563EB] to-[#1E3A8A] flex items-center justify-center shadow-[0_8px_16px_-4px_rgba(37,99,235,0.25)]">
            <Package className="w-5 h-5 text-white" />
          </div>
          <div className="flex items-baseline">
            <span className="text-xl font-extrabold tracking-tight bg-gradient-to-br from-[#2563EB] to-[#1E3A8A] bg-clip-text text-transparent">
              K-24
            </span>
            <span className="text-xs font-bold text-[#64748B] uppercase tracking-widest ml-1.5">
              LOGISTICS
            </span>
          </div>
        </div>

        {/* Form Container (Centered Vertically) */}
        <div className="w-full max-w-md mx-auto flex-1 flex flex-col justify-center">
          {/* Headings */}
          <div className="mb-8 text-center md:text-left">
            <h1 className="text-2xl sm:text-3xl font-bold text-[#0F172A] tracking-tight mb-2">
              Selamat Datang Kembali
            </h1>
            <p className="text-sm text-[#64748B]">
              Masuk ke akun K-24 Logistics Anda untuk melanjutkan
            </p>
          </div>

          {/* Social Login Buttons */}
          <div className="grid grid-cols-2 gap-3.5 mb-6">
            <button
              type="button"
              disabled
              title="Google Login — segera hadir"
              className="flex items-center justify-center w-full px-4 py-2.5 border border-[#E2E8F0] rounded-xl bg-white text-[#334155] text-xs font-semibold hover:bg-[#F8FAFC] transition-all duration-200 shadow-[0_1px_2px_rgba(0,0,0,0.04)] opacity-75 cursor-not-allowed"
            >
              <svg className="w-4 h-4 mr-2" viewBox="0 0 24 24">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05" />
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
              </svg>
              Google
            </button>
            <button
              type="button"
              disabled
              title="GitHub Login — segera hadir"
              className="flex items-center justify-center w-full px-4 py-2.5 border border-[#E2E8F0] rounded-xl bg-white text-[#334155] text-xs font-semibold hover:bg-[#F8FAFC] transition-all duration-200 shadow-[0_1px_2px_rgba(0,0,0,0.04)] opacity-75 cursor-not-allowed"
            >
              <svg className="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                <path fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
              </svg>
              GitHub
            </button>
          </div>

          {/* Divider */}
          <div className="relative flex py-4 items-center mb-6">
            <div className="flex-grow border-t border-[#E2E8F0]" />
            <span className="flex-shrink-0 mx-4 text-[#64748B] text-[11px] font-semibold uppercase tracking-wider">
              ATAU LANJUTKAN DENGAN
            </span>
            <div className="flex-grow border-t border-[#E2E8F0]" />
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            {errorMessage && (
              <div className="p-3.5 bg-red-50 border border-red-200 rounded-xl text-xs text-red-600 font-medium flex items-center gap-2.5 animate-in fade-in duration-200">
                <AlertCircle className="w-4 h-4 text-red-500 flex-shrink-0" />
                <span>{errorMessage}</span>
              </div>
            )}
            <div>
              <label className="block text-xs font-semibold text-[#334155] mb-1.5" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                type="email"
                placeholder="nama@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={isLoading}
                autoComplete="email"
                required
                className="w-full px-4 py-2.5 bg-white border border-[#CBD5E1] rounded-xl text-sm text-[#0F172A] placeholder-[#94A3B8] outline-none transition-all duration-200 focus:border-[#2563EB] focus:ring-4 focus:ring-[#2563EB]/15 disabled:opacity-50"
              />
            </div>

            <div>
              <div className="flex justify-between items-center mb-1.5">
                <label className="block text-xs font-semibold text-[#334155]" htmlFor="password">
                  Password
                </label>
                <button
                  type="button"
                  onClick={() => toast.info('Reset password dapat menghubungi Administrator K-24.')}
                  className="text-xs text-[#64748B] hover:text-[#2563EB] transition-colors"
                >
                  Hubungi admin jika lupa password
                </button>
              </div>
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  placeholder="Masukkan password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={isLoading}
                  autoComplete="current-password"
                  required
                  className="w-full px-4 py-2.5 bg-white border border-[#CBD5E1] rounded-xl text-sm text-[#0F172A] placeholder-[#94A3B8] outline-none transition-all duration-200 focus:border-[#2563EB] focus:ring-4 focus:ring-[#2563EB]/15 disabled:opacity-50 pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-[#94A3B8] hover:text-[#334155] focus:outline-none transition-colors"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div className="pt-2">
              <button
                type="submit"
                disabled={isLoading}
                className="w-full flex justify-center items-center gap-2 py-3 px-4 rounded-xl text-white font-semibold text-sm bg-gradient-to-r from-[#2563EB] to-[#1E3A8A] shadow-[0_4px_14px_0_rgba(37,99,235,0.39)] hover:shadow-[0_6px_20px_0_rgba(37,99,235,0.5)] active:scale-[0.99] transition-all duration-200 disabled:opacity-70 disabled:cursor-not-allowed"
              >
                {isLoading ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin text-white" />
                    <span>Masuk ke Dashboard...</span>
                  </>
                ) : (
                  'Masuk ke Dashboard'
                )}
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* ─── Right Panel: Brand Zone (40% Desktop) ─── */}
      <div 
        className="hidden md:flex md:w-[40%] flex-col items-center justify-between p-12 text-center relative shadow-[-10px_0_30px_rgba(0,0,0,0.15)] overflow-hidden"
        style={{
          background: 'radial-gradient(circle at center, #1E3A8A 0%, #0F172A 100%)'
        }}
      >
        {/* Subtle dot pattern grid overlay */}
        <div 
          className="absolute inset-0 opacity-40 pointer-events-none"
          style={{
            backgroundImage: `radial-gradient(circle at center, rgba(255,255,255,0.12) 1px, transparent 1px)`,
            backgroundSize: '24px 24px'
          }}
        />

        {/* Top Spacer */}
        <div className="flex-1" />

        {/* Center Branding */}
        <div className="flex flex-col items-center flex-[2] justify-center w-full max-w-sm relative z-10">
          <div className="w-24 h-24 rounded-2xl bg-gradient-to-br from-[#2563EB] to-[#1E3A8A] flex items-center justify-center mb-8 shadow-[0_8px_24px_rgba(37,99,235,0.35)] relative border border-white/20">
            <Package className="w-12 h-12 text-white" />
          </div>

          <h2 className="text-3xl font-extrabold text-white mb-2 tracking-tight">
            <span className="text-[#DBE1FF]">K-24</span> Logistics
          </h2>
          <p className="text-sm font-medium text-[#BEC6E0] mb-8">
            Sistem Manajemen Pengiriman Obat
          </p>

          {/* Glass Tags */}
          <div className="flex flex-wrap justify-center gap-2.5 w-full">
            {['Real-time Tracking', 'Driver Management', 'Order Dispatch', 'Mitra Network'].map((tag) => (
              <span
                key={tag}
                className="px-3.5 py-1.5 rounded-full text-xs font-medium text-white/90 bg-white/5 border border-white/10 backdrop-blur-md shadow-sm"
              >
                {tag}
              </span>
            ))}
          </div>
        </div>

        {/* Bottom Quote */}
        <div className="flex-1 flex flex-col justify-end w-full max-w-md pb-6 relative z-10 text-left">
          <blockquote className="pl-4 border-l-2 border-[#2563EB]/60">
            <p className="text-xs text-white/90 italic leading-relaxed mb-2">
              &ldquo;Platform K-24 Logistics memudahkan operasional pengiriman obat kami menjadi lebih efisien dan termonitor secara real-time.&rdquo;
            </p>
            <footer className="text-[11px] font-semibold text-[#BEC6E0]">
              — Tim Operasional K-24 Indonesia
            </footer>
          </blockquote>
        </div>
      </div>
    </div>
  )
}

