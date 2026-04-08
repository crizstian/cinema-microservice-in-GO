package service

import (
	"cinemas/services/booking/internal/models"
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCreateBooking_ValidationErrors(t *testing.T) {
	tests := []struct {
		name    string
		request *models.BookingRequest
		wantErr bool
		errMsg  string
	}{
		{
			name:    "nil request",
			request: nil,
			wantErr: true,
			errMsg:  "invalid booking request",
		},
		{
			name: "empty user name",
			request: &models.BookingRequest{
				User: models.UserMember{
					Name: "",
				},
			},
			wantErr: true,
			errMsg:  "invalid booking request",
		},
		{
			name: "missing showtime_id",
			request: &models.BookingRequest{
				User: models.UserMember{
					Name: "John",
				},
				Booking: models.BookingDetails{
					HoldID:    "hold_123",
					SessionID: "sess_123",
				},
			},
			wantErr: true,
			errMsg:  "showtime_id, hold_id, and session_id are required",
		},
		{
			name: "missing hold_id",
			request: &models.BookingRequest{
				User: models.UserMember{
					Name: "John",
				},
				Booking: models.BookingDetails{
					ShowtimeID: "sht_123",
					SessionID:  "sess_123",
				},
			},
			wantErr: true,
			errMsg:  "showtime_id, hold_id, and session_id are required",
		},
		{
			name: "missing session_id",
			request: &models.BookingRequest{
				User: models.UserMember{
					Name: "John",
				},
				Booking: models.BookingDetails{
					ShowtimeID: "sht_123",
					HoldID:     "hold_123",
				},
			},
			wantErr: true,
			errMsg:  "showtime_id, hold_id, and session_id are required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// No inicializamos DB ni client porque la validación falla antes
			svc := &BookingService{}
			_, err := svc.CreateBooking(context.Background(), tt.request)

			if tt.wantErr {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestNewBookingService(t *testing.T) {
	svc := NewBookingService(nil, nil)
	assert.NotNil(t, svc)
}
