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
	log "github.com/sirupsen/logrus"
)

const makeBookingResponse = "Booking has been created successfully"

// MakeBooking creates a new booking using the SAGA pattern.
// Flow: ValidateShowtime -> VerifyHold -> ProcessPayment -> ConfirmSeats -> CreateTicket -> SendNotification
// Compensations: PaymentFail->ReleaseHold, SeatConfirmFail->Refund+ReleaseHold
func (a API) MakeBooking(c echo.Context) error {
	c.Request().Header.Set("Content-Type", echo.MIMEApplicationJSONCharsetUTF8)

	sp := tracing.CreateChildSpan(c, "make-booking-handler-saga")
	defer sp.Finish()

	// Parse request
	b := new(models.BookingRequest)
	if err := c.Bind(b); err != nil {
		return sendError(c, http.StatusBadRequest, "INVALID_REQUEST", "Could not get Booking Request data", err)
	}

	// Validate required fields
	if b.Booking.ShowtimeID == "" || b.Booking.HoldID == "" || b.Booking.SessionID == "" {
		return sendError(c, http.StatusBadRequest, "INVALID_REQUEST", "showtime_id, hold_id, and session_id are required", nil)
	}

	// SAGA Step 1: Validate showtime exists
	sp.LogEvent("SAGA Step 1: Validating showtime")
	showtime, err := a.client.API.GetShowtime(b.Booking.ShowtimeID)
	if err != nil {
		return sendError(c, http.StatusNotFound, "SHOWTIME_NOT_FOUND", "Showtime not found: "+b.Booking.ShowtimeID, err)
	}
	if showtime.Status != "scheduled" {
		return sendError(c, http.StatusConflict, "SHOWTIME_UNAVAILABLE", "Showtime is not available for booking", nil)
	}

	// SAGA Step 2: Verify seat hold
	sp.LogEvent("SAGA Step 2: Verifying seat hold")
	hold, err := a.client.API.VerifyHold(b.Booking.HoldID, b.Booking.SessionID)
	if err != nil {
		return sendError(c, http.StatusNotFound, "HOLD_EXPIRED", "Hold has expired or not found. Please select seats again.", err)
	}
	if hold.ShowtimeID != b.Booking.ShowtimeID {
		return sendError(c, http.StatusConflict, "HOLD_MISMATCH", "Hold does not match the requested showtime", nil)
	}

	// SAGA Step 3: Process payment
	sp.LogEvent("SAGA Step 3: Processing payment")
	paymentResult, err := ctrls.MakePayment(b, showtime, a.client)
	if err != nil {
		// Compensation: Release hold on payment failure
		sp.LogEvent("SAGA Compensation: Releasing hold due to payment failure")
		if releaseErr := a.client.API.ReleaseHold(b.Booking.HoldID, b.Booking.SessionID); releaseErr != nil {
			log.WithError(releaseErr).Error("Failed to release hold during compensation")
		}
		return sendError(c, http.StatusInternalServerError, "PAYMENT_FAILED", "Payment processing failed", err)
	}
	paymentMap := paymentResult.(*map[string]interface{})
	charge := (*paymentMap)["charge"].(map[string]interface{})
	chargeID := charge["id"].(string)

	// SAGA Step 4: Confirm seat reservation
	sp.LogEvent("SAGA Step 4: Confirming seat reservation")
	reservation, err := a.client.API.ReserveSeats(b.Booking.HoldID, "pending_"+chargeID)
	if err != nil {
		// Compensation: Refund payment on seat confirmation failure
		sp.LogEvent("SAGA Compensation: Refunding payment due to seat confirmation failure")
		if refundErr := a.client.API.RefundPayment(chargeID, "Seat confirmation failed"); refundErr != nil {
			log.WithError(refundErr).Error("Failed to refund payment during compensation")
		}
		return sendError(c, http.StatusInternalServerError, "SEAT_CONFIRMATION_FAILED", "Failed to confirm seat reservation", err)
	}

	// SAGA Step 5: Create ticket in database
	sp.LogEvent("SAGA Step 5: Creating ticket in database")
	ticket, err := ctrls.CreateTicket(b, showtime, reservation, paymentMap, a.db)
	if err != nil {
		// Compensation: This is more complex - seats are reserved, payment is done
		// In production, we might need a manual reconciliation process
		sp.LogEvent("SAGA Compensation: Ticket creation failed - manual intervention may be needed")
		log.WithError(err).Error("Failed to create ticket after successful payment and reservation")
		return sendError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Failed to create ticket", err)
	}

	// Update reservation with actual booking ID
	// (In production, we'd call seat-service to update the booking_id)

	// SAGA Step 6: Send notification (non-critical, no compensation needed)
	sp.LogEvent("SAGA Step 6: Sending notification")
	notificationMsg := "Email sent successfully"
	notificationResult, err := a.client.API.NotificationWall(ticket)
	if err != nil {
		log.WithError(err).Warn("Failed to send notification email - non-critical")
		notificationMsg = "Email notification failed (non-critical)"
	} else {
		nrp := *notificationResult.(*map[string]interface{})
		if msg, ok := nrp["msg"].(string); ok {
			notificationMsg = msg
		}
	}

	// Build response
	paymentMsg := "Payment has been charged successfully"
	if version, ok := (*paymentMap)["version"].(string); ok {
		paymentMsg += " with " + version
	}

	sp.LogEvent("SAGA completed successfully: " + makeBookingResponse)

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"msg":          makeBookingResponse,
		"notification": notificationMsg,
		"ticket":       ticket,
		"payment":      paymentMsg,
	})
}

// sendError sends a structured error response
func sendError(c echo.Context, status int, code, message string, err error) error {
	resp := models.BookingError{
		Code:    code,
		Message: message,
	}
	if err != nil {
		resp.Details = map[string]interface{}{
			"error": err.Error(),
		}
	}
	return c.JSON(status, resp)
}

// GetOrderByID retrieves a booking by its order ID.
func (a API) GetOrderByID(c echo.Context) error {
	var p map[string]interface{}

	id := c.Param("orderId")
	query := bson.M{"order_id": id}

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
