package service

import (
	"cinemas/services/booking/internal/config"
	"cinemas/services/booking/internal/ctrls"
	"cinemas/services/booking/internal/models"
	"context"
	"errors"

	log "github.com/sirupsen/logrus"
	"gopkg.in/mgo.v2"
)

// BookingService encapsula la lógica de negocio de reservas
type BookingService struct {
	db     *mgo.Database
	client *config.Client
}

// NewBookingService crea una nueva instancia del servicio
func NewBookingService(db *mgo.Database, client *config.Client) *BookingService {
	return &BookingService{
		db:     db,
		client: client,
	}
}

// CreateBooking orquesta el proceso completo de crear una reserva:
// 1. Procesar pago
// 2. Crear ticket en DB
// 3. Enviar notificación (no bloquea si falla)
func (s *BookingService) CreateBooking(ctx context.Context, req *models.BookingRequest) (*models.Ticket, error) {
	// Validación básica
	if req == nil || req.User.Name == "" {
		return nil, errors.New("invalid booking request")
	}

	// 1. Procesar pago
	paymentResp, err := ctrls.MakePayment(req, s.client)
	if err != nil {
		log.WithFields(log.Fields{
			"user":  req.User.Name,
			"error": err.Error(),
		}).Error("Payment failed")
		return nil, errors.New("payment failed: " + err.Error())
	}

	paymentData, ok := paymentResp.(*map[string]interface{})
	if !ok {
		return nil, errors.New("invalid payment response format")
	}

	// 2. Crear ticket en DB
	ticket, err := ctrls.CreateTicket(paymentData, req, s.db)
	if err != nil {
		// TODO: Implementar compensación (reversar pago)
		log.WithFields(log.Fields{
			"user":  req.User.Name,
			"error": err.Error(),
		}).Error("Ticket creation failed")
		return nil, errors.New("ticket creation failed: " + err.Error())
	}

	// 3. Enviar notificación (asíncrono, no bloqueante)
	go func() {
		_, notifErr := s.client.API.NotificationWall(ticket)
		if notifErr != nil {
			log.WithFields(log.Fields{
				"ticket_id": ticket.OrderID,
				"error":     notifErr.Error(),
			}).Warn("Notification failed (non-blocking)")
			// En producción: enviar a cola de retry
		}
	}()

	log.WithFields(log.Fields{
		"ticket_id": ticket.OrderID,
		"user":      req.User.Name,
	}).Info("Booking created successfully")

	return &ticket, nil
}
