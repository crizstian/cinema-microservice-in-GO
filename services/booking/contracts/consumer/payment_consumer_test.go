//go:build pact

package consumer

import (
	"fmt"
	"net/http"
	"testing"

	"github.com/pact-foundation/pact-go/v2/consumer"
	"github.com/pact-foundation/pact-go/v2/matchers"
	"github.com/stretchr/testify/assert"
)

// PaymentClient is a simple HTTP client for payment-service
type PaymentClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

func TestBookingPaymentContract(t *testing.T) {
	// Create a new Pact consumer
	mockProvider, err := consumer.NewV2Pact(consumer.MockHTTPProviderConfig{
		Consumer: "booking-service",
		Provider: "payment-service",
		PactDir:  "../../../contracts",
	})
	assert.NoError(t, err)

	// Test 1: Successful payment processing
	t.Run("POST /payment/makePurchase - successful payment", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("a valid credit card").
			UponReceiving("a request to process payment").
			WithRequest("POST", "/payment/makePurchase", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"userName":    matchers.String("John Doe"),
					"currency":    matchers.String("mxn"),
					"number":      matchers.Regex("4242424242424242", `^\d{16}$`),
					"cvc":         matchers.Regex("123", `^\d{3,4}$`),
					"exp_month":   matchers.Regex("12", `^(0[1-9]|1[0-2])$`),
					"exp_year":    matchers.Regex("2026", `^\d{4}$`),
					"amount":      matchers.Integer(450),
					"description": matchers.Like("Ticket(s) for showtime sht_abc123"),
				})
			}).
			WillRespondWith(201, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(map[string]interface{}{
					"user":   "John Doe",
					"amount": 450,
					"charge": map[string]interface{}{
						"id":          "ch_test123",
						"amount":      45000,
						"currency":    "mxn",
						"status":      "succeeded",
						"description": "Ticket(s) for showtime sht_abc123",
						"receipt_url": "https://pay.stripe.com/receipts/abc",
					},
					"version": "Stripe v2024.10",
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				// Call the mock server
				client := &PaymentClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyPaymentCall(client)
			})

		assert.NoError(t, err)
	})

	// Test 2: Payment with invalid amount
	t.Run("POST /payment/makePurchase - invalid amount", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("an invalid payment amount").
			UponReceiving("a request with invalid amount").
			WithRequest("POST", "/payment/makePurchase", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"userName":    matchers.String("John Doe"),
					"currency":    matchers.String("mxn"),
					"number":      matchers.Like("4242424242424242"),
					"cvc":         matchers.Like("123"),
					"exp_month":   matchers.Like("12"),
					"exp_year":    matchers.Like("2026"),
					"amount":      matchers.Integer(0), // Invalid: 0 amount
					"description": matchers.Like("Test payment"),
				})
			}).
			WillRespondWith(400, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"message": matchers.Like("Invalid amount, must be greater than 0"),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &PaymentClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyInvalidPaymentCall(client)
			})

		assert.NoError(t, err)
	})

	// Test 3: Refund payment
	t.Run("POST /payment/{id}/refund - successful refund", func(t *testing.T) {
		err = mockProvider.
			AddInteraction().
			Given("an existing successful charge").
			UponReceiving("a request to refund payment").
			WithRequest("POST", "/payment/ch_test123/refund", func(b *consumer.V2RequestBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"reason": matchers.Term("requested_by_customer", `^(duplicate|fraudulent|requested_by_customer)$`),
				})
			}).
			WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
				b.Header("Content-Type", matchers.String("application/json"))
				b.JSONBody(matchers.MapMatcher{
					"refund_id":       matchers.Regex("re_test123", `^re_[a-zA-Z0-9]+$`),
					"status":          matchers.String("succeeded"),
					"amount_refunded": matchers.Integer(45000),
					"charge_id":       matchers.String("ch_test123"),
					"reason":          matchers.String("requested_by_customer"),
					"created_at":      matchers.Regex("2024-01-15T10:30:00Z", `^\d{4}-\d{2}-\d{2}T`),
				})
			}).
			ExecuteTest(t, func(config consumer.MockServerConfig) error {
				client := &PaymentClient{
					BaseURL:    fmt.Sprintf("http://%s:%d", config.Host, config.Port),
					HTTPClient: &http.Client{},
				}
				return verifyRefundCall(client, "ch_test123")
			})

		assert.NoError(t, err)
	})
}

// Helper functions to make actual HTTP calls
func verifyPaymentCall(client *PaymentClient) error {
	payload := `{
		"userName": "John Doe",
		"currency": "mxn",
		"number": "4242424242424242",
		"cvc": "123",
		"exp_month": "12",
		"exp_year": "2026",
		"amount": 450,
		"description": "Ticket(s) for showtime sht_abc123"
	}`

	req, err := http.NewRequest("POST", client.BaseURL+"/payment/makePurchase",
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

	if resp.StatusCode != 201 {
		return fmt.Errorf("expected status 201, got %d", resp.StatusCode)
	}
	return nil
}

func verifyInvalidPaymentCall(client *PaymentClient) error {
	payload := `{
		"userName": "John Doe",
		"currency": "mxn",
		"number": "4242424242424242",
		"cvc": "123",
		"exp_month": "12",
		"exp_year": "2026",
		"amount": 0,
		"description": "Test payment"
	}`

	req, err := http.NewRequest("POST", client.BaseURL+"/payment/makePurchase",
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
		return fmt.Errorf("expected status 400, got %d", resp.StatusCode)
	}
	return nil
}

func verifyRefundCall(client *PaymentClient, chargeID string) error {
	payload := `{"reason": "requested_by_customer"}`

	req, err := http.NewRequest("POST",
		fmt.Sprintf("%s/payment/%s/refund", client.BaseURL, chargeID),
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
		return fmt.Errorf("expected status 200, got %d", resp.StatusCode)
	}
	return nil
}

func stringReader(s string) *stringReaderImpl {
	return &stringReaderImpl{data: []byte(s), pos: 0}
}

type stringReaderImpl struct {
	data []byte
	pos  int
}

func (r *stringReaderImpl) Read(p []byte) (n int, err error) {
	if r.pos >= len(r.data) {
		return 0, fmt.Errorf("EOF")
	}
	n = copy(p, r.data[r.pos:])
	r.pos += n
	return n, nil
}
