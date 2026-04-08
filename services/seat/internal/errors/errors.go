package errs

import (
	"net/http"

	"cinemas/services/seat/internal/models"

	"github.com/labstack/echo"
	log "github.com/sirupsen/logrus"
)

// Error codes
const (
	CodeInvalidRequest   = "INVALID_REQUEST"
	CodeInvalidSeats     = "INVALID_SEATS"
	CodeSeatsUnavailable = "SEATS_UNAVAILABLE"
	CodeHoldNotFound     = "HOLD_NOT_FOUND"
	CodeHoldExpired      = "HOLD_EXPIRED"
	CodeUnauthorized     = "UNAUTHORIZED"
	CodeNotFound         = "NOT_FOUND"
	CodeConflict         = "CONFLICT"
	CodeInternalError    = "INTERNAL_ERROR"
)

// BadRequest returns a 400 error
func BadRequest(code, message string) *echo.HTTPError {
	log.Warn("Bad request: ", message)
	return echo.NewHTTPError(http.StatusBadRequest, models.Error{
		Code:    code,
		Message: message,
	})
}

// NotFound returns a 404 error
func NotFound(code, message string) *echo.HTTPError {
	log.Warn("Not found: ", message)
	return echo.NewHTTPError(http.StatusNotFound, models.Error{
		Code:    code,
		Message: message,
	})
}

// Conflict returns a 409 error
func Conflict(code, message string) *echo.HTTPError {
	log.Warn("Conflict: ", message)
	return echo.NewHTTPError(http.StatusConflict, models.Error{
		Code:    code,
		Message: message,
	})
}

// ConflictWithSeats returns a 409 error with unavailable seats details
func ConflictWithSeats(unavailableSeats []models.UnavailableSeat) *echo.HTTPError {
	log.Warn("Conflict: seats unavailable")
	return echo.NewHTTPError(http.StatusConflict, models.ConflictError{
		Code:             CodeSeatsUnavailable,
		Message:          "One or more seats are not available",
		UnavailableSeats: unavailableSeats,
	})
}

// Forbidden returns a 403 error
func Forbidden(code, message string) *echo.HTTPError {
	log.Warn("Forbidden: ", message)
	return echo.NewHTTPError(http.StatusForbidden, models.Error{
		Code:    code,
		Message: message,
	})
}

// Internal returns a 500 error
func Internal(code, message string, err error) *echo.HTTPError {
	log.Error("Internal error: ", message, " - ", err)
	return echo.NewHTTPError(http.StatusInternalServerError, models.Error{
		Code:    code,
		Message: message,
	})
}
