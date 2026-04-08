package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestCreateShowtimeRequest_Validate(t *testing.T) {
	validRequest := func() CreateShowtimeRequest {
		return CreateShowtimeRequest{
			MovieID:        "mov_123",
			CinemaID:       "cin_456",
			RoomNumber:     5,
			StartTime:      time.Now().Add(time.Hour),
			EndTime:        time.Now().Add(3 * time.Hour),
			Price:          Price{Regular: 12000, VIP: 20000, Child: 8000},
			AvailableSeats: 150,
		}
	}

	t.Run("valid request", func(t *testing.T) {
		req := validRequest()
		err := req.Validate()
		assert.NoError(t, err)
	})

	t.Run("missing movie_id", func(t *testing.T) {
		req := validRequest()
		req.MovieID = ""
		err := req.Validate()
		assert.Equal(t, ErrInvalidMovieID, err)
	})

	t.Run("missing cinema_id", func(t *testing.T) {
		req := validRequest()
		req.CinemaID = ""
		err := req.Validate()
		assert.Equal(t, ErrInvalidCinemaID, err)
	})

	t.Run("invalid room_number", func(t *testing.T) {
		req := validRequest()
		req.RoomNumber = 0
		err := req.Validate()
		assert.Equal(t, ErrInvalidRoomNumber, err)
	})

	t.Run("zero start_time", func(t *testing.T) {
		req := validRequest()
		req.StartTime = time.Time{}
		err := req.Validate()
		assert.Equal(t, ErrInvalidStartTime, err)
	})

	t.Run("end_time before start_time", func(t *testing.T) {
		req := validRequest()
		req.EndTime = req.StartTime.Add(-time.Hour)
		err := req.Validate()
		assert.Equal(t, ErrInvalidEndTime, err)
	})

	t.Run("invalid price", func(t *testing.T) {
		req := validRequest()
		req.Price.Regular = 0
		err := req.Validate()
		assert.Equal(t, ErrInvalidPrice, err)
	})

	t.Run("invalid seats", func(t *testing.T) {
		req := validRequest()
		req.AvailableSeats = 0
		err := req.Validate()
		assert.Equal(t, ErrInvalidSeats, err)
	})
}

func TestIsValidStatus(t *testing.T) {
	tests := []struct {
		status ShowtimeStatus
		valid  bool
	}{
		{StatusScheduled, true},
		{StatusCancelled, true},
		{StatusCompleted, true},
		{"invalid", false},
		{"", false},
	}

	for _, tt := range tests {
		t.Run(string(tt.status), func(t *testing.T) {
			result := IsValidStatus(tt.status)
			assert.Equal(t, tt.valid, result)
		})
	}
}

func TestShowtimeStatus_Constants(t *testing.T) {
	assert.Equal(t, ShowtimeStatus("scheduled"), StatusScheduled)
	assert.Equal(t, ShowtimeStatus("cancelled"), StatusCancelled)
	assert.Equal(t, ShowtimeStatus("completed"), StatusCompleted)
}

func TestPrice_JSON(t *testing.T) {
	price := Price{
		Regular: 12000,
		VIP:     20000,
		Child:   8000,
	}

	assert.Equal(t, 12000, price.Regular)
	assert.Equal(t, 20000, price.VIP)
	assert.Equal(t, 8000, price.Child)
}
