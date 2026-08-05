'use client'

import { useState, useEffect, useCallback, useMemo, Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import { Search, AlertCircle, Check, X, FileText, Eye } from 'lucide-react'

interface Driver {
  id: number
  name: string
  username: string
  email: string
  phone: string
  plate_number: string
  is_active: boolean
  rating?: number
  vehicle_type?: string
  is_approved: boolean
  ktp_url?: string
  sim_url?: string
  stnk_url?: string
  created_at: string
}

function DriversPageContent() {
  const searchParams = useSearchParams()
  const tabParam = searchParams.get('tab')

  const [drivers, setDrivers] = useState<Driver[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [activeTab, setActiveTab] = useState<'approved' | 'unapproved'>('approved')

  useEffect(() => {
    if (tabParam === 'unapproved') {
      setActiveTab('unapproved')
    } else if (tabParam === 'approved') {
      setActiveTab('approved')
    }
  }, [tabParam])
  const [documentModal, setDocumentModal] = useState<{
    isOpen: boolean
    title: string
    src: string
    driverId?: number
    driverName?: string
  }>({ isOpen: false, title: '', src: '' })

  const [confirmModal, setConfirmModal] = useState<{
    isOpen: boolean
    driverId: number | null
    driverName: string
    action: 'approve' | 'reject' | null
  }>({
    isOpen: false,
    driverId: null,
    driverName: '',
    action: null,
  })
  const [confirmLoading, setConfirmLoading] = useState(false)

  const fetchDrivers = useCallback(async () => {
    setLoading(true)
    try {
      const res = await adminAPI.getDrivers()
      const rawList = res.data?.data ?? res.data ?? []
      const list = Array.isArray(rawList) ? rawList : []
      setDrivers(list)
    } catch (err: any) {
      console.error('[fetchDrivers Error]:', err)
      toast.error(err.response?.data?.message || err.message || 'Gagal memuat data driver.')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { fetchDrivers() }, [fetchDrivers])

  const triggerApprove = (id: number, name: string) => {
    setConfirmModal({
      isOpen: true,
      driverId: id,
      driverName: name,
      action: 'approve'
    })
  }

  const triggerReject = (id: number, name: string) => {
    setConfirmModal({
      isOpen: true,
      driverId: id,
      driverName: name,
      action: 'reject'
    })
  }

  const processConfirmAction = async () => {
    if (!confirmModal.driverId || !confirmModal.action) return
    setConfirmLoading(true)
    try {
      if (confirmModal.action === 'approve') {
        await adminAPI.approveDriver(confirmModal.driverId)
        toast.success('Pendaftaran driver berhasil disetujui!')
      } else {
        await adminAPI.rejectDriver(confirmModal.driverId)
        toast.success('Pendaftaran driver berhasil ditolak.')
      }
      setConfirmModal({ isOpen: false, driverId: null, driverName: '', action: null })
      fetchDrivers()
    } catch (err: any) {
      toast.error(err.response?.data?.message || 'Gagal mengeksekusi aksi.')
    } finally {
      setConfirmLoading(false)
    }
  }

  const filtered = useMemo(() => {
    if (!Array.isArray(drivers)) return []
    return drivers.filter((d) => {
      const q = (search || '').toLowerCase()
      const matchesSearch =
        (d.name || '').toLowerCase().includes(q) ||
        (d.username || '').toLowerCase().includes(q) ||
        (d.email || '').toLowerCase().includes(q) ||
        (d.plate_number || '').toLowerCase().includes(q)
      
      const matchesApproval = activeTab === 'approved' ? Boolean(d.is_approved) : !d.is_approved
      return matchesSearch && matchesApproval
    })
  }, [drivers, search, activeTab])

  const renderDocumentViewer = () => {
    if (!documentModal.isOpen) return null
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
        <div className="bg-card w-full max-w-xl rounded-2xl border border-border overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
          <div className="flex justify-between items-center px-6 py-4 border-b border-border">
            <h3 className="font-bold text-foreground">{documentModal.title}</h3>
            <button
              onClick={() => setDocumentModal({ isOpen: false, title: '', src: '' })}
              className="h-8 w-8 rounded-lg flex items-center justify-center border border-border hover:bg-accent text-muted-foreground transition-colors"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
          <div className="p-6 flex items-center justify-center bg-muted/20 min-h-[300px]">
            {documentModal.src && documentModal.src.length > 10 ? (
              <img
                src={documentModal.src}
                alt={documentModal.title}
                className="max-h-[400px] max-w-full rounded-lg border border-border object-contain shadow-sm"
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none'
                  const fallback = (e.target as HTMLElement).nextElementSibling as HTMLElement
                  if (fallback) fallback.style.display = 'flex'
                }}
              />
            ) : null}
            <div className="hidden flex-col items-center gap-2 text-muted-foreground">
              <FileText className="h-12 w-12 text-muted-foreground/55" />
              <p className="text-xs font-medium">Dokumen tidak dapat dimuat atau berformat teks</p>
            </div>
            {(!documentModal.src || documentModal.src.length < 10) && (
              <div className="flex flex-col items-center gap-2 text-muted-foreground">
                <FileText className="h-12 w-12 text-muted-foreground/55" />
                <p className="text-xs font-medium">Dokumen tidak diunggah / kosong</p>
              </div>
            )}
          </div>
          {documentModal.driverId && activeTab === 'unapproved' && (
            <div className="flex justify-end gap-3 px-6 py-4 bg-muted/40 border-t border-border">
              <button
                onClick={() => {
                  const dId = documentModal.driverId!
                  const dName = documentModal.driverName!
                  setDocumentModal({ isOpen: false, title: '', src: '' })
                  triggerReject(dId, dName)
                }}
                className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-semibold rounded-lg bg-red-100 hover:bg-red-200 text-red-700 dark:bg-red-950/40 dark:hover:bg-red-900/40 dark:text-red-400 transition-colors"
              >
                <X className="h-4 w-4" /> Tolak Pendaftaran
              </button>
              <button
                onClick={() => {
                  const dId = documentModal.driverId!
                  const dName = documentModal.driverName!
                  setDocumentModal({ isOpen: false, title: '', src: '' })
                  triggerApprove(dId, dName)
                }}
                className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-semibold rounded-lg bg-emerald-100 hover:bg-emerald-200 text-emerald-700 dark:bg-emerald-950/40 dark:hover:bg-emerald-900/40 dark:text-emerald-400 transition-colors"
              >
                <Check className="h-4 w-4" /> Setujui Pendaftaran
              </button>
            </div>
          )}
        </div>
      </div>
    )
  }

  const renderConfirmDialog = () => {
    if (!confirmModal.isOpen) return null
    const isApprove = confirmModal.action === 'approve'

    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
        <div className="bg-card w-full max-w-md rounded-2xl border border-border overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
          <div className="p-6 flex flex-col items-center text-center">
            <div className={`h-12 w-12 rounded-full flex items-center justify-center mb-4 ${
              isApprove 
                ? 'bg-emerald-100 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400' 
                : 'bg-red-100 text-red-600 dark:bg-red-950/40 dark:text-red-400'
            }`}>
              {isApprove ? <Check className="h-6 w-6" /> : <X className="h-6 w-6" />}
            </div>
            
            <h3 className="text-lg font-bold text-foreground mb-2">
              {isApprove ? 'Setujui Pendaftaran' : 'Tolak Pendaftaran'}
            </h3>
            
            <p className="text-sm text-muted-foreground leading-relaxed">
              {isApprove 
                ? `Apakah Anda yakin ingin menyetujui pendaftaran driver "${confirmModal.driverName}"? Akun driver akan aktif dan kurir dapat langsung login ke aplikasi.`
                : `Apakah Anda yakin ingin menolak dan menghapus pendaftaran driver "${confirmModal.driverName}"? Data pendaftaran dan berkas berkas yang diunggah akan dihapus secara permanen.`
              }
            </p>
          </div>
          
          <div className="flex justify-end gap-3 px-6 py-4 bg-muted/20 border-t border-border">
            <button
              onClick={() => setConfirmModal({ isOpen: false, driverId: null, driverName: '', action: null })}
              disabled={confirmLoading}
              className="px-4 py-2 text-xs font-semibold rounded-lg border border-border bg-background hover:bg-accent text-foreground transition-colors disabled:opacity-50"
            >
              Batal
            </button>
            <button
              onClick={processConfirmAction}
              disabled={confirmLoading}
              className={`inline-flex items-center justify-center px-4 py-2 text-xs font-semibold rounded-lg text-white transition-colors disabled:opacity-50 min-w-[80px] ${
                isApprove ? 'bg-emerald-600 hover:bg-emerald-700' : 'bg-red-600 hover:bg-red-700'
              }`}
            >
              {confirmLoading ? (
                <div className="h-4 w-4 rounded-full border-2 border-white border-t-transparent animate-spin" />
              ) : (
                isApprove ? 'Setujui' : 'Tolak'
              )}
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <DashboardShell onRefresh={fetchDrivers}>
      <div className="mb-6 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Manajemen Driver</h1>
          <p className="text-sm text-muted-foreground mt-1">Pantau armada pengiriman obat dan persetujuan registrasi kurir.</p>
        </div>
        
        {/* Tab Switching */}
        <div className="flex rounded-xl bg-muted/80 p-1 border border-border shrink-0 self-start">
          <button
            onClick={() => setActiveTab('approved')}
            className={`px-4 py-2 rounded-lg text-xs font-semibold tracking-wide transition-all ${
              activeTab === 'approved'
                ? 'bg-background text-foreground shadow-sm'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            Driver Aktif ({drivers.filter(d => d.is_approved).length})
          </button>
          <button
            onClick={() => setActiveTab('unapproved')}
            className={`px-4 py-2 rounded-lg text-xs font-semibold tracking-wide transition-all ${
              activeTab === 'unapproved'
                ? 'bg-background text-foreground shadow-sm'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            Persetujuan Pendaftaran ({drivers.filter(d => !d.is_approved).length})
          </button>
        </div>
      </div>

      {/* Search Bar */}
      <div className="flex flex-col sm:flex-row gap-3 mb-5">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cari driver berdasarkan nama, plat, email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="h-10 w-full rounded-lg border border-border bg-background pl-9 pr-4 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
          />
        </div>
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
          <p className="text-sm text-muted-foreground">Memuat data kurir driver...</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-border bg-card py-16 gap-3">
          <AlertCircle className="h-10 w-10 text-muted-foreground/40" />
          <h3 className="font-semibold text-foreground">Tidak Ada Data Driver</h3>
          <p className="text-sm text-muted-foreground">Tidak ditemukan data kurir yang sesuai kriteria pencarian.</p>
        </div>
      ) : (
        <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-muted/40">
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Driver</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Username</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Nomor Plat / Armada</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">No. Telepon</th>
                  {activeTab === 'approved' ? (
                    <>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Rating</th>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Status</th>
                    </>
                  ) : (
                    <>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Dokumen KTP/SIM/STNK</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-muted-foreground">Aksi</th>
                    </>
                  )}
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">Terdaftar</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {filtered.map((d) => (
                  <tr key={d.id} className="hover:bg-muted/20 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-gradient-to-br from-blue-100 to-slate-100 text-blue-700 dark:from-blue-900/30 dark:to-slate-900/30 dark:text-blue-300">
                          {d.name?.[0]?.toUpperCase() || 'D'}
                        </div>
                        <div>
                          <p className="font-medium text-foreground">{d.name}</p>
                          <p className="text-xs text-muted-foreground">{d.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <code className="rounded bg-muted px-1.5 py-0.5 text-xs font-mono text-foreground">@{d.username}</code>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex flex-col gap-1">
                        <span className="rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium text-foreground w-max">{d.plate_number || 'Tidak Ada'}</span>
                        <span className="text-[10px] text-muted-foreground uppercase font-bold tracking-wider">{d.vehicle_type === 'mobil' ? '🚗 Mobil' : '🏍️ Motor'}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">{d.phone}</td>
                    
                    {activeTab === 'approved' ? (
                      <>
                        <td className="px-4 py-3">
                          <span className="text-amber-500">⭐</span> {d.rating ? d.rating.toFixed(1) : '5.0'}
                        </td>
                        <td className="px-4 py-3">
                          {d.is_active ? (
                            <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-semibold text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400">
                              <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                              Online
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 rounded-full bg-muted px-2.5 py-0.5 text-xs font-semibold text-muted-foreground">
                              <span className="h-1.5 w-1.5 rounded-full bg-muted-foreground" />
                              Offline
                            </span>
                          )}
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="px-4 py-3">
                          <div className="flex gap-2">
                            <button
                              onClick={() => setDocumentModal({ isOpen: true, title: `KTP - ${d.name}`, src: d.ktp_url || '', driverId: d.id, driverName: d.name })}
                              className="inline-flex items-center gap-1 text-[11px] font-semibold border border-border bg-background hover:bg-accent px-2 py-1 rounded-md text-foreground transition-colors"
                              title="Lihat KTP"
                            >
                              <Eye className="h-3 w-3 text-blue-500" /> KTP
                            </button>
                            <button
                              onClick={() => setDocumentModal({ isOpen: true, title: `SIM - ${d.name}`, src: d.sim_url || '', driverId: d.id, driverName: d.name })}
                              className="inline-flex items-center gap-1 text-[11px] font-semibold border border-border bg-background hover:bg-accent px-2 py-1 rounded-md text-foreground transition-colors"
                              title="Lihat SIM"
                            >
                              <Eye className="h-3 w-3 text-blue-500" /> SIM
                            </button>
                            <button
                              onClick={() => setDocumentModal({ isOpen: true, title: `STNK - ${d.name}`, src: d.stnk_url || '', driverId: d.id, driverName: d.name })}
                              className="inline-flex items-center gap-1 text-[11px] font-semibold border border-border bg-background hover:bg-accent px-2 py-1 rounded-md text-foreground transition-colors"
                              title="Lihat STNK"
                            >
                              <Eye className="h-3 w-3 text-blue-500" /> STNK
                            </button>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex gap-2 justify-end">
                            <button
                              onClick={() => triggerApprove(d.id, d.name)}
                              className="flex items-center justify-center h-8 w-8 rounded-lg bg-emerald-100 hover:bg-emerald-200 text-emerald-700 dark:bg-emerald-950/40 dark:hover:bg-emerald-900/40 dark:text-emerald-400 transition-colors"
                              title="Setujui Pendaftaran"
                            >
                              <Check className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => triggerReject(d.id, d.name)}
                              className="flex items-center justify-center h-8 w-8 rounded-lg bg-red-100 hover:bg-red-200 text-red-700 dark:bg-red-950/40 dark:hover:bg-red-900/40 dark:text-red-400 transition-colors"
                              title="Tolak Pendaftaran"
                            >
                              <X className="h-4 w-4" />
                            </button>
                          </div>
                        </td>
                      </>
                    )}
                    
                    <td className="px-4 py-3 text-muted-foreground text-xs">
                      {new Date(d.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="border-t border-border px-4 py-3">
            <p className="text-xs text-muted-foreground">Menampilkan {filtered.length} dari {drivers.length} driver</p>
          </div>
        </div>
      )}

      {renderDocumentViewer()}
      {renderConfirmDialog()}
    </DashboardShell>
  )
}

export default function DriversPage() {
  return (
    <Suspense fallback={
      <div className="flex flex-col items-center justify-center min-h-[300px]">
        <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin mb-4" />
        <p className="text-sm text-muted-foreground">Memuat halaman driver...</p>
      </div>
    }>
      <DriversPageContent />
    </Suspense>
  )
}
