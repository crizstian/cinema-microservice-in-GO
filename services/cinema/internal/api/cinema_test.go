package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"cinemas/services/cinema/internal/models"

	"github.com/labstack/echo/v4"
)

func TestHandler_Ping(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	h := &Handler{db: nil}

	if err := h.Ping(c); err != nil {
		t.Fatalf("Ping() error = %v", err)
	}

	if rec.Code != http.StatusOK {
		t.Errorf("Ping() status = %d, want %d", rec.Code, http.StatusOK)
	}

	var resp map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	if resp["status"] != "pong" {
		t.Errorf("Ping() status = %q, want %q", resp["status"], "pong")
	}
}

func TestHandler_CreateCinema_InvalidBody(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/cinemas", strings.NewReader("invalid json"))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	h := &Handler{db: nil}

	if err := h.CreateCinema(c); err != nil {
		t.Fatalf("CreateCinema() error = %v", err)
	}

	if rec.Code != http.StatusBadRequest {
		t.Errorf("CreateCinema() status = %d, want %d", rec.Code, http.StatusBadRequest)
	}

	var resp models.ErrorResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	if resp.Error != "invalid_request" {
		t.Errorf("CreateCinema() error = %q, want %q", resp.Error, "invalid_request")
	}
}

func TestHandler_CreateCinema_ValidationError(t *testing.T) {
	e := echo.New()
	body := `{"name": "", "address": "test", "city": "test", "country": "test"}`
	req := httptest.NewRequest(http.MethodPost, "/cinemas", strings.NewReader(body))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	h := &Handler{db: nil}

	if err := h.CreateCinema(c); err != nil {
		t.Fatalf("CreateCinema() error = %v", err)
	}

	if rec.Code != http.StatusBadRequest {
		t.Errorf("CreateCinema() status = %d, want %d", rec.Code, http.StatusBadRequest)
	}

	var resp models.ErrorResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Failed to unmarshal response: %v", err)
	}

	if resp.Error != "validation_error" {
		t.Errorf("CreateCinema() error = %q, want %q", resp.Error, "validation_error")
	}
}

// Note: CreateRoom requires a database connection for cinema lookup.
// Integration tests should be used for full flow testing.
