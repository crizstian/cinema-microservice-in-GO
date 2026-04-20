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

// ShowtimeClient is a simple HTTP client for showtime-service
type ShowtimeClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

func TestBookingShowtimeContract(t *testing.T) {
	mockProvider, err := consumer.NewV2Pact(consumer.MockHTTPProviderConfig{
		Consumer: "booking-service",
		Provider: "showtime-service",
		PactDir:  "../../../contracts",
	})
	assert.NoError(t, err)

	// Test 1: Get showtime by ID - exists and scheduled
	t.Run("GET /showtimes/{id} - showtime exists and scheduled", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("a scheduled showtime exists").
			UponReceiving("a request to get showtime details").
			WithRequest("GET", "/showtimes/sht_abc123").
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"id":              matchers.String("sht_abc123"),
					"movie_id":        matchers.Regex("mov_test123", `^mov_[a-zA-Z0-9]+$`),
					"cinema_id":       matchers.Regex("cin_test", `^cin_[a-zA-Z0-9]+$`),
					"room_number":     matchers.Integer(5),
					"start_time":      matchers.Regex("2024-12-20T19:30:00Z", `^\d{4}-\d{2}-\d{2}T`),
					"end_time":        matchers.Regex("2024-12-20T22:00:00Z", `^\d{4}-\d{2}-\d{2}T`),
					"available_seats": matchers.Integer(100),
					"status":          matchers.String("scheduled"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &ShowtimeClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyGetShowtime(client, "sht_abc123", 200)
			})

		assert.NoError(t, err)
	})

	// Test 2: Get showtime by ID - cancelled
	t.Run("GET /showtimes/{id} - showtime cancelled", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("a cancelled showtime exists").
			UponReceiving("a request for cancelled showtime").
			WithRequest("GET", "/showtimes/sht_cancelled").
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"id":              matchers.String("sht_cancelled"),
					"movie_id":        matchers.Like("mov_test"),
					"cinema_id":       matchers.Like("cin_test"),
					"room_number":     matchers.Integer(3),
					"start_time":      matchers.Like("2024-12-20T15:00:00Z"),
					"end_time":        matchers.Like("2024-12-20T17:30:00Z"),
					"available_seats": matchers.Integer(0),
					"status":          matchers.String("cancelled"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &ShowtimeClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyGetShowtime(client, "sht_cancelled", 200)
			})

		assert.NoError(t, err)
	})

	// Test 3: Get showtime by ID - not found
	t.Run("GET /showtimes/{id} - showtime not found", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("showtime does not exist").
			UponReceiving("a request for non-existent showtime").
			WithRequest("GET", "/showtimes/sht_notfound").
			WillRespondWith(404, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"type":    matchers.String("not_found"),
					"message": matchers.Like("Showtime not found"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &ShowtimeClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyGetShowtime(client, "sht_notfound", 404)
			})

		assert.NoError(t, err)
	})

	// Test 4: List showtimes with filters (for future enhancements)
	t.Run("GET /showtimes?movie_id={id} - list by movie", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("showtimes exist for movie mov_test123").
			UponReceiving("a request to list showtimes by movie").
			WithRequest("GET", "/showtimes", func(b *consumer.V2RequestBuilder) {
				b.Query("movie_id", matchers.String("mov_test123"))
				b.Query("status", matchers.String("scheduled"))
			}).
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(map[string]interface{}{
					"data": []map[string]interface{}{
						{
							"id":              "sht_abc123",
							"movie_id":        "mov_test123",
							"cinema_id":       "cin_test",
							"room_number":     5,
							"start_time":      "2024-12-20T19:30:00Z",
							"end_time":        "2024-12-20T22:00:00Z",
							"available_seats": 100,
							"status":          "scheduled",
						},
					},
					"pagination": map[string]interface{}{
						"page":        1,
						"limit":       20,
						"total":       1,
						"total_pages": 1,
					},
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &ShowtimeClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyListShowtimes(client, "mov_test123")
			})

		assert.NoError(t, err)
	})
}

// Helper functions
func verifyGetShowtime(client *ShowtimeClient, showtimeID string, expectedStatus int) error {
	url := fmt.Sprintf("%s/showtimes/%s", client.BaseURL, showtimeID)
	resp, err := client.HTTPClient.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != expectedStatus {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("expected %d, got %d: %s", expectedStatus, resp.StatusCode, string(body))
	}
	return nil
}

func verifyListShowtimes(client *ShowtimeClient, movieID string) error {
	url := fmt.Sprintf("%s/showtimes?movie_id=%s&status=scheduled", client.BaseURL, movieID)
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
