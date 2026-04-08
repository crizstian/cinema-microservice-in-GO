package errors

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
)

func TestNewValidationError(t *testing.T) {
	err := NewValidationError("invalid input")
	assert.Equal(t, TypeValidation, err.Type)
	assert.Equal(t, "invalid input", err.Message)
}

func TestNewNotFoundError(t *testing.T) {
	err := NewNotFoundError("not found")
	assert.Equal(t, TypeNotFound, err.Type)
	assert.Equal(t, "not found", err.Message)
}

func TestNewConflictError(t *testing.T) {
	err := NewConflictError("conflict")
	assert.Equal(t, TypeConflict, err.Type)
	assert.Equal(t, "conflict", err.Message)
}

func TestNewUnauthorizedError(t *testing.T) {
	err := NewUnauthorizedError("unauthorized")
	assert.Equal(t, TypeUnauthorized, err.Type)
	assert.Equal(t, "unauthorized", err.Message)
}

func TestNewInternalError(t *testing.T) {
	err := NewInternalError("internal error")
	assert.Equal(t, TypeInternal, err.Type)
	assert.Equal(t, "internal error", err.Message)
}

func TestSendValidation(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	SendValidation(c, "bad request")

	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Contains(t, rec.Body.String(), "validation")
}

func TestSendNotFound(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	SendNotFound(c, "not found")

	assert.Equal(t, http.StatusNotFound, rec.Code)
	assert.Contains(t, rec.Body.String(), "not_found")
}

func TestSendConflict(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	SendConflict(c, "conflict")

	assert.Equal(t, http.StatusConflict, rec.Code)
	assert.Contains(t, rec.Body.String(), "conflict")
}

func TestSendUnauthorized(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	SendUnauthorized(c, "unauthorized")

	assert.Equal(t, http.StatusUnauthorized, rec.Code)
	assert.Contains(t, rec.Body.String(), "unauthorized")
}

func TestSendInternal(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	SendInternal(c, "internal error")

	assert.Equal(t, http.StatusInternalServerError, rec.Code)
	assert.Contains(t, rec.Body.String(), "internal")
}
