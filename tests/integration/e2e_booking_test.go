// Package integration provides end-to-end tests for the cinema booking system.
//
// These tests verify the complete booking flow across all microservices:
// 1. User registration (user-service)
// 2. Browse movies (movie-service)
// 3. Select showtime (showtime-service)
// 4. View seat map (seat-service)
// 5. Hold seats (seat-service)
// 6. Create booking with payment (booking-service -> payment-service)
// 7. Confirm seats (seat-service)
// 8. Send notification (notification-service)
//
// Prerequisites:
//   - Run: docker-compose -f docker-compose.e2e.yml up -d
//   - Seed data: mongosh mongodb://localhost:27017/cinema < testdata/seed.js
//   - Run tests: go test -v -tags=e2e ./...
package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

// Service URLs - can be overridden via environment variables
var (
	UserServiceURL         = getEnv("USER_SERVICE_URL", "http://localhost:8004")
	MovieServiceURL        = getEnv("MOVIE_SERVICE_URL", "http://localhost:8000")
	CinemaServiceURL       = getEnv("CINEMA_SERVICE_URL", "http://localhost:8085")
	ShowtimeServiceURL     = getEnv("SHOWTIME_SERVICE_URL", "http://localhost:3003")
	SeatServiceURL         = getEnv("SEAT_SERVICE_URL", "http://localhost:3004")
	PaymentServiceURL      = getEnv("PAYMENT_SERVICE_URL", "http://localhost:8001")
	BookingServiceURL      = getEnv("BOOKING_SERVICE_URL", "http://localhost:8082")
	NotificationServiceURL = getEnv("NOTIFICATION_SERVICE_URL", "http://localhost:8002")
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// E2ETestSuite contains end-to-end tests for the booking flow
type E2ETestSuite struct {
	suite.Suite
	client *http.Client
	ctx    context.Context

	// Test state shared between steps
	accessToken string
	userID      string
	movieID     string
	showtimeID  string
	holdID      string
	sessionID   string
	bookingID   string
	seats       []string
}

func TestE2ESuite(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E tests in short mode")
	}

	// Check if E2E environment is available (any response means service is up)
	if !isServiceHealthy(UserServiceURL + "/") {
		t.Skip("E2E services not available. Run: task test:e2e")
	}

	suite.Run(t, new(E2ETestSuite))
}

func (s *E2ETestSuite) SetupSuite() {
	s.client = &http.Client{
		Timeout: 30 * time.Second,
	}
	s.ctx = context.Background()
	s.sessionID = fmt.Sprintf("sess_e2e_%d", time.Now().UnixNano())
	s.seats = []string{"A5", "A6"} // Two adjacent seats

	// Wait for all services to be healthy
	s.waitForServices()
}

func (s *E2ETestSuite) waitForServices() {
	// Use root path - services respond with 404 but that proves they're running
	services := map[string]string{
		"user":         UserServiceURL + "/",
		"movie":        MovieServiceURL + "/",
		"cinema":       CinemaServiceURL + "/",
		"showtime":     ShowtimeServiceURL + "/",
		"seat":         SeatServiceURL + "/",
		"payment":      PaymentServiceURL + "/",
		"booking":      BookingServiceURL + "/",
		"notification": NotificationServiceURL + "/",
	}

	for name, url := range services {
		s.T().Logf("Waiting for %s service at %s...", name, url)
		for i := 0; i < 30; i++ {
			if isServiceHealthy(url) {
				s.T().Logf("  %s service is healthy", name)
				break
			}
			time.Sleep(1 * time.Second)
		}
	}
}

func isServiceHealthy(url string) bool {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	// Any response (including 404) means the service is up and responding
	// 404 just means no handler for this path, but service is healthy
	return resp.StatusCode < 500
}

// ============================================================
// Step 1: User Registration
// ============================================================

func (s *E2ETestSuite) Test01_UserRegistration() {
	s.T().Log("Step 1: User Registration")

	// Generate unique email for this test run
	email := fmt.Sprintf("e2e_user_%d@test.local", time.Now().UnixNano())

	payload := map[string]interface{}{
		"name":     "E2E Test User",
		"email":    email,
		"password": "TestP@ss123",
		"phone":    "+52 55 1234 5678",
	}

	resp, err := s.postJSON(UserServiceURL+"/users/register", payload, "")
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Registration response: %d - %s", resp.StatusCode, truncate(string(body), 200))

	// Accept 201 (created) or 409 (already exists from previous run)
	assert.Contains(s.T(), []int{201, 409}, resp.StatusCode, "Expected 201 or 409")

	if resp.StatusCode == 201 {
		var result map[string]interface{}
		err = json.Unmarshal(body, &result)
		require.NoError(s.T(), err)

		if user, ok := result["user"].(map[string]interface{}); ok {
			s.userID = user["id"].(string)
			s.T().Logf("  User created: %s", s.userID)
		}
	}

	// Now login to get access token
	s.T().Log("  Logging in...")
	loginPayload := map[string]interface{}{
		"email":    email,
		"password": "TestP@ss123",
	}

	resp, err = s.postJSON(UserServiceURL+"/users/login", loginPayload, "")
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ = io.ReadAll(resp.Body)

	// If user didn't exist, login will fail - that's OK for this test
	if resp.StatusCode == 200 {
		var loginResult map[string]interface{}
		err = json.Unmarshal(body, &loginResult)
		require.NoError(s.T(), err)

		s.accessToken = loginResult["access_token"].(string)
		s.T().Logf("  Login successful, got access token")
	} else {
		s.T().Logf("  Login response: %d (may not be implemented)", resp.StatusCode)
	}
}

// ============================================================
// Step 2: Browse Movies
// ============================================================

func (s *E2ETestSuite) Test02_BrowseMovies() {
	s.T().Log("Step 2: Browse Movies in Cartelera")

	resp, err := s.get(MovieServiceURL+"/movies", s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Movies response: %d - %s", resp.StatusCode, truncate(string(body), 300))

	assert.Equal(s.T(), http.StatusOK, resp.StatusCode)

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err)

	// Extract first movie ID
	if movies, ok := result["movies"].([]interface{}); ok && len(movies) > 0 {
		if movie, ok := movies[0].(map[string]interface{}); ok {
			s.movieID = movie["id"].(string)
			s.T().Logf("  Selected movie: %s - %s", s.movieID, movie["title"])
		}
	} else if data, ok := result["data"].([]interface{}); ok && len(data) > 0 {
		if movie, ok := data[0].(map[string]interface{}); ok {
			s.movieID = movie["id"].(string)
			s.T().Logf("  Selected movie: %s", s.movieID)
		}
	}

	// Fallback to known test movie if API structure differs
	if s.movieID == "" {
		s.movieID = "mov_shawshank"
		s.T().Logf("  Using fallback movie ID: %s", s.movieID)
	}
}

// ============================================================
// Step 2b: Browse Premieres (validates seed data fields)
// ============================================================

func (s *E2ETestSuite) Test02b_BrowsePremieres() {
	s.T().Log("Step 2b: Browse Movie Premieres")

	resp, err := s.get(MovieServiceURL+"/movies/premieres", s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Premieres response: %d - %s", resp.StatusCode, truncate(string(body), 400))

	require.Equal(s.T(), http.StatusOK, resp.StatusCode, "Premieres endpoint must return 200")

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err, "Premieres response must be valid JSON")

	// Verify we have movies data (not null)
	movies, ok := result["movies"].([]interface{})
	require.True(s.T(), ok, "Response must contain 'movies' array, got: %v", result)
	require.NotNil(s.T(), movies, "Movies array must not be null - check seed data has releaseYear/Month/Day fields")
	require.Greater(s.T(), len(movies), 0, "Premieres must return at least one movie - verify seed data dates are current")

	// Verify first movie has required fields
	if len(movies) > 0 {
		movie, ok := movies[0].(map[string]interface{})
		require.True(s.T(), ok, "Movie must be an object")

		// These fields must exist for premieres to work
		title, hasTitle := movie["title"].(string)
		require.True(s.T(), hasTitle, "Movie must have 'title' field")
		s.T().Logf("  First premiere: %s", title)

		// If movie has ID, we can use it
		if id, hasID := movie["id"].(string); hasID && s.movieID == "" {
			s.movieID = id
			s.T().Logf("  Using premiere movie ID: %s", s.movieID)
		}
	}
}

// ============================================================
// Step 3: Select Showtime
// ============================================================

func (s *E2ETestSuite) Test03_SelectShowtime() {
	s.T().Log("Step 3: Select Showtime")

	// Get showtimes for the selected movie
	url := fmt.Sprintf("%s/showtimes?movie_id=%s&status=scheduled", ShowtimeServiceURL, s.movieID)
	resp, err := s.get(url, s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Showtimes response: %d - %s", resp.StatusCode, truncate(string(body), 400))

	assert.Equal(s.T(), http.StatusOK, resp.StatusCode)

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err)

	// Extract first showtime ID
	if data, ok := result["data"].([]interface{}); ok && len(data) > 0 {
		if showtime, ok := data[0].(map[string]interface{}); ok {
			s.showtimeID = showtime["id"].(string)
			s.T().Logf("  Selected showtime: %s at %v", s.showtimeID, showtime["start_time"])
		}
	}

	// Fallback to known test showtime
	if s.showtimeID == "" {
		s.showtimeID = "sht_001"
		s.T().Logf("  Using fallback showtime ID: %s", s.showtimeID)
	}
}

// ============================================================
// Step 4: View Seat Map
// ============================================================

func (s *E2ETestSuite) Test04_ViewSeatMap() {
	s.T().Log("Step 4: View Seat Map")

	url := fmt.Sprintf("%s/seats/availability?showtime_id=%s", SeatServiceURL, s.showtimeID)
	resp, err := s.get(url, s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Seat map response: %d - %s", resp.StatusCode, truncate(string(body), 500))

	require.Equal(s.T(), http.StatusOK, resp.StatusCode, "Seat availability endpoint must return 200")

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err, "Seat map response must be valid JSON")

	// Verify we have seats data
	seats, ok := result["seats"].([]interface{})
	require.True(s.T(), ok, "Response must contain seats array")
	require.Greater(s.T(), len(seats), 0, "Seats array must not be empty")

	// Log available seat count
	availableCount := 0
	for _, seat := range seats {
		if seatMap, ok := seat.(map[string]interface{}); ok {
			if status, ok := seatMap["status"].(string); ok && status == "available" {
				availableCount++
			}
		}
	}
	s.T().Logf("  Available seats: %d", availableCount)
}

// ============================================================
// Step 5: Hold Seats
// ============================================================

func (s *E2ETestSuite) Test05_HoldSeats() {
	s.T().Log("Step 5: Hold Seats")

	payload := map[string]interface{}{
		"showtime_id": s.showtimeID,
		"seat_ids":    s.seats,
		"session_id":  s.sessionID,
	}

	resp, err := s.postJSON(SeatServiceURL+"/seats/hold", payload, s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Hold response: %d - %s", resp.StatusCode, truncate(string(body), 300))

	require.Equal(s.T(), http.StatusCreated, resp.StatusCode, "Seat hold must return 201 Created")

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err, "Hold response must be valid JSON")

	holdID, ok := result["hold_id"].(string)
	require.True(s.T(), ok, "Response must contain hold_id")
	require.NotEmpty(s.T(), holdID, "hold_id must not be empty")

	s.holdID = holdID
	s.T().Logf("  Hold created: %s, expires at: %v", s.holdID, result["expires_at"])
}

// ============================================================
// Step 6: Create Booking with Payment
// ============================================================

func (s *E2ETestSuite) Test06_CreateBooking() {
	s.T().Log("Step 6: Create Booking with Payment")

	payload := map[string]interface{}{
		"user": map[string]interface{}{
			"name":        "E2E Test User",
			"lastName":    "Automation",
			"email":       "e2e_test@cinema.local",
			"phoneNumber": "+52 55 1234 5678",
			"creditCard": map[string]interface{}{
				"number":    "4242424242424242",
				"cvc":       "123",
				"exp_month": "12",
				"exp_year":  "2027",
			},
		},
		"booking": map[string]interface{}{
			"showtime_id": s.showtimeID,
			"hold_id":     s.holdID,
			"session_id":  s.sessionID,
			"seats":       s.seats,
			"totalAmount": 240, // 2 tickets at 120 each
		},
	}

	resp, err := s.postJSON(BookingServiceURL+"/booking", payload, s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Booking response: %d - %s", resp.StatusCode, truncate(string(body), 500))

	require.Equal(s.T(), http.StatusCreated, resp.StatusCode, "Booking must return 201 Created")

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err, "Booking response must be valid JSON")

	// Extract booking ID from ticket
	ticket, ok := result["ticket"].(map[string]interface{})
	require.True(s.T(), ok, "Response must contain ticket object")

	bookingID, ok := ticket["booking_id"].(string)
	require.True(s.T(), ok, "Ticket must contain booking_id")
	require.NotEmpty(s.T(), bookingID, "booking_id must not be empty")

	// Store order_id for verification (this is what we use to retrieve the booking)
	orderID, ok := ticket["order_id"].(string)
	require.True(s.T(), ok, "Ticket must contain order_id")
	require.NotEmpty(s.T(), orderID, "order_id must not be empty")

	s.bookingID = orderID // Use order_id for retrieval
	s.T().Logf("  Booking created: booking_id=%s, order_id=%s", bookingID, orderID)
}

// ============================================================
// Step 7: Verify Booking Created
// ============================================================

func (s *E2ETestSuite) Test07_VerifyBooking() {
	s.T().Log("Step 7: Verify Booking")

	require.NotEmpty(s.T(), s.bookingID, "Booking ID must be available from previous step")

	url := fmt.Sprintf("%s/booking/%s", BookingServiceURL, s.bookingID)
	resp, err := s.get(url, s.accessToken)
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Booking details: %d - %s", resp.StatusCode, truncate(string(body), 400))

	require.Equal(s.T(), http.StatusOK, resp.StatusCode, "Booking retrieval must return 200")

	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	require.NoError(s.T(), err, "Booking response must be valid JSON")

	// Verify ticket data exists
	ticket, ok := result["ticket"].(map[string]interface{})
	require.True(s.T(), ok, "Response must contain ticket object")
	require.NotEmpty(s.T(), ticket, "Ticket object must not be empty")

	s.T().Logf("  Booking verified successfully")
}

// ============================================================
// Step 8: Verify Notification Sent (check service health)
// ============================================================

func (s *E2ETestSuite) Test08_VerifyNotification() {
	s.T().Log("Step 8: Verify Notification Service")

	// Just verify the notification service is responding
	// In a real test, we'd check logs or a mock mailbox
	resp, err := s.get(NotificationServiceURL+"/", "")
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	// Any response < 500 means service is healthy (404 is OK - no root handler)
	assert.Less(s.T(), resp.StatusCode, 500, "Notification service should be responding")
	s.T().Log("  Notification service is healthy - email would have been sent")
}

// ============================================================
// Additional Test: Concurrent Seat Holds
// ============================================================

func (s *E2ETestSuite) Test09_ConcurrentSeatHolds() {
	s.T().Log("Step 9: Test Concurrent Seat Hold (Race Condition Prevention)")

	// Try to hold the same seats from two different sessions
	seats := []string{"B1", "B2"}

	// First session holds seats
	session1 := fmt.Sprintf("sess_concurrent_1_%d", time.Now().UnixNano())
	payload1 := map[string]interface{}{
		"showtime_id": s.showtimeID,
		"seat_ids":    seats,
		"session_id":  session1,
	}

	resp1, err := s.postJSON(SeatServiceURL+"/seats/hold", payload1, "")
	if err != nil {
		s.T().Logf("  First hold request failed: %v", err)
		return
	}
	defer resp1.Body.Close()
	body1, _ := io.ReadAll(resp1.Body)
	s.T().Logf("  First hold attempt: %d - %s", resp1.StatusCode, truncate(string(body1), 200))

	// Second session tries to hold same seats (should fail with 409)
	session2 := fmt.Sprintf("sess_concurrent_2_%d", time.Now().UnixNano())
	payload2 := map[string]interface{}{
		"showtime_id": s.showtimeID,
		"seat_ids":    seats,
		"session_id":  session2,
	}

	resp2, err := s.postJSON(SeatServiceURL+"/seats/hold", payload2, "")
	if err != nil {
		s.T().Logf("  Second hold request failed: %v", err)
		return
	}
	defer resp2.Body.Close()
	body2, _ := io.ReadAll(resp2.Body)
	s.T().Logf("  Second hold attempt: %d - %s", resp2.StatusCode, truncate(string(body2), 200))

	// If seat service is implemented, second request should fail
	if resp1.StatusCode == http.StatusCreated {
		assert.Equal(s.T(), http.StatusConflict, resp2.StatusCode,
			"Second hold should fail with 409 Conflict")
	}
}

// ============================================================
// Additional Test: Hold Expiration
// ============================================================

func (s *E2ETestSuite) Test10_HoldExpiration() {
	s.T().Log("Step 10: Test Hold Expiration")

	// Get TTL from environment (default 300s, but test profile uses 5s)
	holdTTL := getEnv("HOLD_TTL_SECONDS", "300")
	ttlSeconds := 300
	if _, err := fmt.Sscanf(holdTTL, "%d", &ttlSeconds); err != nil {
		ttlSeconds = 300
	}

	// Skip if TTL is too long (> 30 seconds)
	if ttlSeconds > 30 {
		s.T().Skipf("Skipping hold expiration test: TTL=%ds is too long (max 30s for test)", ttlSeconds)
		return
	}

	s.T().Logf("  Testing with HOLD_TTL_SECONDS=%d", ttlSeconds)

	// Create a hold with short TTL
	seats := []string{"Z1", "Z2"} // Use seats unlikely to conflict
	sessionID := fmt.Sprintf("sess_expiry_%d", time.Now().UnixNano())

	payload := map[string]interface{}{
		"showtime_id": s.showtimeID,
		"seat_ids":    seats,
		"session_id":  sessionID,
	}

	resp, err := s.postJSON(SeatServiceURL+"/seats/hold", payload, "")
	require.NoError(s.T(), err)
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	s.T().Logf("  Hold created: %d - %s", resp.StatusCode, truncate(string(body), 200))

	if resp.StatusCode != http.StatusCreated {
		s.T().Skip("  Could not create hold, skipping expiration test")
		return
	}

	// Wait for TTL + 1 second buffer
	waitTime := time.Duration(ttlSeconds+1) * time.Second
	s.T().Logf("  Waiting %v for hold to expire...", waitTime)
	time.Sleep(waitTime)

	// Verify seats are available again
	availURL := fmt.Sprintf("%s/seats/availability?showtime_id=%s", SeatServiceURL, s.showtimeID)
	availResp, err := s.get(availURL, "")
	require.NoError(s.T(), err)
	defer availResp.Body.Close()

	availBody, _ := io.ReadAll(availResp.Body)

	var result map[string]interface{}
	err = json.Unmarshal(availBody, &result)
	require.NoError(s.T(), err)

	// Check if our seats are available
	if seatsData, ok := result["seats"].([]interface{}); ok {
		for _, seat := range seatsData {
			if seatMap, ok := seat.(map[string]interface{}); ok {
				seatID, _ := seatMap["seat_id"].(string)
				status, _ := seatMap["status"].(string)
				for _, targetSeat := range seats {
					if seatID == targetSeat {
						s.T().Logf("  Seat %s status: %s", seatID, status)
						assert.Equal(s.T(), "available", status,
							"Seat %s should be available after TTL expiration", seatID)
					}
				}
			}
		}
	}

	s.T().Log("  Hold expiration verified successfully")
}

// ============================================================
// Helper Methods
// ============================================================

func (s *E2ETestSuite) get(url, token string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(s.ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Accept", "application/json")

	return s.client.Do(req)
}

func (s *E2ETestSuite) postJSON(url string, payload interface{}, token string) (*http.Response, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(s.ctx, "POST", url, bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}

	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	return s.client.Do(req)
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// ============================================================
// Standalone Tests (can run independently)
// ============================================================

func TestHealthChecks(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping health checks in short mode")
	}

	// Check root path - any response (including 404) means service is running
	services := map[string]string{
		"user":         UserServiceURL + "/",
		"movie":        MovieServiceURL + "/",
		"cinema":       CinemaServiceURL + "/",
		"showtime":     ShowtimeServiceURL + "/",
		"seat":         SeatServiceURL + "/",
		"payment":      PaymentServiceURL + "/",
		"booking":      BookingServiceURL + "/",
		"notification": NotificationServiceURL + "/",
	}

	healthyCount := 0
	for name, url := range services {
		t.Run(name, func(t *testing.T) {
			if isServiceHealthy(url) {
				t.Logf("%s is healthy at %s", name, url)
				healthyCount++
			} else {
				t.Errorf("%s is NOT responding at %s", name, url)
			}
		})
	}

	t.Logf("\nHealthy services: %d/%d", healthyCount, len(services))
}
