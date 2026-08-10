package middleware

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"backend_k24apps/internal/models"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

type JWTClaims struct {
	UserID int    `json:"user_id"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

// GenerateToken generates a JWT token signed with a secret for a given user role
func GenerateToken(userID int, email string, role string, secret string) (string, error) {
	claims := &JWTClaims{
		UserID: userID,
		Email:  email,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(365 * 24 * time.Hour)), // Long-lived token valid for 1 year
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// AuthMiddleware protects routes by requiring a valid JWT token
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Status:  "error",
				Message: "Authorization header is missing",
			})
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Status:  "error",
				Message: "Authorization header format must be Bearer <token>",
			})
			c.Abort()
			return
		}

		tokenString := parts[1]
		claims := &JWTClaims{}

		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(secret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Status:  "error",
				Message: "Invalid or expired token",
			})
			c.Abort()
			return
		}

		// Store user details in context for handlers to use
		c.Set("user_id", claims.UserID)
		c.Set("email", claims.Email)
		c.Set("role", claims.Role)
		
		// Fallback for backwards compatibility with driver specific code
		c.Set("driver_id", claims.UserID)

		c.Next()
	}
}
