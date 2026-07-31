package middleware

import (
	"net/http"
	"sync"
	"time"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
)

type rateLimitEntry struct {
	count    int
	windowAt time.Time
}

type ipRateLimiter struct {
	mu      sync.Mutex
	entries map[string]*rateLimitEntry
	max     int           // max requests per window
	window  time.Duration // window duration
}

func newIPRateLimiter(max int, window time.Duration) *ipRateLimiter {
	rl := &ipRateLimiter{
		entries: make(map[string]*rateLimitEntry),
		max:     max,
		window:  window,
	}
	// Background cleanup to prevent memory leak
	go rl.cleanupLoop()
	return rl
}

func (rl *ipRateLimiter) allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	entry, exists := rl.entries[ip]

	if !exists || now.Sub(entry.windowAt) > rl.window {
		rl.entries[ip] = &rateLimitEntry{count: 1, windowAt: now}
		return true
	}

	entry.count++
	return entry.count <= rl.max
}

func (rl *ipRateLimiter) cleanupLoop() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		rl.mu.Lock()
		now := time.Now()
		for ip, entry := range rl.entries {
			if now.Sub(entry.windowAt) > rl.window*2 {
				delete(rl.entries, ip)
			}
		}
		rl.mu.Unlock()
	}
}

// loginLimiter: 5 attempts per minute per IP
var loginLimiter = newIPRateLimiter(5, time.Minute)

// LoginRateLimitMiddleware limits login attempts to 5 per minute per IP.
// Returns HTTP 429 Too Many Requests when limit is exceeded.
func LoginRateLimitMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !loginLimiter.allow(ip) {
			c.JSON(http.StatusTooManyRequests, models.APIResponse{
				Status:  "error",
				Message: "Terlalu banyak percobaan login. Coba lagi dalam 1 menit.",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}
