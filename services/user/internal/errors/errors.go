package errors

import (
	"fmt"
	"net/http"

	"github.com/labstack/echo"
)

// ErrorType represents the type of error
type ErrorType string

const (
	// Internal represents internal server errors
	Internal ErrorType = "internal"
	// External represents external service errors
	External ErrorType = "external"
	// User represents user input errors
	User ErrorType = "user"
)

// AppError represents a structured application error
type AppError struct {
	Message string    `json:"error"`
	Type    ErrorType `json:"type"`
	Status  int       `json:"-"`
}

func (e *AppError) Error() string {
	return e.Message
}

// NewError creates a new AppError
func NewError(errType ErrorType, message string, status int) *AppError {
	return &AppError{
		Message: message,
		Type:    errType,
		Status:  status,
	}
}

// Send creates and returns an HTTP error response
func Send(errType string, msg string, err error) error {
	var status int
	var eType ErrorType

	switch errType {
	case "internal", "Internal":
		status = http.StatusInternalServerError
		eType = Internal
	case "external", "External":
		status = http.StatusInternalServerError
		eType = External
	case "user", "User":
		status = http.StatusBadRequest
		eType = User
	default:
		status = http.StatusInternalServerError
		eType = Internal
	}

	fullMsg := msg
	if err != nil {
		fullMsg = fmt.Sprintf("%s: %v", msg, err)
	}

	return &AppError{
		Message: fullMsg,
		Type:    eType,
		Status:  status,
	}
}

// HTTPErrorHandler is a custom error handler for Echo
func HTTPErrorHandler(err error, c echo.Context) {
	if appErr, ok := err.(*AppError); ok {
		c.JSON(appErr.Status, map[string]interface{}{
			"error": appErr.Message,
			"type":  appErr.Type,
		})
		return
	}

	// Handle Echo's HTTPError
	if he, ok := err.(*echo.HTTPError); ok {
		c.JSON(he.Code, map[string]interface{}{
			"error": he.Message,
			"type":  "internal",
		})
		return
	}

	// Default error response
	c.JSON(http.StatusInternalServerError, map[string]interface{}{
		"error": err.Error(),
		"type":  "internal",
	})
}

// Validation errors
var (
	ErrInvalidEmail     = NewError(User, "Invalid email format", http.StatusBadRequest)
	ErrEmailExists      = NewError(User, "Email already registered", http.StatusConflict)
	ErrInvalidPassword  = NewError(User, "Password must be at least 8 characters", http.StatusBadRequest)
	ErrInvalidCreds     = NewError(User, "Invalid email or password", http.StatusUnauthorized)
	ErrUserNotFound     = NewError(User, "User not found", http.StatusNotFound)
	ErrUnauthorized     = NewError(User, "Unauthorized", http.StatusUnauthorized)
	ErrInvalidToken     = NewError(User, "Invalid or expired token", http.StatusUnauthorized)
	ErrMissingToken     = NewError(User, "Missing authorization token", http.StatusUnauthorized)
	ErrInternalDB       = NewError(Internal, "Database error", http.StatusInternalServerError)
)
