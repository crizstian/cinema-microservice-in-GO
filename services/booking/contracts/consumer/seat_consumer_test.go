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

// SeatClient is a simple HTTP client for seat-service
type SeatClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

func TestBookingSeatContract(t *testing.T) {
	mockProvider, err := consumer.NewV2Pact(consumer.MockHTTPProviderConfig{
		Consumer: "booking-service",
		Provider: "seat-service",
		PactDir:  "../../../contracts",
	})
	assert.NoError(t, err)

	// Test 1: Verify seat hold exists
	t.Run("GET /seats/hold/{hold_id} - verify hold exists", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("a valid hold exists for session sess_abc123").
			UponReceiving("a request to verify seat hold").
			WithRequest("GET", "/seats/hold/hold_test123", func(b *consumer.V2RequestBuilder) {
				b.Query("session_id", matchers.String("sess_abc123"))
			}).
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"hold_id":     matchers.String("hold_test123"),
					"showtime_id": matchers.Regex("sht_abc123", `^sht_[a-zA-Z0-9]+$`),
					"seats":       matchers.EachLike("A1", 1),
					"session_id":  matchers.String("sess_abc123"),
					"expires_at":  matchers.Regex("2024-01-15T10:35:00Z", `^\d{4}-\d{2}-\d{2}T`),
					"ttl_seconds": matchers.Integer(300),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &SeatClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyHoldExists(client, "hold_test123", "sess_abc123")
			})

		assert.NoError(t, err)
	})

	// Test 2: Hold not found or expired
	t.Run("GET /seats/hold/{hold_id} - hold expired", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("the hold has expired").
			UponReceiving("a request for expired hold").
			WithRequest("GET", "/seats/hold/hold_expired", func(b *consumer.V2RequestBuilder) {
				b.Query("session_id", matchers.String("sess_abc123"))
			}).
			WillRespondWith(404, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"code":    matchers.String("HOLD_NOT_FOUND"),
					"message": matchers.Like("Hold not found or already expired"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &SeatClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyHoldExpired(client, "hold_expired", "sess_abc123")
			})

		assert.NoError(t, err)
	})

	// Test 3: Reserve seats (confirm booking)
	t.Run("POST /seats/reserve - confirm reservation", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("a valid hold exists and payment succeeded").
			UponReceiving("a request to confirm seat reservation").
			WithRequest("POST", "/seats/reserve", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"hold_id":    matchers.String("hold_test123"),
					"booking_id": matchers.Regex("pending_ch_abc123", `^(pending_|bkg_)`),
				})
			}).
			WillRespondWith(201, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"reservation_id": matchers.Regex("res_xyz789", `^res_[a-zA-Z0-9]+$`),
					"booking_id":     matchers.Like("pending_ch_abc123"),
					"showtime_id":    matchers.Like("sht_abc123"),
					"seats":          matchers.EachLike("A1", 1),
					"confirmed_at":   matchers.Regex("2024-01-15T10:32:00Z", `^\d{4}-\d{2}-\d{2}T`),
					"message":        matchers.Like("Reservation confirmed successfully"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &SeatClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyReserveSeats(client, "hold_test123", "pending_ch_abc123")
			})

		assert.NoError(t, err)
	})

	// Test 4: Reserve seats - hold expired
	t.Run("POST /seats/reserve - hold expired", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("the hold has expired before reservation").
			UponReceiving("a reservation request with expired hold").
			WithRequest("POST", "/seats/reserve", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"hold_id":    matchers.String("hold_expired"),
					"booking_id": matchers.Like("pending_ch_xyz"),
				})
			}).
			WillRespondWith(404, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"code":    matchers.String("HOLD_EXPIRED"),
					"message": matchers.Like("Hold has expired. Please select seats again."),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &SeatClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyReserveExpiredHold(client)
			})

		assert.NoError(t, err)
	})

	// Test 5: Release hold (compensation)
	t.Run("DELETE /seats/hold/{hold_id} - release hold", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("a hold exists that needs to be released").
			UponReceiving("a request to release seat hold").
			WithRequest("DELETE", "/seats/hold/hold_test123", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"session_id": matchers.String("sess_abc123"),
				})
			}).
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"message":        matchers.String("Hold released successfully"),
					"released_seats": matchers.EachLike("A1", 1),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &SeatClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyReleaseHold(client, "hold_test123", "sess_abc123")
			})

		assert.NoError(t, err)
	})
}

// Helper functions
func verifyHoldExists(client *SeatClient, holdID, sessionID string) error {
	url := fmt.Sprintf("%s/seats/hold/%s?session_id=%s", client.BaseURL, holdID, sessionID)
	resp, err := client.HTTPClient.Get(url)
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

func verifyHoldExpired(client *SeatClient, holdID, sessionID string) error {
	url := fmt.Sprintf("%s/seats/hold/%s?session_id=%s", client.BaseURL, holdID, sessionID)
	resp, err := client.HTTPClient.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 404 {
		return fmt.Errorf("expected 404, got %d", resp.StatusCode)
	}
	return nil
}

func verifyReserveSeats(client *SeatClient, holdID, bookingID string) error {
	payload := fmt.Sprintf(`{"hold_id": "%s", "booking_id": "%s"}`, holdID, bookingID)
	req, err := http.NewRequest("POST", client.BaseURL+"/seats/reserve", stringReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 201 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("expected 201, got %d: %s", resp.StatusCode, string(body))
	}
	return nil
}

func verifyReserveExpiredHold(client *SeatClient) error {
	payload := `{"hold_id": "hold_expired", "booking_id": "pending_ch_xyz"}`
	req, err := http.NewRequest("POST", client.BaseURL+"/seats/reserve", stringReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 404 {
		return fmt.Errorf("expected 404, got %d", resp.StatusCode)
	}
	return nil
}

func verifyReleaseHold(client *SeatClient, holdID, sessionID string) error {
	payload := fmt.Sprintf(`{"session_id": "%s"}`, sessionID)
	req, err := http.NewRequest("DELETE",
		fmt.Sprintf("%s/seats/hold/%s", client.BaseURL, holdID),
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
