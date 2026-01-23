package models

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestBookingModel(t *testing.T) {
	booking := Booking{
		UserType:    "normal",
		City:        "CDMX",
		Cinema:      "Cinepolis",
		Schedule:    "2026-01-25 19:00",
		TotalAmount: 150,
		CinemaRoom:  5,
		Seats:       []string{"A1", "A2"},
	}

	assert.Equal(t, "normal", booking.UserType)
	assert.Equal(t, "CDMX", booking.City)
	assert.Equal(t, 2, len(booking.Seats))
	assert.Greater(t, booking.TotalAmount, 0)
}

func TestTicketModel(t *testing.T) {
	ticket := Ticket{
		OrderID:     "order-123",
		Description: "Test ticket",
		ReceiptURL:  "https://example.com/receipt",
		UserName:    "John Doe",
		Email:       "john@example.com",
	}

	assert.NotEmpty(t, ticket.OrderID)
	assert.NotEmpty(t, ticket.Email)
	assert.Contains(t, ticket.Email, "@")
}

func TestUserMemberModel(t *testing.T) {
	user := UserMember{
		Name:        "John",
		LastName:    "Doe",
		Email:       "john@example.com",
		PhoneNumber: "+1234567890",
		Membership:  "GOLD123",
	}

	assert.NotEmpty(t, user.Name)
	assert.NotEmpty(t, user.Email)
	assert.Contains(t, user.Email, "@")
}

func TestPaymentModel(t *testing.T) {
	payment := Payment{
		UserName:    "John Doe",
		Currency:    "mxn",
		Number:      "4242424242424242",
		Cvc:         "123",
		ExpMonth:    "12",
		ExpYear:     "2026",
		Amount:      150,
		Description: "Movie tickets",
	}

	assert.Equal(t, "mxn", payment.Currency)
	assert.Greater(t, payment.Amount, 0)
	assert.NotEmpty(t, payment.Number)
	assert.Len(t, payment.Cvc, 3)
}

func TestCreditCardValidation(t *testing.T) {
	tests := []struct {
		name    string
		card    CreditCard
		isValid bool
	}{
		{
			name: "valid card",
			card: CreditCard{
				Number:   "4242424242424242",
				Cvc:      "123",
				ExpMonth: "12",
				ExpYear:  "2026",
			},
			isValid: true,
		},
		{
			name: "empty card number",
			card: CreditCard{
				Number:   "",
				Cvc:      "123",
				ExpMonth: "12",
				ExpYear:  "2026",
			},
			isValid: false,
		},
		{
			name: "invalid cvc",
			card: CreditCard{
				Number:   "4242424242424242",
				Cvc:      "12", // Solo 2 dígitos
				ExpMonth: "12",
				ExpYear:  "2026",
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.card.Number != "" && len(tt.card.Cvc) == 3
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
