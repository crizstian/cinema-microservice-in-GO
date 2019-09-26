package ctrls

import (
	"cinemas-microservices/booking-service/src/config"
	"cinemas-microservices/booking-service/src/models"
	"fmt"
	"strings"

	"gopkg.in/mgo.v2"
)

// MakePayment ...
func MakePayment(b *models.BookingRequest, c *config.Client) (interface{}, error) {
	d := fmt.Sprintf(`
	Tickect(s) for movie %s,
	with seat(s) %s
	at time %s`, b.Booking.Movie.Title, strings.Join(b.Booking.Seats, ","), b.Booking.Schedule)

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

// CreateTicket ...
func CreateTicket(pr interface{}, b *models.BookingRequest, db *mgo.Database) (models.Ticket, error) {
	u := func() string {
		if b.User.Membership != "" {
			return "loyal"
		}
		return "normal"
	}()

	payResponse := *pr.(*map[string]interface{})
	charge := payResponse["charge"].(map[string]interface{})

	ticket := models.Ticket{
		Booking: models.Booking{
			City:        b.Booking.City,
			UserType:    u,
			TotalAmount: b.Booking.TotalAmount,
			Cinema:      b.Booking.Cinema,
			CinemaRoom:  b.Booking.CinemaRoom,
			Seats:       b.Booking.Seats,
			Movie: models.Movie{
				Title:   b.Booking.Movie.Title,
				Formtat: b.Booking.Movie.Formtat,
			},
			Schedule: b.Booking.Schedule,
		},
		OrderID:     charge["id"].(string),
		Description: charge["description"].(string),
		ReceiptURL:  charge["receipt_url"].(string),
		UserName:    b.User.Name + " " + b.User.LastName,
		Email:       b.User.Email,
	}

	if err := db.C("booking").Insert(ticket); err != nil {
		return models.Ticket{}, err
	}

	return ticket, nil
}
