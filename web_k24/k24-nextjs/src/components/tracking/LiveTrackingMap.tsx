'use client'

import { useEffect, useRef, useState } from 'react'
import 'leaflet/dist/leaflet.css'

export interface TrackingDriver {
  id: number
  name: string
  phone: string
  plate_number: string
  vehicle_type: string
  is_active: boolean
  current_lat: number
  current_lng: number
  last_location_update: string
  last_updated_seconds_ago: number
}

export interface TrackingStop {
  order_id: number
  order_number: string
  sequence_number: number
  customer_name: string
  customer_phone: string
  delivery_address: string
  lat: number
  lng: number
  status: string
  invoices: string[]
}

interface LiveTrackingMapProps {
  driver: TrackingDriver
  pharmacyName: string
  pharmacyAddress: string
  pharmacyLat: number
  pharmacyLng: number
  stops: TrackingStop[]
}

// Fetch actual street road geometry via OpenStreetMap OSRM Routing Engine with timeout
async function fetchOSRMRoute(waypoints: [number, number][]): Promise<[number, number][]> {
  if (waypoints.length < 2) return waypoints
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), 3500)
  try {
    const coordsStr = waypoints.map(([lat, lng]) => `${lng},${lat}`).join(';')
    const url = `https://router.project-osrm.org/route/v1/driving/${coordsStr}?overview=full&geometries=geojson`
    const res = await fetch(url, { signal: controller.signal })
    clearTimeout(timeoutId)
    const data = await res.json()
    if (data.routes && data.routes.length > 0 && data.routes[0].geometry) {
      const geoCoords: [number, number][] = data.routes[0].geometry.coordinates
      // Convert OSRM GeoJSON [lng, lat] to Leaflet [lat, lng]
      return geoCoords.map(([lng, lat]) => [lat, lng])
    }
  } catch (err) {
    clearTimeout(timeoutId)
    console.warn('[OSRM Route Fetch Timeout/Error, using fallback straight path]:', err)
  }
  return waypoints
}

export default function LiveTrackingMap({
  driver,
  pharmacyName,
  pharmacyAddress,
  pharmacyLat,
  pharmacyLng,
  stops,
}: LiveTrackingMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<any>(null)
  const markersGroupRef = useRef<any>(null)
  const [isRoutingLoading, setIsRoutingLoading] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined' || !mapContainerRef.current) return

    let isMounted = true

    // Import Leaflet dynamically client-side only
    import('leaflet').then(async (L) => {
      if (!isMounted) return

      // Fix default Leaflet marker icon paths
      delete (L.Icon.Default.prototype as any)._getIconUrl
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
        iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
        shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
      })

      // Initialize map instance once
      if (!mapInstanceRef.current) {
        const container = mapContainerRef.current
        if (!container) return

        const initialLat = driver.current_lat || pharmacyLat || -6.2019957
        const initialLng = driver.current_lng || pharmacyLng || 106.8551888

        const map = L.map(container, {
          center: [initialLat, initialLng],
          zoom: 13,
          zoomControl: true,
        })

        // Free OpenStreetMap CartoDB Voyager tiles
        L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
          maxZoom: 19,
        }).addTo(map)

        const layerGroup = L.layerGroup().addTo(map)
        markersGroupRef.current = layerGroup
        mapInstanceRef.current = map
      }

      const map = mapInstanceRef.current
      const layerGroup = markersGroupRef.current
      layerGroup.clearLayers()

      const latLngBounds: [number, number][] = []

      // 1. Pharmacy Pickup Marker
      if (pharmacyLat && pharmacyLng && pharmacyLat !== 0) {
        const pharmacyIcon = L.divIcon({
          className: 'custom-pharmacy-marker',
          html: `<div style="background-color: #10b981; color: white; width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 18px; border: 3px solid white; box-shadow: 0 4px 12px rgba(16,185,129,0.4);">🏥</div>`,
          iconSize: [36, 36],
          iconAnchor: [18, 18],
        })

        const pharMarker = L.marker([pharmacyLat, pharmacyLng], { icon: pharmacyIcon })
        pharMarker.bindPopup(`
          <div style="font-family: sans-serif; padding: 4px;">
            <strong style="color: #059669; font-size: 13px;">🏥 ${pharmacyName || 'Apotek Pickup'}</strong><br/>
            <span style="font-size: 11px; color: #4b5563;">${pharmacyAddress}</span><br/>
            <span style="font-size: 10px; background: #ecfdf5; color: #047857; padding: 2px 6px; border-radius: 4px; display: inline-block; margin-top: 4px; font-weight: bold;">Titik Penjemputan Paket</span>
          </div>
        `)
        layerGroup.addLayer(pharMarker)
        latLngBounds.push([pharmacyLat, pharmacyLng])
      }

      // 2. Collect waypoints for OSRM routing
      const waypoints: [number, number][] = []
      if (pharmacyLat && pharmacyLng && pharmacyLat !== 0) {
        waypoints.push([pharmacyLat, pharmacyLng])
      }

      stops.forEach((stop) => {
        if (!stop.lat || !stop.lng || stop.lat === 0) return

        let stopBgColor = '#64748b' // Slate for pending
        let statusBadge = '<span style="background:#f1f5f9; color:#475569; padding:2px 6px; border-radius:4px; font-size:10px;">Menunggu</span>'

        if (stop.status === 'COMPLETED') {
          stopBgColor = '#10b981' // Green
          statusBadge = '<span style="background:#ecfdf5; color:#047857; padding:2px 6px; border-radius:4px; font-size:10px; font-weight:bold;">Selesai Terantar</span>'
        } else if (stop.status === 'DELIVERING' || stop.status === 'PICKING_UP' || stop.status === 'WAITING_FOR_PICKUP') {
          stopBgColor = '#2563eb' // Blue
          statusBadge = '<span style="background:#eff6ff; color:#1d4ed8; padding:2px 6px; border-radius:4px; font-size:10px; font-weight:bold;">Sedang Diantar</span>'
        }

        const stopIcon = L.divIcon({
          className: 'custom-stop-marker',
          html: `<div style="background-color: ${stopBgColor}; color: white; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 14px; border: 2.5px solid white; box-shadow: 0 4px 10px rgba(0,0,0,0.25);">${stop.sequence_number || '!'}</div>`,
          iconSize: [32, 32],
          iconAnchor: [16, 16],
        })

        const stopMarker = L.marker([stop.lat, stop.lng], { icon: stopIcon })
        const invoicesText = stop.invoices && stop.invoices.length > 0 ? stop.invoices.join(', ') : '-'

        stopMarker.bindPopup(`
          <div style="font-family: sans-serif; padding: 4px; max-width: 220px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
              <strong style="font-size: 13px; color: #1e293b;">Titik #${stop.sequence_number}: ${stop.customer_name}</strong>
            </div>
            <p style="font-size: 11px; color: #64748b; margin: 2px 0 6px 0;">${stop.delivery_address}</p>
            <div style="font-size: 10px; color: #334155; background: #f8fafc; padding: 4px; border-radius: 4px; margin-bottom: 6px;">
              <strong>Faktur:</strong> ${invoicesText}
            </div>
            ${statusBadge}
          </div>
        `)
        layerGroup.addLayer(stopMarker)
        latLngBounds.push([stop.lat, stop.lng])
        waypoints.push([stop.lat, stop.lng])
      })

      // 3. Fetch OSRM Road Geometry & Draw Solid Road Polyline
      if (waypoints.length > 1) {
        setIsRoutingLoading(true)
        let roadPolylineCoords: [number, number][] = waypoints
        try {
          roadPolylineCoords = await fetchOSRMRoute(waypoints)
        } finally {
          if (isMounted) setIsRoutingLoading(false)
        }
        if (!isMounted) return

        // Outer glow path
        const outerGlow = L.polyline(roadPolylineCoords, {
          color: '#3b82f6',
          weight: 8,
          opacity: 0.35,
          lineCap: 'round',
          lineJoin: 'round',
        })
        layerGroup.addLayer(outerGlow)

        // Inner solid road path
        const roadPath = L.polyline(roadPolylineCoords, {
          color: '#2563eb',
          weight: 4.5,
          opacity: 0.9,
          lineCap: 'round',
          lineJoin: 'round',
        })
        layerGroup.addLayer(roadPath)

        // 4. Position Live Driver Marker ONLY when driver has active GPS or is actively delivering
        const isDeliveringOrCompleted = stops.some((s) => s.status === 'DELIVERING' || s.status === 'PICKING_UP' || s.status === 'COMPLETED')
        const isWaitingPickup = !isDeliveringOrCompleted

        let driverLat = driver.current_lat
        let driverLng = driver.current_lng

        // When waiting for pickup: only display driver marker if driver has actual real-time GPS coordinates
        // Do NOT force driver marker onto pharmacy or delivery route
        if (isWaitingPickup) {
          if (!driverLat || !driverLng || driverLat === 0) {
            // Driver hasn't picked up yet and has no active GPS coordinate: do not render marker on map
            driverLat = 0
            driverLng = 0
          }
        } else if ((!driverLat || !driverLng || driverLat === 0) && roadPolylineCoords.length > 0) {
          // Fallback during active delivery if GPS coordinate is zero
          const midIdx = Math.floor(roadPolylineCoords.length / 3)
          driverLat = roadPolylineCoords[midIdx][0]
          driverLng = roadPolylineCoords[midIdx][1]
        }

        if (driverLat && driverLng && driverLat !== 0) {
          const vehicleEmoji = driver.vehicle_type === 'mobil' ? '🚗' : '🏍️'
          const bgGradient = isWaitingPickup
            ? 'linear-gradient(135deg, #d97706, #b45309)'
            : 'linear-gradient(135deg, #2563eb, #1d4ed8)'
          const ringColor = isWaitingPickup ? 'rgba(217, 119, 6, 0.25)' : 'rgba(37, 99, 235, 0.25)'
          const dotColor = isWaitingPickup ? 'rgba(245, 158, 11, 0.4)' : 'rgba(59, 130, 246, 0.4)'
          const statusText = isWaitingPickup
            ? '🟡 Driver Belum Pickup (Menuju Apotek)'
            : '🟢 Sedang Mengantar Paket (Live)'

          const driverIcon = L.divIcon({
            className: 'custom-driver-marker-live',
            html: `
              <div style="position: relative; width: 56px; height: 56px; display: flex; align-items: center; justify-content: center;">
                <div style="position: absolute; width: 56px; height: 56px; background: ${ringColor}; border-radius: 50%; animation: pulse-ring 1.8s cubic-bezier(0.215, 0.61, 0.355, 1) infinite;"></div>
                <div style="position: absolute; width: 40px; height: 40px; background: ${dotColor}; border-radius: 50%; animation: pulse-dot 1.8s cubic-bezier(0.455, 0.03, 0.515, 0.955) -.4s infinite;"></div>
                <div style="background: ${bgGradient}; color: white; width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 20px; border: 3px solid white; box-shadow: 0 8px 20px rgba(0,0,0,0.3); z-index: 10; transition: transform 0.5s ease;">
                  ${vehicleEmoji}
                </div>
                <div style="position: absolute; bottom: -18px; white-space: nowrap; background: #0f172a; color: white; padding: 2px 6px; border-radius: 6px; font-size: 10px; font-weight: bold; border: 1px solid rgba(255,255,255,0.3); shadow: 0 4px 8px rgba(0,0,0,0.3);">
                  Driver ${driver.name.split(' ')[0]}
                </div>
              </div>
            `,
            iconSize: [56, 56],
            iconAnchor: [28, 28],
          })

          const driverMarker = L.marker([driverLat, driverLng], { icon: driverIcon, zIndexOffset: 2000 })
          const updatedText = driver.last_updated_seconds_ago < 60
            ? `${driver.last_updated_seconds_ago || 5} detik lalu`
            : `${Math.floor(driver.last_updated_seconds_ago / 60)} menit lalu`

          driverMarker.bindPopup(`
            <div style="font-family: sans-serif; padding: 6px; min-width: 200px;">
              <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
                <div style="background: #eff6ff; color: #2563eb; width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 16px;">
                  ${vehicleEmoji}
                </div>
                <div>
                  <strong style="font-size: 13px; color: #0f172a; display: block;">${driver.name}</strong>
                  <span style="font-size: 10px; color: #64748b; font-family: monospace; font-weight: bold;">${driver.plate_number || 'Plat Kendaraan'}</span>
                </div>
              </div>
              <div style="font-size: 11px; color: #334155; border-top: 1px solid #e2e8f0; padding-top: 6px; margin-top: 4px;">
                <span><strong>Status:</strong> ${statusText}</span><br/>
                <span><strong>Update GPS:</strong> ${updatedText}</span>
              </div>
            </div>
          `)
          layerGroup.addLayer(driverMarker)
          latLngBounds.push([driverLat, driverLng])
        }
      }

      // Auto-fit bounds if we have coordinates
      if (latLngBounds.length > 0) {
        map.fitBounds(latLngBounds, { padding: [50, 50], maxZoom: 16 })
      }
    })

    return () => {
      isMounted = false
    }
  }, [driver, pharmacyLat, pharmacyLng, pharmacyName, pharmacyAddress, stops])

  const isWaitingPickup = !stops.some((s) => s.status === 'DELIVERING' || s.status === 'PICKING_UP' || s.status === 'COMPLETED')

  return (
    <div className="relative w-full h-[520px] rounded-2xl overflow-hidden border border-border shadow-md bg-card">
      {isWaitingPickup && (
        <div className="absolute top-4 left-14 z-10 bg-amber-600/95 text-white backdrop-blur-xs border border-amber-500 px-3.5 py-1.5 rounded-full shadow-md flex items-center gap-2 text-xs font-bold animate-in fade-in">
          <span className="h-2 w-2 rounded-full bg-white animate-pulse" />
          <span>Menunggu Driver Mengambil Paket (Belum di-Pickup)</span>
        </div>
      )}
      {isRoutingLoading && (
        <div className="absolute top-4 right-4 z-10 bg-background/90 backdrop-blur-xs border border-border px-3 py-1.5 rounded-full shadow-md flex items-center gap-2 text-xs font-semibold text-foreground animate-in fade-in">
          <div className="h-3 w-3 rounded-full border-2 border-blue-600 border-t-transparent animate-spin" />
          <span>Memuat rute jalan raya (OSRM)...</span>
        </div>
      )}
      <div ref={mapContainerRef} className="w-full h-full z-0" />
      <style jsx global>{`
        @keyframes pulse-ring {
          0% { transform: scale(0.6); opacity: 0.9; }
          100% { transform: scale(1.6); opacity: 0; }
        }
        @keyframes pulse-dot {
          0% { transform: scale(0.8); opacity: 0.8; }
          50% { transform: scale(1.15); opacity: 1; }
          100% { transform: scale(0.8); opacity: 0.8; }
        }
      `}</style>
    </div>
  )
}
