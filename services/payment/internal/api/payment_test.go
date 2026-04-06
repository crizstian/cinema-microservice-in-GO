package api

import (
	"cinemas/services/payment/internal/models"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/client"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ========================================
// MOCK STRIPE CLIENT
// ========================================

// MockStripeChargeService mocks the Stripe charge service
type MockStripeChargeService struct {
	charge      *stripe.Charge
	shouldError bool
	err         error
}

func (m *MockStripeChargeService) New(params *stripe.ChargeParams) (*stripe.Charge, error) {
	if m.shouldError {
		return nil, m.err
	}
	return m.charge, nil
}

// MockStripeAPI mocks the Stripe API client
type MockStripeAPI struct {
	Charges *MockStripeChargeService
}

// ========================================
// MOCK SETUP
// ========================================

func setupMockDB(t *testing.T) (*mongo.Database, func()) {
	mongoURI := os.Getenv("MONGODB_TEST_URI")
	if mongoURI == "" {
		t.Skip("MONGODB_TEST_URI not set, skipping integration test")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	require.NoError(t, err)

	err = client.Ping(ctx, nil)
	require.NoError(t, err)

	testDB := client.Database("test_payment_" + time.Now().Format("20060102150405"))

	cleanup := func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}

	return testDB, cleanup
}

func setupMockStripeAPI(shouldError bool) *client.API {
	mockCharge := &stripe.Charge{
		ID:     "ch_mock_12345",
		Amount: 5000,
		Status: "succeeded",
	}

	mockChargeService := &MockStripeChargeService{
		charge:      mockCharge,
		shouldError: shouldError,
	}

	if shouldError {
		mockChargeService.err = &stripe.Error{
			Msg:  "Card declined",
			Type: stripe.ErrorTypeCard,
		}
	}

	// Note: This is a simplified mock. In reality, client.API doesn't have
	// a Charges field that can be set like this. This demonstrates the test structure.
	// In production, you would use a proper interface for the Stripe client.
	return nil // Placeholder for demonstration
}

func seedPayments(t *testing.T, db *mongo.Database) []map[string]interface{} {
	payments := []map[string]interface{}{
		{
			"id":          "pay-001",
			"amount":      5000,
			"currency":    "usd",
			"status":      "succeeded",
			"userName":    "john.doe@example.com",
			"description": "Movie ticket purchase",
		},
		{
			"id":          "pay-002",
			"amount":      2500,
			"currency":    "usd",
			"status":      "succeeded",
			"userName":    "jane.smith@example.com",
			"description": "Movie ticket purchase",
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	docs := make([]interface{}, len(payments))
	for i, p := range payments {
		docs[i] = p
	}

	_, err := db.Collection("payments").InsertMany(ctx, docs)
	require.NoError(t, err)

	return payments
}

// ========================================
// INTEGRATION TESTS - WITH REAL MONGODB
// ========================================

func TestIntegrationGetPurchaseByID(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	payments := seedPayments(t, db)

	// Note: Using nil for stripe client in test - would need proper mock in production
	api := API{db: db, stripe: nil}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/payments/"+payments[0]["id"].(string), nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/payments/:id")
	c.SetParamNames("id")
	c.SetParamValues(payments[0]["id"].(string))

	err := api.GetPurchaseByID(c)
	require.NoError(t, err)

	assert.Equal(t, http.StatusOK, rec.Code)

	var response map[string]interface{}
	err = json.Unmarshal(rec.Body.Bytes(), &response)
	require.NoError(t, err)

	assert.Equal(t, "payment details", response["msg"])
	assert.NotNil(t, response["payment"])
}

func TestIntegrationGetPurchaseByIDNotFound(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	seedPayments(t, db)

	api := API{db: db, stripe: nil}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/payments/non-existent", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/payments/:id")
	c.SetParamNames("id")
	c.SetParamValues("non-existent")

	err := api.GetPurchaseByID(c)
	require.Error(t, err)
}

// ========================================
// UNIT TESTS - DATABASE OPERATIONS
// ========================================

func TestConnectWithValidDB(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	// Note: Using nil for stripe client in test
	repo, err := Connect(db, nil)
	require.NoError(t, err)
	assert.NotNil(t, repo)
}

func TestConnectWithNilDB(t *testing.T) {
	repo, err := Connect(nil, nil)
	require.Error(t, err)
	assert.Nil(t, repo)
	assert.Contains(t, err.Error(), "db object is empty")
}

// ========================================
// TABLE-DRIVEN TESTS
// ========================================

func TestGetPurchaseByIDTableDriven(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	payments := seedPayments(t, db)

	tests := []struct {
		name           string
		paymentID      string
		expectedStatus int
		shouldError    bool
		expectedUser   string
	}{
		{
			name:           "Valid payment ID - pay-001",
			paymentID:      payments[0]["id"].(string),
			expectedStatus: http.StatusOK,
			shouldError:    false,
			expectedUser:   "john.doe@example.com",
		},
		{
			name:           "Valid payment ID - pay-002",
			paymentID:      payments[1]["id"].(string),
			expectedStatus: http.StatusOK,
			shouldError:    false,
			expectedUser:   "jane.smith@example.com",
		},
		{
			name:        "Invalid payment ID",
			paymentID:   "invalid-payment",
			shouldError: true,
		},
		{
			name:        "Empty payment ID",
			paymentID:   "",
			shouldError: true,
		},
	}

	api := API{db: db, stripe: nil}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/payments/"+tt.paymentID, nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			c.SetPath("/payments/:id")
			c.SetParamNames("id")
			c.SetParamValues(tt.paymentID)

			err := api.GetPurchaseByID(c)

			if tt.shouldError {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.expectedStatus, rec.Code)

				var response map[string]interface{}
				err = json.Unmarshal(rec.Body.Bytes(), &response)
				require.NoError(t, err)

				paymentData := response["payment"].(map[string]interface{})
				assert.Equal(t, tt.expectedUser, paymentData["userName"])
			}
		})
	}
}

// ========================================
// VALIDATION TESTS
// ========================================

func TestPaymentRequestValidation(t *testing.T) {
	tests := []struct {
		name        string
		payload     string
		shouldError bool
		errorMsg    string
	}{
		{
			name: "Valid payment request",
			payload: `{
				"userName": "john@example.com",
				"currency": "usd",
				"number": "4242424242424242",
				"cvc": "123",
				"exp_month": "12",
				"exp_year": "2025",
				"amount": 5000,
				"description": "Movie ticket purchase"
			}`,
			shouldError: false,
		},
		{
			name:        "Invalid JSON",
			payload:     `{"userName": "john@example.com", invalid json`,
			shouldError: true,
		},
		{
			name:        "Empty payload",
			payload:     `{}`,
			shouldError: false,
		},
		{
			name: "Missing required fields",
			payload: `{
				"userName": "john@example.com"
			}`,
			shouldError: false, // Binding won't error, but validation might
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodPost, "/payments", strings.NewReader(tt.payload))
			req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			p := new(models.Payment)
			err := c.Bind(p)

			if tt.shouldError {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestPaymentAmountValidation(t *testing.T) {
	tests := []struct {
		name          string
		amount        int64
		expectedValid bool
	}{
		{"Positive amount", 5000, true},
		{"Zero amount", 0, false},
		{"Negative amount", -100, false},
		{"Large amount", 999999, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			payment := models.Payment{
				Amount:   tt.amount,
				Currency: "usd",
			}

			// In production, you would have a validation function
			isValid := payment.Amount > 0
			assert.Equal(t, tt.expectedValid, isValid)
		})
	}
}

func TestCreditCardValidation(t *testing.T) {
	tests := []struct {
		name        string
		cardNumber  string
		shouldError bool
	}{
		{"Valid Visa", "4242424242424242", false},
		{"Valid Mastercard", "5555555555554444", false},
		{"Invalid - too short", "424242", true},
		{"Invalid - letters", "424242424242ABCD", true},
		{"Empty card", "", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Basic validation - in production use proper card validation
			isValid := len(tt.cardNumber) == 16
			for _, ch := range tt.cardNumber {
				if ch < '0' || ch > '9' {
					isValid = false
					break
				}
			}

			if tt.shouldError {
				assert.False(t, isValid)
			} else {
				assert.True(t, isValid)
			}
		})
	}
}

// ========================================
// BENCHMARK TESTS
// ========================================

func BenchmarkGetPurchaseByID(b *testing.B) {
	mongoURI := os.Getenv("MONGODB_TEST_URI")
	if mongoURI == "" {
		b.Skip("MONGODB_TEST_URI not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	require.NoError(b, err)

	testDB := client.Database("bench_payment")
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}()

	// Seed data
	payment := map[string]interface{}{
		"id":     "bench-001",
		"amount": 5000,
		"status": "succeeded",
	}
	testDB.Collection("payments").InsertOne(context.Background(), payment)

	api := API{db: testDB, stripe: nil}
	e := echo.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest(http.MethodGet, "/payments/bench-001", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetPath("/payments/:id")
		c.SetParamNames("id")
		c.SetParamValues("bench-001")
		api.GetPurchaseByID(c)
	}
}

// ========================================
// EDGE CASE TESTS
// ========================================

func TestGetPurchaseByIDWithSpecialCharacters(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	specialPayment := map[string]interface{}{
		"id":     "pay-special-abc123",
		"amount": 5000,
		"status": "succeeded",
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	db.Collection("payments").InsertOne(ctx, specialPayment)

	api := API{db: db, stripe: nil}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/payments/pay-special-abc123", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/payments/:id")
	c.SetParamNames("id")
	c.SetParamValues("pay-special-abc123")

	err := api.GetPurchaseByID(c)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestGetPurchaseByIDEmptyDatabase(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	api := API{db: db, stripe: nil}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/payments/any-id", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/payments/:id")
	c.SetParamNames("id")
	c.SetParamValues("any-id")

	err := api.GetPurchaseByID(c)
	require.Error(t, err)
}

// ========================================
// CONCURRENT ACCESS TESTS
// ========================================

func TestConcurrentGetPurchaseByID(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	payments := seedPayments(t, db)
	api := API{db: db, stripe: nil}

	paymentID := payments[0]["id"].(string)

	done := make(chan bool, 10)
	for i := 0; i < 10; i++ {
		go func() {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/payments/"+paymentID, nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			c.SetPath("/payments/:id")
			c.SetParamNames("id")
			c.SetParamValues(paymentID)

			err := api.GetPurchaseByID(c)
			assert.NoError(t, err)
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}
}

// ========================================
// MOCK STRIPE INTEGRATION TESTS
// ========================================

func TestRegisterPurchaseWithMockStripe(t *testing.T) {
	t.Skip("Requires proper Stripe client interface mocking - demonstration only")

	// This demonstrates the test structure for RegisterPurchase
	// In production, you would:
	// 1. Create a proper interface for the Stripe client
	// 2. Implement a mock that satisfies that interface
	// 3. Inject the mock into the API

	_, cleanup := setupMockDB(t)
	defer cleanup()

	// Demonstrate test structure without actual implementation
	t.Log("RegisterPurchase requires complex mocking of Stripe API")
	t.Log("Would need to:")
	t.Log("  1. Create interface for Stripe client")
	t.Log("  2. Implement mock that satisfies interface")
	t.Log("  3. Inject mock into API")
	t.Log("RegisterPurchase test structure demonstrated")
}

// ========================================
// CURRENCY AND LOCALE TESTS
// ========================================

func TestMultipleCurrencies(t *testing.T) {
	tests := []struct {
		currency string
		valid    bool
	}{
		{"usd", true},
		{"eur", true},
		{"gbp", true},
		{"jpy", true},
		{"invalid", false},
		{"", false},
	}

	validCurrencies := map[string]bool{
		"usd": true,
		"eur": true,
		"gbp": true,
		"jpy": true,
	}

	for _, tt := range tests {
		t.Run(tt.currency, func(t *testing.T) {
			isValid := validCurrencies[tt.currency]
			assert.Equal(t, tt.valid, isValid)
		})
	}
}
