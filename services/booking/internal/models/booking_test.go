package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestBookingDetailsModel(t *testing.T) {
	booking := BookingDetails{
		ShowtimeID:  "sht_abc123",
		HoldID:      "hold_xyz789",
		SessionID:   "sess_123456",
		TotalAmount: 150,
		Seats:       []string{"A1", "A2"},
	}

	assert.Equal(t, "sht_abc123", booking.ShowtimeID)
	assert.Equal(t, "hold_xyz789", booking.HoldID)
	assert.Equal(t, 2, len(booking.Seats))
	assert.Greater(t, booking.TotalAmount, 0)
}

func TestTicketModel(t *testing.T) {
	ticket := Ticket{
		BookingID:     "bkg_123",
		ShowtimeID:    "sht_abc",
		ReservationID: "res_xyz",
		MovieTitle:    "Test Movie",
		CinemaName:    "Test Cinema",
		RoomNumber:    5,
		StartTime:     time.Now(),
		Seats:         []string{"A1", "A2"},
		TotalAmount:   450,
		OrderID:       "order-123",
		ReceiptURL:    "https://example.com/receipt",
		UserName:      "John Doe",
		Email:         "john@example.com",
		CreatedAt:     time.Now(),
	}

	assert.NotEmpty(t, ticket.BookingID)
	assert.NotEmpty(t, ticket.OrderID)
	assert.NotEmpty(t, ticket.Email)
	assert.Contains(t, ticket.Email, "@")
	assert.Equal(t, 2, len(ticket.Seats))
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
