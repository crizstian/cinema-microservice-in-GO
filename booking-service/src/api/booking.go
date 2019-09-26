package api

import (
	"cinemas-microservices/booking-service/src/config"
	"cinemas-microservices/booking-service/src/ctrls"
	errs "cinemas-microservices/booking-service/src/errors"
	"cinemas-microservices/booking-service/src/models"
	"errors"
	"net/http"

	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"

	"github.com/labstack/echo"
)

// MakeBooking ...
func (a API) MakeBooking(c echo.Context) error {
	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	b := new(models.BookingRequest)

	if err := c.Bind(b); err != nil {
		return errs.Send("User", "Could not get Booking Request data", err)
	}

	pr, err := ctrls.MakePayment(b, a.client)

	if err != nil {
		return errs.Send("External", "An error ocurred with the Payment Wall", err)
	}

	ticket, err := ctrls.CreateTicket(pr, b, a.db)

	if err != nil {
		return errs.Send("External", "Could not insert ticket into DB", err)
	}

	nr, err := a.client.API.NotificationWall(ticket)

	if err != nil {
		return errs.Send("External", "Could not send email to user", err)
	}

	nrp := *nr.(*map[string]interface{})

	res := map[string]interface{}{
		"msg":  "Booking has bee created successfully",
		"note": nrp["msg"].(string),
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
