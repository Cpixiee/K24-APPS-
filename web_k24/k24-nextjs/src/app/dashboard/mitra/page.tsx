'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { useAuth } from '@/context/AuthContext'
import { toast } from 'sonner'
import { Search, AlertCircle, Plus, X, ChevronRight, ChevronLeft, ChevronDown, Store, Building2, CheckCircle2, Bike, Car, ExternalLink, LogIn, Loader2 } from 'lucide-react'

const PICKUP_LOCATIONS_K24 = [
  { name: 'PT K-24 Indonesia Cabang Jakarta (Gudang K-24)', lat: -6.2019957, long: 106.8551888 },
  { name: 'PT K-24 Indonesia Cabang Yogyakarta (Gudang K-24)', lat: -7.782889, long: 110.377042 },
  { name: 'PT K-24 Indonesia Cabang Surabaya (Gudang K-24)', lat: -7.2574719, long: 112.7520883 },
]

const PICKUP_LOCATIONS_PRIMAKU = [
  { name: 'Gudang Pusat Primaku Jakarta Hub', lat: -6.1753924, long: 106.8271528 },
  { name: 'Gudang Logistik Primaku Surabaya Depot', lat: -7.2574719, long: 112.7520883 },
]

const INITIAL_FORM = {
  username: '', email: '', name: '', phone: '', password: '',
  pic_name: '', pic_nik: '', alamat_lengkap: '', pickup_index: '', custom_pickup: '',
  motor_dimensi: '', motor_km: '', motor_titik: '', motor_berat: '',
  motor_zona1: '0', motor_zona2: '0', motor_zona3: '0',
  mobil_dimensi: '', mobil_km: '', mobil_titik: '', mobil_berat: '', mobil_lumpsum: '',
}

interface Mitra {
  id: number
  name: string
  username: string
  email: string
  phone: string
  mitra_type?: string
  created_at: string
}

type FormData = typeof INITIAL_FORM
type FormErrors = Partial<Record<keyof FormData | 'motor' | 'mobil', string>>

function FormField({ label, error, children }: { label: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1">
      <label className="text-sm font-medium">{label}</label>
      {children}
      {error && <p className="text-xs text-red-500">{error}</p>}
    </div>
  )
}

function InputField({ error, ...props }: React.InputHTMLAttributes<HTMLInputElement> & { error?: string }) {
  return (
    <input
      {...props}
      className={`h-10 w-full rounded-lg border bg-background px-3 text-sm outline-none transition-all focus:ring-2 ${
        error ? 'border-red-400 focus:border-red-500 focus:ring-red-500/20' : 'border-border focus:border-blue-500 focus:ring-blue-500/20'
      }`}
    />
  )
}

export default function MitraPage() {
  const router = useRouter()
  const { startImpersonation } = useAuth()
  const [remoteLoadingId, setRemoteLoadingId] = useState<number | null>(null)
  const [mitra, setMitra] = useState<Mitra[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [step, setStep] = useState(1)
  const [mitraType, setMitraType] = useState<'K24' | 'PRIMAKU'>('K24')
  const [form, setForm] = useState<FormData>(INITIAL_FORM)
  const [errors, setErrors] = useState<FormErrors>({})
  const [submitting, setSubmitting] = useState(false)
  const [motorOpen, setMotorOpen] = useState(true)
  const [mobilOpen, setMobilOpen] = useState(false)

  const handleRemoteAkses = async (m: Mitra) => {
    setRemoteLoadingId(m.id)
    try {
      const res = await adminAPI.impersonateMitra(m.id)
      const token = res.data?.data?.token
      if (token) {
        startImpersonation({ id: m.id, name: m.name, email: m.email, phone: m.phone }, token)
        toast.success(`Mode Remote Akses Aktif: Menjadi ${m.name}`)
        router.push('/dashboard/create-order')
      }
    } catch (err: any) {
      toast.error(err?.response?.data?.message || 'Gagal memulai remote akses')
    } finally {
      setRemoteLoadingId(null)
    }
  }

  const fetchMitra = useCallback(async () => {
    setLoading(true)
    try {
      const res = await adminAPI.getMitra()
      setMitra(res.data.data || res.data || [])
    } catch { toast.error('Gagal memuat data mitra.') }
    finally { setLoading(false) }
  }, [])

  useEffect(() => { fetchMitra() }, [fetchMitra])

  const filtered = useMemo(() =>
    mitra.filter((m) => {
      const q = search.toLowerCase()
      return m.name?.toLowerCase().includes(q) || m.username?.toLowerCase().includes(q) ||
        m.email?.toLowerCase().includes(q) || m.phone?.includes(q) || (m.mitra_type || '').toLowerCase().includes(q)
    }), [mitra, search])

  const validateStep2 = () => {
    const e: FormErrors = {}
    if (!form.name) e.name = 'Nama Mitra wajib diisi'
    if (!form.phone) e.phone = 'No. HP wajib diisi'
    if (form.email && !/\S+@\S+\.\S+/.test(form.email)) e.email = 'Format email tidak valid'
    if (!form.username) e.username = 'Username wajib diisi'
    if (!form.password) e.password = 'Password wajib diisi'
    else if (form.password.length < 6) e.password = 'Password minimal 6 karakter'
    if (!form.pic_name) e.pic_name = 'Nama PIC wajib diisi'
    if (!form.pic_nik) e.pic_nik = 'NIK PIC wajib diisi'
    if (!form.alamat_lengkap) e.alamat_lengkap = 'Alamat Lengkap wajib diisi'
    if (form.pickup_index === '' && !form.custom_pickup) e.pickup_index = 'Alamat Pickup wajib diisi / dipilih'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const hasMotor = ['motor_dimensi', 'motor_km', 'motor_titik', 'motor_berat', 'motor_zona1', 'motor_zona2', 'motor_zona3'].some((k) => form[k as keyof FormData] !== '')
    const hasMobil = ['mobil_dimensi', 'mobil_km', 'mobil_titik', 'mobil_berat', 'mobil_lumpsum'].some((k) => form[k as keyof FormData] !== '')
    const e2: FormErrors = {}
    if (!hasMotor) e2.motor = 'Minimal 1 skema tarif Motor wajib diisi (misal Skema Zona atau Skema KM)'
    if (!hasMobil) e2.mobil = 'Minimal 1 skema tarif Mobil wajib diisi'
    if (Object.keys(e2).length > 0) { setErrors(e2); return }

    setSubmitting(true)
    try {
      let pickupName = ''
      let pickupLat = -6.2019957
      let pickupLong = 106.8551888

      const pickupList = mitraType === 'PRIMAKU' ? PICKUP_LOCATIONS_PRIMAKU : PICKUP_LOCATIONS_K24
      if (form.pickup_index !== '') {
        const idx = parseInt(form.pickup_index)
        if (pickupList[idx]) {
          pickupName = pickupList[idx].name
          pickupLat = pickupList[idx].lat
          pickupLong = pickupList[idx].long
        }
      } else if (form.custom_pickup) {
        pickupName = form.custom_pickup
      }

      const payload = {
        ...form,
        mitra_type: mitraType,
        pickup_name: pickupName || `Gudang Pickup ${mitraType}`,
        pickup_lat: pickupLat,
        pickup_long: pickupLong,
        motor_dimensi: form.motor_dimensi !== '' ? parseFloat(form.motor_dimensi) : null,
        motor_km: form.motor_km !== '' ? parseFloat(form.motor_km) : null,
        motor_titik: form.motor_titik !== '' ? parseFloat(form.motor_titik) : null,
        motor_berat: form.motor_berat !== '' ? parseFloat(form.motor_berat) : null,
        motor_zona1: form.motor_zona1 !== '' ? parseFloat(form.motor_zona1) : null,
        motor_zona2: form.motor_zona2 !== '' ? parseFloat(form.motor_zona2) : null,
        motor_zona3: form.motor_zona3 !== '' ? parseFloat(form.motor_zona3) : null,
        mobil_dimensi: form.mobil_dimensi !== '' ? parseFloat(form.mobil_dimensi) : null,
        mobil_km: form.mobil_km !== '' ? parseFloat(form.mobil_km) : null,
        mobil_titik: form.mobil_titik !== '' ? parseFloat(form.mobil_titik) : null,
        mobil_berat: form.mobil_berat !== '' ? parseFloat(form.mobil_berat) : null,
        mobil_lumpsum: form.mobil_lumpsum !== '' ? parseFloat(form.mobil_lumpsum) : null,
      }
      await adminAPI.createMitra(payload)
      toast.success(`Mitra (${mitraType}) berhasil ditambahkan!`)
      setShowCreateForm(false); setStep(1); setForm(INITIAL_FORM); setErrors({}); setMotorOpen(true); setMobilOpen(false)
      fetchMitra()
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string } } }
      toast.error(axiosErr.response?.data?.message || 'Gagal menambahkan mitra')
    } finally { setSubmitting(false) }
  }

  const setField = (key: keyof FormData, val: string) => setForm((p) => ({ ...p, [key]: val }))

  // ─── CREATE FORM VIEW ───────────────────────────────────────────────────────
  if (showCreateForm) {
    return (
      <DashboardShell showCreateMitra showCreateForm={showCreateForm}>
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">
              {step === 1 && 'Tambah Apotek Mitra (Langkah 1/3: Pilih Jenis Mitra)'}
              {step === 2 && 'Data Identitas & Pickup Mitra (Langkah 2/3)'}
              {step === 3 && 'Konfigurasi Tarif Armada (Langkah 3/3)'}
            </h1>
            <p className="text-sm text-muted-foreground mt-1">
              {step === 1 && 'Pilih kategori jenis mitra apotek atau partner layanan.'}
              {step === 2 && `Lengkapi data identitas, PIC, dan alamat pickup untuk ${mitraType === 'PRIMAKU' ? 'Primaku Partner' : 'Franchise K-24'}.`}
              {step === 3 && 'Tentukan skema tarif pengiriman untuk armada Motor dan Mobil.'}
            </p>
          </div>
          <button
            onClick={() => { setShowCreateForm(false); setStep(1); setErrors({}); setMotorOpen(true); setMobilOpen(false) }}
            className="flex items-center gap-2 h-9 px-4 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors"
          >
            <X className="h-4 w-4" /> Batal
          </button>
        </div>

        {/* 3 Step Indicator */}
        <div className="flex items-center gap-3 mb-8">
          {[
            { s: 1, label: 'Jenis Mitra' },
            { s: 2, label: 'Data Mitra' },
            { s: 3, label: 'Tarif Armada' },
          ].map((item, idx) => (
            <div key={item.s} className={`flex items-center gap-2 ${idx < 2 ? 'flex-1' : ''}`}>
              <div className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold transition-colors ${
                step >= item.s ? 'bg-blue-600 text-white' : 'bg-muted text-muted-foreground'
              }`}>{item.s}</div>
              <span className={`text-xs font-medium ${step >= item.s ? 'text-foreground' : 'text-muted-foreground'}`}>
                {item.label}
              </span>
              {idx < 2 && <div className={`flex-1 h-px ${step > item.s ? 'bg-blue-600' : 'bg-border'}`} />}
            </div>
          ))}
        </div>

        <form onSubmit={handleSubmit} className="rounded-2xl border border-border bg-card p-6 shadow-sm">
          {/* STEP 1: Pilih Jenis Mitra */}
          {step === 1 && (
            <div className="space-y-6">
              <div className="space-y-1">
                <h3 className="text-base font-bold text-foreground">Pilih Kategori Partner</h3>
                <p className="text-xs text-muted-foreground">Pilih jenis kemitraan yang akan didaftarkan ke dalam sistem OTMS.</p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Card K-24 */}
                <div
                  onClick={() => { setMitraType('K24'); setField('pickup_index', ''); }}
                  className={`relative flex flex-col justify-between p-6 rounded-2xl border-2 transition-all cursor-pointer ${
                    mitraType === 'K24'
                      ? 'border-blue-600 bg-blue-50/40 dark:bg-blue-950/20 shadow-md ring-2 ring-blue-500/20'
                      : 'border-border bg-background hover:border-blue-500/40 hover:bg-muted/30'
                  }`}
                >
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-blue-100 dark:bg-blue-950/50 text-blue-700 dark:text-blue-300">
                        <Store className="h-6 w-6" />
                      </div>
                      {mitraType === 'K24' && (
                        <CheckCircle2 className="h-6 w-6 text-blue-600" />
                      )}
                    </div>
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <h4 className="font-bold text-lg text-foreground">Franchise K-24</h4>
                        <span className="rounded-full bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-300 px-2.5 py-0.5 text-xs font-bold">
                          Standard
                        </span>
                      </div>
                      <p className="text-xs text-muted-foreground leading-relaxed">
                        Outlet apotek franchise resmi K-24 dengan sistem penugasan kurir dari lokasi Gudang K-24.
                      </p>
                    </div>
                  </div>
                  <div className="mt-6 pt-4 border-t border-border/60 flex items-center justify-between text-xs font-medium text-blue-600">
                    <span>Pickup: Gudang K-24</span>
                    <ChevronRight className="h-4 w-4" />
                  </div>
                </div>

                {/* Card Primaku */}
                <div
                  onClick={() => { setMitraType('PRIMAKU'); setField('pickup_index', ''); }}
                  className={`relative flex flex-col justify-between p-6 rounded-2xl border-2 transition-all cursor-pointer ${
                    mitraType === 'PRIMAKU'
                      ? 'border-purple-600 bg-purple-50/40 dark:bg-purple-950/20 shadow-md ring-2 ring-purple-500/20'
                      : 'border-border bg-background hover:border-purple-500/40 hover:bg-muted/30'
                  }`}
                >
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-purple-100 dark:bg-purple-950/50 text-purple-700 dark:text-purple-300">
                        <Building2 className="h-6 w-6" />
                      </div>
                      {mitraType === 'PRIMAKU' && (
                        <CheckCircle2 className="h-6 w-6 text-purple-600" />
                      )}
                    </div>
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <h4 className="font-bold text-lg text-foreground">Primaku Partner</h4>
                        <span className="rounded-full bg-purple-100 text-purple-800 dark:bg-purple-950 dark:text-purple-300 px-2.5 py-0.5 text-xs font-bold">
                          Partner Khusus
                        </span>
                      </div>
                      <p className="text-xs text-muted-foreground leading-relaxed">
                        Integrasi mitra platform Primaku dengan lokasi titik pickup khusus Primaku Hub.
                      </p>
                    </div>
                  </div>
                  <div className="mt-6 pt-4 border-t border-border/60 flex items-center justify-between text-xs font-medium text-purple-600">
                    <span>Pickup: Primaku Hub</span>
                    <ChevronRight className="h-4 w-4" />
                  </div>
                </div>
              </div>

              <div className="flex justify-end pt-4">
                <button
                  type="button"
                  onClick={() => setStep(2)}
                  className="flex items-center gap-2 h-11 px-8 rounded-xl bg-gradient-to-r from-blue-600 to-slate-700 text-white font-medium hover:from-blue-700 hover:to-slate-800 transition-all shadow-sm text-sm"
                >
                  Lanjut ke Data Mitra <ChevronRight className="h-4 w-4" />
                </button>
              </div>
            </div>
          )}

          {/* STEP 2: Data Identitas & Pickup */}
          {step === 2 && (
            <div className="space-y-5 bg-card border border-border p-6 rounded-2xl shadow-sm">
              <h2 className="text-base font-semibold border-b border-border pb-3">Informasi Akun & Outlet Mitra ({mitraType})</h2>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <FormField label="Nama Apotek / Mitra" error={errors.name}>
                  <InputField placeholder="e.g. Apotek K-24 Setiabudi" value={form.name} onChange={(e) => setField('name', e.target.value)} />
                </FormField>
                <FormField label="No. Telepon / WhatsApp" error={errors.phone}>
                  <InputField placeholder="08123456789" value={form.phone} onChange={(e) => setField('phone', e.target.value)} />
                </FormField>
                <FormField label="Email Mitra" error={errors.email}>
                  <InputField type="email" placeholder="mitra@k24.co.id" value={form.email} onChange={(e) => setField('email', e.target.value)} />
                </FormField>
                <FormField label="Username Login" error={errors.username}>
                  <InputField placeholder="k24_setiabudi" value={form.username} onChange={(e) => setField('username', e.target.value)} />
                </FormField>
                <FormField label="Password" error={errors.password}>
                  <InputField type="password" placeholder="••••••••" value={form.password} onChange={(e) => setField('password', e.target.value)} />
                </FormField>
              </div>

              <h2 className="text-base font-semibold border-b border-border pb-3 pt-2">Informasi Penanggung Jawab (PIC) & Lokasi Pickup</h2>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <FormField label="Nama Lengkap PIC" error={errors.pic_name}>
                  <InputField placeholder="Nama Penanggung Jawab Outlet" value={form.pic_name} onChange={(e) => setField('pic_name', e.target.value)} />
                </FormField>
                <FormField label="NIK PIC (KTP)" error={errors.pic_nik}>
                  <InputField placeholder="3271234567890001" value={form.pic_nik} onChange={(e) => setField('pic_nik', e.target.value)} />
                </FormField>
              </div>

              <FormField label="Alamat Lengkap Outlet / Hub" error={errors.alamat_lengkap}>
                <textarea
                  rows={2}
                  placeholder="Jl. Raya Setiabudi No. 123, Jakarta Selatan"
                  value={form.alamat_lengkap}
                  onChange={(e) => setField('alamat_lengkap', e.target.value)}
                  className="w-full rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 text-foreground"
                />
              </FormField>

              <FormField label="Pilih Lokasi Titik Penjemputan (Pickup)" error={errors.pickup_index}>
                <select
                  value={form.pickup_index}
                  onChange={(e) => {
                    setField('pickup_index', e.target.value)
                    if (e.target.value !== '') setField('custom_pickup', '')
                  }}
                  className="h-10 w-full rounded-lg border border-border bg-background px-3 text-sm outline-none focus:border-blue-500 text-foreground"
                >
                  <option value="">-- Pilih Titik Pickup Terdaftar --</option>
                  {(mitraType === 'PRIMAKU' ? PICKUP_LOCATIONS_PRIMAKU : PICKUP_LOCATIONS_K24).map((loc, idx) => (
                    <option key={idx} value={idx.toString()}>
                      {loc.name}
                    </option>
                  ))}
                </select>
              </FormField>

              <FormField label="Atau Custom Nama Titik Pickup (Jika Tidak Ada di Daftar)">
                <InputField
                  placeholder="e.g. Gudang K-24 Cabang Surabaya Selatan"
                  value={form.custom_pickup}
                  onChange={(e) => {
                    setField('custom_pickup', e.target.value)
                    if (e.target.value) setField('pickup_index', '')
                  }}
                />
              </FormField>

              <div className="flex justify-between pt-4">
                <button type="button" onClick={() => setStep(1)} className="flex items-center gap-2 h-10 px-5 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors">
                  <ChevronLeft className="h-4 w-4" /> Kembali
                </button>
                <button
                  type="button"
                  onClick={() => { if (validateStep2()) setStep(3) }}
                  className="flex items-center gap-2 h-10 px-6 rounded-lg bg-blue-600 text-white font-medium text-sm hover:bg-blue-700 transition-colors shadow-md shadow-blue-500/20"
                >
                  Lanjut ke Tarif Armada <ChevronRight className="h-4 w-4" />
                </button>
              </div>
            </div>
          )}

          {/* STEP 3 */}
          {step === 3 && (
            <div className="space-y-6">
              <div className="border border-border rounded-2xl bg-card overflow-hidden">
                <button
                  type="button"
                  onClick={() => setMotorOpen(!motorOpen)}
                  className="w-full flex items-center justify-between p-4 bg-muted/30"
                >
                  <div className="flex items-center gap-3">
                    <Bike className="h-5 w-5 text-blue-600" />
                    <span className="font-semibold">Tarif Armada Motor</span>
                  </div>
                  <ChevronDown className={`h-5 w-5 transition-transform ${motorOpen ? 'rotate-180' : ''}`} />
                </button>

                <div
                  className={`transition-all duration-300 ease-in-out ${
                    motorOpen ? 'max-h-[800px] border-t border-border opacity-100 p-4' : 'max-h-0 opacity-0 pointer-events-none'
                  } overflow-hidden space-y-4`}
                >
                  <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Tarif Standar (Non-Zona)</div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    {[{key:'motor_km',label:'Per KM (Rp)'},{key:'motor_titik',label:'Per Titik (Rp)'},{key:'motor_dimensi',label:'Per Dimensi (Rp)'},{key:'motor_berat',label:'Per Berat (Rp)'}].map(({key,label}) => (
                      <FormField key={key} label={label}>
                        <InputField type="number" placeholder="0" value={form[key as keyof FormData]} onChange={(e) => setField(key as keyof FormData, e.target.value)} />
                      </FormField>
                    ))}
                  </div>

                  <div className="pt-2 border-t border-border/60">
                    <div className="flex flex-col gap-1 mb-3">
                      <div className="text-xs font-semibold text-blue-600 dark:text-blue-400 uppercase tracking-wider">
                        Tarif Skema Zona (Surabaya / Sidoarjo) - Tagihan Mitra
                      </div>
                      <p className="text-[11px] text-muted-foreground">
                        Isikan tarif yang ditagihkan ke mitra. Pendapatan bersih driver otomatis diset: <strong>Zona 1 = Rp 10.500</strong> | <strong>Zona 2 = Rp 17.500</strong> | <strong>Zona 3 = Rp 24.500</strong> | <strong>Zona 4 = Rp 26.000 (Flat)</strong> | <strong>Zona 5 = Rp 30.000 (Flat)</strong> | <strong>Non-Zona = Rp 1.750/KM</strong>.
                      </p>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                      {[{key:'motor_zona1',label:'Tagihan Zona 1 (Rp)'},{key:'motor_zona2',label:'Tagihan Zona 2 (Rp)'},{key:'motor_zona3',label:'Tagihan Zona 3 (Rp)'}].map(({key,label}) => (
                        <FormField key={key} label={label}>
                          <InputField type="number" placeholder="0" value={form[key as keyof FormData]} onChange={(e) => setField(key as keyof FormData, e.target.value)} />
                        </FormField>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Separator "atau" */}
              <div className="relative flex items-center justify-center my-2">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-dashed border-border" />
                </div>
                <div className="relative flex h-8 w-12 items-center justify-center rounded-full border border-border bg-background text-[10px] font-bold uppercase tracking-wider text-muted-foreground shadow-sm">
                  atau
                </div>
              </div>

              {/* Mobil tariffs */}
              <div className="border border-border rounded-2xl bg-card overflow-hidden">
                <button
                  type="button"
                  onClick={() => setMobilOpen(!mobilOpen)}
                  className="w-full flex items-center justify-between p-4 bg-muted/30"
                >
                  <div className="flex items-center gap-3">
                    <Car className="h-5 w-5 text-emerald-600" />
                    <span className="font-semibold">Tarif Armada Mobil</span>
                  </div>
                  <ChevronDown className={`h-5 w-5 transition-transform ${mobilOpen ? 'rotate-180' : ''}`} />
                </button>

                <div
                  className={`transition-all duration-300 ease-in-out ${
                    mobilOpen ? 'max-h-[500px] border-t border-border opacity-100 p-4' : 'max-h-0 opacity-0 pointer-events-none'
                  } overflow-hidden`}
                >
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    {[{key:'mobil_km',label:'Per KM (Rp)'},{key:'mobil_titik',label:'Per Titik (Rp)'},{key:'mobil_dimensi',label:'Per Dimensi (Rp)'},{key:'mobil_berat',label:'Per Berat (Rp)'},{key:'mobil_lumpsum',label:'Lumpsum (Rp)'}].map(({key,label}) => (
                      <FormField key={key} label={label}>
                        <InputField type="number" placeholder="0" value={form[key as keyof FormData]} onChange={(e) => setField(key as keyof FormData, e.target.value)} />
                      </FormField>
                    ))}
                  </div>
                </div>
              </div>

              <div className="flex justify-between pt-2">
                <button type="button" onClick={() => setStep(2)} className="flex items-center gap-2 h-10 px-5 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors">
                  <ChevronLeft className="h-4 w-4" /> Kembali
                </button>
                <button type="submit" disabled={submitting} className="flex items-center gap-2 h-10 px-6 rounded-lg bg-blue-600 text-white font-medium text-sm hover:bg-blue-700 disabled:opacity-70">
                  {submitting ? 'Menyimpan...' : 'Simpan Mitra'}
                </button>
              </div>
            </div>
          )}
        </form>
      </DashboardShell>
    )
  }

  // ─── LIST VIEW ──────────────────────────────────────────────────────────────
  return (
    <DashboardShell onRefresh={fetchMitra} showCreateMitra onCreateMitra={() => setShowCreateForm(true)}>
      <div className="mb-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Mitra</h1>
          <p className="text-sm text-muted-foreground mt-1">Daftar dan kelola lokasi outlet apotek mitra franchise K-24.</p>
        </div>
        <button
          onClick={() => setShowCreateForm(true)}
          className="sm:hidden flex items-center gap-2 h-10 px-4 rounded-lg bg-gradient-to-r from-blue-600 to-slate-700 text-white text-sm font-medium"
        >
          <Plus className="h-4 w-4" /> Tambah Mitra
        </button>
      </div>

      <div className="relative mb-5">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <input
          type="text"
          placeholder="Cari mitra berdasarkan nama, username, email..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="h-10 w-full max-w-md rounded-lg border border-border bg-background pl-9 pr-4 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
        />
      </div>

      {loading ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
          <p className="text-sm text-muted-foreground">Memuat data mitra...</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-border bg-card py-16 gap-3">
          <AlertCircle className="h-10 w-10 text-muted-foreground/40" />
          <h3 className="font-semibold">Tidak Ada Data Mitra</h3>
          <p className="text-sm text-muted-foreground">Belum ada mitra terdaftar yang sesuai pencarian.</p>
        </div>
      ) : (
        <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-muted/40">
                  {['Apotek Mitra', 'Tipe Partner', 'Username', 'Email', 'No. HP', 'Terdaftar', 'Aksi'].map((h) => (
                    <th key={h} className={`px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground ${h === 'Aksi' ? 'text-right' : 'text-left'}`}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {filtered.map((m) => (
                  <tr key={m.id} className="hover:bg-muted/20 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-gradient-to-br from-blue-100 to-slate-100 text-blue-700 font-bold text-sm dark:from-blue-900/30 dark:to-slate-900/30 dark:text-blue-300">
                          {m.name?.[0]?.toUpperCase() || 'M'}
                        </div>
                        <span className="font-medium">{m.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-bold ${
                        m.mitra_type === 'PRIMAKU'
                          ? 'bg-purple-100 text-purple-700 dark:bg-purple-950/30 dark:text-purple-300'
                          : 'bg-blue-100 text-blue-700 dark:bg-blue-950/30 dark:text-blue-300'
                      }`}>
                        {m.mitra_type === 'PRIMAKU' ? 'Primaku' : 'K-24'}
                      </span>
                    </td>
                    <td className="px-4 py-3"><code className="rounded bg-muted px-1.5 py-0.5 text-xs font-mono">@{m.username}</code></td>
                    <td className="px-4 py-3 text-muted-foreground">{m.email || '-'}</td>
                    <td className="px-4 py-3 text-muted-foreground">{m.phone}</td>
                    <td className="px-4 py-3 text-xs text-muted-foreground">
                      {new Date(m.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        type="button"
                        disabled={remoteLoadingId === m.id}
                        onClick={() => handleRemoteAkses(m)}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-blue-50 text-blue-600 hover:bg-blue-100 dark:bg-blue-950/40 dark:text-blue-400 dark:hover:bg-blue-900/60 border border-blue-200 dark:border-blue-800/60 transition-colors shadow-xs disabled:opacity-50"
                        title="Remote Akses ke Akun Mitra"
                      >
                        {remoteLoadingId === m.id ? (
                          <Loader2 className="h-3.5 w-3.5 animate-spin" />
                        ) : (
                          <ExternalLink className="h-3.5 w-3.5" />
                        )}
                        <span>Remote Akses</span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="border-t border-border px-4 py-3">
            <p className="text-xs text-muted-foreground">Menampilkan {filtered.length} dari {mitra.length} mitra</p>
          </div>
        </div>
      )}
    </DashboardShell>
  )
}
