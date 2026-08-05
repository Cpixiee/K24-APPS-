// API Service — connects to K-24 Go backend at port 8087
import axios from 'axios'

const BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8087'

// Client-side axios instance (uses localStorage token, for client components)
export const apiClient = axios.create({
  baseURL: '/api',
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
  getMitra: () => apiClient.get('/admin/mitra'),
  createMitra: (data: unknown) => apiClient.post('/admin/mitra', data),
  createOrder: (data: unknown) => apiClient.post('/admin/orders', data),
  getMitraProfile: () => apiClient.get('/admin/mitra/profile'),
  getRecipients: () => apiClient.get('/admin/recipients'),
  calculateOrderPrice: (data: unknown) => apiClient.post('/admin/orders/calculate', data),
  createBulkOrders: (data: unknown) => apiClient.post('/admin/orders/bulk', data),
  getOrders: () => apiClient.get('/admin/orders'),
  getFlatInvoices: (date?: string) => apiClient.get(`/admin/orders/invoices-flat${date ? `?date=${date}` : ''}`),
  getOrderDetail: (dispatchId: string | number) => apiClient.get(`/admin/orders/${dispatchId}`),
  approveDriver: (id: number) => apiClient.post(`/admin/drivers/${id}/approve`),
  rejectDriver: (id: number) => apiClient.post(`/admin/drivers/${id}/reject`),
  approveRejectOrder: (id: number, approve: boolean) => apiClient.post(`/admin/orders/${id}/approve-reject`, { approve }),
  approveFacture: (id: number | string, approve: boolean) => apiClient.post(`/admin/orders/${id}/approve-facture`, { approve }),
  getPendingDispatchOrders: () => apiClient.get('/admin/dispatch/orders'),
  getDispatchDrivers: (vehicleType: string) => apiClient.get(`/admin/dispatch/drivers?vehicle_type=${vehicleType}`),
  createDispatchGroup: (data: unknown) => apiClient.post('/admin/dispatch', data),
  
  // Public Pharmacist workflows
  getPublicOrderDetail: (id: string | number) => apiClient.get(`/public/orders/${id}`),
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
