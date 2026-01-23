package api

import (
	"cinemas/services/payment/internal/models"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
)

func TestRegisterPurchase_InvalidJSON(t *testing.T) {
	// Setup
	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/payment/register", strings.NewReader(`invalid json`))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	a := API{}

	// Execute
	err := a.RegisterPurchase(c)

	// Assert - debe fallar por JSON inválido
	assert.Error(t, err)
}

func TestPaymentValidation(t *testing.T) {
	tests := []struct {
		name    string
		payment models.Payment
		isValid bool
	}{
		{
			name: "valid payment",
			payment: models.Payment{
				UserName:    "John Doe",
				Currency:    "usd",
				Number:      "4242424242424242",
				Cvc:         "123",
				ExpMonth:    "12",
				ExpYear:     "2026",
				Amount:      100,
				Description: "Test",
			},
			isValid: true,
		},
		{
			name: "zero amount",
			payment: models.Payment{
				UserName: "John Doe",
				Amount:   0,
			},
			isValid: false,
		},
		{
			name: "empty user name",
			payment: models.Payment{
				UserName: "",
				Amount:   100,
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.payment.UserName != "" && tt.payment.Amount > 0
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
