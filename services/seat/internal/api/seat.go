package api

import (
	"context"
	"net/http"
	"time"

	"cinemas/services/seat/internal/db"
	errs "cinemas/services/seat/internal/errors"
	"cinemas/services/seat/internal/models"

	"github.com/labstack/echo"
)

// API holds the database clients
type API struct {
	redis *db.RedisClient
	mongo *db.MongoClient
}

// Repository defines the seat API interface
type Repository interface {
	GetAvailability(c echo.Context) error
	HoldSeats(c echo.Context) error
	GetHold(c echo.Context) error
	ReleaseHold(c echo.Context) error
	ReserveSeats(c echo.Context) error
	CreateRoomLayout(c echo.Context) error
	GetRoomLayout(c echo.Context) error
}

// NewAPI creates a new API instance
func NewAPI(redis *db.RedisClient, mongo *db.MongoClient) Repository {
	return &API{
		redis: redis,
		mongo: mongo,
	}
}

// PingAPI handles health check
func PingAPI(c echo.Context) error {
	return c.String(http.StatusOK, "pong")
}

// GetAvailability returns the seat map with availability status
func (a *API) GetAvailability(c echo.Context) error {
	showtimeID := c.QueryParam("showtime_id")
	if showtimeID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "showtime_id is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get room ID for this showtime
	roomID, err := a.mongo.GetShowtimeRoomID(ctx, showtimeID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get showtime info", err)
	}

	// Get room layout
	layout, err := a.mongo.GetRoomLayout(ctx, roomID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get room layout", err)
	}
	if layout == nil {
		return errs.NotFound(errs.CodeNotFound, "Room layout not found")
	}

	// Get reserved seats from MongoDB
	reservedSeats, err := a.mongo.GetReservedSeats(ctx, showtimeID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get reserved seats", err)
	}

	// Get held seats from Redis
	heldSeats, err := a.redis.GetHeldSeats(ctx, showtimeID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get held seats", err)
	}

	// Build seat map
	seats := make([]models.Seat, 0, len(layout.Seats))
	summary := models.AvailabilitySummary{Total: len(layout.Seats)}

	for _, def := range layout.Seats {
		seat := models.Seat{
			ID:            def.ID,
			Row:           def.Row,
			Number:        def.Number,
			Type:          def.Type,
			PriceModifier: def.PriceModifier,
		}

		// Determine status
		if def.Type == models.SeatTypeUnavailable {
			seat.Status = models.SeatStatusUnavailable
			summary.Unavailable++
		} else if reservedSeats[def.ID] {
			seat.Status = models.SeatStatusReserved
			summary.Reserved++
		} else if hold, ok := heldSeats[def.ID]; ok {
			seat.Status = models.SeatStatusHeld
			seat.HeldUntil = hold.HeldUntil
			seat.HeldBy = hold.HeldBy
			summary.Held++
		} else {
			seat.Status = models.SeatStatusAvailable
			summary.Available++
		}

		seats = append(seats, seat)
	}

	// Build row labels
	rowLabels := make([]string, 0)
	seenRows := make(map[string]bool)
	for _, seat := range seats {
		if !seenRows[seat.Row] {
			rowLabels = append(rowLabels, seat.Row)
			seenRows[seat.Row] = true
		}
	}

	seatMap := models.SeatMap{
		ShowtimeID: showtimeID,
		RoomID:     roomID,
		RoomLayout: models.RoomLayoutMatrix{
			Rows:      layout.Rows,
			Columns:   layout.Columns,
			RowLabels: rowLabels,
		},
		Seats:   seats,
		Summary: summary,
	}

	return c.JSON(http.StatusOK, seatMap)
}

// HoldSeats creates a temporary hold on seats
func (a *API) HoldSeats(c echo.Context) error {
	var req models.HoldRequest
	if err := c.Bind(&req); err != nil {
		return errs.BadRequest(errs.CodeInvalidRequest, "Invalid request body")
	}

	// Validate request
	if req.ShowtimeID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "showtime_id is required")
	}
	if len(req.SeatIDs) == 0 {
		return errs.BadRequest(errs.CodeInvalidRequest, "seat_ids is required")
	}
	if len(req.SeatIDs) > 10 {
		return errs.BadRequest(errs.CodeInvalidRequest, "Maximum 10 seats per hold")
	}
	if len(req.SessionID) < 10 {
		return errs.BadRequest(errs.CodeInvalidRequest, "session_id must be at least 10 characters")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Verify seats exist in layout
	roomID, err := a.mongo.GetShowtimeRoomID(ctx, req.ShowtimeID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get showtime info", err)
	}

	layout, err := a.mongo.GetRoomLayout(ctx, roomID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get room layout", err)
	}
	if layout == nil {
		return errs.NotFound(errs.CodeNotFound, "Room layout not found")
	}

	// Build seat lookup
	seatLookup := make(map[string]*models.SeatDefinition)
	for i := range layout.Seats {
		seatLookup[layout.Seats[i].ID] = &layout.Seats[i]
	}

	// Verify all requested seats exist and are not unavailable type
	invalidSeats := make([]string, 0)
	for _, seatID := range req.SeatIDs {
		def, ok := seatLookup[seatID]
		if !ok {
			invalidSeats = append(invalidSeats, seatID)
		} else if def.Type == models.SeatTypeUnavailable {
			invalidSeats = append(invalidSeats, seatID)
		}
	}
	if len(invalidSeats) > 0 {
		return errs.BadRequest(errs.CodeInvalidSeats, "Invalid or unavailable seats: "+joinStrings(invalidSeats))
	}

	// Check if seats are already reserved in MongoDB
	reservedSeats, err := a.mongo.GetReservedSeats(ctx, req.ShowtimeID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to check reserved seats", err)
	}

	alreadyReserved := make([]models.UnavailableSeat, 0)
	for _, seatID := range req.SeatIDs {
		if reservedSeats[seatID] {
			alreadyReserved = append(alreadyReserved, models.UnavailableSeat{
				SeatID: seatID,
				Status: models.SeatStatusReserved,
			})
		}
	}
	if len(alreadyReserved) > 0 {
		return errs.ConflictWithSeats(alreadyReserved)
	}

	// Try to hold seats atomically in Redis
	hold, unavailable, err := a.redis.HoldSeats(ctx, req.ShowtimeID, req.SeatIDs, req.SessionID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to hold seats", err)
	}
	if len(unavailable) > 0 {
		return errs.ConflictWithSeats(unavailable)
	}

	// Build response with seat details
	seats := make([]models.Seat, 0, len(req.SeatIDs))
	for _, seatID := range req.SeatIDs {
		def := seatLookup[seatID]
		seats = append(seats, models.Seat{
			ID:            def.ID,
			Row:           def.Row,
			Number:        def.Number,
			Type:          def.Type,
			Status:        models.SeatStatusHeld,
			HeldUntil:     &hold.ExpiresAt,
			HeldBy:        req.SessionID,
			PriceModifier: def.PriceModifier,
		})
	}

	response := models.HoldResponse{
		HoldID:     hold.HoldID,
		ShowtimeID: hold.ShowtimeID,
		Seats:      seats,
		ExpiresAt:  hold.ExpiresAt,
		TTLSeconds: int(time.Until(hold.ExpiresAt).Seconds()),
		Message:    "Seats held successfully. Complete payment within 5 minutes.",
	}

	c.Response().Header().Set("X-Hold-Expires", hold.ExpiresAt.Format(time.RFC3339))
	return c.JSON(http.StatusCreated, response)
}

// GetHold retrieves a seat hold by ID (for verification)
func (a *API) GetHold(c echo.Context) error {
	holdID := c.Param("hold_id")
	if holdID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "hold_id is required")
	}

	sessionID := c.QueryParam("session_id")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	hold, err := a.redis.GetHold(ctx, holdID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get hold", err)
	}
	if hold == nil {
		return errs.NotFound(errs.CodeHoldNotFound, "Hold not found or expired")
	}

	// If session_id provided, verify ownership
	if sessionID != "" && hold.SessionID != sessionID {
		return errs.Forbidden(errs.CodeUnauthorized, "Not authorized to view this hold")
	}

	response := models.HoldResponse{
		HoldID:     hold.HoldID,
		ShowtimeID: hold.ShowtimeID,
		Seats:      nil, // We don't store seat details in Redis hold
		ExpiresAt:  hold.ExpiresAt,
		TTLSeconds: int(time.Until(hold.ExpiresAt).Seconds()),
		Message:    "Hold is valid",
	}

	return c.JSON(http.StatusOK, response)
}

// ReleaseHold releases a seat hold
func (a *API) ReleaseHold(c echo.Context) error {
	holdID := c.Param("hold_id")
	if holdID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "hold_id is required")
	}

	var req models.ReleaseHoldRequest
	if err := c.Bind(&req); err != nil {
		return errs.BadRequest(errs.CodeInvalidRequest, "Invalid request body")
	}

	if req.SessionID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "session_id is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get the hold first
	hold, err := a.redis.GetHold(ctx, holdID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get hold", err)
	}
	if hold == nil {
		return errs.NotFound(errs.CodeHoldNotFound, "Hold not found or already expired")
	}

	// Verify session ownership
	if hold.SessionID != req.SessionID {
		return errs.Forbidden(errs.CodeUnauthorized, "Not authorized to release this hold")
	}

	// Release the hold
	released, err := a.redis.ReleaseHold(ctx, holdID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to release hold", err)
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"message":        "Hold released successfully",
		"released_seats": released.SeatIDs,
	})
}

// ReserveSeats converts a hold to a permanent reservation
func (a *API) ReserveSeats(c echo.Context) error {
	var req models.ReserveRequest
	if err := c.Bind(&req); err != nil {
		return errs.BadRequest(errs.CodeInvalidRequest, "Invalid request body")
	}

	if req.HoldID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "hold_id is required")
	}
	if req.BookingID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "booking_id is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check for existing reservation (idempotency)
	existingRes, err := a.mongo.GetReservationByHoldID(ctx, req.HoldID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to check existing reservation", err)
	}
	if existingRes != nil {
		// Return existing reservation (idempotent)
		return a.buildReservationResponse(c, existingRes, http.StatusConflict)
	}

	// Get the hold
	hold, err := a.redis.GetHold(ctx, req.HoldID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get hold", err)
	}
	if hold == nil {
		return errs.NotFound(errs.CodeHoldExpired, "Hold has expired. Please select seats again.")
	}

	// Create reservation in MongoDB
	reservation, err := a.mongo.CreateReservation(ctx, hold, req.BookingID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to create reservation", err)
	}

	// Release the hold from Redis (seats are now permanently reserved)
	_, _ = a.redis.ReleaseHold(ctx, req.HoldID)

	return a.buildReservationResponse(c, reservation, http.StatusCreated)
}

// buildReservationResponse builds the reservation response with seat details
func (a *API) buildReservationResponse(c echo.Context, res *models.Reservation, status int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get room layout for seat details
	roomID, _ := a.mongo.GetShowtimeRoomID(ctx, res.ShowtimeID)
	layout, _ := a.mongo.GetRoomLayout(ctx, roomID)

	seats := make([]models.Seat, 0, len(res.SeatIDs))
	if layout != nil {
		seatLookup := make(map[string]*models.SeatDefinition)
		for i := range layout.Seats {
			seatLookup[layout.Seats[i].ID] = &layout.Seats[i]
		}

		for _, seatID := range res.SeatIDs {
			if def, ok := seatLookup[seatID]; ok {
				seats = append(seats, models.Seat{
					ID:            def.ID,
					Row:           def.Row,
					Number:        def.Number,
					Type:          def.Type,
					Status:        models.SeatStatusReserved,
					PriceModifier: def.PriceModifier,
				})
			}
		}
	}

	response := models.ReservationResponse{
		ReservationID: res.ReservationID,
		BookingID:     res.BookingID,
		ShowtimeID:    res.ShowtimeID,
		Seats:         seats,
		ConfirmedAt:   res.ConfirmedAt,
		Message:       "Reservation confirmed successfully",
	}

	return c.JSON(status, response)
}

// CreateRoomLayout creates a new room layout
func (a *API) CreateRoomLayout(c echo.Context) error {
	var layout models.RoomLayout
	if err := c.Bind(&layout); err != nil {
		return errs.BadRequest(errs.CodeInvalidRequest, "Invalid request body")
	}

	// Validate
	if layout.RoomID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "room_id is required")
	}
	if layout.Name == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "name is required")
	}
	if layout.Rows < 1 || layout.Rows > 26 {
		return errs.BadRequest(errs.CodeInvalidRequest, "rows must be between 1 and 26")
	}
	if layout.Columns < 1 || layout.Columns > 50 {
		return errs.BadRequest(errs.CodeInvalidRequest, "columns must be between 1 and 50")
	}
	if len(layout.Seats) == 0 {
		return errs.BadRequest(errs.CodeInvalidRequest, "seats array is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := a.mongo.CreateRoomLayout(ctx, &layout); err != nil {
		if err.Error()[:17] == "room already exists" {
			return errs.Conflict(errs.CodeConflict, err.Error())
		}
		return errs.Internal(errs.CodeInternalError, "Failed to create room layout", err)
	}

	return c.JSON(http.StatusCreated, layout)
}

// GetRoomLayout retrieves a room layout
func (a *API) GetRoomLayout(c echo.Context) error {
	roomID := c.Param("room_id")
	if roomID == "" {
		return errs.BadRequest(errs.CodeInvalidRequest, "room_id is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	layout, err := a.mongo.GetRoomLayout(ctx, roomID)
	if err != nil {
		return errs.Internal(errs.CodeInternalError, "Failed to get room layout", err)
	}
	if layout == nil {
		return errs.NotFound(errs.CodeNotFound, "Room layout not found")
	}

	return c.JSON(http.StatusOK, layout)
}

// Helper function
func joinStrings(strs []string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += ", " + strs[i]
	}
	return result
}
