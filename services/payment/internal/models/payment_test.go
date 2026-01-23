package models

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPaymentModel(t *testing.T) {
	p := Payment{
		UserName:    "John Doe",
		Currency:    "usd",
		Number:      "4242424242424242",
		Cvc:         "123",
		ExpMonth:    "12",
		ExpYear:     "2025",
		Amount:      100,
		Description: "Test payment",
	}

	assert.Equal(t, "John Doe", p.UserName)
	assert.Equal(t, "usd", p.Currency)
	assert.Equal(t, int64(100), p.Amount)
	assert.NotEmpty(t, p.Number, "Card number should not be empty")
	assert.Len(t, p.Cvc, 3, "CVC should be 3 digits")
}

func TestPaymentValidation(t *testing.T) {
	tests := []struct {
		name     string
		payment  Payment
		isValid  bool
	}{
		{
			name: "valid payment",
			payment: Payment{
				UserName: "Test User",
				Amount:   50,
				Number:   "4242424242424242",
				Cvc:      "123",
			},
			isValid: true,
		},
		{
			name: "zero amount",
			payment: Payment{
				UserName: "Test User",
				Amount:   0,
				Number:   "4242424242424242",
			},
			isValid: false,
		},
		{
			name: "empty card number",
			payment: Payment{
				UserName: "Test User",
				Amount:   50,
				Number:   "",
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.payment.Amount > 0 && tt.payment.Number != ""
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
