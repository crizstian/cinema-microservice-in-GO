package ctrls

import (
	"cinemas/services/booking/internal/config"
	"cinemas/services/booking/internal/models"
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/mongo"
)

// MakePayment processes a payment for the booking (v2 with showtime info).
func MakePayment(b *models.BookingRequest, showtime *models.Showtime, c *config.Client) (interface{}, error) {
	d := fmt.Sprintf(`Ticket(s) for showtime %s, seats %s`,
		showtime.ID, strings.Join(b.Booking.Seats, ","))

	p := models.Payment{
		UserName:    b.User.Name + " " + b.User.LastName,
		Currency:    "mxn",
		Number:      b.User.CreditCard.Number,
		Cvc:         b.User.CreditCard.Cvc,
		ExpMonth:    b.User.CreditCard.ExpMonth,
		ExpYear:     b.User.CreditCard.ExpYear,
		Amount:      b.Booking.TotalAmount,
		Description: d,
	}

	return c.API.PaymentWall(p)
}

// CreateTicket creates a ticket in the database after successful payment (v2).
func CreateTicket(
	b *models.BookingRequest,
	showtime *models.Showtime,
	reservation *models.ReservationResponse,
	payResponse *map[string]interface{},
	db *mongo.Database,
) (models.Ticket, error) {
	charge := (*payResponse)["charge"].(map[string]interface{})

	ticket := models.Ticket{
		BookingID:     "bkg_" + uuid.New().String()[:8],
		ShowtimeID:    showtime.ID,
		ReservationID: reservation.ReservationID,
		MovieTitle:    "", // Will be enriched by caller or movie-service
		CinemaName:    "", // Will be enriched by caller or cinema-service
		RoomNumber:    showtime.RoomNumber,
		StartTime:     showtime.StartTime,
		Seats:         b.Booking.Seats,
		TotalAmount:   b.Booking.TotalAmount,
		OrderID:       charge["id"].(string),
		ReceiptURL:    getStringOrEmpty(charge, "receipt_url"),
		UserName:      b.User.Name + " " + b.User.LastName,
		Email:         b.User.Email,
		CreatedAt:     time.Now(),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := db.Collection("booking").InsertOne(ctx, ticket)
	if err != nil {
		return models.Ticket{}, err
	}

	return ticket, nil
}

// getStringOrEmpty safely extracts a string from a map
func getStringOrEmpty(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
