package api

import (
	"cinemas-microservices/booking-service/src/config"
	"cinemas-microservices/booking-service/src/ctrls"
	errs "cinemas-microservices/booking-service/src/errors"
	"cinemas-microservices/booking-service/src/models"
	"cinemas-microservices/booking-service/src/tracing"
	"errors"
	"net/http"

	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"

	"github.com/labstack/echo"
)

const makeBookingResponse = "Booking has been created successfully"

// MakeBooking ...
func (a API) MakeBooking(c echo.Context) error {

	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	sp := tracing.CreateChildSpan(c, "MakeBooking handler")
	defer sp.Finish()

	b := new(models.BookingRequest)

	if err := c.Bind(b); err != nil {
		return errs.SendWithOpenTracing(sp, "User", "Could not get Booking Request data", err)
	}

	pr := tracing.TraceFunction(c, ctrls.MakePayment, b, a.client)
	prp := pr[0].Interface().(*map[string]interface{})
	prv := *prp

	if e := pr[1].Interface(); e != nil {
		return errs.SendWithOpenTracing(sp, "External", "An error ocurred with the Payment Wall", e.(error))
	}

	t := tracing.TraceFunction(c, ctrls.CreateTicket, prp, b, a.db)
	ticket := t[0].Interface().(models.Ticket)

	if e := t[1].Interface(); e != nil {
		return errs.SendWithOpenTracing(sp, "External", "Could not insert ticket into DB", e.(error))
	}

	n := tracing.TraceFunction(c, a.client.API.NotificationWall, ticket)
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

// GetOrderByID ...
func (a API) GetOrderByID(c echo.Context) error {
	var p map[string]interface{}

	id := c.Param("id")
	// projection := bson.M{"_id": 0, "id": 1, "title": 1, "format": 1}
	query := bson.M{"orderid": id}

	err := a.db.C("booking").Find(query).One(&p)

	if err != nil {
		return errs.Send("external", "Failed to GetOrderByID", err)
	}

	res := map[string]interface{}{
		"ticket": p,
		"msg":    "ticket details",
	}

	return c.JSON(http.StatusOK, res)
}

type (
	// API ...
	API struct {
		db     *mgo.Database
		client *config.Client
	}

	// Repository ...
	Repository interface {
		MakeBooking(c echo.Context) error
		GetOrderByID(c echo.Context) error
	}
)

// Connect ...
func Connect(db *mgo.Database, client *config.Client) (Repository, error) {
	if db == nil {
		return nil, errs.Send("Internal", "Failed to initialize repository", errors.New("db object is empty"))
	}
	api := new(API)
	api.db = db
	api.client = client

	return api, nil
}
