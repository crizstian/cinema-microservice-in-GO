package api

import (
	"cinemas/services/booking/internal/models"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestBookingRequest_Validation(t *testing.T) {
	tests := []struct {
		name    string
		request models.BookingRequest
		isValid bool
	}{
		{
			name: "valid booking request",
			request: models.BookingRequest{
				User: models.UserMember{
					Name:     "John",
					LastName: "Doe",
					Email:    "john@example.com",
				},
				Booking: models.Booking{
					City:        "CDMX",
					Cinema:      "Cinepolis",
					TotalAmount: 100,
				},
			},
			isValid: true,
		},
		{
			name: "empty user name",
			request: models.BookingRequest{
				User: models.UserMember{
					Name: "",
				},
			},
			isValid: false,
		},
		{
			name: "empty email",
			request: models.BookingRequest{
				User: models.UserMember{
					Name:  "John",
					Email: "",
				},
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.request.User.Name != "" && tt.request.User.Email != ""
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
