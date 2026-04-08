package api

import (
	"fmt"
	"net/http"
	"time"

	errs "cinemas/services/showtime/internal/errors"
	"cinemas/services/showtime/internal/models"

	"github.com/labstack/echo"
)

// API handles showtime operations
type API struct {
	Store        ShowtimeStore
	MovieClient  MovieServiceClient
	WebhookSender WebhookSender
}

// ShowtimeStore defines the storage interface
type ShowtimeStore interface {
	List(query models.ListShowtimesQuery) (*models.ShowtimeList, error)
	Get(id string) (*models.Showtime, error)
	Create(showtime *models.Showtime) error
	Update(id string, showtime *models.Showtime) error
	CheckRoomConflict(cinemaID string, roomNumber int, startTime, endTime time.Time, excludeID string) (bool, error)
}

// MovieServiceClient defines the movie service client interface
type MovieServiceClient interface {
	MovieExists(movieID string) (bool, error)
}

// WebhookSender defines the webhook sender interface
type WebhookSender interface {
	Send(event models.WebhookEvent) error
}

// Repository defines the API interface
type Repository interface {
	ListShowtimes(c echo.Context) error
	GetShowtime(c echo.Context) error
	CreateShowtime(c echo.Context) error
	UpdateShowtime(c echo.Context) error
	CancelShowtime(c echo.Context) error
}

// Connect creates a new API instance
func Connect(store ShowtimeStore, movieClient MovieServiceClient, webhookSender WebhookSender) Repository {
	return &API{
		Store:        store,
		MovieClient:  movieClient,
		WebhookSender: webhookSender,
	}
}

// ListShowtimes handles GET /showtimes
func (a *API) ListShowtimes(c echo.Context) error {
	query := models.ListShowtimesQuery{
		Page:  1,
		Limit: 20,
	}

	if err := c.Bind(&query); err != nil {
		return errs.SendValidation(c, "invalid query parameters")
	}

	if query.Page < 1 {
		query.Page = 1
	}
	if query.Limit < 1 || query.Limit > 100 {
		query.Limit = 20
	}

	result, err := a.Store.List(query)
	if err != nil {
		return errs.SendInternal(c, "failed to list showtimes")
	}

	return c.JSON(http.StatusOK, result)
}

// GetShowtime handles GET /showtimes/:id
func (a *API) GetShowtime(c echo.Context) error {
	id := c.Param("id")
	if id == "" {
		return errs.SendValidation(c, "missing showtime id")
	}

	showtime, err := a.Store.Get(id)
	if err != nil {
		if err == models.ErrShowtimeNotFound {
			return errs.SendNotFound(c, "showtime not found")
		}
		return errs.SendInternal(c, "failed to get showtime")
	}

	return c.JSON(http.StatusOK, showtime)
}

// CreateShowtime handles POST /showtimes
func (a *API) CreateShowtime(c echo.Context) error {
	var req models.CreateShowtimeRequest

	if err := c.Bind(&req); err != nil {
		return errs.SendValidation(c, "invalid request body")
	}

	if err := req.Validate(); err != nil {
		return errs.SendValidation(c, err.Error())
	}

	// Validate movie exists
	exists, err := a.MovieClient.MovieExists(req.MovieID)
	if err != nil {
		return errs.SendInternal(c, "failed to validate movie")
	}
	if !exists {
		return errs.SendNotFound(c, "movie not found in movie-service")
	}

	// Check room conflict
	conflict, err := a.Store.CheckRoomConflict(req.CinemaID, req.RoomNumber, req.StartTime, req.EndTime, "")
	if err != nil {
		return errs.SendInternal(c, "failed to check room availability")
	}
	if conflict {
		return errs.SendConflict(c, "room is occupied at the specified time")
	}

	now := time.Now()
	showtime := &models.Showtime{
		ID:             generateID(),
		MovieID:        req.MovieID,
		CinemaID:       req.CinemaID,
		RoomNumber:     req.RoomNumber,
		StartTime:      req.StartTime,
		EndTime:        req.EndTime,
		Price:          req.Price,
		AvailableSeats: req.AvailableSeats,
		Status:         models.StatusScheduled,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := a.Store.Create(showtime); err != nil {
		return errs.SendInternal(c, "failed to create showtime")
	}

	// Send webhook event
	if a.WebhookSender != nil {
		event := models.WebhookEvent{
			Event:     "showtime.created",
			Timestamp: now,
			Data:      *showtime,
		}
		_ = a.WebhookSender.Send(event)
	}

	c.Response().Header().Set("Location", fmt.Sprintf("/showtimes/%s", showtime.ID))
	return c.JSON(http.StatusCreated, showtime)
}

// UpdateShowtime handles PUT /showtimes/:id
func (a *API) UpdateShowtime(c echo.Context) error {
	id := c.Param("id")
	if id == "" {
		return errs.SendValidation(c, "missing showtime id")
	}

	showtime, err := a.Store.Get(id)
	if err != nil {
		if err == models.ErrShowtimeNotFound {
			return errs.SendNotFound(c, "showtime not found")
		}
		return errs.SendInternal(c, "failed to get showtime")
	}

	if showtime.Status == models.StatusCompleted || showtime.Status == models.StatusCancelled {
		return errs.SendConflict(c, "cannot modify completed or cancelled showtime")
	}

	var req models.UpdateShowtimeRequest
	if err := c.Bind(&req); err != nil {
		return errs.SendValidation(c, "invalid request body")
	}

	// Apply updates
	if req.RoomNumber != nil {
		showtime.RoomNumber = *req.RoomNumber
	}
	if req.StartTime != nil {
		showtime.StartTime = *req.StartTime
	}
	if req.EndTime != nil {
		showtime.EndTime = *req.EndTime
	}
	if req.Price != nil {
		showtime.Price = *req.Price
	}
	if req.AvailableSeats != nil {
		showtime.AvailableSeats = *req.AvailableSeats
	}
	if req.Status != nil && models.IsValidStatus(*req.Status) {
		showtime.Status = *req.Status
	}

	showtime.UpdatedAt = time.Now()

	if err := a.Store.Update(id, showtime); err != nil {
		return errs.SendInternal(c, "failed to update showtime")
	}

	return c.JSON(http.StatusOK, showtime)
}

// CancelShowtime handles DELETE /showtimes/:id
func (a *API) CancelShowtime(c echo.Context) error {
	id := c.Param("id")
	if id == "" {
		return errs.SendValidation(c, "missing showtime id")
	}

	showtime, err := a.Store.Get(id)
	if err != nil {
		if err == models.ErrShowtimeNotFound {
			return errs.SendNotFound(c, "showtime not found")
		}
		return errs.SendInternal(c, "failed to get showtime")
	}

	if showtime.Status == models.StatusCancelled || showtime.Status == models.StatusCompleted {
		return errs.SendConflict(c, "showtime already cancelled or completed")
	}

	now := time.Now()
	showtime.Status = models.StatusCancelled
	showtime.UpdatedAt = now

	if err := a.Store.Update(id, showtime); err != nil {
		return errs.SendInternal(c, "failed to cancel showtime")
	}

	// Send webhook event
	if a.WebhookSender != nil {
		event := models.WebhookEvent{
			Event:     "showtime.cancelled",
			Timestamp: now,
			Data:      *showtime,
		}
		_ = a.WebhookSender.Send(event)
	}

	return c.JSON(http.StatusOK, showtime)
}

// generateID generates a unique showtime ID
func generateID() string {
	return fmt.Sprintf("sht_%d", time.Now().UnixNano())
}
