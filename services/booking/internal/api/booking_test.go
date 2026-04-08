package api

import (
	"cinemas/services/booking/internal/config"
	"cinemas/services/booking/internal/models"
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
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ========================================
// MOCK CLIENT FOR EXTERNAL SERVICES
// ========================================

// MockAPIClient mocks the client.Services interface with SAGA support
type MockAPIClient struct {
	paymentResp      map[string]interface{}
	notificationResp map[string]interface{}
	showtimeResp     *models.Showtime
	holdResp         *models.HoldResponse
	reservationResp  *models.ReservationResponse

	paymentErr       error
	notificationErr  error
	showtimeErr      error
	holdErr          error
	reservationErr   error
	refundErr        error
	releaseHoldErr   error

	paymentURL      string
	notificationURL string
	seatURL         string
	showtimeURL     string
}

func (m *MockAPIClient) PaymentWall(createRequest interface{}) (interface{}, error) {
	if m.paymentErr != nil {
		return nil, m.paymentErr
	}
	return &m.paymentResp, nil
}

func (m *MockAPIClient) NotificationWall(createRequest interface{}) (interface{}, error) {
	if m.notificationErr != nil {
		return nil, m.notificationErr
	}
	return &m.notificationResp, nil
}

func (m *MockAPIClient) GetShowtime(showtimeID string) (*models.Showtime, error) {
	if m.showtimeErr != nil {
		return nil, m.showtimeErr
	}
	return m.showtimeResp, nil
}

func (m *MockAPIClient) VerifyHold(holdID, sessionID string) (*models.HoldResponse, error) {
	if m.holdErr != nil {
		return nil, m.holdErr
	}
	return m.holdResp, nil
}

func (m *MockAPIClient) ReserveSeats(holdID, bookingID string) (*models.ReservationResponse, error) {
	if m.reservationErr != nil {
		return nil, m.reservationErr
	}
	return m.reservationResp, nil
}

func (m *MockAPIClient) ReleaseHold(holdID, sessionID string) error {
	return m.releaseHoldErr
}

func (m *MockAPIClient) RefundPayment(chargeID, reason string) error {
	return m.refundErr
}

func (m *MockAPIClient) SetBasePaymentURL(url string) {
	m.paymentURL = url
}

func (m *MockAPIClient) SetNotificationURL(url string) {
	m.notificationURL = url
}

func (m *MockAPIClient) SetBaseSeatURL(url string) {
	m.seatURL = url
}

func (m *MockAPIClient) SetBaseShowtimeURL(url string) {
	m.showtimeURL = url
}

func (m *MockAPIClient) GetBasePaymentURL() string {
	return m.paymentURL
}

func (m *MockAPIClient) GetNotificationURL() string {
	return m.notificationURL
}

func (m *MockAPIClient) GetBaseSeatURL() string {
	return m.seatURL
}

func (m *MockAPIClient) GetBaseShowtimeURL() string {
	return m.showtimeURL
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

	testDB := client.Database("test_booking_" + time.Now().Format("20060102150405"))

	cleanup := func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}

	return testDB, cleanup
}

func setupMockClient() *config.Client {
	mockAPI := &MockAPIClient{
		paymentResp: map[string]interface{}{
			"msg": "Payment successful",
			"charge": map[string]interface{}{
				"id":          "ch_12345",
				"amount":      5000,
				"status":      "succeeded",
				"receipt_url": "https://pay.stripe.com/receipts/test",
			},
			"version": "Stripe v2024.10",
		},
		notificationResp: map[string]interface{}{
			"msg": "Email sent successfully",
		},
		showtimeResp: &models.Showtime{
			ID:             "sht_test123",
			MovieID:        "mov_test",
			CinemaID:       "cin_test",
			RoomNumber:     5,
			StartTime:      time.Now().Add(24 * time.Hour),
			EndTime:        time.Now().Add(26 * time.Hour),
			AvailableSeats: 100,
			Status:         "scheduled",
		},
		holdResp: &models.HoldResponse{
			HoldID:     "hold_test123",
			ShowtimeID: "sht_test123",
			Seats:      []string{"A1", "A2"},
			SessionID:  "sess_test",
			ExpiresAt:  time.Now().Add(5 * time.Minute),
			TTLSeconds: 300,
		},
		reservationResp: &models.ReservationResponse{
			ReservationID: "res_test123",
			BookingID:     "bkg_test",
			ShowtimeID:    "sht_test123",
			Seats: []models.SeatInfo{
				{ID: "A1", Row: "A", Number: 1, Type: "regular", Status: "reserved"},
				{ID: "A2", Row: "A", Number: 2, Type: "regular", Status: "reserved"},
			},
			ConfirmedAt: time.Now(),
		},
		paymentErr:      nil,
		notificationErr: nil,
		paymentURL:      "http://localhost:8100",
		notificationURL: "http://localhost:8200",
		seatURL:         "http://localhost:8300",
		showtimeURL:     "http://localhost:8400",
	}

	return &config.Client{
		API: mockAPI,
	}
}

func seedBookings(t *testing.T, db *mongo.Database) []map[string]interface{} {
	bookings := []map[string]interface{}{
		{
			"orderid": "order-001",
			"booking": map[string]interface{}{
				"userType":    "member",
				"city":        "New York",
				"cinema":      "Cinema 1",
				"schedule":    "2024-12-25T18:00:00Z",
				"movie":       map[string]interface{}{"title": "The Matrix", "format": "IMAX"},
				"cinemaRoom":  1,
				"seats":       []string{"A1", "A2"},
				"totalAmount": 50,
			},
			"userName": "john.doe@example.com",
		},
		{
			"orderid": "order-002",
			"booking": map[string]interface{}{
				"userType":    "regular",
				"city":        "Los Angeles",
				"cinema":      "Cinema 2",
				"schedule":    "2024-12-26T20:00:00Z",
				"movie":       map[string]interface{}{"title": "Inception", "format": "Standard"},
				"cinemaRoom":  2,
				"seats":       []string{"B1"},
				"totalAmount": 25,
			},
			"userName": "jane.smith@example.com",
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	docs := make([]interface{}, len(bookings))
	for i, b := range bookings {
		docs[i] = b
	}

	_, err := db.Collection("booking").InsertMany(ctx, docs)
	require.NoError(t, err)

	return bookings
}

// ========================================
// INTEGRATION TESTS - WITH REAL MONGODB
// ========================================

func TestIntegrationGetOrderByID(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	bookings := seedBookings(t, db)
	mockClient := setupMockClient()

	api := API{db: db, client: mockClient}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/bookings/"+bookings[0]["orderid"].(string), nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/bookings/:id")
	c.SetParamNames("id")
	c.SetParamValues(bookings[0]["orderid"].(string))

	err := api.GetOrderByID(c)
	require.NoError(t, err)

	assert.Equal(t, http.StatusOK, rec.Code)

	var response map[string]interface{}
	err = json.Unmarshal(rec.Body.Bytes(), &response)
	require.NoError(t, err)

	assert.Equal(t, "ticket details", response["msg"])
	assert.NotNil(t, response["ticket"])
}

func TestIntegrationGetOrderByIDNotFound(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	seedBookings(t, db)
	mockClient := setupMockClient()

	api := API{db: db, client: mockClient}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/bookings/non-existent", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/bookings/:id")
	c.SetParamNames("id")
	c.SetParamValues("non-existent")

	err := api.GetOrderByID(c)
	require.Error(t, err)
}

// ========================================
// UNIT TESTS - DATABASE OPERATIONS
// ========================================

func TestConnectWithValidDB(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	mockClient := setupMockClient()

	repo, err := Connect(db, mockClient)
	require.NoError(t, err)
	assert.NotNil(t, repo)
}

func TestConnectWithNilDB(t *testing.T) {
	mockClient := setupMockClient()

	repo, err := Connect(nil, mockClient)
	require.Error(t, err)
	assert.Nil(t, repo)
	assert.Contains(t, err.Error(), "Failed to initialize repository")
}

// ========================================
// TABLE-DRIVEN TESTS
// ========================================

func TestGetOrderByIDTableDriven(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	bookings := seedBookings(t, db)
	mockClient := setupMockClient()

	tests := []struct {
		name           string
		orderID        string
		expectedStatus int
		shouldError    bool
		expectedUser   string
	}{
		{
			name:           "Valid order ID - order-001",
			orderID:        bookings[0]["orderid"].(string),
			expectedStatus: http.StatusOK,
			shouldError:    false,
			expectedUser:   "john.doe@example.com",
		},
		{
			name:           "Valid order ID - order-002",
			orderID:        bookings[1]["orderid"].(string),
			expectedStatus: http.StatusOK,
			shouldError:    false,
			expectedUser:   "jane.smith@example.com",
		},
		{
			name:        "Invalid order ID",
			orderID:     "invalid-order",
			shouldError: true,
		},
		{
			name:        "Empty order ID",
			orderID:     "",
			shouldError: true,
		},
	}

	api := API{db: db, client: mockClient}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/bookings/"+tt.orderID, nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			c.SetPath("/bookings/:id")
			c.SetParamNames("id")
			c.SetParamValues(tt.orderID)

			err := api.GetOrderByID(c)

			if tt.shouldError {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.expectedStatus, rec.Code)

				var response map[string]interface{}
				err = json.Unmarshal(rec.Body.Bytes(), &response)
				require.NoError(t, err)

				ticketData := response["ticket"].(map[string]interface{})
				assert.Equal(t, tt.expectedUser, ticketData["userName"])
			}
		})
	}
}

// ========================================
// VALIDATION TESTS
// ========================================

func TestBookingRequestValidation(t *testing.T) {
	tests := []struct {
		name        string
		payload     string
		shouldError bool
		errorMsg    string
	}{
		{
			name: "Valid booking request (v2 with showtime_id and hold_id)",
			payload: `{
				"user": {
					"name": "John",
					"lastName": "Doe",
					"email": "john@example.com",
					"phoneNumber": "+1234567890",
					"creditCard": {
						"number": "4242424242424242",
						"cvc": "123",
						"exp_month": "12",
						"exp_year": "2026"
					},
					"membership": "gold"
				},
				"booking": {
					"showtime_id": "sht_abc123",
					"hold_id": "123e4567-e89b-12d3-a456-426614174000",
					"session_id": "sess_xyz789",
					"seats": ["A1", "A2"],
					"totalAmount": 450
				}
			}`,
			shouldError: false,
		},
		{
			name:        "Invalid JSON",
			payload:     `{"user": {invalid json`,
			shouldError: true,
		},
		{
			name:        "Empty payload",
			payload:     `{}`,
			shouldError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodPost, "/bookings", strings.NewReader(tt.payload))
			req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			b := new(models.BookingRequest)
			err := c.Bind(b)

			if tt.shouldError {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

// ========================================
// SAGA FLOW TESTS
// ========================================

func TestMakeBookingSAGASuccess(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	mockClient := setupMockClient()
	api := API{db: db, client: mockClient}

	payload := `{
		"user": {
			"name": "John",
			"lastName": "Doe",
			"email": "john@example.com",
			"creditCard": {
				"number": "4242424242424242",
				"cvc": "123",
				"exp_month": "12",
				"exp_year": "2026"
			}
		},
		"booking": {
			"showtime_id": "sht_test123",
			"hold_id": "hold_test123",
			"session_id": "sess_test",
			"seats": ["A1", "A2"],
			"totalAmount": 450
		}
	}`

	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/booking", strings.NewReader(payload))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := api.MakeBooking(c)
	require.NoError(t, err)
	assert.Equal(t, http.StatusCreated, rec.Code)

	var response map[string]interface{}
	err = json.Unmarshal(rec.Body.Bytes(), &response)
	require.NoError(t, err)

	assert.Equal(t, "Booking has been created successfully", response["msg"])
	assert.NotNil(t, response["ticket"])
	assert.Contains(t, response["payment"].(string), "Payment has been charged successfully")
}

func TestMakeBookingSAGAMissingRequiredFields(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	mockClient := setupMockClient()
	api := API{db: db, client: mockClient}

	// Missing showtime_id, hold_id, session_id
	payload := `{
		"user": {
			"name": "John",
			"lastName": "Doe",
			"email": "john@example.com",
			"creditCard": {
				"number": "4242424242424242",
				"cvc": "123",
				"exp_month": "12",
				"exp_year": "2026"
			}
		},
		"booking": {
			"seats": ["A1", "A2"],
			"totalAmount": 450
		}
	}`

	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/booking", strings.NewReader(payload))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := api.MakeBooking(c)
	require.NoError(t, err) // Handler returns JSON error, not error
	assert.Equal(t, http.StatusBadRequest, rec.Code)

	var response models.BookingError
	err = json.Unmarshal(rec.Body.Bytes(), &response)
	require.NoError(t, err)
	assert.Equal(t, "INVALID_REQUEST", response.Code)
}

// ========================================
// BENCHMARK TESTS
// ========================================

func BenchmarkGetOrderByID(b *testing.B) {
	mongoURI := os.Getenv("MONGODB_TEST_URI")
	if mongoURI == "" {
		b.Skip("MONGODB_TEST_URI not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	require.NoError(b, err)

	testDB := client.Database("bench_booking")
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}()

	// Seed data
	booking := map[string]interface{}{
		"orderid": "bench-001",
		"booking": map[string]interface{}{
			"city":        "New York",
			"totalAmount": 50,
		},
	}
	testDB.Collection("booking").InsertOne(context.Background(), booking)

	mockClient := setupMockClient()
	api := API{db: testDB, client: mockClient}
	e := echo.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest(http.MethodGet, "/bookings/bench-001", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetPath("/bookings/:id")
		c.SetParamNames("id")
		c.SetParamValues("bench-001")
		api.GetOrderByID(c)
	}
}

// ========================================
// EDGE CASE TESTS
// ========================================

func TestGetOrderByIDWithSpecialCharacters(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	specialBooking := map[string]interface{}{
		"orderid": "order-special-abc123",
		"booking": map[string]interface{}{
			"city":        "New York",
			"totalAmount": 50,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	db.Collection("booking").InsertOne(ctx, specialBooking)

	mockClient := setupMockClient()
	api := API{db: db, client: mockClient}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/bookings/order-special-abc123", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/bookings/:id")
	c.SetParamNames("id")
	c.SetParamValues("order-special-abc123")

	err := api.GetOrderByID(c)
	require.NoError(t, err)
	assert.Equal(t, http.StatusOK, rec.Code)
}

func TestGetOrderByIDEmptyDatabase(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	mockClient := setupMockClient()
	api := API{db: db, client: mockClient}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/bookings/any-id", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/bookings/:id")
	c.SetParamNames("id")
	c.SetParamValues("any-id")

	err := api.GetOrderByID(c)
	require.Error(t, err)
}

// ========================================
// CONCURRENT ACCESS TESTS
// ========================================

func TestConcurrentGetOrderByID(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	bookings := seedBookings(t, db)
	mockClient := setupMockClient()
	api := API{db: db, client: mockClient}

	orderID := bookings[0]["orderid"].(string)

	done := make(chan bool, 10)
	for i := 0; i < 10; i++ {
		go func() {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/bookings/"+orderID, nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			c.SetPath("/bookings/:id")
			c.SetParamNames("id")
			c.SetParamValues(orderID)

			err := api.GetOrderByID(c)
			assert.NoError(t, err)
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}
}
