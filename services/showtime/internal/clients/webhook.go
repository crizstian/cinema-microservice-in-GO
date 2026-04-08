package clients

import (
	"cinemas/services/showtime/internal/models"

	log "github.com/sirupsen/logrus"
)

// NoOpWebhookSender is a webhook sender that does nothing (for testing)
type NoOpWebhookSender struct{}

// NewNoOpWebhookSender creates a no-op webhook sender
func NewNoOpWebhookSender() *NoOpWebhookSender {
	return &NoOpWebhookSender{}
}

// Send logs the event but doesn't actually send it
func (w *NoOpWebhookSender) Send(event models.WebhookEvent) error {
	log.Infof("Webhook event (no-op): %s", event.Event)
	return nil
}
