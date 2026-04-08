package service

import (
	"cinemas/services/booking/internal/config"
	"cinemas/services/booking/internal/ctrls"
	"cinemas/services/booking/internal/models"
	"context"
	"errors"

	log "github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/mongo"
)

// BookingService encapsula la lógica de negocio de reservas con patrón SAGA
type BookingService struct {
	db     *mongo.Database
	client *config.Client
}

// NewBookingService crea una nueva instancia del servicio
func NewBookingService(db *mongo.Database, client *config.Client) *BookingService {
	return &BookingService{
		db:     db,
		client: client,
	}
}

// CreateBooking orquesta el proceso completo de crear una reserva usando SAGA:
// 1. Validar showtime
// 2. Verificar hold de asientos
// 3. Procesar pago
// 4. Confirmar reserva de asientos
// 5. Crear ticket en DB
// 6. Enviar notificación (no bloquea si falla)
func (s *BookingService) CreateBooking(ctx context.Context, req *models.BookingRequest) (*models.Ticket, error) {
	// Validación básica
	if req == nil || req.User.Name == "" {
		return nil, errors.New("invalid booking request")
	}
	if req.Booking.ShowtimeID == "" || req.Booking.HoldID == "" || req.Booking.SessionID == "" {
		return nil, errors.New("showtime_id, hold_id, and session_id are required")
	}

	// SAGA Step 1: Validar showtime
	showtime, err := s.client.API.GetShowtime(req.Booking.ShowtimeID)
	if err != nil {
		return nil, errors.New("showtime not found: " + err.Error())
	}
	if showtime.Status != "scheduled" {
		return nil, errors.New("showtime is not available for booking")
	}

	// SAGA Step 2: Verificar hold de asientos
	hold, err := s.client.API.VerifyHold(req.Booking.HoldID, req.Booking.SessionID)
	if err != nil {
		return nil, errors.New("hold expired or not found: " + err.Error())
	}
	if hold.ShowtimeID != req.Booking.ShowtimeID {
		return nil, errors.New("hold does not match the requested showtime")
	}

	// SAGA Step 3: Procesar pago
	paymentResp, err := ctrls.MakePayment(req, showtime, s.client)
	if err != nil {
		// Compensación: liberar hold
		if releaseErr := s.client.API.ReleaseHold(req.Booking.HoldID, req.Booking.SessionID); releaseErr != nil {
			log.WithError(releaseErr).Error("Failed to release hold during payment compensation")
		}
		return nil, errors.New("payment failed: " + err.Error())
	}

	paymentData, ok := paymentResp.(*map[string]interface{})
	if !ok {
		return nil, errors.New("invalid payment response format")
	}
	charge := (*paymentData)["charge"].(map[string]interface{})
	chargeID := charge["id"].(string)

	// SAGA Step 4: Confirmar reserva de asientos
	reservation, err := s.client.API.ReserveSeats(req.Booking.HoldID, "pending_"+chargeID)
	if err != nil {
		// Compensación: refund del pago
		if refundErr := s.client.API.RefundPayment(chargeID, "Seat confirmation failed"); refundErr != nil {
			log.WithError(refundErr).Error("Failed to refund during seat confirmation compensation")
		}
		return nil, errors.New("seat confirmation failed: " + err.Error())
	}

	// SAGA Step 5: Crear ticket en DB
	ticket, err := ctrls.CreateTicket(req, showtime, reservation, paymentData, s.db)
	if err != nil {
		log.WithError(err).Error("Ticket creation failed - manual intervention may be needed")
		return nil, errors.New("ticket creation failed: " + err.Error())
	}

	// SAGA Step 6: Enviar notificación (asíncrono, no bloqueante)
	go func() {
		_, notifErr := s.client.API.NotificationWall(ticket)
		if notifErr != nil {
			log.WithFields(log.Fields{
				"booking_id": ticket.BookingID,
				"error":      notifErr.Error(),
			}).Warn("Notification failed (non-blocking)")
		}
	}()

	log.WithFields(log.Fields{
		"booking_id": ticket.BookingID,
		"user":       req.User.Name,
	}).Info("Booking created successfully via SAGA")

	return &ticket, nil
}
