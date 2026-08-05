'use client'

import { useState, useEffect, useCallback } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import { Check, X, ClipboardList, Camera, AlertTriangle, FileText, CheckCircle2, Clock, Upload, Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

interface Order {
  id: number
  order_number: string
  status: string
  pharmacy_name: string
  pharmacy_address: string
  delivery_address: string
  customer_name: string
  medicine_summary: string
  delivery_fee: number
  unboxing_option?: string
  checked_invoices?: string
  extra_items_note?: string
  extra_items_photo_url?: string
  facture_photo_url?: string
}

export default function ApotekerUnboxPage() {
  const params = useParams()
  const router = useRouter()
  const orderId = params.orderId as string

  const [order, setOrder] = useState<Order | null>(null)
  const [invoices, setInvoices] = useState<string[]>([])
  const [allOrders, setAllOrders] = useState<any[]>([])
  const [activeTabIndex, setActiveTabIndex] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [invoiceStatuses, setInvoiceStatuses] = useState<Record<string, 'done' | 'missing'>>({})
  const [missingNotes, setMissingNotes] = useState<Record<string, string>>({})
  
  // Mandatory Apoteker Proof Photo State
  const [proofPhoto, setProofPhoto] = useState('')

  // Extra items states
  const [hasExtraItems, setHasExtraItems] = useState(false)
  const [extraItemsNote, setExtraItemsNote] = useState('')
  const [extraItemsPhoto, setExtraItemsPhoto] = useState('')

  const [submitting, setSubmitting] = useState(false)
  const [successState, setSuccessState] = useState<'direct' | 'later' | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)
  const [debugApiUrl, setDebugApiUrl] = useState('')

  // New decision states
  const [showDecisionModal, setShowDecisionModal] = useState(false)
  const [isDelaying, setIsDelaying] = useState(false)
  const [delayReason, setDelayReason] = useState('')

  const handleProofPhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onloadend = () => {
      setProofPhoto(reader.result as string)
    }
    reader.readAsDataURL(file)
  }

  const selectOrderTab = (idx: number, siblingList?: any[]) => {
    const list = siblingList || allOrders
    if (!list || list.length === 0 || !list[idx]) return
    setActiveTabIndex(idx)
    const current = list[idx]
    setOrder({
      id: current.id,
      order_number: current.order_number,
      status: current.status,
      pharmacy_name: current.pharmacy_name,
      pharmacy_address: current.delivery_address,
      delivery_address: current.delivery_address,
      customer_name: current.customer_name,
      medicine_summary: current.invoices?.join(', ') || '',
      delivery_fee: 0,
      unboxing_option: current.unboxing_option,
      checked_invoices: current.checked_invoices,
      extra_items_note: current.extra_items_note,
      extra_items_photo_url: current.extra_items_photo_url,
      facture_photo_url: current.facture_photo_url,
    })
    const invs = current.invoices || []
    setInvoices(invs)
    const statuses: Record<string, 'done' | 'missing'> = {}
    invs.forEach((inv: string) => { statuses[inv] = 'done' })
    setInvoiceStatuses(statuses)
  }

  const fetchOrderDetails = useCallback(async () => {
    setLoading(true)
    setErrorMsg(null)

    const fullUrl = `/api/public/orders/${orderId}`
    setDebugApiUrl(fullUrl)

    try {
      const res = await adminAPI.getPublicOrderDetail(orderId)
      const data = res.data.data
      setOrder(data.order)
      setInvoices(data.invoices || [])
      const siblings = data.all_orders || []
      setAllOrders(siblings)

      // Find current order index in siblings
      let foundIdx = 0
      if (siblings.length > 0) {
        const match = siblings.findIndex((s: any) => s.id === data.order.id || s.order_number === data.order.order_number)
        if (match >= 0) foundIdx = match
      }
      setActiveTabIndex(foundIdx)
      
      // Initialize checklist statuses
      const statuses: Record<string, 'done' | 'missing'> = {}
      ;(data.invoices || []).forEach((inv: string) => {
        statuses[inv] = 'done'
      })
      setInvoiceStatuses(statuses)

      // Only show decision modal if unboxing_option is empty
      if (!data.order.unboxing_option) {
        setShowDecisionModal(true)
      }
    } catch (err: any) {
      const msg = err.response?.data?.message || err.message || 'Gagal mengambil data order.'
      setErrorMsg(msg)
      toast.error('Gagal mengambil data order. Pastikan QR code benar.')
    } finally {
      setLoading(false)
    }
  }, [orderId])

  useEffect(() => {
    if (orderId) fetchOrderDetails()
  }, [orderId, fetchOrderDetails])

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onloadend = () => {
      setExtraItemsPhoto(reader.result as string)
    }
    reader.readAsDataURL(file)
  }

  // Start Unboxing API call
  const handleStartUnboxing = async () => {
    setSubmitting(true)
    try {
      await adminAPI.startUnboxOrder(orderId)
      setOrder(prev => prev ? { ...prev, unboxing_option: 'UNBOXING' } : null)
      setShowDecisionModal(false)
      toast.success('Mulai unboxing!')
    } catch (err: any) {
      toast.error('Gagal memulai unboxing.')
    } finally {
      setSubmitting(false)
    }
  }

  // Delay/Wait Unboxing API call
  const handleConfirmDelay = async () => {
    if (!delayReason.trim()) {
      toast.error('Alasan penundaan wajib diisi.')
      return
    }
    setSubmitting(true)
    try {
      await adminAPI.waitUnboxOrder(orderId, delayReason)
      toast.success('Unboxing ditunda.')
      setSuccessState('later')
      setShowDecisionModal(false)
    } catch (err: any) {
      toast.error('Gagal menunda unboxing.')
    } finally {
      setSubmitting(false)
    }
  }

  // Submit Direct Unboxing (UNBOXING)
  const handleSubmitUnboxing = async () => {
    // Validate missing notes
    const missingInvoices = invoices.filter(inv => invoiceStatuses[inv] === 'missing')
    for (const inv of missingInvoices) {
      if (!missingNotes[inv]?.trim()) {
        toast.error(`Catatan wajib diisi untuk invoice ${inv} yang hilang.`)
        return
      }
    }

    if (hasExtraItems && !extraItemsNote.trim()) {
      toast.error('Catatan wajib diisi untuk barang tanpa invoice.')
      return
    }

    // Mandatory photo proof check
    if (!proofPhoto) {
      toast.error('Wajib mengunggah Foto Bukti Pemeriksaan/Verifikasi Invoice oleh Apoteker!')
      return
    }

    setSubmitting(true)
    try {
      const checkedPayload = invoices.map(inv => {
        const stat = invoiceStatuses[inv]
        const note = stat === 'missing' ? ` (Hilang: ${missingNotes[inv]})` : ''
        return `${inv}: ${stat.toUpperCase()}${note}`
      }).join('; ')

      const targetId = order?.id ? String(order.id) : orderId
      await adminAPI.unboxOrder(targetId, {
        checked_invoices: checkedPayload,
        extra_items_note: hasExtraItems ? extraItemsNote : '',
        extra_items_photo_url: proofPhoto || (hasExtraItems ? extraItemsPhoto : ''),
      })

      if (allOrders.length > 1 && activeTabIndex < allOrders.length - 1) {
        toast.success(`Unboxing Order ${activeTabIndex + 1} (${order?.pharmacy_name}) selesai! Melanjutkan ke Order ${activeTabIndex + 2}...`)
        const nextIdx = activeTabIndex + 1
        selectOrderTab(nextIdx)
        setProofPhoto('')
        setHasExtraItems(false)
        setExtraItemsNote('')
        setExtraItemsPhoto('')
      } else {
        toast.success('Unboxing seluruh order dalam pengiriman berhasil disubmit!')
        setSuccessState('direct')
      }
    } catch (err: any) {
      toast.error(err.response?.data?.message || 'Gagal mengirim hasil unboxing.')
    } finally {
      setSubmitting(false)
    }
  }

  // Staff K-24 Scan Approval (POD Verification)
  const handleK24ApprovePOD = async () => {
    setSubmitting(true)
    try {
      await adminAPI.approvePublicPOD(orderId)
      toast.success('Pengembalian POD berhasil disetujui K-24 (COMPLETED)!')
      setSuccessState('direct')
    } catch (err: any) {
      toast.error(err.response?.data?.message || 'Gagal menyetujui pengembalian POD.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50 dark:bg-slate-950 p-4 text-center">
        <div className="h-8 w-8 rounded-full border-2 border-blue-500 border-t-transparent animate-spin mb-4" />
        <p className="text-sm text-muted-foreground font-medium">Memverifikasi dokumen pesanan...</p>
      </div>
    )
  }

  if (errorMsg) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50 dark:bg-slate-950 p-6 text-center">
        <AlertTriangle className="h-14 w-14 text-red-500 mb-4 animate-pulse" />
        <h1 className="text-xl font-bold text-foreground">Gagal Memverifikasi Dokumen</h1>
        <p className="text-sm text-red-500 mt-2 max-w-md font-medium leading-relaxed bg-red-50 dark:bg-red-950/20 p-4 rounded-xl border border-red-200/50">
          Error: {errorMsg}
        </p>
        <button
          onClick={fetchOrderDetails}
          className="mt-6 px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold text-xs shadow-md transition-all cursor-pointer"
        >
          Coba Lagi
        </button>
      </div>
    )
  }

  if (!order) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50 dark:bg-slate-950 p-6 text-center">
        <AlertTriangle className="h-14 w-14 text-red-500 mb-4 animate-pulse" />
        <h1 className="text-xl font-bold text-foreground">Order Tidak Ditemukan</h1>
        <p className="text-sm text-muted-foreground mt-2 max-w-sm">QR Code atau link yang Anda buka tidak valid atau order telah dihapus.</p>
      </div>
    )
  }

  if (successState) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50 dark:bg-slate-950 p-6 text-center">
        <div className="bg-card w-full max-w-md border border-border rounded-3xl p-8 shadow-2xl space-y-6">
          <div className="flex justify-center">
            {successState === 'direct' ? (
              <div className="h-16 w-16 rounded-full bg-emerald-100 dark:bg-emerald-950/40 text-emerald-600 dark:text-emerald-400 flex items-center justify-center">
                <CheckCircle2 className="h-10 w-10" />
              </div>
            ) : (
              <div className="h-16 w-16 rounded-full bg-amber-100 dark:bg-amber-950/40 text-amber-600 dark:text-amber-400 flex items-center justify-center">
                <Clock className="h-10 w-10 animate-pulse" />
              </div>
            )}
          </div>
          <div>
            <h1 className="text-2xl font-black text-foreground">
              {order.status === 'READY_FOR_PICKUP_FACTURE' || order.status === 'COMPLETED' ? 'Pengembalian POD Disetujui' : 'Unboxing Selesai'}
            </h1>
            <p className="text-sm text-muted-foreground mt-2 leading-relaxed">
              {successState === 'direct' 
                ? 'Terima kasih, verifikasi pengembalian POD & unboxing obat telah disetujui (COMPLETED).' 
                : 'Driver diizinkan melanjutkan perjalanan. Anda dapat membuka kembali halaman ini saat siap melakukan verifikasi faktur.'}
            </p>
          </div>
          <div className="border-t border-border pt-6 text-xs text-muted-foreground">
            Apotek: <strong>{order.pharmacy_name}</strong> • Order ID: <strong>{order.order_number}</strong>
          </div>
        </div>
      </div>
    )
  }

  // ─── K-24 Staff Scan View for READY_FOR_PICKUP_FACTURE (Pengembalian POD) ───
  if (order.status === 'READY_FOR_PICKUP_FACTURE') {
    return (
      <div className="min-h-screen bg-slate-50 dark:bg-slate-950 text-foreground py-10 px-4">
        <div className="max-w-xl mx-auto space-y-6">
          {/* Header Banner */}
          <div className="bg-gradient-to-r from-emerald-600 to-teal-700 rounded-3xl p-6 text-white shadow-xl">
            <div className="flex items-center gap-3 mb-2">
              <CheckCircle2 className="h-6 w-6 text-emerald-200" />
              <span className="text-xs font-bold uppercase tracking-widest text-emerald-200">Verifikasi Pengembalian POD K-24</span>
            </div>
            <h1 className="text-xl font-extrabold">{order.pharmacy_name}</h1>
            <p className="text-xs text-emerald-100 mt-1 leading-relaxed">{order.delivery_address}</p>
            <div className="mt-4 pt-4 border-t border-white/20 flex justify-between items-center text-xs">
              <span>Order ID: <strong>{order.order_number}</strong></span>
              <span className="px-2.5 py-0.5 rounded-full bg-white/25 text-white font-bold uppercase tracking-wider">Pengembalian POD</span>
            </div>
          </div>

          {/* Verification Details Card */}
          <div className="bg-card border border-border rounded-3xl p-6 shadow-sm space-y-6">
            <div>
              <h3 className="font-extrabold text-base text-foreground">Hasil Verifikasi Apoteker</h3>
              <p className="text-xs text-muted-foreground mt-1">Status kelengkapan invoice & foto pertanggungjawaban dari Apoteker.</p>
            </div>

            {/* Invoices Check Result */}
            {order.checked_invoices && (
              <div className="space-y-2 bg-muted/40 p-4 rounded-2xl border border-border">
                <span className="text-xs font-bold text-foreground">Daftar Invoice & Catatan:</span>
                <div className="text-xs space-y-1 font-mono text-muted-foreground">
                  {order.checked_invoices.split('; ').map((item, idx) => (
                    <div key={idx} className={`p-2 rounded-lg font-semibold ${item.includes('MISSING') ? 'bg-red-50 text-red-700 dark:bg-red-950/40' : 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40'}`}>
                      {item}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Apoteker Proof Photo */}
            {order.extra_items_photo_url && (
              <div className="space-y-2">
                <span className="text-xs font-bold text-foreground flex items-center gap-1.5">
                  <Camera className="h-4 w-4 text-blue-600" />
                  Foto Bukti Pertanggungjawaban Apoteker:
                </span>
                <div className="rounded-2xl overflow-hidden border border-border bg-black/5 max-h-64 flex justify-center">
                  <img src={order.extra_items_photo_url} alt="Foto Bukti Apoteker" className="object-contain max-h-64 w-full" />
                </div>
              </div>
            )}

            {/* Facture Photo uploaded by Driver if any */}
            {order.facture_photo_url && (
              <div className="space-y-2">
                <span className="text-xs font-bold text-foreground flex items-center gap-1.5">
                  <FileText className="h-4 w-4 text-indigo-600" />
                  Foto Faktur Fisik Bertanda Tangan (Driver):
                </span>
                <div className="rounded-2xl overflow-hidden border border-border bg-black/5 max-h-64 flex justify-center">
                  <img src={order.facture_photo_url} alt="Foto Faktur Driver" className="object-contain max-h-64 w-full" />
                </div>
              </div>
            )}

            {/* Approve Button DONE */}
            <button
              type="button"
              onClick={handleK24ApprovePOD}
              disabled={submitting}
              className="w-full flex items-center justify-center gap-2 h-14 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-base transition-all disabled:opacity-75 shadow-lg shadow-emerald-500/20 cursor-pointer"
            >
              {submitting ? <Loader2 className="h-6 w-6 animate-spin" /> : <CheckCircle2 className="h-6 w-6" />}
              Setujui & Selesaikan (Done)
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 text-foreground py-10 px-4">
      <div className="max-w-xl mx-auto space-y-6">
        
        {/* Decision Modal Overlay */}
        {showDecisionModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
            <div className="bg-card w-full max-w-md border border-border rounded-3xl p-6 shadow-2xl space-y-6 transform animate-in zoom-in-95 duration-200">
              {!isDelaying ? (
                <>
                  <div className="text-center space-y-3">
                    <div className="mx-auto h-12 w-12 rounded-full bg-blue-100 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 flex items-center justify-center">
                      <ClipboardList className="h-6 w-6" />
                    </div>
                    <h2 className="text-xl font-black text-foreground">Lanjutkan Unboxing Obat?</h2>
                    <p className="text-xs text-muted-foreground leading-relaxed">
                      Apakah Anda ingin langsung memulai verifikasi kesesuaian dokumen obat (unboxing) sekarang, atau menundanya?
                    </p>
                  </div>

                  <div className="grid grid-cols-1 gap-3 pt-2">
                    <button
                      type="button"
                      onClick={handleStartUnboxing}
                      disabled={submitting}
                      className="w-full flex items-center justify-center gap-2 h-11 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-sm transition-all shadow-md shadow-blue-500/10"
                    >
                      {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                      Ya, Mulai Unboxing
                    </button>
                    <button
                      type="button"
                      onClick={() => setIsDelaying(true)}
                      disabled={submitting}
                      className="w-full h-11 rounded-xl bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200 dark:bg-amber-950/20 dark:hover:bg-amber-950/40 dark:text-amber-400 dark:border-amber-900 font-bold text-sm transition-all"
                    >
                      Tunda Unboxing
                    </button>
                  </div>
                </>
              ) : (
                <>
                  <div className="text-center space-y-3">
                    <div className="mx-auto h-12 w-12 rounded-full bg-amber-100 dark:bg-amber-950/40 text-amber-600 dark:text-amber-400 flex items-center justify-center">
                      <Clock className="h-6 w-6 animate-pulse" />
                    </div>
                    <h2 className="text-xl font-black text-foreground">Alasan Menunda Unboxing</h2>
                    <p className="text-xs text-muted-foreground leading-relaxed">
                      Berikan alasan mengapa unboxing ditunda agar driver dapat melanjutkan pengantaran berikutnya.
                    </p>
                  </div>

                  <div className="space-y-4 pt-2">
                    <textarea
                      placeholder="Tulis alasan penundaan (misal: Apoteker sedang sibuk, mati lampu, dll)..."
                      className="w-full h-24 rounded-xl border border-border bg-background p-3 text-xs outline-none resize-none text-foreground"
                      value={delayReason}
                      onChange={(e) => setDelayReason(e.target.value)}
                    />

                    <div className="flex gap-3">
                      <button
                        type="button"
                        onClick={() => setIsDelaying(false)}
                        disabled={submitting}
                        className="flex-1 h-11 rounded-xl border border-border hover:bg-accent text-foreground font-bold text-sm transition-all"
                      >
                        Kembali
                      </button>
                      <button
                        type="button"
                        onClick={handleConfirmDelay}
                        disabled={submitting}
                        className="flex-1 flex items-center justify-center gap-2 h-11 rounded-xl bg-amber-600 hover:bg-amber-700 text-white font-bold text-sm transition-all shadow-md shadow-amber-500/10"
                      >
                        {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                        Simpan & Tunda
                      </button>
                    </div>
                  </div>
                </>
              )}
            </div>
          </div>
        )}

        {/* Multi-Order Tab System */}
        {allOrders && allOrders.length > 1 && (
          <div className="bg-card border border-border rounded-2xl p-3 shadow-sm space-y-2">
            <div className="text-[10px] font-extrabold uppercase tracking-wider text-muted-foreground px-1 flex items-center justify-between">
              <span>Daftar Order Pengantaran ({allOrders.length} Apotek)</span>
              <span className="text-blue-600 font-bold flex items-center gap-1">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-ping" /> Real-Time Sync
              </span>
            </div>
            <div className="flex gap-2 overflow-x-auto pb-1">
              {allOrders.map((ord, idx) => (
                <button
                  key={ord.id}
                  type="button"
                  onClick={() => selectOrderTab(idx)}
                  className={cn(
                    "flex items-center gap-2 px-3.5 py-2 rounded-xl font-bold text-xs whitespace-nowrap transition-all cursor-pointer border",
                    activeTabIndex === idx
                      ? "bg-blue-600 text-white border-blue-600 shadow-md shadow-blue-500/20"
                      : "bg-muted/50 text-foreground border-border hover:bg-accent"
                  )}
                >
                  <span>Order {idx + 1}: {ord.pharmacy_name}</span>
                  {ord.status === 'COMPLETED' ? (
                    <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                  ) : (
                    <span className="text-[10px] bg-white/20 px-1.5 py-0.5 rounded-full">{ord.invoices?.length || 1} Inv</span>
                  )}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Top Header Card */}
        <div className="bg-gradient-to-r from-blue-600 to-indigo-700 rounded-3xl p-6 text-white shadow-xl">
          <div className="flex items-center gap-3 mb-2">
            <ClipboardList className="h-6 w-6 text-blue-200" />
            <span className="text-xs font-bold uppercase tracking-widest text-blue-200">Portal Verifikasi Apotek</span>
          </div>
          <h1 className="text-xl font-extrabold">{order.pharmacy_name}</h1>
          <p className="text-xs text-blue-100 mt-1 leading-relaxed">{order.delivery_address}</p>
          <div className="mt-4 pt-4 border-t border-white/20 flex justify-between items-center text-xs">
            <span>Nomor Dokumen: <strong>{order.order_number}</strong></span>
            <span className="px-2.5 py-0.5 rounded-full bg-white/25 text-white font-bold uppercase tracking-wider">{order.status}</span>
          </div>
        </div>

        {/* Main Checklist Card */}
        <div className="bg-card border border-border rounded-3xl p-6 shadow-sm space-y-6">
          <div>
            <h3 className="font-extrabold text-base text-foreground">Kesesuaian Invoice / Faktur</h3>
            <p className="text-xs text-muted-foreground mt-1">Cocokkan nomor invoice obat fisik dengan daftar di bawah ini.</p>
          </div>

          <div className="space-y-4">
            {invoices.map((inv) => {
              const status = invoiceStatuses[inv] || 'done'
              return (
                <div key={inv} className="border border-border rounded-2xl p-4 bg-background space-y-3.5">
                  <div className="flex items-center justify-between gap-3 flex-wrap">
                    <div className="flex items-center gap-2">
                      <FileText className="h-4 w-4 text-blue-500" />
                      <span className="text-sm font-bold text-foreground">{inv}</span>
                    </div>
                    
                    {/* Done / Missing Buttons */}
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => setInvoiceStatuses(p => ({ ...p, [inv]: 'done' }))}
                        className={cn(
                          "h-8 px-3 rounded-lg text-xs font-bold transition-all border",
                          status === 'done'
                            ? "bg-emerald-50 text-emerald-700 border-emerald-200"
                            : "bg-background text-muted-foreground border-border hover:bg-accent"
                        )}
                      >
                        Sesuai (Done)
                      </button>
                      <button
                        type="button"
                        onClick={() => setInvoiceStatuses(p => ({ ...p, [inv]: 'missing' }))}
                        className={cn(
                          "h-8 px-3 rounded-lg text-xs font-bold transition-all border",
                          status === 'missing'
                            ? "bg-red-50 text-red-700 border-red-200"
                            : "bg-background text-muted-foreground border-border hover:bg-accent"
                        )}
                      >
                        Tidak Sesuai (Missing)
                      </button>
                    </div>
                  </div>

                  {status === 'missing' && (
                    <div className="space-y-1.5 pt-2 border-t border-dashed border-border animate-in slide-in-from-top-1 duration-150">
                      <label className="text-[11px] font-bold text-red-500">Catatan Masalah / Keterangan Kehilangan (Wajib)</label>
                      <input
                        type="text"
                        placeholder="Contoh: Barang kurang 2 box paracetamol..."
                        className="h-9 w-full rounded-lg border border-red-200 bg-red-50/20 px-3 text-xs outline-none text-foreground"
                        value={missingNotes[inv] || ''}
                        onChange={(e) => setMissingNotes(p => ({ ...p, [inv]: e.target.value }))}
                      />
                    </div>
                  )}
                </div>
              )
            })}
          </div>

          {/* Extra Items Section */}
          <div className="border-t border-border pt-6 space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="font-bold text-sm text-foreground">Ada barang tanpa invoice?</h4>
                <p className="text-xs text-muted-foreground mt-0.5">Centang jika terdapat obat masuk tanpa dokumen faktur.</p>
              </div>
              <input
                type="checkbox"
                checked={hasExtraItems}
                onChange={(e) => setHasExtraItems(e.target.checked)}
                className="h-5 w-5 rounded border-border accent-blue-600 cursor-pointer"
              />
            </div>

            {hasExtraItems && (
              <div className="space-y-4 p-4 rounded-2xl border border-dashed border-blue-300 bg-blue-50/10 animate-in slide-in-from-top-2 duration-200">
                <div className="space-y-1.5">
                  <label className="text-xs font-bold text-foreground">Catatan Barang Tambahan (Wajib)</label>
                  <textarea
                    placeholder="Tuliskan nama obat, kuantitas, dan detail lainnya..."
                    className="w-full h-20 rounded-lg border border-border bg-background p-3 text-xs outline-none resize-none text-foreground"
                    value={extraItemsNote}
                    onChange={(e) => setExtraItemsNote(e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <label className="text-xs font-bold text-foreground">Foto Barang Bukti (Wajib)</label>
                  <div className="flex gap-4 items-center">
                    <label className="flex flex-col items-center justify-center h-20 w-20 rounded-xl border border-dashed border-border bg-background cursor-pointer hover:bg-accent transition-colors">
                      <Camera className="h-5 w-5 text-muted-foreground" />
                      <span className="text-[10px] text-muted-foreground mt-1 font-semibold">Upload</span>
                      <input type="file" accept="image/*" className="hidden" onChange={handlePhotoUpload} />
                    </label>
                    
                    {extraItemsPhoto && (
                      <div className="relative h-20 w-20 rounded-xl overflow-hidden border border-border">
                        <img src={extraItemsPhoto} alt="Barang tambahan" className="h-full w-full object-cover" />
                        <button
                          type="button"
                          onClick={() => setExtraItemsPhoto('')}
                          className="absolute top-1 right-1 h-5 w-5 rounded-full bg-red-500 text-white flex items-center justify-center text-xs"
                        >
                          ×
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Mandatory Apoteker Photo Verification Section */}
          <div className="border-t border-border pt-6 space-y-3">
            <div>
              <h4 className="font-bold text-sm text-foreground flex items-center gap-1.5">
                <Camera className="h-4 w-4 text-blue-600 dark:text-blue-400" />
                <span>Foto Bukti Verifikasi Apoteker</span>
                <span className="text-red-500 font-extrabold text-xs">*Wajib</span>
              </h4>
              <p className="text-xs text-muted-foreground mt-0.5">
                Unggah foto bukti fisik pemeriksaan obat/invoice oleh Apoteker sebagai pertanggungjawaban legalitas unboxing.
              </p>
            </div>

            <div className="flex gap-4 items-center pt-1">
              <label className="flex flex-col items-center justify-center h-24 w-full sm:w-40 rounded-2xl border-2 border-dashed border-blue-300 dark:border-blue-800 bg-blue-50/20 dark:bg-blue-950/20 cursor-pointer hover:bg-blue-100/30 transition-all text-center p-3">
                <Camera className="h-6 w-6 text-blue-600 dark:text-blue-400 mb-1" />
                <span className="text-xs text-blue-600 dark:text-blue-400 font-bold">Ambil / Upload Foto</span>
                <span className="text-[9px] text-muted-foreground mt-0.5">Bukti Fisik Faktur</span>
                <input type="file" accept="image/*" className="hidden" onChange={handleProofPhotoUpload} />
              </label>

              {proofPhoto ? (
                <div className="relative h-24 w-32 rounded-2xl overflow-hidden border-2 border-emerald-500 shadow-sm shrink-0">
                  <img src={proofPhoto} alt="Bukti Verifikasi Apoteker" className="h-full w-full object-cover" />
                  <span className="absolute bottom-1 left-1 bg-emerald-600 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-md">
                    ✓ Ter-upload
                  </span>
                  <button
                    type="button"
                    onClick={() => setProofPhoto('')}
                    className="absolute top-1 right-1 h-6 w-6 rounded-full bg-red-600 text-white flex items-center justify-center text-xs font-bold shadow-xs hover:bg-red-700"
                  >
                    ×
                  </button>
                </div>
              ) : (
                <div className="text-xs text-red-500 bg-red-50 dark:bg-red-950/20 border border-red-200 dark:border-red-900/40 p-3 rounded-xl flex-1 font-medium leading-snug">
                  ⚠️ Foto bukti verifikasi wajib diunggah sebelum dapat menyelesaikan proses unboxing.
                </div>
              )}
            </div>
          </div>

          {/* Action button */}
          <button
            onClick={handleSubmitUnboxing}
            disabled={submitting}
            className="w-full flex items-center justify-center gap-2 h-12 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-sm transition-all disabled:opacity-75 shadow-lg shadow-blue-500/10"
          >
            {submitting ? <Loader2 className="h-5 w-5 animate-spin" /> : <CheckCircle2 className="h-5 w-5" />}
            Selesaikan Unboxing (Done)
          </button>
        </div>
      </div>
    </div>
  )
}
