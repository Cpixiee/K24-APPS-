package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// CORSMiddleware restricts cross-origin access to the configured frontend origin.
// Set CORS_ORIGIN in your .env (e.g. https://k24.yourdomain.com).
// For local development it defaults to http://localhost:5173.
func CORSMiddleware(allowedOrigin string) gin.HandlerFunc {
	// Support multiple comma-separated origins: "https://app.k24.com,http://localhost:5173"
	allowed := strings.Split(allowedOrigin, ",")
	for i := range allowed {
		allowed[i] = strings.TrimSpace(allowed[i])
	}

	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")

		// Check if the request origin is in our allowed list
		isAllowed := false
		for _, o := range allowed {
			if o == "*" || o == origin {
				isAllowed = true
				break
			}
		}

		if isAllowed {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
			c.Writer.Header().Set("Vary", "Origin") // required when not using wildcard
		}

		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers",
			"Content-Type, Content-Length, Accept-Encoding, Authorization, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
