package server

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
)

func TestNew(t *testing.T) {
	cfg := Config{Port: "3003"}
	s := New(cfg)

	assert.NotNil(t, s)
	assert.NotNil(t, s.Echo)
	assert.NotNil(t, s.Logger)
	assert.Equal(t, "3003", s.Port)
}

func TestNew_DefaultPort(t *testing.T) {
	cfg := Config{}
	s := New(cfg)

	assert.Equal(t, "3003", s.Port)
}

func TestServer_Group(t *testing.T) {
	cfg := Config{Port: "3003"}
	s := New(cfg)

	group := s.Group("/api")
	assert.NotNil(t, group)
}

func TestServer_Echo(t *testing.T) {
	cfg := Config{Port: "3003"}
	s := New(cfg)

	s.Echo.GET("/test", func(c echo.Context) error {
		return c.String(http.StatusOK, "ok")
	})

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	s.Echo.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
}
