package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
)

func TestDefaultConfig(t *testing.T) {
	config := DefaultConfig()

	assert.NotNil(t, config)
	assert.NotEmpty(t, config.SecretKey)
	assert.Equal(t, 15*time.Minute, config.AccessTokenExpiry)
	assert.Equal(t, 7*24*time.Hour, config.RefreshTokenExpiry)
}

func TestGenerateTokenPair(t *testing.T) {
	config := DefaultConfig()

	accessToken, refreshToken, err := config.GenerateTokenPair("usr_123", "test@example.com")

	assert.NoError(t, err)
	assert.NotEmpty(t, accessToken)
	assert.NotEmpty(t, refreshToken)
	assert.NotEqual(t, accessToken, refreshToken)
}

func TestValidateToken_ValidAccessToken(t *testing.T) {
	config := DefaultConfig()

	accessToken, _, err := config.GenerateTokenPair("usr_123", "test@example.com")
	assert.NoError(t, err)

	claims, err := config.ValidateToken(accessToken)

	assert.NoError(t, err)
	assert.NotNil(t, claims)
	assert.Equal(t, "usr_123", claims.UserID)
	assert.Equal(t, "test@example.com", claims.Email)
	assert.Equal(t, "access", claims.Type)
}

func TestValidateToken_ValidRefreshToken(t *testing.T) {
	config := DefaultConfig()

	_, refreshToken, err := config.GenerateTokenPair("usr_456", "user@example.com")
	assert.NoError(t, err)

	claims, err := config.ValidateToken(refreshToken)

	assert.NoError(t, err)
	assert.NotNil(t, claims)
	assert.Equal(t, "usr_456", claims.UserID)
	assert.Equal(t, "user@example.com", claims.Email)
	assert.Equal(t, "refresh", claims.Type)
}

func TestValidateToken_InvalidToken(t *testing.T) {
	config := DefaultConfig()

	claims, err := config.ValidateToken("invalid.token.here")

	assert.Error(t, err)
	assert.Nil(t, claims)
}

func TestValidateToken_ExpiredToken(t *testing.T) {
	// Create config with very short expiry
	config := &JWTConfig{
		SecretKey:          []byte("test-secret"),
		AccessTokenExpiry:  -1 * time.Hour, // Already expired
		RefreshTokenExpiry: -1 * time.Hour,
	}

	accessToken, _, err := config.GenerateTokenPair("usr_123", "test@example.com")
	assert.NoError(t, err)

	claims, err := config.ValidateToken(accessToken)

	assert.Error(t, err)
	assert.Nil(t, claims)
}

func TestJWTMiddleware_MissingToken(t *testing.T) {
	e := echo.New()
	config := DefaultConfig()

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	handler := JWTMiddleware(config)(func(c echo.Context) error {
		return c.String(http.StatusOK, "success")
	})

	err := handler(c)

	assert.NoError(t, err) // Middleware returns JSON response, not error
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestJWTMiddleware_InvalidFormat(t *testing.T) {
	e := echo.New()
	config := DefaultConfig()

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "InvalidFormat token")
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	handler := JWTMiddleware(config)(func(c echo.Context) error {
		return c.String(http.StatusOK, "success")
	})

	err := handler(c)

	assert.NoError(t, err)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestJWTMiddleware_ValidToken(t *testing.T) {
	e := echo.New()
	config := DefaultConfig()

	accessToken, _, err := config.GenerateTokenPair("usr_123", "test@example.com")
	assert.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+accessToken)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	var capturedUserID string
	handler := JWTMiddleware(config)(func(c echo.Context) error {
		capturedUserID = c.Get("user_id").(string)
		return c.String(http.StatusOK, "success")
	})

	err = handler(c)

	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "usr_123", capturedUserID)
}

func TestJWTMiddleware_RefreshTokenNotAllowed(t *testing.T) {
	e := echo.New()
	config := DefaultConfig()

	// Generate refresh token and try to use it as access token
	_, refreshToken, err := config.GenerateTokenPair("usr_123", "test@example.com")
	assert.NoError(t, err)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer "+refreshToken)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	handler := JWTMiddleware(config)(func(c echo.Context) error {
		return c.String(http.StatusOK, "success")
	})

	err = handler(c)

	assert.NoError(t, err)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}
