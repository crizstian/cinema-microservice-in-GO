package errors

import (
	"net/http"

	"github.com/labstack/echo"
)

// ErrorType represents the type of error
type ErrorType string

const (
	TypeValidation   ErrorType = "validation"
	TypeNotFound     ErrorType = "not_found"
	TypeConflict     ErrorType = "conflict"
	TypeUnauthorized ErrorType = "unauthorized"
	TypeInternal     ErrorType = "internal"
)

// APIError represents an API error response
type APIError struct {
	Type    ErrorType              `json:"type"`
	Message string                 `json:"message"`
	Details map[string]interface{} `json:"details,omitempty"`
}

// NewValidationError creates a validation error
func NewValidationError(message string) *APIError {
	return &APIError{
		Type:    TypeValidation,
		Message: message,
	}
}

// NewNotFoundError creates a not found error
func NewNotFoundError(message string) *APIError {
	return &APIError{
		Type:    TypeNotFound,
		Message: message,
	}
}

// NewConflictError creates a conflict error
func NewConflictError(message string) *APIError {
	return &APIError{
		Type:    TypeConflict,
		Message: message,
	}
}

// NewUnauthorizedError creates an unauthorized error
func NewUnauthorizedError(message string) *APIError {
	return &APIError{
		Type:    TypeUnauthorized,
		Message: message,
	}
}

// NewInternalError creates an internal error
func NewInternalError(message string) *APIError {
	return &APIError{
		Type:    TypeInternal,
		Message: message,
	}
}

// Send sends an error response
func Send(c echo.Context, statusCode int, err *APIError) error {
	return c.JSON(statusCode, err)
}

// SendValidation sends a validation error
func SendValidation(c echo.Context, message string) error {
	return Send(c, http.StatusBadRequest, NewValidationError(message))
}

// SendNotFound sends a not found error
func SendNotFound(c echo.Context, message string) error {
	return Send(c, http.StatusNotFound, NewNotFoundError(message))
}

// SendConflict sends a conflict error
func SendConflict(c echo.Context, message string) error {
	return Send(c, http.StatusConflict, NewConflictError(message))
}

// SendUnauthorized sends an unauthorized error
func SendUnauthorized(c echo.Context, message string) error {
	return Send(c, http.StatusUnauthorized, NewUnauthorizedError(message))
}

// SendInternal sends an internal error
func SendInternal(c echo.Context, message string) error {
	return Send(c, http.StatusInternalServerError, NewInternalError(message))
}
