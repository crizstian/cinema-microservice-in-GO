package models

import "time"

// BookingDetails represents the seat booking details (v2 with hold_id)
type BookingDetails struct {
	ShowtimeID  string   `json:"showtime_id" bson:"showtime_id"`
	HoldID      string   `json:"hold_id" bson:"hold_id"`
	SessionID   string   `json:"session_id" bson:"session_id"`
	Seats       []string `json:"seats" bson:"seats"`
	TotalAmount int      `json:"totalAmount" bson:"total_amount"`
}

// Ticket represents a confirmed booking ticket (v2)
type Ticket struct {
	BookingID     string    `json:"booking_id" bson:"booking_id"`
	ShowtimeID    string    `json:"showtime_id" bson:"showtime_id"`
	ReservationID string    `json:"reservation_id" bson:"reservation_id"`
	MovieTitle    string    `json:"movie_title" bson:"movie_title"`
	CinemaName    string    `json:"cinema_name" bson:"cinema_name"`
	RoomNumber    int       `json:"room_number" bson:"room_number"`
	StartTime     time.Time `json:"start_time" bson:"start_time"`
	Seats         []string  `json:"seats" bson:"seats"`
	TotalAmount   int       `json:"total_amount" bson:"total_amount"`
	OrderID       string    `json:"order_id" bson:"order_id"`
	ReceiptURL    string    `json:"receipt_url" bson:"receipt_url"`
	UserName      string    `json:"user_name" bson:"user_name"`
	Email         string    `json:"email" bson:"email"`
	CreatedAt     time.Time `json:"created_at" bson:"created_at"`
}

// CreditCard ...
type CreditCard struct {
	Number   string `json:"number"`
	Cvc      string `json:"cvc"`
	ExpMonth string `json:"exp_month"`
	ExpYear  string `json:"exp_year"`
}

// UserMember ...
type UserMember struct {
	Name        string     `json:"name"`
	LastName    string     `json:"lastName"`
	Email       string     `json:"email"`
	PhoneNumber string     `json:"phoneNumber"`
	CreditCard  CreditCard `json:"creditCard"`
	Membership  string     `json:"membership"`
}

// BookingRequest represents the request body for creating a booking (v2)
type BookingRequest struct {
	User    UserMember     `json:"user"`
	Booking BookingDetails `json:"booking"`
}

// Payment represents the payment request to payment-service
type Payment struct {
	UserName    string `json:"userName"`
	Currency    string `json:"currency"`
	Number      string `json:"number"`
	Cvc         string `json:"cvc"`
	ExpMonth    string `json:"exp_month"`
	ExpYear     string `json:"exp_year"`
	Amount      int    `json:"amount"`
	Description string `json:"description"`
}

// Showtime represents the response from showtime-service
type Showtime struct {
	ID             string    `json:"id"`
	MovieID        string    `json:"movie_id"`
	CinemaID       string    `json:"cinema_id"`
	RoomNumber     int       `json:"room_number"`
	StartTime      time.Time `json:"start_time"`
	EndTime        time.Time `json:"end_time"`
	AvailableSeats int       `json:"available_seats"`
	Status         string    `json:"status"`
}

// HoldResponse represents the response from seat-service hold verification
type HoldResponse struct {
	HoldID     string    `json:"hold_id"`
	ShowtimeID string    `json:"showtime_id"`
	Seats      []string  `json:"seats"`
	SessionID  string    `json:"session_id"`
	ExpiresAt  time.Time `json:"expires_at"`
	TTLSeconds int       `json:"ttl_seconds"`
}

// ReserveRequest represents the request to seat-service to confirm reservation
type ReserveRequest struct {
	HoldID    string `json:"hold_id"`
	BookingID string `json:"booking_id"`
}

// SeatInfo represents seat information from seat-service
type SeatInfo struct {
	ID     string `json:"id"`
	Row    string `json:"row"`
	Number int    `json:"number"`
	Type   string `json:"type"`
	Status string `json:"status"`
}

// ReservationResponse represents the response from seat-service reservation
type ReservationResponse struct {
	ReservationID string     `json:"reservation_id"`
	BookingID     string     `json:"booking_id"`
	ShowtimeID    string     `json:"showtime_id"`
	Seats         []SeatInfo `json:"seats"`
	ConfirmedAt   time.Time  `json:"confirmed_at"`
}

// GetSeatIDs returns just the seat IDs as strings
func (r *ReservationResponse) GetSeatIDs() []string {
	ids := make([]string, len(r.Seats))
	for i, s := range r.Seats {
		ids[i] = s.ID
	}
	return ids
}

// RefundRequest represents the request to payment-service for refund
type RefundRequest struct {
	ChargeID string `json:"charge_id"`
	Reason   string `json:"reason"`
}

// ReleaseHoldRequest represents the request to seat-service to release a hold
type ReleaseHoldRequest struct {
	SessionID string `json:"session_id"`
}

// BookingError represents a structured error response
type BookingError struct {
	Code    string                 `json:"code"`
	Message string                 `json:"message"`
	Details map[string]interface{} `json:"details,omitempty"`
}
