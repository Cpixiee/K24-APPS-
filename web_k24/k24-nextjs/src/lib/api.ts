// API Service — connects to K-24 Go backend at port 8087
import axios from 'axios'

const BASE_URL = process.env.NEXT_PUBLIC_API_URL || ''

// Client-side axios instance (uses localStorage token, for client components)
export const apiClient = axios.create({
  baseURL: `${BASE_URL}/api`,
  timeout: 60000,
  headers: { 'Content-Type': 'application/json' },
})

// Attach JWT token automatically on every request
apiClient.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('k24_token')
    if (token) config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Handle 401 globally
apiClient.interceptors.response.use(
  (res) => res,
  (err) => {
    if (
      err.response?.status === 401 &&
      typeof window !== 'undefined' &&
      window.location.pathname !== '/login'
    ) {
      localStorage.removeItem('k24_token')
      localStorage.removeItem('k24_user')
      localStorage.removeItem('k24_login_time')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

// ===== Auth =====
export const authAPI = {
  login: (email: string, password: string) =>
    apiClient.post('/auth/login', { email, password }),
}

// ===== Admin & Mitra Actions =====
export const adminAPI = {
  getStats: () => apiClient.get('/admin/stats'),
  getDrivers: () => apiClient.get('/admin/drivers'),
  getDriverDocument: (id: number, type: string) => apiClient.get(`/admin/drivers/${id}/document?type=${type}`),
  getMitra: () => apiClient.get('/admin/mitra'),
  createMitra: (data: unknown) => apiClient.post('/admin/mitra', data),
  impersonateMitra: (mitraId: number) => apiClient.post(`/admin/mitra/${mitraId}/impersonate`),
  createOrder: (data: unknown) => apiClient.post('/admin/orders', data),
  getMitraProfile: () => apiClient.get('/admin/mitra/profile'),
  getRecipients: () => apiClient.get('/admin/recipients'),
  calculateOrderPrice: (data: unknown) => apiClient.post('/admin/orders/calculate', data),
  createBulkOrders: (data: unknown) => apiClient.post('/admin/orders/bulk', data),
  getOrders: () => apiClient.get('/admin/orders'),
  getFlatInvoices: (date?: string) => apiClient.get(`/admin/orders/invoices-flat${date ? `?date=${date}` : ''}`),
  getOrderDetail: (dispatchId: string | number) => apiClient.get(`/admin/orders/${dispatchId}`),
  deleteOrder: (id: string | number) => apiClient.delete(`/admin/orders/${id}`),
  approveDriver: (id: number) => apiClient.post(`/admin/drivers/${id}/approve`),
  rejectDriver: (id: number) => apiClient.post(`/admin/drivers/${id}/reject`),
  updateDriver: (id: number, data: { name: string; phone?: string; email?: string; vehicle_type?: string; plate_number?: string }) =>
    apiClient.put(`/admin/drivers/${id}`, data),
  suspendDriver: (id: number, durationDays: number, reason: string) =>
    apiClient.post(`/admin/drivers/${id}/suspend`, { duration_days: durationDays, reason }),
  unsuspendDriver: (id: number) =>
    apiClient.post(`/admin/drivers/${id}/unsuspend`),
  deleteDriver: (id: number) =>
    apiClient.delete(`/admin/drivers/${id}`),
  approveRejectOrder: (id: number, approve: boolean) => apiClient.post(`/admin/orders/${id}/approve-reject`, { approve }),
  approveFacture: (id: number | string, approve: boolean) => apiClient.post(`/admin/orders/${id}/approve-facture`, { approve }),
  getPendingDispatchOrders: () => apiClient.get('/admin/dispatch/orders'),
  getDispatchDrivers: (vehicleType: string) => apiClient.get(`/admin/dispatch/drivers?vehicle_type=${vehicleType}`),
  createDispatchGroup: (data: unknown) => apiClient.post('/admin/dispatch', data),
  cancelDriverAssignment: (dispatchId: string | number) => apiClient.post(`/admin/dispatch/${dispatchId}/cancel`),
  getDispatchLiveTracking: (dispatchId: string | number) => apiClient.get(`/admin/dispatch/${dispatchId}/live-track`),
  
  // Public Pharmacist & Client workflows
  getPublicOrderDetail: (id: string | number) => apiClient.get(`/public/orders/${id}`),
  getPublicDispatchLiveTracking: (dispatchId: string | number) => apiClient.get(`/public/dispatch/${dispatchId}/live-track`),
  startUnboxOrder: (id: string | number) => apiClient.post(`/public/orders/${id}/start-unbox`),
  unboxOrder: (id: string | number, data: { checked_invoices: string; extra_items_note?: string; extra_items_photo_url?: string }) =>
    apiClient.post(`/public/orders/${id}/unbox`, data),
  waitUnboxOrder: (id: string | number, reason: string) =>
    apiClient.post(`/public/orders/${id}/wait-unbox`, { reason }),
  approvePublicPOD: (id: string | number) => apiClient.post(`/public/orders/${id}/approve-pod`),
}

// ===== Notifications =====
export const notificationsAPI = {
  getNotifications: () => apiClient.get('/notifications'),
  markRead: () => apiClient.post('/notifications/read'),
}

// ===== Health =====
export const healthAPI = {
  check: () => apiClient.get('/health'),
}
