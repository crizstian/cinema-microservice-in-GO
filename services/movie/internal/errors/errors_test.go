package errs

import (
	"errors"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSend_UserError(t *testing.T) {
	testErr := errors.New("test user error")

	httpErr := Send(ErrUsr, "Invalid input", testErr)

	assert.NotNil(t, httpErr)
	assert.Equal(t, http.StatusBadRequest, httpErr.Code)
	assert.Contains(t, httpErr.Message, "Invalid input")
	assert.Contains(t, httpErr.Message, "verify your data")
}

func TestSend_ExternalError(t *testing.T) {
	testErr := errors.New("database connection failed")

	httpErr := Send(ErrExt, "Database error", testErr)

	assert.NotNil(t, httpErr)
	assert.Equal(t, http.StatusInternalServerError, httpErr.Code)
	assert.Contains(t, httpErr.Message, "Database error")
	assert.Contains(t, httpErr.Message, "contact you're administrator")
}

func TestSend_InternalError(t *testing.T) {
	testErr := errors.New("internal processing error")

	httpErr := Send(ErrInt, "Processing failed", testErr)

	assert.NotNil(t, httpErr)
	assert.Equal(t, http.StatusNotAcceptable, httpErr.Code)
	assert.Contains(t, httpErr.Message, "Processing failed")
}

func TestSend_UnknownStatus(t *testing.T) {
	testErr := errors.New("unknown error")

	httpErr := Send("unknown", "Something happened", testErr)

	assert.NotNil(t, httpErr)
	// When status doesn't match any case, code remains 0
	assert.Equal(t, 0, httpErr.Code)
}

func TestErrorConstants(t *testing.T) {
	assert.Equal(t, "user", ErrUsr)
	assert.Equal(t, "external", ErrExt)
	assert.Equal(t, "internal", ErrInt)
}

func TestSend_TableDriven(t *testing.T) {
	tests := []struct {
		name           string
		status         string
		msg            string
		expectedCode   int
		expectedSubstr string
	}{
		{
			name:           "User error with validation message",
			status:         ErrUsr,
			msg:            "Email format invalid",
			expectedCode:   http.StatusBadRequest,
			expectedSubstr: "verify your data",
		},
		{
			name:           "External error with service message",
			status:         ErrExt,
			msg:            "Service unavailable",
			expectedCode:   http.StatusInternalServerError,
			expectedSubstr: "contact you're administrator",
		},
		{
			name:           "Internal error with system message",
			status:         ErrInt,
			msg:            "Memory allocation failed",
			expectedCode:   http.StatusNotAcceptable,
			expectedSubstr: "Memory allocation failed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := errors.New("test error")
			httpErr := Send(tt.status, tt.msg, err)

			assert.Equal(t, tt.expectedCode, httpErr.Code)
			assert.Contains(t, httpErr.Message, tt.expectedSubstr)
		})
	}
}
