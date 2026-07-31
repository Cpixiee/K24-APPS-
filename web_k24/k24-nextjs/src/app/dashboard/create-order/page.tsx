'use client'

import { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import { useRouter } from 'next/navigation'
import DashboardShell from '@/components/layout/DashboardShell'
import { adminAPI } from '@/lib/api'
import { toast } from 'sonner'
import { ArrowLeft, ArrowRight, Plus, Trash2, Upload, Search, Loader2, CheckCircle, HelpCircle, X, Check } from 'lucide-react'
import { cn } from '@/lib/utils'
import * as XLSX from 'xlsx'

const INITIAL_ROW = () => ({
  id: Date.now() + Math.random(),
  nama_apotek: '', alamat_lengkap: '',
  latitude: 0, longitude: 0,
  invoices: [] as string[], kubik_aktual: '', berat_aktual: '',
})

type OrderRow = ReturnType<typeof INITIAL_ROW>

interface MitraProfile {
  motor_km?: number; motor_titik?: number; motor_dimensi?: number; motor_berat?: number
  mobil_km?: number; mobil_titik?: number; mobil_dimensi?: number; mobil_berat?: number; mobil_lumpsum?: number
}

interface Recipient {
  nama_apotek: string; alamat_lengkap: string; latitude?: number; longitude?: number
}

interface PreviewItem {
  nama_apotek: string; price?: number; jarak_km?: number; warning?: string
}

const inputClass = 'h-10 w-full rounded-lg border border-border bg-background px-3 text-sm outline-none transition-all focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 text-foreground'

export default function CreateOrderPage() {
  const router = useRouter()
  const [step, setStep] = useState(1)
  const [selectedArmada, setSelectedArmada] = useState<'motor' | 'mobil'>('motor')
  const [selectedRate, setSelectedRate] = useState('km')
  const [inputMethod, setInputMethod] = useState<'manual' | 'csv'>('manual')
  const [mitraProfile, setMitraProfile] = useState<MitraProfile | null>(null)
  const [recipients, setRecipients] = useState<Recipient[]>([])
  const [rows, setRows] = useState<OrderRow[]>([INITIAL_ROW()])
  const [preview, setPreview] = useState<{ items: PreviewItem[]; total_price: number } | null>(null)
  const [invoiceInput, setInvoiceInput] = useState<Record<number, string>>({})
  const [submitting, setSubmitting] = useState(false)

  // Autocomplete popup states
  const [activeLookupRowId, setActiveLookupRowId] = useState<number | null>(null)
  const [lookupQuery, setLookupQuery] = useState('')
  const [isManualInput, setIsManualInput] = useState(false)
  const [manualName, setManualName] = useState('')
  const [manualAddress, setManualAddress] = useState('')

  const fetchProfile = useCallback(async () => {
    try {
      const res = await adminAPI.getMitraProfile()
      const p = res.data.data || res.data
      setMitraProfile(p)
    } catch { toast.error('Gagal memuat profil konfigurasi tarif') }
  }, [])

  const fetchRecipients = useCallback(async () => {
    try {
      const res = await adminAPI.getRecipients()
      setRecipients(res.data.data || res.data || [])
    } catch { /* silent */ }
  }, [])

  useEffect(() => { fetchProfile(); fetchRecipients() }, [fetchProfile, fetchRecipients])

  // Filter rate configurations: only show rates that are configured (val > 0)
  const motorRates = useMemo(() => {
    if (!mitraProfile) return []
    return [
      { key: 'km', label: 'Skema KM', val: mitraProfile.motor_km, unit: '/km' },
      { key: 'titik', label: 'Skema Titik', val: mitraProfile.motor_titik, unit: '/titik' },
      { key: 'dimensi', label: 'Skema Dimensi', val: mitraProfile.motor_dimensi, unit: '/dm³' },
      { key: 'berat', label: 'Skema Berat', val: mitraProfile.motor_berat, unit: '/kg' },
    ].filter((r) => r.val != null && r.val > 0)
  }, [mitraProfile])

  const mobilRates = useMemo(() => {
    if (!mitraProfile) return []
    return [
      { key: 'km', label: 'Skema KM', val: mitraProfile.mobil_km, unit: '/km' },
      { key: 'titik', label: 'Skema Titik', val: mitraProfile.mobil_titik, unit: '/titik' },
      { key: 'dimensi', label: 'Skema Dimensi', val: mitraProfile.mobil_dimensi, unit: '/dm³' },
      { key: 'berat', label: 'Skema Berat', val: mitraProfile.mobil_berat, unit: '/kg' },
      { key: 'lumpsum', label: 'Skema Lumpsum', val: mitraProfile.mobil_lumpsum, unit: '/unit' },
    ].filter((r) => r.val != null && r.val > 0)
  }, [mitraProfile])

  // Auto-switch rate when armada changes
  useEffect(() => {
    const rates = selectedArmada === 'motor' ? motorRates : mobilRates
    if (rates.length > 0) {
      if (!rates.some((r) => r.key === selectedRate)) {
        setSelectedRate(rates[0].key)
      }
    }
  }, [selectedArmada, motorRates, mobilRates, selectedRate])

  const calcPreview = useCallback(async (currentRows: OrderRow[]) => {
    const valid = currentRows.filter((r) => r.nama_apotek.trim() && r.alamat_lengkap.trim())
    if (!valid.length) { setPreview(null); return }
    try {
      const res = await adminAPI.calculateOrderPrice({
        armada: selectedArmada, rate_type: selectedRate,
        items: valid.map((r) => ({
          nama_apotek: r.nama_apotek, alamat_lengkap: r.alamat_lengkap,
          kubik_aktual: r.kubik_aktual !== '' ? parseFloat(r.kubik_aktual) : null,
          berat_aktual: r.berat_aktual !== '' ? parseFloat(r.berat_aktual) : null,
          jumlah_invoice: r.invoices.length,
        }))
      })
      setPreview(res.data.data || res.data)
    } catch { /* silent */ }
  }, [selectedArmada, selectedRate])

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    calcPreview(rows)
  }, [selectedArmada, selectedRate, calcPreview])

  const updateRow = (id: number, field: keyof OrderRow, val: unknown) => {
    const updated = rows.map((r) => r.id === id ? { ...r, [field]: val } : r)
    setRows(updated)
    if (['nama_apotek', 'alamat_lengkap', 'kubik_aktual', 'berat_aktual'].includes(field as string)) calcPreview(updated)
  }

  const handleSelectRecipient = (rowId: number, recName: string, recAddress: string, recLat = 0, recLng = 0) => {
    const updated = rows.map((r) => r.id === rowId ? {
      ...r, nama_apotek: recName, alamat_lengkap: recAddress,
      latitude: recLat, longitude: recLng
    } : r)
    setRows(updated)
    calcPreview(updated)
    setActiveLookupRowId(null)
  }

  const removeRow = (id: number) => {
    if (rows.length === 1) { toast.warning('Minimal wajib terdapat 1 baris order.'); return }
    const updated = rows.filter((r) => r.id !== id)
    setRows(updated); calcPreview(updated)
  }

  const parseCSVLine = (text: string): string[] => {
    const result: string[] = []
    let cell = ''
    let inQuotes = false
    for (let i = 0; i < text.length; i++) {
      const char = text[i]
      if (char === '"') {
        if (inQuotes && text[i + 1] === '"') {
          cell += '"'
          i++
        } else {
          inQuotes = !inQuotes
        }
      } else if ((char === ',' || char === ';') && !inQuotes) {
        result.push(cell.trim())
        cell = ''
      } else {
        cell += char
      }
    }
    result.push(cell.trim())
    return result
  }

  const handleFileImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (evt) => {
      try {
        const data = new Uint8Array(evt.target?.result as ArrayBuffer)
        const workbook = XLSX.read(data, { type: 'array' })

        // Automatically pick Sheet 1 (first sheet/page)
        const firstSheetName = workbook.SheetNames[0]
        const worksheet = workbook.Sheets[firstSheetName]

        // Convert worksheet to 2D array of rows
        const rowsData = XLSX.utils.sheet_to_json<Array<string | number | undefined>>(worksheet, { header: 1 })

        // 1. Locate Table Header Row (containing "Nama Apotek" or "ALAMAT")
        let headerRowIndex = -1
        let namaColIdx = -1
        let alamatColIdx = -1
        let invoiceStartColIdx = -1

        for (let r = 0; r < Math.min(15, rowsData.length); r++) {
          const row = rowsData[r]
          if (!row) continue
          for (let c = 0; c < row.length; c++) {
            const cellText = String(row[c] ?? '').trim().toLowerCase()
            if (cellText.includes('nama apotek') || cellText.includes('penerima')) {
              headerRowIndex = r
              namaColIdx = c
            } else if (cellText.includes('alamat')) {
              headerRowIndex = r
              alamatColIdx = c
            } else if (cellText.includes('invoice')) {
              headerRowIndex = r
              if (invoiceStartColIdx === -1) invoiceStartColIdx = c
            }
          }
          if (namaColIdx !== -1 && alamatColIdx !== -1) break
        }

        // Fallbacks if table header is flat (simple CSV)
        if (namaColIdx === -1) namaColIdx = 0
        if (alamatColIdx === -1) alamatColIdx = 1
        if (invoiceStartColIdx === -1) invoiceStartColIdx = 2
        const startDataRow = headerRowIndex !== -1 ? headerRowIndex + 1 : 0

        const parsedMap: Map<string, OrderRow> = new Map()
        let currentItem: OrderRow | null = null

        // 2. Iterate data rows starting after header row
        for (let i = startDataRow; i < rowsData.length; i++) {
          const row = rowsData[i]
          if (!row || row.length === 0) continue

          const rawNama = String(row[namaColIdx] ?? '').trim()
          const rawAlamat = String(row[alamatColIdx] ?? '').trim()

          // Filter out title headers or non-order rows
          const lowerNama = rawNama.toLowerCase()
          if (
            lowerNama.includes('hari, tanggal') ||
            lowerNama.includes('waktu pickup') ||
            lowerNama.includes('form serah terima') ||
            lowerNama.includes('delivery') ||
            lowerNama.includes('armada') ||
            lowerNama.includes('nama apotek')
          ) {
            continue
          }

          // Check if this row defines a NEW Apotek entry
          const isNewApotek = rawNama.length > 0 && (
            rawNama.toUpperCase().startsWith('K-24') ||
            rawNama.toUpperCase().startsWith('APOTEK') ||
            rawNama.toUpperCase().startsWith('K24') ||
            rawAlamat.length > 0
          )

          if (isNewApotek) {
            // Save previous item if valid
            if (currentItem && (currentItem.nama_apotek || currentItem.alamat_lengkap)) {
              const key = `${currentItem.nama_apotek}_${currentItem.alamat_lengkap}`
              if (!parsedMap.has(key)) {
                parsedMap.set(key, currentItem)
              } else {
                const existing = parsedMap.get(key)!
                for (const inv of currentItem.invoices) {
                  if (!existing.invoices.includes(inv)) existing.invoices.push(inv)
                }
              }
            }

            currentItem = {
              id: Date.now() + i + Math.random(),
              nama_apotek: rawNama,
              alamat_lengkap: rawAlamat,
              invoices: [],
              kubik_aktual: '',
              berat_aktual: '',
              latitude: 0,
              longitude: 0,
            }
          }

          // Extract all invoice numbers across invoice columns
          if (currentItem) {
            if (!currentItem.alamat_lengkap && rawAlamat) {
              currentItem.alamat_lengkap = rawAlamat
            }

            for (let c = invoiceStartColIdx; c < row.length; c++) {
              const cellVal = String(row[c] ?? '').trim()
              if (!cellVal) continue

              const lowerCell = cellVal.toLowerCase()

              // Handle "BARANG SUSULAN" specifically
              if (lowerCell.includes('barang susulan') || lowerCell.includes('susulan')) {
                const invTag = 'BARANG SUSULAN'
                if (!currentItem.invoices.includes(invTag)) {
                  currentItem.invoices.push(invTag)
                }
                continue
              }

              if (
                lowerCell.includes('faktur') ||
                lowerCell.includes('revisi') ||
                lowerCell.includes('jumlah') ||
                lowerCell.includes('total') ||
                lowerCell.includes('mobil') ||
                lowerCell.includes('motor')
              ) {
                continue
              }

              const tokens = cellVal.split(/[\s,;]+/)
              for (const token of tokens) {
                const cleanToken = token.replace(/^"|"$/g, '').trim()
                if (cleanToken && /^\d{4,10}$|^INV-?/i.test(cleanToken)) {
                  const formattedInv = cleanToken.toUpperCase().startsWith('INV-')
                    ? cleanToken.toUpperCase()
                    : `INV-${cleanToken}`
                  if (!currentItem.invoices.includes(formattedInv)) {
                    currentItem.invoices.push(formattedInv)
                  }
                }
              }
            }
          }
        }

        // Save last item
        if (currentItem && (currentItem.nama_apotek || currentItem.alamat_lengkap)) {
          const key = `${currentItem.nama_apotek}_${currentItem.alamat_lengkap}`
          if (!parsedMap.has(key)) {
            parsedMap.set(key, currentItem)
          } else {
            const existing = parsedMap.get(key)!
            for (const inv of currentItem.invoices) {
              if (!existing.invoices.includes(inv)) existing.invoices.push(inv)
            }
          }
        }

        const parsed = Array.from(parsedMap.values())

        if (parsed.length > 0) {
          setRows(parsed)
          toast.success(`Berhasil mengimpor ${parsed.length} titik apotek dari ${file.name}!`)
          calcPreview(parsed)
          setStep(3)
        } else {
          toast.error('Format file tidak dapat dikenali. Pastikan tabel memiliki kolom Nama Apotek dan Alamat.')
        }
      } catch (err) {
        console.error('Error parsing file:', err)
        toast.error(`Gagal membaca file ${file.name}. Pastikan format file Excel (.xlsx/.xls) atau CSV benar.`)
      }
    }
    reader.readAsArrayBuffer(file)
  }

  // Ref guard: prevents double-submit even if state update hasn't re-rendered yet
  const isSubmittingRef = useRef(false)

  const handleSubmit = async () => {
    if (isSubmittingRef.current) return   // <-- block second click immediately
    const empty = rows.filter((r) => !r.nama_apotek.trim() || !r.alamat_lengkap.trim())
    if (empty.length > 0) { toast.error('Mohon lengkapi Nama Apotek dan Alamat untuk seluruh baris.'); return }
    isSubmittingRef.current = true
    setSubmitting(true)
    try {
      await adminAPI.createBulkOrders({
        armada: selectedArmada, rate_type: selectedRate,
        items: rows.map((r) => ({
          nama_apotek: r.nama_apotek, alamat_lengkap: r.alamat_lengkap,
          latitude: r.latitude || 0, longitude: r.longitude || 0,
          kubik_aktual: r.kubik_aktual !== '' ? parseFloat(r.kubik_aktual) : null,
          berat_aktual: r.berat_aktual !== '' ? parseFloat(r.berat_aktual) : null,
          invoices: r.invoices,
        }))
      })
      toast.success('Order berhasil didaftarkan!')
      setStep(1); setRows([INITIAL_ROW()]); setPreview(null); setInvoiceInput({})
      router.push('/dashboard/orders')
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string } } }
      toast.error(axiosErr.response?.data?.message || 'Gagal mengirim order')
    } finally {
      isSubmittingRef.current = false
      setSubmitting(false)
    }
  }

  const formatRp = (n?: number) => n != null ? `Rp ${n.toLocaleString('id-ID')}` : '-'
  const totalEstimated = preview?.total_price

  // Search filter for popup search apotek
  const filteredRecipients = useMemo(() => {
    if (!lookupQuery) return recipients.slice(0, 10)
    const q = lookupQuery.toLowerCase()
    return recipients.filter((r) =>
      r.nama_apotek?.toLowerCase().includes(q) ||
      r.alamat_lengkap?.toLowerCase().includes(q)
    )
  }, [recipients, lookupQuery])

  return (
    <DashboardShell>
      {/* Centered Stepper Header Layout */}
      <div className="relative flex flex-col md:flex-row items-center justify-between gap-4 mb-8 pb-4 border-b border-border">
        {/* Left Side: Back & Title */}
        <div className="flex items-center gap-3 w-full md:w-auto">
          <button
            onClick={() => step > 1 ? setStep(step - 1) : router.push('/dashboard/orders')}
            className="flex items-center justify-center h-9 w-9 rounded-lg border border-border text-sm font-medium hover:bg-accent transition-colors shrink-0 text-foreground"
            title="Kembali"
          >
            <ArrowLeft className="h-4 w-4" />
          </button>
          <div className="min-w-0">
            <h1 className="text-lg font-bold leading-tight text-foreground">Buat Order Pengiriman</h1>
            <p className="text-xs text-muted-foreground">Langkah {step} dari 3</p>
          </div>
        </div>

        {/* Center: Stepper */}
        <div className="md:absolute md:left-1/2 md:-translate-x-1/2 flex items-center justify-center gap-2 my-2 md:my-0">
          {['Armada & Rate', 'Metode Input', 'Form Order'].map((label, i) => (
            <div key={i} className="flex items-center gap-2">
              <div className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold transition-all ${
                step > i + 1
                  ? 'bg-emerald-600 text-white shadow-sm'
                  : step === i + 1
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-500/25 ring-2 ring-blue-500/20'
                    : 'bg-muted text-muted-foreground'
              }`}>
                {step > i + 1 ? '✓' : i + 1}
              </div>
              <span className={`text-xs hidden sm:block font-medium ${step === i + 1 ? 'text-foreground font-semibold' : 'text-muted-foreground'}`}>{label}</span>
              {i < 2 && <div className={`w-8 h-px ${step > i + 1 ? 'bg-emerald-600' : 'bg-border'}`} />}
            </div>
          ))}
        </div>

        {/* Right Side: Action Button */}
        <div className="w-full md:w-auto flex justify-end">
          {step < 3 ? (
            <button
              onClick={() => {
                const rates = selectedArmada === 'motor' ? motorRates : mobilRates
                if (rates.length === 0) {
                  toast.error(`Tidak ada skema tarif aktif untuk armada ${selectedArmada}.`)
                  return
                }
                setStep(step + 1)
              }}
              className="flex items-center gap-2 h-10 px-5 rounded-lg border border-border bg-card text-foreground text-sm font-medium hover:bg-accent transition-all shadow-sm w-full md:w-auto justify-center"
            >
              Lanjut <ArrowRight className="h-4 w-4 text-muted-foreground" />
            </button>
          ) : (
            <button
              onClick={handleSubmit}
              disabled={submitting}
              className="flex items-center gap-2 h-10 px-5 rounded-lg bg-gradient-to-r from-emerald-600 to-teal-600 text-white text-sm font-medium hover:from-emerald-700 hover:to-teal-700 transition-all disabled:opacity-70 w-full md:w-auto justify-center"
            >
              {submitting ? <><Loader2 className="h-4 w-4 animate-spin" /> Menyimpan...</> : <><CheckCircle className="h-4 w-4" /> Submit Order</>}
            </button>
          )}
        </div>
      </div>

      {/* ─── STEP 1: Pilih Armada & Rate ─── */}
      {step === 1 && (
        <div className="space-y-6">
          <div className="text-center max-w-xl mx-auto mb-4">
            <h2 className="text-xl font-extrabold text-foreground">Pilih Armada & Skema Tarif</h2>
            <p className="text-sm text-muted-foreground mt-1">Pilih jenis kendaraan dan skema tarif untuk order ini. Hanya skema tarif aktif yang ditampilkan.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl mx-auto">
            {/* Motor Card */}
            <div
              onClick={() => {
                if (motorRates.length > 0) setSelectedArmada('motor')
              }}
              className={cn(
                "rounded-3xl border-2 p-6 flex flex-col justify-between transition-all duration-300",
                motorRates.length === 0
                  ? "opacity-50 cursor-not-allowed border-border bg-muted/40"
                  : selectedArmada === 'motor'
                    ? "border-blue-500 bg-blue-50/20 dark:bg-blue-950/10 shadow-lg shadow-blue-500/5 cursor-pointer"
                    : "border-border bg-card hover:border-blue-500/40 hover:shadow-md cursor-pointer"
              )}
            >
              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="h-14 w-14 rounded-2xl bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center text-3xl select-none shadow-sm">
                    🏍️
                  </div>
                  <div>
                    <h3 className="font-extrabold text-lg text-foreground">Motor / Roda Dua</h3>
                    <p className="text-xs text-muted-foreground">Pengiriman cepat, hemat, volume kecil</p>
                  </div>
                </div>

                <div className="space-y-2.5">
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground/80 mb-3">Skema Tarif Aktif</p>
                  {motorRates.length > 0 ? (
                    motorRates.map((r) => (
                      <div
                        key={r.key}
                        onClick={(e) => {
                          e.stopPropagation()
                          setSelectedArmada('motor')
                          setSelectedRate(r.key)
                        }}
                        className={cn(
                          "flex items-center justify-between p-3.5 rounded-xl border transition-all duration-200 cursor-pointer",
                          selectedArmada === 'motor' && selectedRate === r.key
                            ? "border-blue-500 bg-background shadow-sm"
                            : "border-border bg-background/50 hover:border-blue-300"
                        )}
                      >
                        <span className="text-sm font-semibold text-foreground">{r.label}</span>
                        <span className="text-sm font-extrabold text-blue-600 dark:text-blue-400">
                          {formatRp(r.val)} <span className="text-xs font-normal text-muted-foreground">{r.unit}</span>
                        </span>
                      </div>
                    ))
                  ) : (
                    <div className="text-center py-8 text-xs text-muted-foreground border border-dashed border-border rounded-xl">
                      Tidak ada skema tarif aktif untuk Motor.
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Mobil Card */}
            <div
              onClick={() => {
                if (mobilRates.length > 0) setSelectedArmada('mobil')
              }}
              className={cn(
                "rounded-3xl border-2 p-6 flex flex-col justify-between transition-all duration-300",
                mobilRates.length === 0
                  ? "opacity-50 cursor-not-allowed border-border bg-muted/40"
                  : selectedArmada === 'mobil'
                    ? "border-blue-500 bg-blue-50/20 dark:bg-blue-950/10 shadow-lg shadow-blue-500/5 cursor-pointer"
                    : "border-border bg-card hover:border-blue-500/40 hover:shadow-md cursor-pointer"
              )}
            >
              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="h-14 w-14 rounded-2xl bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center text-3xl select-none shadow-sm">
                    🚚
                  </div>
                  <div>
                    <h3 className="font-extrabold text-lg text-foreground">Mobil / Roda Empat</h3>
                    <p className="text-xs text-muted-foreground">Kapasitas muat besar & aman cuaca buruk</p>
                  </div>
                </div>

                <div className="space-y-2.5">
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground/80 mb-3">Skema Tarif Aktif</p>
                  {mobilRates.length > 0 ? (
                    mobilRates.map((r) => (
                      <div
                        key={r.key}
                        onClick={(e) => {
                          e.stopPropagation()
                          setSelectedArmada('mobil')
                          setSelectedRate(r.key)
                        }}
                        className={cn(
                          "flex items-center justify-between p-3.5 rounded-xl border transition-all duration-200 cursor-pointer",
                          selectedArmada === 'mobil' && selectedRate === r.key
                            ? "border-blue-500 bg-background shadow-sm"
                            : "border-border bg-background/50 hover:border-blue-300"
                        )}
                      >
                        <span className="text-sm font-semibold text-foreground">{r.label}</span>
                        <span className="text-sm font-extrabold text-blue-600 dark:text-blue-400">
                          {formatRp(r.val)} <span className="text-xs font-normal text-muted-foreground">{r.unit}</span>
                        </span>
                      </div>
                    ))
                  ) : (
                    <div className="text-center py-8 text-xs text-muted-foreground border border-dashed border-border rounded-xl">
                      Tidak ada skema tarif aktif untuk Mobil.
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ─── STEP 2: Metode Input ─── */}
      {step === 2 && (
        <div className="flex flex-col items-center justify-center py-12">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl w-full">
            {[
              { key: 'manual', label: 'Input Manual', icon: '⌨️', desc: 'Isi data pengiriman satu per satu menggunakan form tabel dengan lookup database apotek.' },
              { key: 'csv', label: 'Upload Excel / CSV', icon: '📊', desc: 'Upload file Excel (.xlsx, .xls) atau CSV untuk mengimpor banyak data pengiriman sekaligus.' },
            ].map((m) => {
              const isSelected = inputMethod === m.key
              let displayClass = ''
              if (isSelected) {
                if (m.key === 'manual') {
                  displayClass = 'border-blue-500 bg-blue-50/50 dark:bg-blue-950/10 shadow-lg shadow-blue-500/10'
                } else {
                  displayClass = 'border-amber-500 bg-amber-50/50 dark:bg-amber-950/10 shadow-lg shadow-amber-500/10'
                }
              } else {
                if (m.key === 'manual') {
                  displayClass = 'border-border bg-card hover:border-blue-500/40 hover:shadow-md'
                } else {
                  displayClass = 'border-border bg-card hover:border-amber-500/40 hover:shadow-md'
                }
              }

              return (
                <div
                  key={m.key}
                  onClick={() => setInputMethod(m.key as 'manual' | 'csv')}
                  className={`rounded-3xl border-2 p-8 md:p-10 cursor-pointer transition-all duration-300 min-h-[240px] flex flex-col justify-between ${displayClass}`}
                >
                  <div className="flex flex-col items-center text-center h-full justify-center">
                    <div className="text-5xl md:text-6xl mb-6 select-none">{m.icon}</div>
                    <h3 className="font-bold text-xl md:text-2xl mb-3 text-foreground">{m.label}</h3>
                    <p className="text-sm md:text-base text-muted-foreground leading-relaxed">{m.desc}</p>
                  </div>
                </div>
              )
            })}
            {inputMethod === 'csv' && (
              <div className="md:col-span-2 mt-2 space-y-3">
                <label className="flex flex-col items-center justify-center gap-3 h-36 rounded-2xl border-2 border-dashed border-amber-500/50 bg-amber-50/30 dark:bg-amber-950/10 cursor-pointer hover:bg-amber-50/50 transition-all text-amber-600 dark:text-amber-500">
                  <Upload className="h-8 w-8 text-amber-500" />
                  <span className="text-sm text-muted-foreground font-medium">Klik untuk upload file Excel (.xlsx / .xls) atau CSV</span>
                  <input type="file" accept=".csv, .xlsx, .xls" className="hidden" onChange={handleFileImport} />
                </label>
                <div className="flex flex-col sm:flex-row items-center justify-between gap-2 px-2">
                  <p className="text-xs text-muted-foreground">Format Kolom: Nama Apotek, Alamat, Invoice1;Invoice2, Kubik, Berat</p>
                  <a
                    href="/sample_order_k24.csv"
                    download="sample_order_k24.csv"
                    className="inline-flex items-center gap-1.5 text-xs font-semibold text-amber-600 hover:text-amber-700 hover:underline"
                  >
                    <span>📥 Download File Contoh Format</span>
                  </a>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ─── STEP 3: Form Data Order ─── */}
      {step === 3 && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="font-semibold text-foreground">Data Pengiriman</h2>
              <p className="text-xs text-muted-foreground">Armada: <strong>{selectedArmada.toUpperCase()}</strong> — Rate: <strong>{selectedRate.toUpperCase()}</strong> — {rows.length} titik pengiriman</p>
            </div>
            <button onClick={() => setRows((p) => [...p, INITIAL_ROW()])}
              className="flex items-center gap-2 h-9 px-3 rounded-lg border border-border bg-card hover:bg-accent text-sm font-medium transition-colors shadow-sm text-foreground">
              <Plus className="h-4 w-4" /> Tambah Baris
            </button>
          </div>

          {/* Horizontal scrollable table layout for form order */}
          <div className="rounded-2xl border border-border bg-card shadow-sm overflow-hidden mb-6">
            <div className="overflow-x-auto dashboard-scroll">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-left">
                    <th className="px-3 py-3 text-center text-xs font-semibold uppercase tracking-wider text-muted-foreground w-12">#</th>
                    <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground min-w-[220px]">Nama Apotek Penerima</th>
                    <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground min-w-[280px]">Alamat Lengkap</th>
                    {selectedRate === 'dimensi' && <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground w-36">Kubik (dm³)</th>}
                    {selectedRate === 'berat' && <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground w-36">Berat (kg)</th>}
                    <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground min-w-[260px]">No. Invoice</th>
                    <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground min-w-[130px]">Estimasi</th>
                    <th className="px-3 py-3 text-center text-xs font-semibold w-12"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {rows.map((row, idx) => {
                    const previewItem = preview?.items?.find((p) => p.nama_apotek === row.nama_apotek)
                    return (
                      <tr key={row.id} className="hover:bg-muted/10 transition-colors">
                        {/* Number */}
                        <td className="px-3 py-4 text-center align-top">
                          <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-blue-50 text-blue-600 font-bold text-xs">
                            {idx + 1}
                          </span>
                        </td>

                        {/* Pharmacy Name */}
                        <td className="px-4 py-4 align-top">
                          <div className="flex items-center gap-2">
                            <button
                              type="button"
                              onClick={() => {
                                setActiveLookupRowId(row.id)
                                setLookupQuery('')
                                setIsManualInput(false)
                                setManualName(row.nama_apotek)
                                setManualAddress(row.alamat_lengkap)
                              }}
                              className={cn(
                                "flex items-center justify-between h-10 w-full px-3 text-sm rounded-lg border text-left outline-none hover:bg-accent/40 transition-all truncate",
                                row.nama_apotek ? "border-border text-foreground font-medium bg-background" : "border-dashed border-blue-300 text-blue-600 bg-background"
                              )}
                            >
                              <span className="truncate">{row.nama_apotek || 'Cari / Pilih Apotek'}</span>
                              <Search className="h-4 w-4 shrink-0 text-muted-foreground ml-2" />
                            </button>
                          </div>
                        </td>

                        {/* Complete Address */}
                        <td className="px-4 py-4 align-top">
                          <input
                            type="text"
                            disabled
                            placeholder="Alamat lengkap akan terisi setelah memilih apotek"
                            className="h-10 w-full rounded-lg border border-border bg-muted/30 px-3 text-xs outline-none truncate text-foreground"
                            value={row.alamat_lengkap}
                          />
                        </td>

                        {/* Kubik */}
                        {selectedRate === 'dimensi' && (
                          <td className="px-4 py-4 align-top">
                            <input
                              type="number"
                              placeholder="Optional"
                              className={inputClass}
                              value={row.kubik_aktual}
                              onChange={(e) => updateRow(row.id, 'kubik_aktual', e.target.value)}
                            />
                          </td>
                        )}

                        {/* Berat */}
                        {selectedRate === 'berat' && (
                          <td className="px-4 py-4 align-top">
                            <input
                              type="number"
                              placeholder="Optional"
                              className={inputClass}
                              value={row.berat_aktual}
                              onChange={(e) => updateRow(row.id, 'berat_aktual', e.target.value)}
                            />
                          </td>
                        )}

                        {/* Invoices */}
                        <td className="px-4 py-4 align-top">
                          <div className="flex flex-col gap-1.5">
                            <input
                              type="text"
                              placeholder="Invoice (Enter)"
                              className="h-8 w-full rounded-lg border border-border bg-background px-2.5 text-xs outline-none text-foreground"
                              value={invoiceInput[row.id] || ''}
                              onChange={(e) => setInvoiceInput((p) => ({ ...p, [row.id]: e.target.value }))}
                              onKeyDown={(e) => {
                                  if (e.key === 'Enter') {
                                    e.preventDefault()
                                    const val = invoiceInput[row.id]?.trim()
                                    if (val) {
                                      updateRow(row.id, 'invoices', [...row.invoices, val])
                                      setInvoiceInput((p) => ({ ...p, [row.id]: '' }))
                                    }
                                  }
                                }}
                            />
                            {row.invoices.length > 0 && (
                              <div className="flex flex-wrap gap-1 max-h-16 overflow-y-auto pt-1">
                                {row.invoices.map((inv, i) => (
                                  <span key={i} className="inline-flex items-center gap-1 rounded-full bg-blue-50 border border-blue-200 px-2 py-0.5 text-[10px] font-semibold text-blue-700 dark:bg-blue-950/20 dark:text-blue-400">
                                    {inv}
                                    <button
                                      type="button"
                                      onClick={() => updateRow(row.id, 'invoices', row.invoices.filter((_, j) => j !== i))}
                                      className="ml-0.5 text-blue-500 hover:text-red-500 text-xs"
                                    >
                                      ×
                                    </button>
                                  </span>
                                ))}
                              </div>
                            )}
                          </div>
                        </td>

                        {/* Estimation */}
                        <td className="px-4 py-4 text-xs font-semibold align-top">
                          {previewItem ? (
                            <div className="flex flex-col">
                              {/* Price hidden per user request */}
                              {selectedRate === 'km' && previewItem.jarak_km && (
                                <span className="text-[10px] text-muted-foreground font-normal">{previewItem.jarak_km.toFixed(1)} km</span>
                              )}
                              {selectedRate === 'titik' && (
                                <span className="text-[10px] text-muted-foreground font-normal">1 titik</span>
                              )}
                              {selectedRate === 'dimensi' && row.kubik_aktual && (
                                <span className="text-[10px] text-muted-foreground font-normal">{row.kubik_aktual} dm³</span>
                              )}
                              {selectedRate === 'berat' && row.berat_aktual && (
                                <span className="text-[10px] text-muted-foreground font-normal">{row.berat_aktual} kg</span>
                              )}
                            </div>
                          ) : (
                            <span className="text-muted-foreground font-normal italic">—</span>
                          )}
                        </td>

                        {/* Delete Row Button */}
                        <td className="px-3 py-4 text-center align-top">
                          <button
                            type="button"
                            onClick={() => removeRow(row.id)}
                            className="flex h-8 w-8 items-center justify-center rounded-lg text-muted-foreground hover:bg-red-50 hover:text-red-600 transition-colors"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ─── MODAL DIALOG: Pharmacy Database Search / Manual Input ─── */}
      {activeLookupRowId !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="relative w-full max-w-lg rounded-2xl border border-border bg-card p-6 shadow-2xl animate-fade-in flex flex-col max-h-[90vh]">
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-3 border-b border-border mb-4">
              <div>
                <h3 className="font-bold text-base text-foreground">Cari / Input Penerima</h3>
                <p className="text-xs text-muted-foreground">Pilih dari database K-24 atau ketik baru (auto-save).</p>
              </div>
              <button
                onClick={() => setActiveLookupRowId(null)}
                className="h-8 w-8 rounded-lg flex items-center justify-center hover:bg-accent text-muted-foreground hover:text-foreground border border-border"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Mode Selector */}
            <div className="grid grid-cols-2 gap-2 p-1 bg-muted rounded-lg mb-4">
              <button
                type="button"
                onClick={() => setIsManualInput(false)}
                className={cn(
                  "py-1.5 text-xs font-semibold rounded-md transition-all",
                  !isManualInput ? "bg-background text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground"
                )}
              >
                Pilih dari Database
              </button>
              <button
                type="button"
                onClick={() => {
                  setIsManualInput(true)
                  if (!manualName && !manualAddress) {
                    setManualName(lookupQuery)
                  }
                }}
                className={cn(
                  "py-1.5 text-xs font-semibold rounded-md transition-all",
                  isManualInput ? "bg-background text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground"
                )}
              >
                Isi Mandiri / Manual
              </button>
            </div>

            {/* Mode 1: Database Lookup */}
            {!isManualInput ? (
              <div className="flex-1 flex flex-col min-h-0">
                <div className="relative mb-3 shrink-0">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <input
                    type="text"
                    className="h-10 w-full rounded-lg border border-border bg-background pl-9 pr-8 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 text-foreground"
                    placeholder="Masukkan nama apotek atau alamat..."
                    value={lookupQuery}
                    onChange={(e) => setLookupQuery(e.target.value)}
                    autoFocus
                  />
                  {lookupQuery && (
                    <button
                      onClick={() => setLookupQuery('')}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-muted-foreground hover:text-foreground"
                    >
                      Clear
                    </button>
                  )}
                </div>

                <div className="flex-1 overflow-y-auto dashboard-scroll space-y-1 pr-1">
                  {filteredRecipients.length > 0 ? (
                    filteredRecipients.map((rec, i) => (
                      <button
                        key={i}
                        type="button"
                        onClick={() => handleSelectRecipient(activeLookupRowId, rec.nama_apotek, rec.alamat_lengkap, rec.latitude, rec.longitude)}
                        className="w-full text-left p-3 rounded-xl border border-transparent hover:border-blue-500/20 hover:bg-blue-50/20 transition-all flex items-start justify-between"
                      >
                        <div className="min-w-0 pr-3">
                          <p className="text-sm font-semibold truncate text-foreground">{rec.nama_apotek}</p>
                          <p className="text-xs text-muted-foreground truncate mt-0.5">{rec.alamat_lengkap}</p>
                        </div>
                        <Check className="h-4 w-4 text-blue-600 opacity-0 group-hover:opacity-100 shrink-0" />
                      </button>
                    ))
                  ) : (
                    <div className="flex flex-col items-center py-6 text-center">
                      <HelpCircle className="h-8 w-8 text-muted-foreground/30 mb-2" />
                      <p className="text-sm text-muted-foreground">Tidak ditemukan di database.</p>
                      <button
                        type="button"
                        onClick={() => {
                          setIsManualInput(true)
                          setManualName(lookupQuery)
                        }}
                        className="text-xs text-blue-600 font-semibold hover:underline mt-2"
                      >
                        Klik untuk Isi Mandiri & Save Baru
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              /* Mode 2: Manual input form */
              <div className="space-y-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-muted-foreground">Nama Apotek Baru</label>
                  <input
                    type="text"
                    className={inputClass}
                    placeholder="Masukkan nama apotek baru..."
                    value={manualName}
                    onChange={(e) => setManualName(e.target.value)}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-muted-foreground">Alamat Lengkap</label>
                  <textarea
                    className="w-full rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 h-24 resize-none text-foreground"
                    placeholder="Masukkan alamat lengkap pengiriman..."
                    value={manualAddress}
                    onChange={(e) => setManualAddress(e.target.value)}
                  />
                </div>
                <div className="flex justify-end pt-2 border-t border-border">
                  <button
                    type="button"
                    onClick={() => {
                      if (!manualName.trim() || !manualAddress.trim()) {
                        toast.error('Nama apotek dan alamat lengkap wajib diisi.')
                        return
                      }
                      handleSelectRecipient(activeLookupRowId, manualName, manualAddress)
                    }}
                    className="flex items-center justify-center gap-2 h-10 px-5 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold transition-all shadow-md shadow-blue-500/10"
                  >
                    <Check className="h-4 w-4" /> Gunakan & Simpan
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </DashboardShell>
  )
}
