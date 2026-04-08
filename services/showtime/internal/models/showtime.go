package models

import "time"

// ShowtimeStatus represents the status of a showtime
type ShowtimeStatus string

const (
	StatusScheduled ShowtimeStatus = "scheduled"
	StatusCancelled ShowtimeStatus = "cancelled"
	StatusCompleted ShowtimeStatus = "completed"
)

// Price represents ticket prices for different types
type Price struct {
	Regular int `json:"regular" bson:"regular"`
	VIP     int `json:"vip,omitempty" bson:"vip,omitempty"`
	Child   int `json:"child,omitempty" bson:"child,omitempty"`
}

// Showtime represents a movie showtime
type Showtime struct {
	ID             string         `json:"id" bson:"_id"`
	MovieID        string         `json:"movie_id" bson:"movie_id"`
	CinemaID       string         `json:"cinema_id" bson:"cinema_id"`
	RoomNumber     int            `json:"room_number" bson:"room_number"`
	StartTime      time.Time      `json:"start_time" bson:"start_time"`
	EndTime        time.Time      `json:"end_time" bson:"end_time"`
	Price          Price          `json:"price" bson:"price"`
	AvailableSeats int            `json:"available_seats" bson:"available_seats"`
	Status         ShowtimeStatus `json:"status" bson:"status"`
	CreatedAt      time.Time      `json:"created_at" bson:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at" bson:"updated_at"`
}

// CreateShowtimeRequest represents the request to create a showtime
type CreateShowtimeRequest struct {
	MovieID        string    `json:"movie_id"`
	CinemaID       string    `json:"cinema_id"`
	RoomNumber     int       `json:"room_number"`
	StartTime      time.Time `json:"start_time"`
	EndTime        time.Time `json:"end_time"`
	Price          Price     `json:"price"`
	AvailableSeats int       `json:"available_seats"`
}

// UpdateShowtimeRequest represents the request to update a showtime
type UpdateShowtimeRequest struct {
	RoomNumber     *int            `json:"room_number,omitempty"`
	StartTime      *time.Time      `json:"start_time,omitempty"`
	EndTime        *time.Time      `json:"end_time,omitempty"`
	Price          *Price          `json:"price,omitempty"`
	AvailableSeats *int            `json:"available_seats,omitempty"`
	Status         *ShowtimeStatus `json:"status,omitempty"`
}

// Pagination represents pagination info
type Pagination struct {
	Page       int `json:"page"`
	Limit      int `json:"limit"`
	Total      int `json:"total"`
	TotalPages int `json:"total_pages"`
}

// ShowtimeList represents a paginated list of showtimes
type ShowtimeList struct {
	Data       []Showtime `json:"data"`
	Pagination Pagination `json:"pagination"`
}

// ListShowtimesQuery represents query parameters for listing showtimes
type ListShowtimesQuery struct {
	MovieID  string         `query:"movie_id"`
	CinemaID string         `query:"cinema_id"`
	Date     string         `query:"date"`
	Status   ShowtimeStatus `query:"status"`
	Page     int            `query:"page"`
	Limit    int            `query:"limit"`
}

// WebhookEvent represents an event sent to webhooks
type WebhookEvent struct {
	Event     string    `json:"event"`
	Timestamp time.Time `json:"timestamp"`
	Data      Showtime  `json:"data"`
}

// Validate validates a CreateShowtimeRequest
func (r *CreateShowtimeRequest) Validate() error {
	if r.MovieID == "" {
		return ErrInvalidMovieID
	}
	if r.CinemaID == "" {
		return ErrInvalidCinemaID
	}
	if r.RoomNumber < 1 {
		return ErrInvalidRoomNumber
	}
	if r.StartTime.IsZero() {
		return ErrInvalidStartTime
	}
	if r.EndTime.IsZero() || r.EndTime.Before(r.StartTime) {
		return ErrInvalidEndTime
	}
	if r.Price.Regular <= 0 {
		return ErrInvalidPrice
	}
	if r.AvailableSeats < 1 {
		return ErrInvalidSeats
	}
	return nil
}

// IsValidStatus checks if a status string is valid
func IsValidStatus(s ShowtimeStatus) bool {
	switch s {
	case StatusScheduled, StatusCancelled, StatusCompleted:
		return true
	}
	return false
}
