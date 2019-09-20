package api

import (
	errs "cinemas-microservices/payment-service/src/errors"
	"cinemas-microservices/payment-service/src/models"
	"errors"
	"net/http"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/client"

	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"

	"github.com/labstack/echo"
)

// RegisterPurchase ...
func (a API) RegisterPurchase(c echo.Context) error {
	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	p := new(models.Payment)

	if err := c.Bind(p); err != nil {
		return errs.Send("User", "Could not get Payment data", err)
	}

	chargeParams := &stripe.ChargeParams{
		Amount:      stripe.Int64(p.Amount * 100),
		Currency:    stripe.String(p.Currency),
		Description: stripe.String(p.Description),
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number:   stripe.String(p.Number),
				CVC:      stripe.String(p.Cvc),
				ExpMonth: stripe.String(p.ExpMonth),
				ExpYear:  stripe.String(p.ExpYear),
			},
		},
	}

	ch, err := a.stripe.Charges.New(chargeParams)
	if err != nil {
		return errs.Send("External", "Stripe Error", err)
	}

	if err = a.db.C("payments").Insert(ch); err != nil {
		return errs.Send("External", "Could not insert payment into DB", err)
	}

	res := map[string]interface{}{
		"user":   p.UserName,
		"amount": p.Amount,
		"charge": ch,
	}

	return c.JSON(http.StatusOK, res)
}

// GetPurchaseByID ...
func (a API) GetPurchaseByID(c echo.Context) error {
	var p map[string]interface{}

	id := c.Param("id")
	// projection := bson.M{"_id": 0, "id": 1, "title": 1, "format": 1}
	query := bson.M{"id": id}

	err := a.db.C("payments").Find(query).One(&p)

	if err != nil {
		return errs.Send("external", "Failed to GetMovieByID", err)
	}

	res := map[string]interface{}{
		"payment": p,
		"msg":     "payment details",
	}

	return c.JSON(http.StatusOK, res)
}

type (
	// API ...
	API struct {
		db     *mgo.Database
		stripe *client.API
	}

	// Repository ...
	Repository interface {
		RegisterPurchase(c echo.Context) error
		GetPurchaseByID(c echo.Context) error
	}
)

// Connect ...
func Connect(db *mgo.Database, stripe *client.API) (Repository, error) {
	if db == nil {
		return nil, errs.Send("Internal", "Failed to initialize repository", errors.New("db object is empty"))
	}
	api := new(API)
	api.db = db
	api.stripe = stripe

	return api, nil
}
