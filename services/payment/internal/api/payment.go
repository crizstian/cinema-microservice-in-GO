package api

import (
	errs "cinemas/services/payment/internal/errors"
	"cinemas/services/payment/internal/models"
	"context"
	"errors"
	"net/http"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/client"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"

	"github.com/labstack/echo"
)

// RegisterPurchase processes a payment and stores it in the database.
func (a API) RegisterPurchase(c echo.Context) error {
	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	p := new(models.Payment)

	if err := c.Bind(p); err != nil {
		return errs.Send("User", "Could not get Payment data", err)
	}

	// Validación defensiva del monto
	if p.Amount <= 0 {
		return errs.Send("User", "Invalid amount, must be greater than 0", errors.New("amount must be > 0"))
	}

	var ch interface{}

	if a.mockMode {
		// Mock mode: return a fake charge without calling Stripe
		ch = map[string]interface{}{
			"id":       "ch_mock_" + time.Now().Format("20060102150405"),
			"amount":   p.Amount * 100,
			"currency": p.Currency,
			"status":   "succeeded",
			"paid":     true,
			"receipt_url": "https://mock.stripe.com/receipts/mock_receipt",
		}
	} else {
		chargeParams := &stripe.ChargeParams{
			Amount:      stripe.Int64(p.Amount * 100), // p.Amount en unidades de moneda (no centavos)
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

		var err error
		ch, err = a.stripe.Charges.New(chargeParams)
		if err != nil {
			return errs.Send("External", "Stripe Error", err)
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := a.db.Collection("payments").InsertOne(ctx, ch)
	if err != nil {
		return errs.Send("External", "Could not insert payment into DB", err)
	}

	res := map[string]interface{}{
		"user":    p.UserName,
		"amount":  p.Amount,
		"charge":  ch,
		"version": "mock",
	}

	return c.JSON(http.StatusCreated, res)
}

// GetPurchaseByID retrieves a payment by its ID.
func (a API) GetPurchaseByID(c echo.Context) error {
	var p map[string]interface{}

	id := c.Param("id")
	query := bson.M{"id": id}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err := a.db.Collection("payments").FindOne(ctx, query).Decode(&p)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return errs.Send("External", "Payment not found", err)
		}
		return errs.Send("External", "Failed to GetPurchaseByID", err)
	}

	res := map[string]interface{}{
		"payment": p,
		"msg":     "payment details",
	}

	return c.JSON(http.StatusOK, res)
}

// RefundPayment processes a refund for an existing charge.
func (a API) RefundPayment(c echo.Context) error {
	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	chargeID := c.Param("id")
	if chargeID == "" {
		return errs.Send("User", "Missing charge ID", errors.New("charge_id is required"))
	}

	req := new(models.RefundRequest)
	if err := c.Bind(req); err != nil {
		return errs.Send("User", "Could not parse refund request", err)
	}

	if err := req.Validate(); err != nil {
		return errs.Send("User", err.Error(), err)
	}

	// Build refund params
	refundParams := &stripe.RefundParams{
		Charge: stripe.String(chargeID),
		Reason: stripe.String(req.Reason),
	}

	if req.Amount != nil {
		refundParams.Amount = stripe.Int64(*req.Amount)
	}

	// Process refund via Stripe
	refund, err := a.stripe.Refunds.New(refundParams)
	if err != nil {
		stripeErr, ok := err.(*stripe.Error)
		if ok && stripeErr.Code == stripe.ErrorCodeResourceMissing {
			return errs.Send("User", "Charge not found", err)
		}
		return errs.Send("External", "Stripe refund failed", err)
	}

	// Store refund record in database
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = a.db.Collection("refunds").InsertOne(ctx, refund)
	if err != nil {
		// Log but don't fail - refund was processed
		// In production, implement retry/compensation logic
	}

	response := models.RefundResponse{
		RefundID:       refund.ID,
		Status:         models.RefundStatus(refund.Status),
		AmountRefunded: refund.Amount,
		ChargeID:       chargeID,
		Reason:         req.Reason,
		CreatedAt:      time.Unix(refund.Created, 0),
	}

	return c.JSON(http.StatusOK, response)
}

type (
	// API holds the database and Stripe client.
	API struct {
		db       *mongo.Database
		stripe   *client.API
		mockMode bool
	}

	// Repository defines the payment repository interface.
	Repository interface {
		RegisterPurchase(c echo.Context) error
		GetPurchaseByID(c echo.Context) error
		RefundPayment(c echo.Context) error
	}
)

// Connect initializes the API with a database and Stripe client.
func Connect(db *mongo.Database, stripeClient *client.API, mockMode bool) (Repository, error) {
	if db == nil {
		// Mensaje de alto nivel; el mensaje interno se conserva en el error original
		return nil, errs.Send("Internal", "Failed to initialize repository", errors.New("db object is empty"))
	}

	api := &API{
		db:       db,
		stripe:   stripeClient,
		mockMode: mockMode,
	}

	return api, nil
}
