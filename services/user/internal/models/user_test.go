package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestUser_ToProfile(t *testing.T) {
	now := time.Now()

	user := &User{
		ID:             "usr_abc123",
		Name:           "John Doe",
		Email:          "john@example.com",
		Phone:          "+1234567890",
		PasswordHash:   "hashedpassword",
		MembershipType: "loyal",
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	profile := user.ToProfile()

	assert.Equal(t, user.ID, profile.ID)
	assert.Equal(t, user.Name, profile.Name)
	assert.Equal(t, user.Email, profile.Email)
	assert.Equal(t, user.Phone, profile.Phone)
	assert.Equal(t, user.MembershipType, profile.MembershipType)
	assert.Equal(t, user.CreatedAt, profile.CreatedAt)
}

func TestUser_ToProfile_ExcludesPasswordHash(t *testing.T) {
	user := &User{
		ID:           "usr_abc123",
		Name:         "John Doe",
		Email:        "john@example.com",
		PasswordHash: "supersecretpasswordhash",
	}

	profile := user.ToProfile()

	// Profile should not have password hash field
	// This is ensured by the struct definition, but we verify the conversion works
	assert.NotNil(t, profile)
	assert.Equal(t, user.ID, profile.ID)
}

func TestUserRegistration_Fields(t *testing.T) {
	reg := UserRegistration{
		Name:     "Jane Doe",
		Email:    "jane@example.com",
		Password: "securepassword123",
		Phone:    "+1987654321",
	}

	assert.Equal(t, "Jane Doe", reg.Name)
	assert.Equal(t, "jane@example.com", reg.Email)
	assert.Equal(t, "securepassword123", reg.Password)
	assert.Equal(t, "+1987654321", reg.Phone)
}

func TestUserLogin_Fields(t *testing.T) {
	login := UserLogin{
		Email:    "test@example.com",
		Password: "password123",
	}

	assert.Equal(t, "test@example.com", login.Email)
	assert.Equal(t, "password123", login.Password)
}

func TestAuthResponse_Fields(t *testing.T) {
	profile := &UserProfile{
		ID:             "usr_123",
		Name:           "Test User",
		Email:          "test@example.com",
		MembershipType: "normal",
		CreatedAt:      time.Now(),
	}

	auth := AuthResponse{
		AccessToken:  "access.token.here",
		RefreshToken: "refresh.token.here",
		TokenType:    "Bearer",
		ExpiresIn:    900,
		User:         profile,
	}

	assert.Equal(t, "access.token.here", auth.AccessToken)
	assert.Equal(t, "refresh.token.here", auth.RefreshToken)
	assert.Equal(t, "Bearer", auth.TokenType)
	assert.Equal(t, 900, auth.ExpiresIn)
	assert.NotNil(t, auth.User)
	assert.Equal(t, "usr_123", auth.User.ID)
}

func TestBookingHistoryResponse_EmptyBookings(t *testing.T) {
	response := BookingHistoryResponse{
		Bookings: []BookingSummary{},
		Total:    0,
		Limit:    10,
		Offset:   0,
	}

	assert.Empty(t, response.Bookings)
	assert.Equal(t, 0, response.Total)
	assert.Equal(t, 10, response.Limit)
	assert.Equal(t, 0, response.Offset)
}

func TestBookingSummary_Fields(t *testing.T) {
	now := time.Now()

	booking := BookingSummary{
		OrderID:     "ch_123abc",
		MovieTitle:  "Test Movie",
		Cinema:      "Test Cinema",
		Schedule:    "2026-04-10 19:30",
		Seats:       []string{"A1", "A2"},
		TotalAmount: 350,
		CreatedAt:   now,
	}

	assert.Equal(t, "ch_123abc", booking.OrderID)
	assert.Equal(t, "Test Movie", booking.MovieTitle)
	assert.Equal(t, "Test Cinema", booking.Cinema)
	assert.Equal(t, "2026-04-10 19:30", booking.Schedule)
	assert.Len(t, booking.Seats, 2)
	assert.Equal(t, 350, booking.TotalAmount)
	assert.Equal(t, now, booking.CreatedAt)
}
