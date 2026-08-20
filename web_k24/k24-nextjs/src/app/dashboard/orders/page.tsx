'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { useAuth } from '@/context/AuthContext'
import { toast } from 'sonner'
import { Search, ArrowLeft, FileText, Truck, CheckCircle, AlertCircle, Activity, MapPin, User, UserX, Compass, CreditCard, Phone, Download, Printer, Map, Calendar, Clock, MoreVertical, ChevronLeft, ChevronRight, Navigation, Pencil, Trash2, Loader2 } from 'lucide-react'

// Matches backend OrderSummary struct from admin_orders.go GetOrders
interface OrderSummary {
  dispatch_id: string
  mitra_id: number
  mitra_name: string
  created_at: string
  stop_count: number
  total_fee: number
  status: string
  is_dispatched: boolean
  driver_name: string
  driver_phone?: string
  addresses?: string
}

// Matches backend OrderDetailResponse from admin_orders.go GetOrderDetail
interface StopItem {
  id: number
  order_number: string
  status: string
  nama_apotek: string
  alamat: string
  invoices: string[]
  fee: number
  driver_id: number
  driver_name: string
  driver_phone?: string
  driver_plate?: string
  driver_vehicle?: string
  rate_type: string
  armada: string
  distance_km: number
  pickup_photo_url?: string
  pickup_note?: string
  arrived_photo_url?: string
  arrived_note?: string
  handover_photo_url?: string
  reject_photo_url?: string
  reject_note?: string
  reject_reason?: string
  reject_approved?: boolean
  unboxing_option?: string
  checked_invoices?: string
  extra_items_note?: string
  extra_items_photo_url?: string
  facture_photo_url?: string
  signature_photo_url?: string
  pod_signature_photo_url?: string
}

interface OrderDetail {
  dispatch_id: string
  rate_type: string
  armada: string
  created_at?: string
  stops: StopItem[]
  driver_groups?: { driver_id: number; driver_name: string; stops: StopItem[]; total_fee: number }[]
  grand_total: number
}

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  PENDING: { label: 'Pending Dispatch', color: 'bg-slate-100 text-slate-700 dark:bg-slate-900/30 dark:text-slate-400' },
  WAITING_FOR_PICKUP: { label: 'Waiting for Pickup', color: 'bg-amber-50 text-amber-700 dark:bg-amber-950/20 dark:text-amber-400' },
  READY_FOR_PICKUP_FACTURE: { label: 'Physical Facture Pending', color: 'bg-blue-50/50 text-blue-700 dark:bg-blue-950/20 dark:text-blue-400' },
  DELIVERING: { label: 'Delivering', color: 'bg-blue-50 text-blue-700 dark:bg-blue-950/20 dark:text-blue-400' },
  ON_DELIVERY: { label: 'Delivering', color: 'bg-blue-50 text-blue-700 dark:bg-blue-950/20 dark:text-blue-400' },
  COMPLETED_WAITING_APPROVAL: { label: 'Menunggu Approval Faktur', color: 'bg-purple-100 text-purple-700 dark:bg-purple-950/40 dark:text-purple-400 animate-pulse' },
  REJECTED_WAITING_APPROVAL: { label: 'Menunggu Approval Reject', color: 'bg-rose-100 text-rose-700 dark:bg-rose-950/40 dark:text-rose-400 animate-pulse' },
  COMPLETED:  { label: 'Completed',  color: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400' },
  CANCELLED:  { label: 'Cancelled',  color: 'bg-red-50 text-red-700 dark:bg-red-950/20 dark:text-red-400' },
}

const formatRp = (n: number) => `Rp ${n.toLocaleString('id-ID')}`

export default function OrdersPage() {
  const router = useRouter()
  const { user } = useAuth()
  const [orders, setOrders] = useState<OrderSummary[]>([])
  const [loading, setLoading] = useState(true)
  const [searchId, setSearchId] = useState('')
  const [filterStatus, setFilterStatus] = useState('ALL')
  const [searchDriver, setSearchDriver] = useState('')
  const [searchMitra, setSearchMitra] = useState('')
  const [selectedDispatchId, setSelectedDispatchId] = useState<string | null>(null)
  const [orderDetail, setOrderDetail] = useState<OrderDetail | null>(null)
  const [loadingDetail, setLoadingDetail] = useState(false)
  const [approvingId, setApprovingId] = useState<number | null>(null)
  const [activeStopIndex, setActiveStopIndex] = useState(0)
  const [lightboxImage, setLightboxImage] = useState<{
    url: string
    title: string
    timestamp?: string
  } | null>(null)

  const formatFullPhotoUrl = (url?: string) => {
    if (!url) return ''
    if (url.startsWith('http://') || url.startsWith('https://')) return url
    const hostname = typeof window !== 'undefined' ? window.location.hostname : '103.236.140.19'
    return `http://${hostname}:9001${url.startsWith('/') ? '' : '/'}${url}`
  }

  // Action Dropdown & Delete Modal States
  const [openDropdownId, setOpenDropdownId] = useState<string | null>(null)
  const [dropdownPos, setDropdownPos] = useState<{ top: number; left: number } | null>(null)
  const [deletingOrder, setDeletingOrder] = useState<{ id: string; count: number } | null>(null)
  const [isDeleting, setIsDeleting] = useState(false)
  const [cancelingDriverOrder, setCancelingDriverOrder] = useState<{ id: string } | null>(null)
  const [isCancelingDriver, setIsCancelingDriver] = useState(false)

  const toggleDropdown = (e: React.MouseEvent<HTMLButtonElement>, dispatchId: string) => {
    e.stopPropagation()
    if (openDropdownId === dispatchId) {
      setOpenDropdownId(null)
      setDropdownPos(null)
    } else {
      const rect = e.currentTarget.getBoundingClientRect()
      let top = rect.bottom + 4
      if (rect.bottom + 100 > window.innerHeight) {
        top = rect.top - 88
      }
      setDropdownPos({
        top,
        left: Math.max(10, rect.right - 176),
      })
      setOpenDropdownId(dispatchId)
    }
  }

  const handleEditOrder = (dispatchId: string) => {
    setOpenDropdownId(null)
    setDropdownPos(null)
    router.push(`/dashboard/create-order?edit_id=${encodeURIComponent(dispatchId)}`)
  }

  const handleDeleteClick = (dispatchId: string, count: number) => {
    setOpenDropdownId(null)
    setDropdownPos(null)
    setDeletingOrder({ id: dispatchId, count })
  }

  const handleCancelDriverClick = (dispatchId: string) => {
    setOpenDropdownId(null)
    setDropdownPos(null)
    setCancelingDriverOrder({ id: dispatchId })
  }

  const handleConfirmCancelDriver = async () => {
    if (!cancelingDriverOrder) return
    setIsCancelingDriver(true)
    try {
      await adminAPI.cancelDriverAssignment(cancelingDriverOrder.id)
      toast.success(`Penugasan driver untuk order ${cancelingDriverOrder.id} berhasil dibatalkan!`)
      setCancelingDriverOrder(null)
      if (selectedDispatchId) {
        fetchDetail(cancelingDriverOrder.id)
      }
      fetchOrders()
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string } } }
      toast.error(axiosErr.response?.data?.message || 'Gagal membatalkan penugasan driver')
    } finally {
      setIsCancelingDriver(false)
    }
  }

  const handleConfirmDelete = async () => {
    if (!deletingOrder) return
    setIsDeleting(true)
    try {
      await adminAPI.deleteOrder(deletingOrder.id)
      toast.success(`Order ${deletingOrder.id} berhasil dihapus!`)
      setDeletingOrder(null)
      fetchOrders()
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string } } }
      toast.error(axiosErr.response?.data?.message || 'Gagal menghapus order')
    } finally {
      setIsDeleting(false)
    }
  }

  const handleApproveReject = async (orderId: number, approve: boolean) => {
    setApprovingId(orderId)
    try {
      await adminAPI.approveRejectOrder(orderId, approve)
      toast.success(approve ? 'Order reject disetujui (dibatalkan)' : 'Order reject ditolak')
      if (selectedDispatchId) {
        fetchDetail(selectedDispatchId)
      } else {
        fetchOrders()
      }
    } catch (err: any) {
      toast.error('Gagal memproses persetujuan reject.')
    } finally {
      setApprovingId(null)
    }
  }

  const handleApproveFacture = async (orderId: number, approve: boolean) => {
    setApprovingId(orderId)
    try {
      await adminAPI.approveFacture(orderId, approve)
      toast.success(approve ? 'Faktur disetujui, order selesai' : 'Faktur ditolak, driver harus upload ulang')
      if (selectedDispatchId) {
        fetchDetail(selectedDispatchId)
      } else {
        fetchOrders()
      }
    } catch (err: any) {
      toast.error('Gagal memproses persetujuan faktur.')
    } finally {
      setApprovingId(null)
    }
  }

  const PhotoGalleryViewer = ({ photoField, title, timestamp }: { photoField?: string; title: string; timestamp?: string }) => {
    const [activeIndex, setActiveIndex] = useState(0)

    if (!photoField) return null

    let photos: string[] = []
    try {
      if (photoField.startsWith('[')) {
        photos = JSON.parse(photoField)
      }
    } catch {}
    if (!photos.length) {
      if (photoField.includes('|||')) {
        photos = photoField.split('|||').map((s) => s.trim()).filter(Boolean)
      } else {
        photos = [photoField]
      }
    }

    if (!photos.length) return null

    const activePhoto = photos[activeIndex] || photos[0]
    const formattedActivePhoto = formatFullPhotoUrl(activePhoto)

    return (
      <div className="mt-2 p-3 bg-card border border-border rounded-xl space-y-2">
        <div className="flex items-center justify-between">
          <p className="text-xs font-bold text-foreground flex items-center gap-1.5">
            <span>📷 {title}</span>
            <span className="text-[10px] font-semibold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/40 px-2 py-0.5 rounded-full">
              {photos.length} Foto
            </span>
          </p>
          {photos.length > 1 && (
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => setActiveIndex((prev) => (prev > 0 ? prev - 1 : photos.length - 1))}
                className="h-6 w-6 rounded bg-muted flex items-center justify-center text-xs font-bold hover:bg-accent text-foreground transition-colors"
                title="Foto Sebelumnya"
              >
                ‹
              </button>
              <span className="text-[11px] font-medium text-muted-foreground px-1">
                {activeIndex + 1} / {photos.length}
              </span>
              <button
                type="button"
                onClick={() => setActiveIndex((prev) => (prev < photos.length - 1 ? prev + 1 : 0))}
                className="h-6 w-6 rounded bg-muted flex items-center justify-center text-xs font-bold hover:bg-accent text-foreground transition-colors"
                title="Foto Selanjutnya"
              >
                ›
              </button>
            </div>
          )}
        </div>

        <div className="relative group overflow-hidden rounded-lg border border-border bg-black/5">
          <img
            src={formattedActivePhoto}
            alt={`${title} ${activeIndex + 1}`}
            className="h-44 w-full object-contain rounded-lg bg-slate-900/10 cursor-pointer hover:opacity-95 transition-all"
            onClick={() => setLightboxImage({ url: activePhoto, title: `${title} (${activeIndex + 1}/${photos.length})`, timestamp })}
          />

          {/* Dynamic Watermark Badge on Thumbnail */}
          <div className="absolute bottom-2 left-2 bg-black/80 backdrop-blur-sm text-white px-2 py-0.5 rounded text-[9px] font-mono border border-white/20 pointer-events-none z-10 flex items-center gap-1 shadow">
            <span className="text-amber-400 font-bold">🕒 {timestamp || 'VERIFIED TIMESTAMP'}</span>
          </div>

          <div className="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10">
            <span className="bg-black/70 text-white text-[10px] px-2 py-1 rounded-md">Klik untuk perbesar 🔍</span>
          </div>
        </div>

        {photos.length > 1 && (
          <div className="flex items-center gap-2 overflow-x-auto pt-1">
            {photos.map((p, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => setActiveIndex(idx)}
                className={`h-12 w-16 rounded-md overflow-hidden border-2 shrink-0 transition-all ${
                  activeIndex === idx
                    ? 'border-blue-500 ring-2 ring-blue-500/20 scale-105'
                    : 'border-border opacity-60 hover:opacity-100'
                }`}
              >
                <img src={formatFullPhotoUrl(p)} alt={`Thumb ${idx + 1}`} className="h-full w-full object-cover" />
              </button>
            ))}
          </div>
        )}
      </div>
    )
  }

  const renderCheckedInvoicesList = (checkedInvoicesStr?: string) => {
    if (!checkedInvoicesStr) return null

    const items = checkedInvoicesStr.split(';').map(i => i.trim()).filter(Boolean)
    if (items.length === 0) return null

    return (
      <div className="space-y-2 mt-2">
        <div className="text-xs font-bold text-foreground flex items-center gap-1.5">
          <span>📋 Hasil Verifikasi Invoice (Unboxing Apoteker):</span>
        </div>
        <div className="grid grid-cols-1 gap-2">
          {items.map((item, idx) => {
            const isDone = item.toUpperCase().includes(': DONE')
            let invoiceNo = item
            let note = ''

            if (item.includes('(Hilang:')) {
              const parts = item.split('(Hilang:')
              invoiceNo = parts[0].replace(/: MISSING/i, '').trim()
              note = parts[1].replace(/\)$/, '').trim()
            } else if (item.includes(':')) {
              const parts = item.split(':')
              invoiceNo = parts[0].trim()
              if (!isDone) note = parts.slice(1).join(':').trim()
            }

            if (isDone) {
              return (
                <div 
                  key={idx} 
                  className="p-2.5 rounded-xl border border-emerald-200 dark:border-emerald-900/50 bg-emerald-50/60 dark:bg-emerald-950/20 text-emerald-800 dark:text-emerald-300 text-xs flex items-center justify-between font-medium shadow-xs"
                >
                  <div className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
                    <span className="font-bold font-mono">{invoiceNo}</span>
                  </div>
                  <span className="px-2.5 py-0.5 rounded-md bg-emerald-600 text-white font-extrabold text-[10px] uppercase tracking-wide">
                    Aman (Done)
                  </span>
                </div>
              )
            }

            return (
              <div 
                key={idx} 
                className="p-3 rounded-xl border border-rose-200 dark:border-rose-900/50 bg-rose-50/70 dark:bg-rose-950/30 text-rose-900 dark:text-rose-200 text-xs space-y-1.5 shadow-xs"
              >
                <div className="flex items-center justify-between font-medium">
                  <div className="flex items-center gap-2">
                    <AlertCircle className="h-4 w-4 text-rose-600 dark:text-rose-400 shrink-0" />
                    <span className="font-bold font-mono">{invoiceNo}</span>
                  </div>
                  <span className="px-2.5 py-0.5 rounded-md bg-rose-600 text-white font-extrabold text-[10px] uppercase tracking-wide">
                    Bermasalah / Red
                  </span>
                </div>
                {note && (
                  <div className="pl-6 text-xs text-rose-800 dark:text-rose-200 bg-white/70 dark:bg-rose-900/40 p-2.5 rounded-lg border border-rose-200 dark:border-rose-800 leading-relaxed">
                    <strong className="text-rose-900 dark:text-rose-100">Alasan / Catatan:</strong> {note}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </div>
    )
  }

  const renderStopApproval = (s: StopItem) => {
    return (
      <div className="space-y-3 pt-2">
        {/* 1. Foto Bukti Pickup (Driver Gudang K-24) */}
        {s.pickup_photo_url ? (
          <div className="p-3.5 rounded-xl border border-blue-100 dark:border-blue-900 bg-blue-50/20 dark:bg-blue-950/10 space-y-2">
            <div className="flex items-center justify-between text-xs text-blue-700 dark:text-blue-400 font-bold">
              <span>📦 1. Foto Bukti Pickup (Driver Gudang K-24)</span>
              {s.pickup_note && <span className="font-normal italic text-muted-foreground">"{s.pickup_note}"</span>}
            </div>
            <PhotoGalleryViewer photoField={s.pickup_photo_url} title="Bukti Pickup Barang" />
          </div>
        ) : (
          <div className="p-3 rounded-xl border border-dashed border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/50 text-xs text-muted-foreground flex items-center justify-between">
            <span className="font-medium">📦 1. Foto Bukti Pickup:</span>
            <span className="italic text-slate-400">Belum di-upload oleh driver</span>
          </div>
        )}

        {/* 2. Foto Bukti Tiba di Lokasi (Driver) */}
        {s.arrived_photo_url ? (
          <div className="p-3.5 rounded-xl border border-emerald-100 dark:border-emerald-900 bg-emerald-50/20 dark:bg-emerald-950/10 space-y-2">
            <div className="flex items-center justify-between text-xs text-emerald-700 dark:text-emerald-400 font-bold">
              <span>📍 2. Foto Bukti Tiba di Lokasi Apotek (Driver)</span>
              {s.arrived_note && <span className="font-normal italic text-muted-foreground">"{s.arrived_note}"</span>}
            </div>
            <PhotoGalleryViewer photoField={s.arrived_photo_url} title="Bukti Tiba di Lokasi Apotek" />
          </div>
        ) : (
          <div className="p-3 rounded-xl border border-dashed border-slate-200 dark:border-slate-800 bg-slate-50/50 dark:bg-slate-900/50 text-xs text-muted-foreground flex items-center justify-between">
            <span className="font-medium">📍 2. Foto Bukti Tiba di Lokasi:</span>
            <span className="italic text-slate-400">Belum di-upload oleh driver</span>
          </div>
        )}

        {/* Driver Rejection Case */}
        {s.status === 'REJECTED_WAITING_APPROVAL' && (
          <div className="p-4 rounded-xl border border-dashed border-rose-300 bg-rose-50/10 dark:bg-rose-950/10 space-y-3.5">
            <div className="flex items-center gap-2 text-rose-600 dark:text-rose-400">
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span className="text-xs font-bold font-sans">Driver Mengajukan Penolakan (Rejection)</span>
            </div>
            <div className="text-xs space-y-1.5 text-muted-foreground leading-relaxed">
              <p>
                Alasan: <strong className="text-foreground">{s.reject_reason || '—'}</strong>
              </p>
              {s.reject_note && (
                <p>
                  Catatan: <span className="italic text-foreground">"{s.reject_note}"</span>
                </p>
              )}
              <PhotoGalleryViewer photoField={s.reject_photo_url} title="Bukti Penolakan" />
            </div>
            <div className="flex gap-2 pt-1">
              <button
                onClick={() => handleApproveReject(s.id, true)}
                disabled={approvingId !== null}
                className="h-8 px-3 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs transition-colors shadow-sm"
              >
                Setujui Penolakan (Batalkan Order)
              </button>
              <button
                onClick={() => handleApproveReject(s.id, false)}
                disabled={approvingId !== null}
                className="h-8 px-3 rounded-lg bg-rose-50 text-rose-700 border border-rose-200 hover:bg-rose-100 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900 transition-colors font-bold text-xs"
              >
                Tolak Penolakan (Kembalikan ke Driver)
              </button>
            </div>
          </div>
        )}

        {/* 3. Bukti Serah Terima & Verifikasi Invoice (Apoteker & Driver) */}
        {(s.checked_invoices || s.status === 'COMPLETED_WAITING_APPROVAL' || s.status === 'COMPLETED' || s.unboxing_option || s.handover_photo_url || s.signature_photo_url || s.facture_photo_url) && (
          <div className={`p-4 rounded-xl border border-dashed ${
            s.status === 'COMPLETED' ? 'border-emerald-300 bg-emerald-50/10 dark:bg-emerald-950/10' : 'border-purple-300 bg-purple-50/10 dark:bg-purple-950/10'
          } space-y-3.5`}>
            <div className={`flex items-center gap-2 ${s.status === 'COMPLETED' ? 'text-emerald-600 dark:text-emerald-400' : 'text-purple-600 dark:text-purple-400'}`}>
              <CheckCircle className="h-4 w-4 shrink-0" />
              <span className="text-xs font-bold font-sans">
                🤝 3. Bukti Serah Terima & Verifikasi Invoice (Apoteker)
              </span>
            </div>

            <div className="text-xs space-y-3 text-muted-foreground leading-relaxed">
              {s.unboxing_option === 'WAITING_FOR_UNBOXING' && s.extra_items_note && (
                <div className="p-2.5 rounded-lg bg-amber-50 dark:bg-amber-950/20 border border-amber-100 dark:border-amber-900 text-amber-800 dark:text-amber-300 font-medium">
                  ⚠️ <strong>Unboxing Ditunda Apoteker:</strong> {s.extra_items_note}
                </div>
              )}

              {/* Render Invoices List Green / Red */}
              {renderCheckedInvoicesList(s.checked_invoices)}

              {s.extra_items_note && s.unboxing_option !== 'WAITING_FOR_UNBOXING' && (
                <p className="pt-1">
                  Catatan Unboxing Tambahan: <span className="text-foreground font-medium">{s.extra_items_note}</span>
                </p>
              )}

              {s.extra_items_photo_url && (
                <PhotoGalleryViewer photoField={s.extra_items_photo_url} title="Foto Barang Tambahan" />
              )}

              {/* 3a. Foto Serah Terima Paket (Penerima) */}
              {s.handover_photo_url && (
                <div className="pt-2 border-t border-dashed border-border/80">
                  <span className="text-xs font-bold text-foreground block mb-2">🤝 Foto Bukti Serah Terima Paket (Penerima/Apoteker):</span>
                  <PhotoGalleryViewer photoField={s.handover_photo_url} title="Foto Serah Terima Paket" />
                </div>
              )}

              {/* 3b. Tanda Tangan Digital Apoteker */}
              {s.signature_photo_url && (
                <div className="pt-2 border-t border-dashed border-border/80">
                  <span className="text-xs font-bold text-foreground block mb-2">✍️ Tanda Tangan Digital Verifikasi Apoteker:</span>
                  <PhotoGalleryViewer photoField={s.signature_photo_url} title="Tanda Tangan Digital Apoteker" />
                </div>
              )}

              {/* 3c. Bukti Faktur Fisik Uploaded by Driver */}
              {s.facture_photo_url && s.facture_photo_url !== s.extra_items_photo_url ? (
                <div className="pt-2 border-t border-dashed border-border/80">
                  <span className="text-xs font-bold text-foreground block mb-2">📄 Bukti Faktur Fisik Tanda Tangan & Cap (Driver):</span>
                  <PhotoGalleryViewer photoField={s.facture_photo_url} title="Foto Faktur Tanda Tangan & Cap" />
                </div>
              ) : null}
            </div>

            {s.status !== 'COMPLETED' && s.status === 'COMPLETED_WAITING_APPROVAL' && (
              <div className="flex gap-2 pt-1">
                <button
                  onClick={() => handleApproveFacture(s.id, true)}
                  disabled={approvingId !== null}
                  className="h-8 px-3 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs transition-colors shadow-sm"
                >
                  Setujui Faktur & Selesaikan Order
                </button>
                <button
                  onClick={() => handleApproveFacture(s.id, false)}
                  disabled={approvingId !== null}
                  className="h-8 px-3 rounded-lg bg-rose-50 text-rose-700 border border-rose-200 hover:bg-rose-100 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900 transition-colors font-bold text-xs"
                >
                  Tolak Faktur (Re-upload)
                </button>
              </div>
            )}
          </div>
        )}

        {/* 4. Bukti Pengembalian POD ke KDE / Gudang K-24 */}
        {s.pod_signature_photo_url ? (
          <div className="p-3.5 rounded-xl border border-indigo-200 dark:border-indigo-900 bg-indigo-50/30 dark:bg-indigo-950/20 space-y-2">
            <div className="flex items-center justify-between text-xs text-indigo-700 dark:text-indigo-400 font-bold">
              <span>🏢 4. Bukti Pengembalian POD ke KDE / Gudang K-24</span>
              <span className="text-[10px] bg-indigo-600 text-white px-2 py-0.5 rounded font-extrabold">VERIFIED POD</span>
            </div>
            <PhotoGalleryViewer photoField={s.pod_signature_photo_url} title="Bukti Tanda Tangan & Cap Pengembalian POD Gudang" />
          </div>
        ) : s.status === 'COMPLETED' ? (
          <div className="p-3 rounded-xl border border-dashed border-indigo-200 dark:border-indigo-900/60 bg-indigo-50/20 dark:bg-indigo-950/10 text-xs text-muted-foreground flex items-center justify-between">
            <span className="font-medium text-indigo-700 dark:text-indigo-400">🏢 4. Bukti Pengembalian POD ke KDE:</span>
            <span className="italic text-slate-400">Belum di-upload / Proses serah terima POD</span>
          </div>
        ) : null}

        {s.status === 'PENDING' && s.unboxing_option === 'WAITING_FOR_UNBOXING' && !s.checked_invoices && (
          <div className="p-4 rounded-xl border border-dashed border-amber-300 bg-amber-50/10 dark:bg-amber-950/10 space-y-1.5 text-xs text-muted-foreground">
            <div className="flex items-center gap-2 text-amber-600 dark:text-amber-400 font-bold">
              <Clock className="h-4 w-4 shrink-0" />
              <span>Unboxing Ditunda oleh Apoteker</span>
            </div>
            {s.extra_items_note && (
              <p className="leading-relaxed mt-1">
                Alasan Tunda: <strong className="text-foreground">"{s.extra_items_note}"</strong>
              </p>
            )}
          </div>
        )}
      </div>
    )
  }

  const fetchOrders = useCallback(async () => {
    setLoading(true)
    try {
      const res = await adminAPI.getOrders()
      setOrders(res.data.data || [])
    } catch { toast.error('Gagal memuat daftar order.') }
    finally { setLoading(false) }
  }, [])

  useEffect(() => { fetchOrders() }, [fetchOrders])

  const fetchDetail = useCallback(async (dispatchId: string) => {
    setLoadingDetail(true)
    setSelectedDispatchId(dispatchId)
    setOrderDetail(null)
    try {
      const res = await adminAPI.getOrderDetail(dispatchId)
      setOrderDetail(res.data.data || null)
    } catch { toast.error('Gagal memuat detail order.') }
    finally { setLoadingDetail(false) }
  }, [])

  const filtered = orders.filter((o) => {
    const matchId = !searchId || o.dispatch_id?.toLowerCase().includes(searchId.toLowerCase())
    const matchStatus = filterStatus === 'ALL' || o.status === filterStatus
    const matchDriver = !searchDriver || (o.driver_name || '').toLowerCase().includes(searchDriver.toLowerCase())
    const matchMitra = !searchMitra || (o.mitra_name || '').toLowerCase().includes(searchMitra.toLowerCase())
    return matchId && matchStatus && matchDriver && matchMitra
  })

  // ─── DETAIL VIEW ───────────────────────────────────────────────────────────
  if (selectedDispatchId) {
    const isDispatched = orderDetail?.stops?.some((s) => s.driver_id > 0) || false
    const assignedDriver = orderDetail?.stops?.find((s) => s.driver_id > 0)
    const totalDistance = orderDetail?.stops?.reduce((acc, s) => acc + (s.distance_km || 0), 0) || 0
    const uniqueDriverIds = new Set(orderDetail?.stops?.map((s) => s.driver_id).filter((id) => id > 0))
    const driverCount = orderDetail?.driver_groups?.length || uniqueDriverIds.size || (assignedDriver ? 1 : 0)
    const dispatchStatus = orderDetail?.stops?.[0]?.status || 'PENDING'
    const mainStatusConf = STATUS_CONFIG[dispatchStatus] || { label: dispatchStatus, color: 'bg-muted text-muted-foreground' }

    return (
      <DashboardShell onRefresh={() => fetchDetail(selectedDispatchId)}>
        {loadingDetail ? (
          <div className="flex items-center justify-center py-24">
            <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
          </div>
        ) : !orderDetail ? (
          <div className="flex flex-col items-center py-16 rounded-2xl border border-border bg-card gap-3">
            <AlertCircle className="h-10 w-10 text-muted-foreground/40" />
            <p className="text-muted-foreground">Gagal memuat detail order.</p>
            <button
              onClick={() => { setSelectedDispatchId(null); setOrderDetail(null) }}
              className="flex items-center gap-2 h-9 px-3 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors"
            >
              <ArrowLeft className="h-4 w-4" /> Kembali
            </button>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Header section */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div className="flex items-center gap-4">
                <button
                  onClick={() => { setSelectedDispatchId(null); setOrderDetail(null) }}
                  className="flex items-center justify-center h-10 w-10 rounded-xl border border-border bg-card hover:bg-accent transition-colors"
                  title="Kembali"
                >
                  <ArrowLeft className="h-5 w-5" />
                </button>
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h1 className="text-2xl font-bold text-foreground">Detail Order</h1>
                    <span className="text-2xl font-bold text-blue-600">{orderDetail.dispatch_id}</span>
                  </div>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    Pengiriman dibuat pada {new Date(orderDetail.created_at || Date.now()).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })} • {new Date(orderDetail.created_at || Date.now()).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })} WIB
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-3 bg-card border border-border px-4 py-2.5 rounded-xl self-start md:self-auto shadow-sm">
                <span className="text-xs text-muted-foreground font-medium">Status Order</span>
                <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${mainStatusConf.color}`}>
                  <span className="h-1.5 w-1.5 rounded-full bg-current" />
                  {mainStatusConf.label}
                </span>
              </div>
            </div>

            {/* Stats row */}
            <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
              {/* Card 1: Armada */}
              <div className="bg-card border border-border p-4 rounded-2xl flex items-center gap-3.5 shadow-sm">
                <div className="h-10 w-10 rounded-full bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 flex items-center justify-center shrink-0">
                  <Truck className="h-5 w-5" />
                </div>
                <div>
                  <p className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider">Armada</p>
                  <p className="font-extrabold text-sm uppercase text-foreground">{orderDetail.armada || 'MOTOR'}</p>
                  <p className="text-[10px] text-muted-foreground">Jenis Kendaraan</p>
                </div>
              </div>

              {/* Card 2: Total Titik */}
              <div className="bg-card border border-border p-4 rounded-2xl flex items-center gap-3.5 shadow-sm">
                <div className="h-10 w-10 rounded-full bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 dark:text-emerald-400 flex items-center justify-center shrink-0">
                  <MapPin className="h-5 w-5" />
                </div>
                <div>
                  <p className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider">Total Titik</p>
                  <p className="font-extrabold text-sm text-foreground">{orderDetail.stops?.length || 0} Titik</p>
                  <p className="text-[10px] text-muted-foreground">Tujuan Pengiriman</p>
                </div>
              </div>

              {/* Card 3: Driver */}
              <div className="bg-card border border-border p-4 rounded-2xl flex items-center gap-3.5 shadow-sm">
                <div className="h-10 w-10 rounded-full bg-purple-50 dark:bg-purple-950/40 text-purple-600 dark:text-purple-400 flex items-center justify-center shrink-0">
                  <User className="h-5 w-5" />
                </div>
                <div>
                  <p className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider">Driver</p>
                  <p className="font-extrabold text-sm text-foreground">{driverCount > 0 ? `${driverCount} Driver` : 'Belum Ada'}</p>
                  <p className="text-[10px] text-muted-foreground">Ditugaskan</p>
                </div>
              </div>

              {/* Card 4: Total Jarak */}
              <div className="bg-card border border-border p-4 rounded-2xl flex items-center gap-3.5 shadow-sm">
                <div className="h-10 w-10 rounded-full bg-sky-50 dark:bg-sky-950/40 text-sky-600 dark:text-sky-400 flex items-center justify-center shrink-0">
                  <Compass className="h-5 w-5" />
                </div>
                <div>
                  <p className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider">Total Jarak</p>
                  <p className="font-extrabold text-sm text-foreground">{isDispatched && totalDistance > 0 ? `${totalDistance.toFixed(1)} km` : '—'}</p>
                  <p className="text-[10px] text-muted-foreground">Estimasi Jarak</p>
                </div>
              </div>


            </div>

            {/* Two-Column Grid Layout */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Left column */}
              <div className="lg:col-span-2 space-y-6">
                
                {/* Rincian Titik Pengiriman dengan Sistem Tab Horizontal */}
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <h3 className="font-bold text-base text-foreground">Rincian Titik Pengiriman</h3>
                    <span className="text-xs font-semibold text-muted-foreground bg-muted px-2.5 py-1 rounded-lg">
                      Total {orderDetail.stops?.length || 0} Titik Alamat
                    </span>
                  </div>

                  {/* Grid Layout Cards per Stop (Default 4 Columns, Responsive Wrap) */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2.5 pb-3 border-b border-border">
                    {orderDetail.stops?.map((s, idx) => {
                      const isActive = activeStopIndex === idx
                      const sc = STATUS_CONFIG[s.status] || { label: s.status, color: 'bg-muted text-muted-foreground' }
                      return (
                        <button
                          key={s.id || idx}
                          type="button"
                          onClick={() => setActiveStopIndex(idx)}
                          className={`w-full flex flex-col justify-between gap-2 p-3 rounded-xl text-xs font-bold transition-all text-left border ${
                            isActive
                              ? 'bg-blue-600 border-blue-600 text-white shadow-md shadow-blue-500/20 scale-[1.01]'
                              : 'bg-card hover:bg-muted/60 text-muted-foreground hover:text-foreground border-border'
                          }`}
                        >
                          <div className="flex items-center gap-2 min-w-0 w-full">
                            <span className={`h-5 w-5 rounded-full flex items-center justify-center text-[10px] font-extrabold shrink-0 ${
                              isActive ? 'bg-white/20 text-white' : 'bg-blue-100 dark:bg-blue-950 text-blue-600'
                            }`}>
                              {idx + 1}
                            </span>
                            <span className="font-bold text-xs truncate flex-1 min-w-0" title={s.nama_apotek}>
                              {s.nama_apotek}
                            </span>
                          </div>
                          <div className="flex items-center justify-between w-full pt-1.5 border-t border-current/10">
                            <span className={`px-2 py-0.5 rounded text-[9px] font-semibold ${
                              isActive ? 'bg-white/20 text-white' : sc.color
                            }`}>
                              {sc.label}
                            </span>
                          </div>
                        </button>
                      )
                    })}
                  </div>

                  {/* Active Selected Stop Detail View */}
                  {orderDetail.stops && orderDetail.stops[activeStopIndex] && (() => {
                    const s = orderDetail.stops[activeStopIndex]
                    const idx = activeStopIndex
                    const sc = STATUS_CONFIG[s.status] || { label: s.status, color: 'bg-muted text-muted-foreground' }
                    return (
                      <div className="bg-card border border-border rounded-2xl p-5 hover:border-blue-300 dark:hover:border-blue-800 transition-all space-y-4">
                        <div className="flex justify-between items-start gap-4">
                          <div className="space-y-1">
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="h-6 px-2.5 rounded-full bg-blue-600 text-white text-xs font-extrabold flex items-center justify-center">
                                Titik {idx + 1}
                              </span>
                              <h4 className="font-bold text-base text-foreground">{s.nama_apotek}</h4>
                              <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold ${sc.color}`}>
                                {sc.label}
                              </span>
                            </div>
                            <p className="text-xs text-muted-foreground leading-relaxed pt-1">{s.alamat}</p>
                          </div>
                        </div>

                        <div className="flex flex-wrap gap-x-6 gap-y-2 pt-3 border-t border-border/80 text-xs text-muted-foreground">
                          <div className="flex items-center gap-1.5">
                            <User className="h-3.5 w-3.5 text-blue-500 shrink-0" />
                            <span>Driver: <strong className="text-foreground font-semibold">{s.driver_name || 'Belum ditugaskan'}</strong></span>
                          </div>
                          <div className="flex items-center gap-1.5">
                            <Compass className="h-3.5 w-3.5 text-blue-500 shrink-0" />
                            <span>Jarak: <strong className="text-foreground font-semibold">{isDispatched && s.distance_km > 0 ? `${s.distance_km.toFixed(1)} km` : '—'}</strong></span>
                          </div>
                        </div>

                        {renderStopApproval(s)}
                      </div>
                    )
                  })()}
                </div>


              </div>

              {/* Right column */}
              <div className="space-y-6">
                {/* Informasi Driver */}
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm">
                  <h3 className="font-bold text-base text-foreground mb-4">Informasi Driver</h3>
                  {assignedDriver ? (
                    <div className="space-y-4">
                      <div className="flex items-center gap-3.5">
                        <div className="h-12 w-12 rounded-full bg-blue-100 dark:bg-blue-950 text-blue-600 dark:text-blue-400 font-bold text-lg flex items-center justify-center shrink-0">
                          {assignedDriver.driver_name[0].toUpperCase()}
                        </div>
                        <div>
                          <h4 className="font-bold text-sm text-foreground">{assignedDriver.driver_name}</h4>
                          <p className="text-xs text-muted-foreground mt-0.5">
                            {assignedDriver.driver_vehicle === 'mobil' ? '🚗 Mobil Pengantar' : '🏍️ Motor Pengantar'}
                          </p>
                          {assignedDriver.driver_plate && (
                            <span className="inline-flex mt-1.5 px-2 py-0.5 rounded bg-muted text-[10px] font-bold border border-border text-foreground">
                              {assignedDriver.driver_plate}
                            </span>
                          )}
                        </div>
                      </div>

                      <div className="flex flex-col gap-2">
                        <button
                          onClick={() => window.open(`tel:${assignedDriver.driver_phone || '08123456789'}`)}
                          className="w-full flex items-center justify-center gap-2 h-10 px-4 rounded-lg bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 border border-blue-100 dark:border-blue-900/60 hover:bg-blue-100 dark:hover:bg-blue-950/60 transition-colors font-semibold text-xs"
                        >
                          <Phone className="h-4 w-4" /> Hubungi Driver
                        </button>
                        <button
                          onClick={() => handleCancelDriverClick(orderDetail.dispatch_id)}
                          className="w-full flex items-center justify-center gap-2 h-10 px-4 rounded-lg bg-rose-50 dark:bg-rose-950/40 text-rose-600 dark:text-rose-400 border border-rose-200 dark:border-rose-900/60 hover:bg-rose-100 dark:hover:bg-rose-950/60 transition-colors font-semibold text-xs"
                        >
                          <UserX className="h-4 w-4" /> Batalkan Penugasan Driver
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="text-center py-6 text-muted-foreground text-xs">
                      Belum ada driver yang ditugaskan ke order ini.
                    </div>
                  )}
                </div>

                {/* Detail Pengiriman */}
                <div className="bg-card border border-border p-6 rounded-2xl shadow-sm">
                  <h3 className="font-bold text-base text-foreground mb-4">Detail Pengiriman</h3>
                  <div className="space-y-3.5 text-xs">
                    <div className="flex justify-between border-b border-border/50 pb-2">
                      <span className="text-muted-foreground">Nomor Order</span>
                      <span className="font-semibold text-foreground">{orderDetail.dispatch_id}</span>
                    </div>
                    <div className="flex justify-between border-b border-border/50 pb-2">
                      <span className="text-muted-foreground">Tanggal Dibuat</span>
                      <span className="font-semibold text-foreground">
                        {new Date(orderDetail.created_at || Date.now()).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' })}
                      </span>
                    </div>
                    <div className="flex justify-between border-b border-border/50 pb-2">
                      <span className="text-muted-foreground">Armada</span>
                      <span className="font-semibold text-foreground uppercase">{orderDetail.armada || 'motor'}</span>
                    </div>
                    <div className="flex justify-between border-b border-border/50 pb-2">
                      <span className="text-muted-foreground">Rate</span>
                      <span className="font-semibold text-foreground capitalize">{orderDetail.rate_type || 'per titik'}</span>
                    </div>
                    <div className="flex justify-between border-b border-border/50 pb-2">
                      <span className="text-muted-foreground">Jumlah Titik</span>
                      <span className="font-semibold text-foreground">{orderDetail.stops?.length || 0} Titik</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Estimasi Jarak</span>
                      <span className="font-semibold text-foreground">{totalDistance.toFixed(1)} km</span>
                    </div>
                  </div>
                </div>

                {/* Action buttons row */}
                <div className="space-y-3">
                  {orderDetail.dispatch_id && (
                    <Link
                      href={`/dashboard/dispatch/${orderDetail.dispatch_id}/tracking`}
                      className="flex items-center justify-center gap-2 h-11 w-full rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-bold text-xs shadow-md hover:shadow-lg transition-all"
                    >
                      <Navigation className="h-4 w-4" /> Lihat Live Tracking Kurir (Peta Realtime) 🛰️
                    </Link>
                  )}
                  <div className="grid grid-cols-2 gap-3">
                    <button className="flex items-center justify-center gap-1.5 h-10 px-3 rounded-lg border border-blue-200 dark:border-blue-900 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/20 transition-colors font-semibold text-xs bg-card">
                      <Download className="h-4 w-4" /> Download Invoice
                    </button>
                    <button className="flex items-center justify-center gap-1.5 h-10 px-3 rounded-lg border border-blue-200 dark:border-blue-900 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/20 transition-colors font-semibold text-xs bg-card">
                      <Printer className="h-4 w-4" /> Cetak
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </DashboardShell>
    )
  }

  // ─── LIST VIEW ─────────────────────────────────────────────────────────────
  return (
    <DashboardShell onRefresh={fetchOrders}>
      <div className="mb-6">
        <h1 className="text-2xl font-bold tracking-tight">Daftar Order</h1>
        <p className="text-sm text-muted-foreground mt-1">Riwayat semua order bulk yang telah dibuat (dikelompokkan per Parent Order ID).</p>
      </div>

      {/* Filters */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 mb-6 rounded-2xl border border-border bg-card p-4 shadow-sm">
        {/* Left: Cari Order ID */}
        <div className="relative flex-1 max-w-xs w-full">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            type="text"
            placeholder="Cari Order ID..."
            value={searchId}
            onChange={(e) => setSearchId(e.target.value)}
            className="h-10 w-full rounded-xl border border-border bg-background pl-10 pr-3 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all"
          />
        </div>

        {/* Right: Select Status, Cari Driver, Cari Mitra (if admin) */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full md:w-auto">
          <div className="relative">
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="h-10 rounded-xl border border-border bg-background pl-4 pr-10 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 min-w-[160px] w-full sm:w-auto appearance-none cursor-pointer font-medium"
            >
              <option value="ALL">Semua Status</option>
              <option value="PENDING">Pending Dispatch</option>
              <option value="WAITING_FOR_PICKUP">Waiting for Pickup</option>
              <option value="DELIVERING">Delivering</option>
              <option value="COMPLETED">Completed</option>
              <option value="CANCELLED">Cancelled</option>
            </select>
            <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3.5 text-muted-foreground">
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          </div>

          <div className="relative">
            <User className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Cari Driver..."
              value={searchDriver}
              onChange={(e) => setSearchDriver(e.target.value)}
              className="h-10 rounded-xl border border-border bg-background pl-10 pr-3 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 min-w-[160px] w-full sm:w-auto transition-all"
            />
          </div>

          {user?.role === 'ADMIN' && (
            <div className="relative">
              <User className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <input
                type="text"
                placeholder="Cari Mitra..."
                value={searchMitra}
                onChange={(e) => setSearchMitra(e.target.value)}
                className="h-10 rounded-xl border border-border bg-background pl-10 pr-3 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 min-w-[160px] w-full sm:w-auto transition-all"
              />
            </div>
          )}
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
          <p className="text-sm text-muted-foreground">Memuat daftar order...</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-2xl border border-border bg-card py-16 gap-3">
          <FileText className="h-10 w-10 text-muted-foreground/40" />
          <h3 className="font-semibold">Tidak Ada Order</h3>
          <p className="text-sm text-muted-foreground">Belum ada order yang sesuai filter pencarian.</p>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden min-h-[220px]">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40">
                    {[
                      'Order ID', 'Status', 'Driver', 'Alamat Tujuan', 'Dibuat', 'Aksi'
                    ].map((h) => (
                      <th key={h} className="px-5 py-3 text-left text-xs font-bold uppercase tracking-wider text-muted-foreground whitespace-nowrap">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {filtered.map((o) => {
                    const statusConf = STATUS_CONFIG[o.status] || { label: o.status, color: 'bg-muted text-muted-foreground' }
                    return (
                      <tr
                        key={o.dispatch_id}
                        onClick={() => fetchDetail(o.dispatch_id)}
                        className="hover:bg-muted/20 transition-colors cursor-pointer"
                      >
                        {/* Order ID */}
                        <td className="px-5 py-4">
                          <div className="flex flex-col">
                            <span className="font-extrabold text-sm text-blue-600">{o.dispatch_id}</span>
                            <span className="text-xs text-muted-foreground mt-0.5">{o.stop_count} titik pengiriman</span>
                          </div>
                        </td>

                        {/* Status */}
                        <td className="px-5 py-4">
                          <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${statusConf.color}`}>
                            <span className="h-1.5 w-1.5 rounded-full bg-current" />
                            {statusConf.label}
                          </span>
                        </td>

                        {/* Driver */}
                        <td className="px-5 py-4">
                          <div className="flex items-center gap-2.5">
                            <div className="h-8 w-8 rounded-full bg-blue-100 dark:bg-blue-950 text-blue-600 dark:text-blue-400 font-bold text-xs flex items-center justify-center shrink-0 overflow-hidden">
                              {o.driver_name ? o.driver_name[0].toUpperCase() : <User className="h-4 w-4" />}
                            </div>
                            <div className="flex flex-col">
                              <span className="font-extrabold text-sm text-foreground">{o.driver_name || 'Belum Dispatch'}</span>
                              {o.driver_phone && (
                                <span className="text-[10px] text-muted-foreground flex items-center gap-1 mt-0.5">
                                  <Phone className="h-3 w-3 shrink-0" /> {o.driver_phone}
                                </span>
                              )}
                            </div>
                          </div>
                        </td>



                        {/* Alamat */}
                        <td className="px-5 py-4">
                          <div className="flex flex-col gap-1.5 items-start max-w-sm">
                            <div className="flex items-start gap-1.5">
                              <MapPin className="h-4 w-4 text-blue-500 shrink-0 mt-0.5" />
                              <span className="text-xs text-foreground line-clamp-2 leading-relaxed" title={o.addresses}>{o.addresses || '—'}</span>
                            </div>
                            <span className="inline-flex items-center justify-center rounded-lg bg-slate-100 dark:bg-slate-800 px-2 py-0.5 text-[10px] font-bold text-slate-600 dark:text-slate-400 font-semibold">
                              {o.stop_count} Titik
                            </span>
                          </div>
                        </td>

                        {/* Dibuat */}
                        <td className="px-5 py-4 text-xs text-muted-foreground whitespace-nowrap">
                          <div className="flex flex-col gap-1 text-xs text-muted-foreground">
                            <span className="flex items-center gap-1.5">
                              <Calendar className="h-3.5 w-3.5 shrink-0 text-muted-foreground/70" />
                              {new Date(o.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}
                            </span>
                            <span className="flex items-center gap-1.5">
                              <Clock className="h-3.5 w-3.5 shrink-0 text-muted-foreground/70" />
                              {new Date(o.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })} WIB
                            </span>
                          </div>
                        </td>

                        {/* Aksi */}
                        <td className="px-5 py-4 whitespace-nowrap">
                          <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
                            <button
                              onClick={() => fetchDetail(o.dispatch_id)}
                              className="inline-flex items-center gap-1 text-xs font-semibold text-blue-600 hover:text-blue-500 bg-blue-50/50 hover:bg-blue-50 dark:bg-blue-950/20 dark:hover:bg-blue-950/40 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/60 transition-colors"
                            >
                              Lihat Detail
                            </button>
                            <button
                              type="button"
                              onClick={(e) => toggleDropdown(e, o.dispatch_id)}
                              className="h-8 w-8 flex items-center justify-center rounded-lg hover:bg-muted text-muted-foreground hover:text-foreground transition-colors shrink-0 border border-transparent hover:border-border"
                              title="Pilihan Aksi"
                            >
                              <MoreVertical className="h-4 w-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>

            {/* Fixed Position Dropdown Popup (Escapes overflow-hidden completely!) */}
            {openDropdownId && dropdownPos && (
              <>
                <div
                  className="fixed inset-0 z-50 bg-transparent"
                  onClick={(e) => {
                    e.stopPropagation()
                    setOpenDropdownId(null)
                    setDropdownPos(null)
                  }}
                />
                <div
                  style={{ top: `${dropdownPos.top}px`, left: `${dropdownPos.left}px` }}
                  className="fixed z-50 w-44 rounded-xl border border-border bg-card p-1.5 shadow-2xl shadow-black/20 animate-in fade-in-50 zoom-in-95"
                  onClick={(e) => e.stopPropagation()}
                >
                  {(() => {
                    const ord = orders.find((o) => o.dispatch_id === openDropdownId)
                    return (
                      <>
                        <button
                          type="button"
                          onClick={() => handleEditOrder(openDropdownId)}
                          className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-xs font-semibold text-foreground hover:bg-blue-50 dark:hover:bg-blue-950/30 hover:text-blue-600 transition-colors"
                        >
                          <Pencil className="h-3.5 w-3.5 text-blue-500 shrink-0" />
                          <span>Edit Order</span>
                        </button>
                        {ord?.is_dispatched && (
                          <button
                            type="button"
                            onClick={() => handleCancelDriverClick(openDropdownId)}
                            className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-xs font-semibold text-amber-600 dark:text-amber-400 hover:bg-amber-50 dark:hover:bg-amber-950/30 transition-colors"
                          >
                            <UserX className="h-3.5 w-3.5 text-amber-500 shrink-0" />
                            <span>Batal Driver</span>
                          </button>
                        )}
                        <div className="my-1 border-t border-border/60" />
                        <button
                          type="button"
                          onClick={() => handleDeleteClick(openDropdownId, ord?.stop_count || 1)}
                          className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-xs font-semibold text-rose-600 dark:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/30 transition-colors"
                        >
                          <Trash2 className="h-3.5 w-3.5 text-rose-500 shrink-0" />
                          <span>Hapus Order</span>
                        </button>
                      </>
                    )
                  })()}
                </div>
              </>
            )}

            {/* Cancel Driver Assignment Confirmation Modal */}
            {cancelingDriverOrder && (
              <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-in fade-in">
                <div className="w-full max-w-md rounded-2xl border border-border bg-card p-6 shadow-xl space-y-4">
                  <div className="flex items-center gap-3 text-amber-600 dark:text-amber-400">
                    <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-100 dark:bg-amber-950/50">
                      <UserX className="h-5 w-5" />
                    </div>
                    <div>
                      <h3 className="font-bold text-lg text-foreground">Batalkan Penugasan Driver?</h3>
                      <p className="text-xs text-muted-foreground">Order {cancelingDriverOrder.id}</p>
                    </div>
                  </div>

                  <p className="text-sm text-muted-foreground leading-relaxed">
                    Penugasan driver untuk order <strong className="text-foreground">{cancelingDriverOrder.id}</strong> akan dibatalkan. Status order akan dikembalikan ke <strong className="text-foreground">PENDING</strong> dan dimasukkan kembali ke antrean <strong className="text-foreground">Dispatch Operator (OTMS)</strong> agar dapat di-dispatch ke driver lain.
                  </p>

                  <div className="flex items-center justify-end gap-2.5 pt-2">
                    <button
                      type="button"
                      disabled={isCancelingDriver}
                      onClick={() => setCancelingDriverOrder(null)}
                      className="h-10 px-4 rounded-xl border border-border text-sm font-semibold hover:bg-accent transition-colors"
                    >
                      Batal
                    </button>
                    <button
                      type="button"
                      disabled={isCancelingDriver}
                      onClick={handleConfirmCancelDriver}
                      className="h-10 px-4 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-sm font-semibold flex items-center justify-center gap-2 shadow-sm transition-colors disabled:opacity-50"
                    >
                      {isCancelingDriver && <Loader2 className="h-4 w-4 animate-spin" />}
                      <span>Ya, Batalkan Driver</span>
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Delete Confirmation Modal */}
            {deletingOrder && (
              <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 animate-in fade-in">
                <div className="w-full max-w-md rounded-2xl border border-border bg-card p-6 shadow-xl space-y-4">
                  <div className="flex items-center gap-3 text-rose-600 dark:text-rose-400">
                    <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-rose-100 dark:bg-rose-950/50">
                      <Trash2 className="h-5 w-5" />
                    </div>
                    <div>
                      <h3 className="font-bold text-lg text-foreground">Hapus Order {deletingOrder.id}?</h3>
                      <p className="text-xs text-muted-foreground">Konfirmasi penghapusan order dari sistem</p>
                    </div>
                  </div>

                  <p className="text-sm text-muted-foreground leading-relaxed">
                    Apakah Anda yakin ingin menghapus order <strong className="text-foreground">{deletingOrder.id}</strong> ({deletingOrder.count} titik alamat)? Order dan rincian pengantaran akan dihapus secara permanen.
                  </p>

                  <div className="flex items-center justify-end gap-2.5 pt-2">
                    <button
                      type="button"
                      disabled={isDeleting}
                      onClick={() => setDeletingOrder(null)}
                      className="h-10 px-4 rounded-xl border border-border text-sm font-semibold hover:bg-accent transition-colors"
                    >
                      Batal
                    </button>
                    <button
                      type="button"
                      disabled={isDeleting}
                      onClick={handleConfirmDelete}
                      className="h-10 px-5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white font-semibold text-sm transition-colors shadow-md shadow-rose-500/20 flex items-center gap-2"
                    >
                      {isDeleting ? <><Loader2 className="h-4 w-4 animate-spin" /> Menghapus...</> : 'Ya, Hapus Order'}
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Pagination footer */}
            <div className="border-t border-border px-5 py-4 flex items-center justify-between">
              <p className="text-xs text-muted-foreground">Menampilkan {filtered.length} dari {orders.length} order</p>
              <div className="flex items-center gap-2">
                <button className="h-8 w-8 flex items-center justify-center rounded-lg border border-border bg-card text-muted-foreground hover:bg-accent transition-colors disabled:opacity-50" disabled>
                  <ChevronLeft className="h-4 w-4" />
                </button>
                <button className="h-8 w-8 flex items-center justify-center rounded-lg border border-blue-500 bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400 font-bold text-xs">
                  1
                </button>
                <button className="h-8 w-8 flex items-center justify-center rounded-lg border border-border bg-card text-muted-foreground hover:bg-accent transition-colors disabled:opacity-50" disabled>
                  <ChevronRight className="h-4 w-4" />
                </button>
              </div>
            </div>
          </div>

          {/* Bottom status indicators */}
          <div className="flex items-center gap-5 text-xs text-muted-foreground mt-4 px-1 font-semibold">
            <span className="flex items-center gap-2">
              <Activity className="h-4 w-4 text-amber-500 shrink-0" />
              <span>Menunggu: <strong className="text-foreground">{orders.filter(o => o.status === 'PENDING' || !o.is_dispatched).length}</strong></span>
            </span>
            <span className="flex items-center gap-2">
              <Truck className="h-4 w-4 text-blue-500 shrink-0" />
              <span>Aktif: <strong className="text-foreground">{orders.filter(o => o.is_dispatched && o.status !== 'COMPLETED' && o.status !== 'CANCELLED').length}</strong></span>
            </span>
            <span className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-emerald-500 shrink-0" />
              <span>Selesai: <strong className="text-foreground">{orders.filter(o => o.status === 'COMPLETED').length}</strong></span>
            </span>
          </div>
        </div>
      )}

      {/* Photo Lightbox Preview Modal */}
      {lightboxImage && (
        <div
          className="fixed inset-0 z-[100] bg-black/90 backdrop-blur-md flex items-center justify-center p-4 sm:p-6"
          onClick={() => setLightboxImage(null)}
        >
          <div
            className="relative max-w-4xl w-full bg-slate-950 rounded-2xl border border-slate-800 overflow-hidden shadow-2xl flex flex-col max-h-[90vh]"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="flex items-center justify-between px-5 py-3.5 border-b border-slate-800 bg-slate-900/80">
              <div className="flex items-center gap-2">
                <span className="text-lg">📷</span>
                <h3 className="font-bold text-sm text-white">{lightboxImage.title}</h3>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => {
                    const fullUrl = formatFullPhotoUrl(lightboxImage.url)
                    window.open(fullUrl, '_blank', 'noopener,noreferrer')
                  }}
                  className="px-3 py-1.5 rounded-lg bg-blue-600/30 hover:bg-blue-600/50 text-blue-300 text-xs font-semibold border border-blue-500/30 transition-colors flex items-center gap-1"
                >
                  <span>Buka di Tab Baru</span> ↗
                </button>
                <button
                  type="button"
                  onClick={() => setLightboxImage(null)}
                  className="h-8 w-8 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 flex items-center justify-center font-bold text-base transition-colors"
                >
                  ✕
                </button>
              </div>
            </div>

            {/* Modal Image View */}
            <div className="relative flex-1 bg-black flex items-center justify-center min-h-[300px] max-h-[70vh] p-2 overflow-auto">
              <img
                src={formatFullPhotoUrl(lightboxImage.url)}
                alt={lightboxImage.title}
                className="max-h-[68vh] max-w-full object-contain rounded-lg shadow-lg"
              />

              {/* Dynamic Camera Watermark Overlay */}
              <div className="absolute bottom-4 left-4 right-4 sm:left-6 sm:right-auto bg-black/85 backdrop-blur-md text-white p-3 rounded-xl border border-white/20 shadow-xl max-w-md pointer-events-none">
                <div className="flex items-center justify-between gap-3 border-b border-white/10 pb-1.5 mb-1.5">
                  <span className="font-extrabold text-xs tracking-wider text-amber-400 font-mono uppercase flex items-center gap-1.5">
                    <span>🕒</span> {lightboxImage.timestamp || 'REALTIME TIMESTAMP VERIFIED'}
                  </span>
                  <span className="text-[9px] bg-amber-500/20 text-amber-300 border border-amber-500/30 px-1.5 py-0.5 rounded font-bold">
                    GPS VERIFIED
                  </span>
                </div>
                <p className="text-[10px] text-slate-300 font-mono leading-tight">
                  📍 K-24 LOGISTICS SYSTEM • REALTIME DIGITAL WATERMARK STAMP
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </DashboardShell>
  )
}
