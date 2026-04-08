package middleware

import (
	"net/http"
	"os"
	"strings"
	"time"

	errs "cinemas/services/user/internal/errors"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo"
)

// JWTConfig holds JWT configuration
type JWTConfig struct {
	SecretKey          []byte
	AccessTokenExpiry  time.Duration
	RefreshTokenExpiry time.Duration
}

// Claims represents JWT claims
type Claims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Type   string `json:"type"` // "access" or "refresh"
	jwt.RegisteredClaims
}

// DefaultConfig returns default JWT configuration
func DefaultConfig() *JWTConfig {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "cinema-ticketing-secret-key-change-in-production"
	}

	return &JWTConfig{
		SecretKey:          []byte(secret),
		AccessTokenExpiry:  15 * time.Minute,
		RefreshTokenExpiry: 7 * 24 * time.Hour,
	}
}

// GenerateTokenPair generates access and refresh tokens
func (c *JWTConfig) GenerateTokenPair(userID, email string) (accessToken, refreshToken string, err error) {
	// Access token
	accessClaims := &Claims{
		UserID: userID,
		Email:  email,
		Type:   "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(c.AccessTokenExpiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "cinema-user-service",
		},
	}

	accessJWT := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessToken, err = accessJWT.SignedString(c.SecretKey)
	if err != nil {
		return "", "", err
	}

	// Refresh token
	refreshClaims := &Claims{
		UserID: userID,
		Email:  email,
		Type:   "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(c.RefreshTokenExpiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "cinema-user-service",
		},
	}

	refreshJWT := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshToken, err = refreshJWT.SignedString(c.SecretKey)
	if err != nil {
		return "", "", err
	}

	return accessToken, refreshToken, nil
}

// ValidateToken validates a JWT token and returns claims
func (c *JWTConfig) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errs.ErrInvalidToken
		}
		return c.SecretKey, nil
	})

	if err != nil {
		return nil, errs.ErrInvalidToken
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errs.ErrInvalidToken
}

// JWTMiddleware creates Echo middleware for JWT authentication
func JWTMiddleware(config *JWTConfig) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"error": "Missing authorization token",
					"type":  "user",
				})
			}

			// Check Bearer prefix
			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"error": "Invalid authorization header format",
					"type":  "user",
				})
			}

			tokenString := parts[1]

			// Validate token
			claims, err := config.ValidateToken(tokenString)
			if err != nil {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"error": "Invalid or expired token",
					"type":  "user",
				})
			}

			// Check token type (must be access token)
			if claims.Type != "access" {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"error": "Invalid token type",
					"type":  "user",
				})
			}

			// Store user info in context
			c.Set("user_id", claims.UserID)
			c.Set("email", claims.Email)

			return next(c)
		}
	}
}
