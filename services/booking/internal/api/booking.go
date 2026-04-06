package api

import (
	"cinemas/services/booking/internal/config"
	"cinemas/services/booking/internal/ctrls"
	errs "cinemas/services/booking/internal/errors"
	"cinemas/services/booking/internal/models"
	"cinemas/services/booking/internal/tracing"
	"context"
	"errors"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"

	"github.com/labstack/echo"
)

const makeBookingResponse = "Booking has been created successfully"

// MakeBooking creates a new booking with payment and notification.
func (a API) MakeBooking(c echo.Context) error {

	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	sp := tracing.CreateChildSpan(c, "make-booking-handler")
	defer sp.Finish()

	b := new(models.BookingRequest)

	if err := c.Bind(b); err != nil {
		return errs.SendWithOpenTracing(sp, "User", "Could not get Booking Request data", err)
	}

	pr := tracing.TraceFunction(sp, ctrls.MakePayment, b, a.client)
	prp := pr[0].Interface().(*map[string]interface{})
	prv := *prp

	if e := pr[1].Interface(); e != nil {
		return errs.SendWithOpenTracing(sp, "External", "An error ocurred with the Payment Wall", e.(error))
	}

	t := tracing.TraceFunction(sp, ctrls.CreateTicket, prp, b, a.db)
	ticket := t[0].Interface().(models.Ticket)

	if e := t[1].Interface(); e != nil {
		return errs.SendWithOpenTracing(sp, "External", "Could not insert ticket into DB", e.(error))
	}

	n := tracing.TraceFunction(sp, a.client.API.NotificationWall, ticket)
	nrp := *n[0].Interface().(*map[string]interface{})

	if e := n[1].Interface(); e != nil {
		return errs.SendWithOpenTracing(sp, "External", "Could not send email to user", e.(error))
	}

	pm := "Payment has been charged succuessfully"
	if prv["version"] != nil {
		pm += " with " + prv["version"].(string)
	}

	sp.LogEvent("Called MakeBooking function, with response: " + makeBookingResponse)

	res := map[string]interface{}{
		"msg":          makeBookingResponse,
		"notification": nrp["msg"].(string),
		"ticket":       ticket,
		"payment":      pm,
	}

	return c.JSON(http.StatusCreated, res)
}

// GetOrderByID retrieves a booking by its order ID.
func (a API) GetOrderByID(c echo.Context) error {
	var p map[string]interface{}

	id := c.Param("id")
	query := bson.M{"orderid": id}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err := a.db.Collection("booking").FindOne(ctx, query).Decode(&p)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return errs.Send("external", "Order not found", err)
		}
		return errs.Send("external", "Failed to GetOrderByID", err)
	}

	res := map[string]interface{}{
		"ticket": p,
		"msg":    "ticket details",
	}

	return c.JSON(http.StatusOK, res)
}

type (
	// API holds the database and client connections.
	API struct {
		db     *mongo.Database
		client *config.Client
	}

	// Repository defines the booking repository interface.
	Repository interface {
		MakeBooking(c echo.Context) error
		GetOrderByID(c echo.Context) error
	}
)

// Connect initializes the API with a database connection and client.
func Connect(db *mongo.Database, client *config.Client) (Repository, error) {
	if db == nil {
		return nil, errs.Send("Internal", "Failed to initialize repository", errors.New("db object is empty"))
	}
	api := new(API)
	api.db = db
	api.client = client

	return api, nil
}
