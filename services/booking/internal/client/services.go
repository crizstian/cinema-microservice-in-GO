package client

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"cinemas/services/booking/internal/models"
)

var basePaymentURL string
var baseNotificationURL string
var baseSeatURL string
var baseShowtimeURL string

// Operations holds the HTTP client for service calls
type Operations struct {
	Client *Client
}

// Services defines the interface for all external service calls
type Services interface {
	// Payment operations
	PaymentWall(createRequest interface{}) (interface{}, error)
	RefundPayment(chargeID, reason string) error

	// Notification operations
	NotificationWall(createRequest interface{}) (interface{}, error)

	// Showtime operations
	GetShowtime(showtimeID string) (*models.Showtime, error)

	// Seat operations
	VerifyHold(holdID, sessionID string) (*models.HoldResponse, error)
	ReserveSeats(holdID, bookingID string) (*models.ReservationResponse, error)
	ReleaseHold(holdID, sessionID string) error

	// URL setters
	SetBasePaymentURL(url string)
	SetNotificationURL(url string)
	SetBaseSeatURL(url string)
	SetBaseShowtimeURL(url string)

	// URL getters
	GetBasePaymentURL() string
	GetNotificationURL() string
	GetBaseSeatURL() string
	GetBaseShowtimeURL() string
}

// PaymentWall ...
func (o Operations) PaymentWall(createRequest interface{}) (interface{}, error) {
	// Timeout de 5 segundos para evitar bloqueos en payment service
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	url := basePaymentURL + "/payment/makePurchase"

	req, err := o.Client.NewRequest(ctx, http.MethodPost, url, createRequest)
	paymentResponse := new(map[string]interface{})

	if err != nil {
		return nil, err
	}

	return paymentResponse, o.Client.Do(ctx, req, paymentResponse)
}

// NotificationWall ...
func (o Operations) NotificationWall(createRequest interface{}) (interface{}, error) {
	// Timeout de 3 segundos para notificaciones (pueden ser asíncronas)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := baseNotificationURL + "/notification/sendEmail"

	req, err := o.Client.NewRequest(ctx, http.MethodPost, url, createRequest)
	nr := new(map[string]interface{})

	if err != nil {
		return nil, err
	}

	return nr, o.Client.Do(ctx, req, nr)
}

// SetBasePaymentURL ...
func (o Operations) SetBasePaymentURL(url string) {
	basePaymentURL = url
}

// SetNotificationURL ...
func (o Operations) SetNotificationURL(url string) {
	baseNotificationURL = url
}

// GetBasePaymentURL ...
func (o Operations) GetBasePaymentURL() string {
	return basePaymentURL
}

// GetNotificationURL returns the notification service base URL
func (o Operations) GetNotificationURL() string {
	return baseNotificationURL
}

// SetBaseSeatURL sets the seat service base URL
func (o Operations) SetBaseSeatURL(url string) {
	baseSeatURL = url
}

// GetBaseSeatURL returns the seat service base URL
func (o Operations) GetBaseSeatURL() string {
	return baseSeatURL
}

// SetBaseShowtimeURL sets the showtime service base URL
func (o Operations) SetBaseShowtimeURL(url string) {
	baseShowtimeURL = url
}

// GetBaseShowtimeURL returns the showtime service base URL
func (o Operations) GetBaseShowtimeURL() string {
	return baseShowtimeURL
}

// GetShowtime retrieves showtime details from showtime-service
func (o Operations) GetShowtime(showtimeID string) (*models.Showtime, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := fmt.Sprintf("%s/showtimes/%s", baseShowtimeURL, showtimeID)

	req, err := o.Client.NewRequest(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	showtime := new(models.Showtime)
	if err := o.Client.Do(ctx, req, showtime); err != nil {
		return nil, err
	}

	return showtime, nil
}

// VerifyHold verifies that a seat hold exists and is valid
func (o Operations) VerifyHold(holdID, sessionID string) (*models.HoldResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := fmt.Sprintf("%s/seats/hold/%s?session_id=%s", baseSeatURL, holdID, sessionID)

	req, err := o.Client.NewRequest(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	hold := new(models.HoldResponse)
	if err := o.Client.Do(ctx, req, hold); err != nil {
		return nil, err
	}

	return hold, nil
}

// ReserveSeats confirms the seat reservation after payment
func (o Operations) ReserveSeats(holdID, bookingID string) (*models.ReservationResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	url := fmt.Sprintf("%s/seats/reserve", baseSeatURL)

	reserveReq := models.ReserveRequest{
		HoldID:    holdID,
		BookingID: bookingID,
	}

	req, err := o.Client.NewRequest(ctx, http.MethodPost, url, reserveReq)
	if err != nil {
		return nil, err
	}

	reservation := new(models.ReservationResponse)
	if err := o.Client.Do(ctx, req, reservation); err != nil {
		return nil, err
	}

	return reservation, nil
}

// ReleaseHold releases a seat hold (compensation action)
func (o Operations) ReleaseHold(holdID, sessionID string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := fmt.Sprintf("%s/seats/hold/%s", baseSeatURL, holdID)

	releaseReq := models.ReleaseHoldRequest{
		SessionID: sessionID,
	}

	req, err := o.Client.NewRequest(ctx, http.MethodDelete, url, releaseReq)
	if err != nil {
		return err
	}

	return o.Client.Do(ctx, req, nil)
}

// RefundPayment requests a refund from payment-service (compensation action)
func (o Operations) RefundPayment(chargeID, reason string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Payment service uses /{id}/refund pattern
	url := fmt.Sprintf("%s/payment/%s/refund", basePaymentURL, chargeID)

	refundReq := struct {
		Reason string `json:"reason"`
	}{
		Reason: reason,
	}

	req, err := o.Client.NewRequest(ctx, http.MethodPost, url, refundReq)
	if err != nil {
		return err
	}

	return o.Client.Do(ctx, req, nil)
}
