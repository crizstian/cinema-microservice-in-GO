package models

import "time"

// SeatType represents the type of seat
type SeatType string

const (
	SeatTypeRegular     SeatType = "regular"
	SeatTypeVIP         SeatType = "vip"
	SeatTypeWheelchair  SeatType = "wheelchair"
	SeatTypeUnavailable SeatType = "unavailable"
)

// SeatStatus represents the current status of a seat
type SeatStatus string

const (
	SeatStatusAvailable   SeatStatus = "available"
	SeatStatusHeld        SeatStatus = "held"
	SeatStatusReserved    SeatStatus = "reserved"
	SeatStatusOccupied    SeatStatus = "occupied"
	SeatStatusUnavailable SeatStatus = "unavailable"
)

// Seat represents an individual seat
type Seat struct {
	ID            string     `json:"id" bson:"id"`
	Row           string     `json:"row" bson:"row"`
	Number        int        `json:"number" bson:"number"`
	Type          SeatType   `json:"type" bson:"type"`
	Status        SeatStatus `json:"status" bson:"status"`
	HeldUntil     *time.Time `json:"held_until,omitempty" bson:"held_until,omitempty"`
	HeldBy        string     `json:"held_by,omitempty" bson:"held_by,omitempty"`
	PriceModifier float64    `json:"price_modifier,omitempty" bson:"price_modifier,omitempty"`
}

// SeatMap represents the complete seat map for a showtime
type SeatMap struct {
	ShowtimeID string            `json:"showtime_id" bson:"showtime_id"`
	RoomID     string            `json:"room_id" bson:"room_id"`
	RoomLayout RoomLayoutMatrix  `json:"room_layout" bson:"room_layout"`
	Seats      []Seat            `json:"seats" bson:"seats"`
	Summary    AvailabilitySummary `json:"summary" bson:"summary"`
}

// RoomLayoutMatrix represents the room layout structure
type RoomLayoutMatrix struct {
	Rows      int      `json:"rows" bson:"rows"`
	Columns   int      `json:"columns" bson:"columns"`
	RowLabels []string `json:"row_labels" bson:"row_labels"`
}

// AvailabilitySummary provides a quick count of seat availability
type AvailabilitySummary struct {
	Total       int `json:"total" bson:"total"`
	Available   int `json:"available" bson:"available"`
	Held        int `json:"held" bson:"held"`
	Reserved    int `json:"reserved" bson:"reserved"`
	Unavailable int `json:"unavailable" bson:"unavailable"`
}

// HoldRequest represents a request to hold seats
type HoldRequest struct {
	ShowtimeID string   `json:"showtime_id"`
	SeatIDs    []string `json:"seat_ids"`
	SessionID  string   `json:"session_id"`
}

// HoldResponse represents the response after holding seats
type HoldResponse struct {
	HoldID     string    `json:"hold_id"`
	ShowtimeID string    `json:"showtime_id"`
	Seats      []Seat    `json:"seats"`
	ExpiresAt  time.Time `json:"expires_at"`
	TTLSeconds int       `json:"ttl_seconds"`
	Message    string    `json:"message"`
}

// Hold represents a temporary seat hold in Redis
type Hold struct {
	HoldID     string    `json:"hold_id"`
	ShowtimeID string    `json:"showtime_id"`
	SeatIDs    []string  `json:"seat_ids"`
	SessionID  string    `json:"session_id"`
	ExpiresAt  time.Time `json:"expires_at"`
	CreatedAt  time.Time `json:"created_at"`
}

// ReleaseHoldRequest represents a request to release a hold
type ReleaseHoldRequest struct {
	SessionID string `json:"session_id"`
}

// ReserveRequest represents a request to confirm a reservation
type ReserveRequest struct {
	HoldID    string `json:"hold_id"`
	BookingID string `json:"booking_id"`
}

// Reservation represents a confirmed seat reservation in MongoDB
type Reservation struct {
	ReservationID string    `json:"reservation_id" bson:"reservation_id"`
	BookingID     string    `json:"booking_id" bson:"booking_id"`
	ShowtimeID    string    `json:"showtime_id" bson:"showtime_id"`
	SeatIDs       []string  `json:"seat_ids" bson:"seat_ids"`
	SessionID     string    `json:"session_id" bson:"session_id"`
	ConfirmedAt   time.Time `json:"confirmed_at" bson:"confirmed_at"`
}

// ReservationResponse represents the response after confirming a reservation
type ReservationResponse struct {
	ReservationID string    `json:"reservation_id"`
	BookingID     string    `json:"booking_id"`
	ShowtimeID    string    `json:"showtime_id"`
	Seats         []Seat    `json:"seats"`
	ConfirmedAt   time.Time `json:"confirmed_at"`
	Message       string    `json:"message"`
}

// RoomLayout represents a room's seat configuration
type RoomLayout struct {
	RoomID    string           `json:"room_id" bson:"room_id"`
	Name      string           `json:"name" bson:"name"`
	Rows      int              `json:"rows" bson:"rows"`
	Columns   int              `json:"columns" bson:"columns"`
	Seats     []SeatDefinition `json:"seats" bson:"seats"`
	CreatedAt time.Time        `json:"created_at" bson:"created_at"`
	UpdatedAt time.Time        `json:"updated_at" bson:"updated_at"`
}

// SeatDefinition defines a seat in the room layout
type SeatDefinition struct {
	ID            string   `json:"id" bson:"id"`
	Row           string   `json:"row" bson:"row"`
	Number        int      `json:"number" bson:"number"`
	Type          SeatType `json:"type" bson:"type"`
	PriceModifier float64  `json:"price_modifier,omitempty" bson:"price_modifier,omitempty"`
}

// UnavailableSeat provides details about why a seat is not available
type UnavailableSeat struct {
	SeatID    string     `json:"seat_id"`
	Status    SeatStatus `json:"status"`
	HeldBy    string     `json:"held_by,omitempty"`
	HeldUntil *time.Time `json:"held_until,omitempty"`
}

// ConflictError represents a conflict error response
type ConflictError struct {
	Code             string            `json:"code"`
	Message          string            `json:"message"`
	UnavailableSeats []UnavailableSeat `json:"unavailable_seats"`
}

// Error represents a standard error response
type Error struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
