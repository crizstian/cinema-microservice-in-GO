//go:build pact

package consumer

import (
	"fmt"
	"io"
	"net/http"
	"testing"

	"github.com/pact-foundation/pact-go/v2/consumer"
	"github.com/pact-foundation/pact-go/v2/matchers"
	"github.com/stretchr/testify/assert"
)

// NotificationClient is a simple HTTP client for notification-service
type NotificationClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

func TestBookingNotificationContract(t *testing.T) {
	mockProvider, err := consumer.NewV2Pact(consumer.MockHTTPProviderConfig{
		Consumer: "booking-service",
		Provider: "notification-service",
		PactDir:  "../../../contracts",
	})
	assert.NoError(t, err)

	// Test 1: Send booking confirmation email
	t.Run("POST /notification/sendEmail - successful email", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("email service is available").
			UponReceiving("a request to send booking confirmation").
			WithRequest("POST", "/notification/sendEmail", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"booking_id":     matchers.Regex("bkg_abc123", `^bkg_[a-zA-Z0-9]+$`),
					"showtime_id":    matchers.Regex("sht_test", `^sht_[a-zA-Z0-9]+$`),
					"reservation_id": matchers.Regex("res_xyz", `^res_[a-zA-Z0-9]+$`),
					"movie_title":    matchers.Like("Dune Part Two"),
					"cinema_name":    matchers.Like("Cinepolis Reforma"),
					"room_number":    matchers.Integer(5),
					"start_time":     matchers.Like("2024-12-20T19:30:00Z"),
					"seats":          matchers.EachLike("A1", 1),
					"total_amount":   matchers.Integer(450),
					"order_id":       matchers.Regex("ch_abc123", `^ch_[a-zA-Z0-9]+$`),
					"receipt_url":    matchers.Regex("https://pay.stripe.com/receipts/test", `^https://`),
					"user_name":      matchers.Like("John Doe"),
					"email":          matchers.Regex("john@example.com", `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`),
				})
			}).
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"msg":        matchers.String("Email sent successfully"),
					"message_id": matchers.Like("msg_abc123"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &NotificationClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifySendEmail(client)
			})

		assert.NoError(t, err)
	})

	// Test 2: Send email - invalid email address
	t.Run("POST /notification/sendEmail - invalid email", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("invalid email address provided").
			UponReceiving("a request with invalid email").
			WithRequest("POST", "/notification/sendEmail", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"booking_id":   matchers.Like("bkg_abc123"),
					"showtime_id":  matchers.Like("sht_test"),
					"movie_title":  matchers.Like("Test Movie"),
					"cinema_name":  matchers.Like("Test Cinema"),
					"room_number":  matchers.Integer(1),
					"start_time":   matchers.Like("2024-12-20T19:30:00Z"),
					"seats":        matchers.EachLike("A1", 1),
					"total_amount": matchers.Integer(100),
					"order_id":     matchers.Like("ch_test"),
					"user_name":    matchers.Like("John"),
					"email":        matchers.String("invalid-email"), // Invalid email
				})
			}).
			WillRespondWith(400, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"message": matchers.Like("Invalid email address"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &NotificationClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifySendInvalidEmail(client)
			})

		assert.NoError(t, err)
	})

	// Test 3: Email service unavailable (graceful degradation)
	t.Run("POST /notification/sendEmail - service unavailable", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("email service is temporarily unavailable").
			UponReceiving("a request when service is down").
			WithRequest("POST", "/notification/sendEmail", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"booking_id":   matchers.Like("bkg_test"),
					"showtime_id":  matchers.Like("sht_test"),
					"movie_title":  matchers.Like("Test Movie"),
					"cinema_name":  matchers.Like("Test Cinema"),
					"room_number":  matchers.Integer(1),
					"start_time":   matchers.Like("2024-12-20T19:30:00Z"),
					"seats":        matchers.EachLike("A1", 1),
					"total_amount": matchers.Integer(100),
					"order_id":     matchers.Like("ch_test"),
					"user_name":    matchers.Like("John"),
					"email":        matchers.Like("john@example.com"),
				})
			}).
			WillRespondWith(503, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"message":    matchers.Like("Email service temporarily unavailable"),
					"retry_after": matchers.Integer(60),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &NotificationClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifySendEmailUnavailable(client)
			})

		assert.NoError(t, err)
	})
}

// Helper functions
func verifySendEmail(client *NotificationClient) error {
	payload := `{
		"booking_id": "bkg_abc123",
		"showtime_id": "sht_test",
		"reservation_id": "res_xyz",
		"movie_title": "Dune Part Two",
		"cinema_name": "Cinepolis Reforma",
		"room_number": 5,
		"start_time": "2024-12-20T19:30:00Z",
		"seats": ["A1", "A2"],
		"total_amount": 450,
		"order_id": "ch_abc123",
		"receipt_url": "https://pay.stripe.com/receipts/test",
		"user_name": "John Doe",
		"email": "john@example.com"
	}`

	req, err := http.NewRequest("POST", client.BaseURL+"/notification/sendEmail",
		stringReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("expected 200, got %d: %s", resp.StatusCode, string(body))
	}
	return nil
}

func verifySendInvalidEmail(client *NotificationClient) error {
	payload := `{
		"booking_id": "bkg_abc123",
		"showtime_id": "sht_test",
		"movie_title": "Test Movie",
		"cinema_name": "Test Cinema",
		"room_number": 1,
		"start_time": "2024-12-20T19:30:00Z",
		"seats": ["A1"],
		"total_amount": 100,
		"order_id": "ch_test",
		"user_name": "John",
		"email": "invalid-email"
	}`

	req, err := http.NewRequest("POST", client.BaseURL+"/notification/sendEmail",
		stringReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 400 {
		return fmt.Errorf("expected 400, got %d", resp.StatusCode)
	}
	return nil
}

func verifySendEmailUnavailable(client *NotificationClient) error {
	payload := `{
		"booking_id": "bkg_test",
		"showtime_id": "sht_test",
		"movie_title": "Test Movie",
		"cinema_name": "Test Cinema",
		"room_number": 1,
		"start_time": "2024-12-20T19:30:00Z",
		"seats": ["A1"],
		"total_amount": 100,
		"order_id": "ch_test",
		"user_name": "John",
		"email": "john@example.com"
	}`

	req, err := http.NewRequest("POST", client.BaseURL+"/notification/sendEmail",
		stringReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 503 {
		return fmt.Errorf("expected 503, got %d", resp.StatusCode)
	}
	return nil
}
