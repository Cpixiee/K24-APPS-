'use client'

import { useEffect, useRef } from 'react'
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

  useEffect(() => {
    if (typeof window === 'undefined' || !mapContainerRef.current) return

    // Import Leaflet dynamically client-side only
    import('leaflet').then((L) => {
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

        const initialLat = driver.current_lat || pharmacyLat || -7.782889
        const initialLng = driver.current_lng || pharmacyLng || 110.377042

        const map = L.map(container, {
          center: [initialLat, initialLng],
          zoom: 14,
          zoomControl: true,
        })

        // Free OpenStreetMap CartoDB Positron tiles (Sleek, modern, 0 API cost)
        L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
          maxZoom: 19,
        }).addTo(map)

        const layerGroup = L.layerGroup().addTo(map)
        markersGroupRef.current = layerGroup
        mapInstanceRef.current = map
      }

      // Refresh markers & polyline path
      const map = mapInstanceRef.current
      const layerGroup = markersGroupRef.current
      layerGroup.clearLayers()

      const latLngBounds: [number, number][] = []

      // 1. Pharmacy Pickup Marker
      if (pharmacyLat && pharmacyLng && pharmacyLat !== 0) {
        const pharmacyIcon = L.divIcon({
          className: 'custom-pharmacy-marker',
          html: `<div style="background-color: #10b981; color: white; width: 34px; height: 34px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 16px; border: 2px solid white; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">🏥</div>`,
          iconSize: [34, 34],
          iconAnchor: [17, 17],
        })

        const pharMarker = L.marker([pharmacyLat, pharmacyLng], { icon: pharmacyIcon })
        pharMarker.bindPopup(`
          <div style="font-family: sans-serif; padding: 4px;">
            <strong style="color: #059669; font-size: 13px;">🏥 ${pharmacyName || 'Apotek Pickup'}</strong><br/>
            <span style="font-size: 11px; color: #4b5563;">${pharmacyAddress}</span><br/>
            <span style="font-size: 10px; background: #ecfdf5; color: #047857; padding: 2px 6px; border-radius: 4px; display: inline-block; margin-top: 4px;">Lokasi Pengambilan Order</span>
          </div>
        `)
        layerGroup.addLayer(pharMarker)
        latLngBounds.push([pharmacyLat, pharmacyLng])
      }

      // 2. Sequential Destination Stop Markers (1..10)
      const routePoints: [number, number][] = []
      if (pharmacyLat && pharmacyLng && pharmacyLat !== 0) {
        routePoints.push([pharmacyLat, pharmacyLng])
      }

      stops.forEach((stop) => {
        if (!stop.lat || !stop.lng || stop.lat === 0) return

        let stopBgColor = '#64748b' // Slate for pending
        let statusBadge = '<span style="background:#f1f5f9; color:#475569; padding:2px 6px; border-radius:4px; font-size:10px;">Menunggu</span>'

        if (stop.status === 'COMPLETED') {
          stopBgColor = '#10b981' // Green
          statusBadge = '<span style="background:#ecfdf5; color:#047857; padding:2px 6px; border-radius:4px; font-size:10px;">Selesai Terantar</span>'
        } else if (stop.status === 'DELIVERING' || stop.status === 'PICKING_UP' || stop.status === 'WAITING_FOR_PICKUP') {
          stopBgColor = '#2563eb' // Blue
          statusBadge = '<span style="background:#eff6ff; color:#1d4ed8; padding:2px 6px; border-radius:4px; font-size:10px; font-weight:bold;">Sedang Diantar</span>'
        }

        const stopIcon = L.divIcon({
          className: 'custom-stop-marker',
          html: `<div style="background-color: ${stopBgColor}; color: white; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 13px; border: 2px solid white; box-shadow: 0 4px 8px rgba(0,0,0,0.25);">${stop.sequence_number || '!'}</div>`,
          iconSize: [30, 30],
          iconAnchor: [15, 15],
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
        routePoints.push([stop.lat, stop.lng])
      })

      // 3. Draw Polyline Route connecting Pharmacy to Sequential Stops
      if (routePoints.length > 1) {
        const polyline = L.polyline(routePoints, {
          color: '#3b82f6',
          weight: 4,
          opacity: 0.7,
          dashArray: '8, 8',
        })
        layerGroup.addLayer(polyline)
      }

      // 4. Driver Live Position Marker (with animated pulsing radar)
      if (driver.current_lat && driver.current_lng && driver.current_lat !== 0) {
        const vehicleEmoji = driver.vehicle_type === 'mobil' ? '🚗' : '🏍️'
        const driverIcon = L.divIcon({
          className: 'custom-driver-marker',
          html: `
            <div style="position: relative; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center;">
              <div style="position: absolute; width: 44px; height: 44px; background: rgba(37, 99, 235, 0.25); border-radius: 50%; animation: pulse 2s infinite;"></div>
              <div style="background: linear-gradient(135deg, #2563eb, #1d4ed8); color: white; width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 18px; border: 2.5px solid white; box-shadow: 0 6px 14px rgba(37, 99, 235, 0.5); z-index: 10;">
                ${vehicleEmoji}
              </div>
            </div>
          `,
          iconSize: [44, 44],
          iconAnchor: [22, 22],
        })

        const driverMarker = L.marker([driver.current_lat, driver.current_lng], { icon: driverIcon, zIndexOffset: 1000 })
        const updatedText = driver.last_updated_seconds_ago < 60
          ? `${driver.last_updated_seconds_ago} detik lalu`
          : `${Math.floor(driver.last_updated_seconds_ago / 60)} menit lalu`

        driverMarker.bindPopup(`
          <div style="font-family: sans-serif; padding: 4px; min-width: 180px;">
            <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
              <div style="background: #eff6ff; color: #2563eb; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold;">
                ${vehicleEmoji}
              </div>
              <div>
                <strong style="font-size: 13px; color: #0f172a; display: block;">${driver.name}</strong>
                <span style="font-size: 10px; color: #64748b; font-family: monospace;">${driver.plate_number || 'No Plat'}</span>
              </div>
            </div>
            <div style="font-size: 11px; color: #334155; border-t: 1px solid #e2e8f0; padding-top: 4px; margin-top: 4px;">
              <span><strong>Status:</strong> ${driver.is_active ? '🟢 Online' : '⚪ Offline'}</span><br/>
              <span><strong>Update GPS:</strong> ${updatedText}</span>
            </div>
          </div>
        `)
        layerGroup.addLayer(driverMarker)
        latLngBounds.push([driver.current_lat, driver.current_lng])
      }

      // Auto-fit bounds if we have coordinates
      if (latLngBounds.length > 0) {
        map.fitBounds(latLngBounds, { padding: [40, 40], maxZoom: 16 })
      }
    })
  }, [driver, pharmacyLat, pharmacyLng, pharmacyName, pharmacyAddress, stops])

  return (
    <div className="relative w-full h-[500px] rounded-2xl overflow-hidden border border-border shadow-md">
      <div ref={mapContainerRef} className="w-full h-full z-0" />
      <style jsx global>{`
        @keyframes pulse {
          0% { transform: scale(0.8); opacity: 0.8; }
          100% { transform: scale(1.6); opacity: 0; }
        }
      `}</style>
    </div>
  )
}
