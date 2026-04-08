package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPingAPI(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := PingAPI(c)

	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "pong", rec.Body.String())
}

func TestPingAPI_MultipleRequests(t *testing.T) {
	e := echo.New()

	for i := 0; i < 10; i++ {
		req := httptest.NewRequest(http.MethodGet, "/ping", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		err := PingAPI(c)

		require.NoError(t, err)
		assert.Equal(t, http.StatusOK, rec.Code)
		assert.Equal(t, "pong", rec.Body.String())
	}
}

func TestPingAPI_ResponseHeaders(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := PingAPI(c)

	require.NoError(t, err)
	// Verify content type is text/plain (default for c.String)
	assert.Contains(t, rec.Header().Get("Content-Type"), "text/plain")
}
