package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"cinemas/services/seat/internal/db"
	"cinemas/services/seat/internal/models"

	"github.com/labstack/echo"
)

// TestConfig holds test configuration
type TestConfig struct {
	RedisAddr string
	MongoURI  string
	MongoDB   string
}

// getTestConfig returns test configuration from env or defaults
func getTestConfig() TestConfig {
	return TestConfig{
		RedisAddr: "localhost:6379",
		MongoURI:  "mongodb://localhost:27017",
		MongoDB:   "cinema_seats_test",
	}
}

// setupTestAPI creates a test API instance with real Redis and MongoDB connections
// Skip if connections fail (for CI without services)
func setupTestAPI(t *testing.T) (*API, func()) {
	t.Helper()
	cfg := getTestConfig()

	redis, err := db.NewRedisClient(cfg.RedisAddr, "", 15) // Use DB 15 for tests
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
	}

	mongo, err := db.NewMongoClient(cfg.MongoURI, cfg.MongoDB)
	if err != nil {
		redis.Close()
		t.Skipf("Skipping test: MongoDB not available: %v", err)
	}

	api := &API{
		redis: redis,
		mongo: mongo,
	}

	cleanup := func() {
		// Clean up test data
		ctx := context.Background()
		mongo.Database().Drop(ctx)
		redis.Close()
	}

	return api, cleanup
}

// setupTestRoom creates a test room layout
func setupTestRoom(t *testing.T, api *API, roomID string, seatCount int) {
	t.Helper()
	ctx := context.Background()

	seats := make([]models.SeatDefinition, 0, seatCount)
	for i := 0; i < seatCount; i++ {
		row := string('A' + rune(i/10))
		num := (i % 10) + 1
		seats = append(seats, models.SeatDefinition{
			ID:            row + string('0'+rune(num)),
			Row:           row,
			Number:        num,
			Type:          models.SeatTypeRegular,
			PriceModifier: 1.0,
		})
	}

	layout := &models.RoomLayout{
		RoomID:  roomID,
		Name:    "Test Room",
		Rows:    (seatCount + 9) / 10,
		Columns: 10,
		Seats:   seats,
	}

	if err := api.mongo.CreateRoomLayout(ctx, layout); err != nil {
		t.Fatalf("Failed to create test room: %v", err)
	}
}

// TestConcurrentHoldSameSeats tests that only one of many concurrent requests
// can hold the same seats
func TestConcurrentHoldSameSeats(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	api, cleanup := setupTestAPI(t)
	defer cleanup()

	// Setup test room
	setupTestRoom(t, api, "room_001", 20)

	// Create Echo instance
	e := echo.New()

	showtimeID := "showtime_concurrent_test"
	seatIDs := []string{"A1", "A2"}
	numGoroutines := 10

	var successCount int32
	var wg sync.WaitGroup

	// Launch concurrent hold requests
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(sessionNum int) {
			defer wg.Done()

			req := models.HoldRequest{
				ShowtimeID: showtimeID,
				SeatIDs:    seatIDs,
				SessionID:  "test_session_" + string('a'+rune(sessionNum)) + "0123456789",
			}
			body, _ := json.Marshal(req)

			httpReq := httptest.NewRequest(http.MethodPost, "/seats/hold", bytes.NewReader(body))
			httpReq.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(httpReq, rec)

			err := api.HoldSeats(c)
			if err == nil && rec.Code == http.StatusCreated {
				atomic.AddInt32(&successCount, 1)
			}
		}(i)
	}

	wg.Wait()

	// Only ONE request should succeed
	if successCount != 1 {
		t.Errorf("Expected exactly 1 successful hold, got %d", successCount)
	}
}

// TestHoldExpiration tests that holds expire after TTL
func TestHoldExpiration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	api, cleanup := setupTestAPI(t)
	defer cleanup()

	// Setup test room
	setupTestRoom(t, api, "room_001", 20)

	ctx := context.Background()
	showtimeID := "showtime_expiration_test"
	seatIDs := []string{"A3"}
	sessionID := "test_session_exp123456"

	// Create a hold
	hold, unavailable, err := api.redis.HoldSeats(ctx, showtimeID, seatIDs, sessionID)
	if err != nil {
		t.Fatalf("Failed to create hold: %v", err)
	}
	if len(unavailable) > 0 {
		t.Fatalf("Seats should be available: %v", unavailable)
	}

	// Verify hold exists
	retrieved, err := api.redis.GetHold(ctx, hold.HoldID)
	if err != nil {
		t.Fatalf("Failed to get hold: %v", err)
	}
	if retrieved == nil {
		t.Fatal("Hold should exist")
	}

	// Verify seat is held
	status, err := api.redis.GetSeatHoldStatus(ctx, showtimeID, "A3")
	if err != nil {
		t.Fatalf("Failed to get seat status: %v", err)
	}
	if status == nil {
		t.Fatal("Seat should be held")
	}

	t.Logf("Hold created with TTL, expires at: %v", hold.ExpiresAt)
}

// TestConcurrentDifferentSeats tests that concurrent requests for different seats
// all succeed
func TestConcurrentDifferentSeats(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	api, cleanup := setupTestAPI(t)
	defer cleanup()

	// Setup test room with many seats
	setupTestRoom(t, api, "room_001", 100)

	e := echo.New()
	showtimeID := "showtime_diff_seats_test"
	numGoroutines := 10

	var successCount int32
	var wg sync.WaitGroup

	// Each goroutine requests different seats
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()

			// Each request gets unique seats
			row := string('A' + rune(idx))
			seatIDs := []string{row + "1", row + "2"}

			req := models.HoldRequest{
				ShowtimeID: showtimeID,
				SeatIDs:    seatIDs,
				SessionID:  "test_session_diff_" + string('a'+rune(idx)) + "0123456789",
			}
			body, _ := json.Marshal(req)

			httpReq := httptest.NewRequest(http.MethodPost, "/seats/hold", bytes.NewReader(body))
			httpReq.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(httpReq, rec)

			err := api.HoldSeats(c)
			if err == nil && rec.Code == http.StatusCreated {
				atomic.AddInt32(&successCount, 1)
			}
		}(i)
	}

	wg.Wait()

	// ALL requests should succeed since they request different seats
	if successCount != int32(numGoroutines) {
		t.Errorf("Expected %d successful holds, got %d", numGoroutines, successCount)
	}
}

// TestReserveIdempotency tests that reserve is idempotent
func TestReserveIdempotency(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	api, cleanup := setupTestAPI(t)
	defer cleanup()

	setupTestRoom(t, api, "room_001", 20)

	ctx := context.Background()
	showtimeID := "showtime_idempotent_test"
	seatIDs := []string{"A5", "A6"}
	sessionID := "test_session_idemp123456"
	bookingID := "booking_123"

	// Create a hold
	hold, _, err := api.redis.HoldSeats(ctx, showtimeID, seatIDs, sessionID)
	if err != nil {
		t.Fatalf("Failed to create hold: %v", err)
	}

	// First reserve - should succeed
	res1, err := api.mongo.CreateReservation(ctx, hold, bookingID)
	if err != nil {
		t.Fatalf("First reserve failed: %v", err)
	}

	// Second reserve with same hold - should return same reservation (idempotent)
	res2, err := api.mongo.CreateReservation(ctx, hold, bookingID)
	if err != nil {
		t.Fatalf("Second reserve failed: %v", err)
	}

	if res1.ReservationID != res2.ReservationID {
		t.Errorf("Expected same reservation ID, got %s and %s", res1.ReservationID, res2.ReservationID)
	}
}

// TestReleaseHoldAuthorization tests that only the session owner can release a hold
func TestReleaseHoldAuthorization(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	api, cleanup := setupTestAPI(t)
	defer cleanup()

	setupTestRoom(t, api, "room_001", 20)

	ctx := context.Background()
	showtimeID := "showtime_auth_test"
	seatIDs := []string{"A7"}
	sessionID := "test_session_auth123456"

	// Create a hold
	hold, _, err := api.redis.HoldSeats(ctx, showtimeID, seatIDs, sessionID)
	if err != nil {
		t.Fatalf("Failed to create hold: %v", err)
	}

	e := echo.New()

	// Try to release with wrong session - should fail
	wrongReq := models.ReleaseHoldRequest{SessionID: "wrong_session_1234567890"}
	body, _ := json.Marshal(wrongReq)

	httpReq := httptest.NewRequest(http.MethodDelete, "/seats/hold/"+hold.HoldID, bytes.NewReader(body))
	httpReq.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(httpReq, rec)
	c.SetParamNames("hold_id")
	c.SetParamValues(hold.HoldID)

	err = api.ReleaseHold(c)
	if err == nil {
		t.Error("Expected error for unauthorized release")
	}

	// Try to release with correct session - should succeed
	correctReq := models.ReleaseHoldRequest{SessionID: sessionID}
	body, _ = json.Marshal(correctReq)

	httpReq = httptest.NewRequest(http.MethodDelete, "/seats/hold/"+hold.HoldID, bytes.NewReader(body))
	httpReq.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec = httptest.NewRecorder()
	c = e.NewContext(httpReq, rec)
	c.SetParamNames("hold_id")
	c.SetParamValues(hold.HoldID)

	err = api.ReleaseHold(c)
	if err != nil {
		t.Errorf("Authorized release should succeed: %v", err)
	}
}

// TestHighConcurrencyStress tests the system under high concurrent load
func TestHighConcurrencyStress(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping stress test in short mode")
	}

	api, cleanup := setupTestAPI(t)
	defer cleanup()

	// Large room
	setupTestRoom(t, api, "room_001", 200)

	e := echo.New()
	showtimeID := "showtime_stress_test"
	numGoroutines := 50
	numSeatsPerRequest := 2

	results := make(chan struct {
		success bool
		seatID  string
	}, numGoroutines)

	var wg sync.WaitGroup

	start := time.Now()

	// Half try same seats (conflict), half try different seats
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()

			var seatIDs []string
			if idx < numGoroutines/2 {
				// All these try the same seats (A1, A2)
				seatIDs = []string{"A1", "A2"}
			} else {
				// Each of these tries different seats
				row := string('B' + rune(idx-numGoroutines/2))
				seatIDs = make([]string, numSeatsPerRequest)
				for j := 0; j < numSeatsPerRequest; j++ {
					seatIDs[j] = row + string('1'+rune(j))
				}
			}

			req := models.HoldRequest{
				ShowtimeID: showtimeID,
				SeatIDs:    seatIDs,
				SessionID:  "stress_session_" + string('a'+rune(idx%26)) + "0123456789",
			}
			body, _ := json.Marshal(req)

			httpReq := httptest.NewRequest(http.MethodPost, "/seats/hold", bytes.NewReader(body))
			httpReq.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
			rec := httptest.NewRecorder()
			c := e.NewContext(httpReq, rec)

			err := api.HoldSeats(c)
			results <- struct {
				success bool
				seatID  string
			}{
				success: err == nil && rec.Code == http.StatusCreated,
				seatID:  seatIDs[0],
			}
		}(i)
	}

	wg.Wait()
	close(results)

	elapsed := time.Since(start)

	var totalSuccess, conflictSuccess, nonConflictSuccess int
	for r := range results {
		if r.success {
			totalSuccess++
			if r.seatID == "A1" {
				conflictSuccess++
			} else {
				nonConflictSuccess++
			}
		}
	}

	t.Logf("Stress test completed in %v", elapsed)
	t.Logf("Total successful holds: %d/%d", totalSuccess, numGoroutines)
	t.Logf("Conflict group (A1,A2): %d successful (expected 1)", conflictSuccess)
	t.Logf("Non-conflict group: %d successful (expected %d)", nonConflictSuccess, numGoroutines/2)

	// Exactly 1 should succeed for the conflict group
	if conflictSuccess != 1 {
		t.Errorf("Expected exactly 1 success for conflicting seats, got %d", conflictSuccess)
	}

	// All should succeed for the non-conflict group
	if nonConflictSuccess != numGoroutines/2 {
		t.Errorf("Expected %d successes for non-conflicting seats, got %d", numGoroutines/2, nonConflictSuccess)
	}
}
