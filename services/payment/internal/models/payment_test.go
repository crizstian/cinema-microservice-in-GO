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
		name    string
		payment Payment
		isValid bool
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

func TestRefundRequest_Validate(t *testing.T) {
	tests := []struct {
		name      string
		request   RefundRequest
		expectErr bool
		errMsg    string
	}{
		{
			name: "valid full refund",
			request: RefundRequest{
				Reason: "requested_by_customer",
			},
			expectErr: false,
		},
		{
			name: "valid partial refund",
			request: RefundRequest{
				Reason: "duplicate",
				Amount: ptrInt64(2500),
			},
			expectErr: false,
		},
		{
			name: "valid fraudulent refund",
			request: RefundRequest{
				Reason: "fraudulent",
			},
			expectErr: false,
		},
		{
			name:      "missing reason",
			request:   RefundRequest{},
			expectErr: true,
			errMsg:    "reason is required",
		},
		{
			name: "invalid reason",
			request: RefundRequest{
				Reason: "invalid_reason",
			},
			expectErr: true,
			errMsg:    "invalid refund reason",
		},
		{
			name: "zero amount",
			request: RefundRequest{
				Reason: "duplicate",
				Amount: ptrInt64(0),
			},
			expectErr: true,
			errMsg:    "amount must be greater than 0",
		},
		{
			name: "negative amount",
			request: RefundRequest{
				Reason: "duplicate",
				Amount: ptrInt64(-100),
			},
			expectErr: true,
			errMsg:    "amount must be greater than 0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.request.Validate()
			if tt.expectErr {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestIsValidRefundReason(t *testing.T) {
	tests := []struct {
		reason string
		valid  bool
	}{
		{"duplicate", true},
		{"fraudulent", true},
		{"requested_by_customer", true},
		{"invalid", false},
		{"", false},
		{"customer_request", false},
	}

	for _, tt := range tests {
		t.Run(tt.reason, func(t *testing.T) {
			result := IsValidRefundReason(tt.reason)
			assert.Equal(t, tt.valid, result)
		})
	}
}

func TestRefundStatusConstants(t *testing.T) {
	assert.Equal(t, RefundStatus("pending"), RefundStatusPending)
	assert.Equal(t, RefundStatus("succeeded"), RefundStatusSucceeded)
	assert.Equal(t, RefundStatus("failed"), RefundStatusFailed)
	assert.Equal(t, RefundStatus("canceled"), RefundStatusCanceled)
}

func TestRefundReasonConstants(t *testing.T) {
	assert.Equal(t, RefundReason("duplicate"), RefundReasonDuplicate)
	assert.Equal(t, RefundReason("fraudulent"), RefundReasonFraudulent)
	assert.Equal(t, RefundReason("requested_by_customer"), RefundReasonRequestedByCustomer)
}

// Helper function for creating int64 pointers
func ptrInt64(v int64) *int64 {
	return &v
}
