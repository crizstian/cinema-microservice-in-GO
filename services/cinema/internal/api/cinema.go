package api

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"cinemas/services/cinema/internal/models"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// Handler holds the database connection for API handlers.
type Handler struct {
	db *mongo.Database
}

// NewHandler creates a new API handler.
func NewHandler(db *mongo.Database) *Handler {
	return &Handler{db: db}
}

// ListCinemas returns a list of cinemas with optional city filter.
func (h *Handler) ListCinemas(c echo.Context) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	filter := bson.M{}
	if city := c.QueryParam("city"); city != "" {
		filter["city"] = city
	}

	limit := 20
	if l := c.QueryParam("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
			limit = parsed
		}
	}

	offset := 0
	if o := c.QueryParam("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	opts := options.Find().SetLimit(int64(limit)).SetSkip(int64(offset))
	cursor, err := h.db.Collection("cinemas").Find(ctx, filter, opts)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to fetch cinemas",
		})
	}
	defer cursor.Close(ctx)

	var cinemas []models.Cinema
	if err := cursor.All(ctx, &cinemas); err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to decode cinemas",
		})
	}

	if cinemas == nil {
		cinemas = []models.Cinema{}
	}

	total, _ := h.db.Collection("cinemas").CountDocuments(ctx, filter)

	return c.JSON(http.StatusOK, models.CinemaListResponse{
		Cinemas: cinemas,
		Total:   int(total),
	})
}

// GetCinema returns a single cinema by ID with its rooms.
func (h *Handler) GetCinema(c echo.Context) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	id := c.Param("id")

	var cinema models.Cinema
	err := h.db.Collection("cinemas").FindOne(ctx, bson.M{"_id": id}).Decode(&cinema)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return c.JSON(http.StatusNotFound, models.ErrorResponse{
				Error:   "not_found",
				Message: "Cinema not found",
			})
		}
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to fetch cinema",
		})
	}

	cursor, err := h.db.Collection("rooms").Find(ctx, bson.M{"cinema_id": id})
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to fetch rooms",
		})
	}
	defer cursor.Close(ctx)

	var rooms []models.Room
	if err := cursor.All(ctx, &rooms); err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to decode rooms",
		})
	}

	if rooms == nil {
		rooms = []models.Room{}
	}

	result := models.CinemaWithRooms{
		Cinema: cinema,
		Rooms:  rooms,
	}

	return c.JSON(http.StatusOK, result)
}

// CreateCinema creates a new cinema.
func (h *Handler) CreateCinema(c echo.Context) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var req models.CreateCinemaRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error:   "invalid_request",
			Message: "Invalid request body",
		})
	}

	if err := req.Validate(); err != nil {
		return c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error:   "validation_error",
			Message: err.Error(),
		})
	}

	cinema := models.Cinema{
		ID:        "cin_" + uuid.New().String()[:8],
		Name:      req.Name,
		Address:   req.Address,
		City:      req.City,
		Country:   req.Country,
		Location:  req.Location,
		Amenities: req.Amenities,
	}

	_, err := h.db.Collection("cinemas").InsertOne(ctx, cinema)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to create cinema",
		})
	}

	return c.JSON(http.StatusCreated, cinema)
}

// ListRooms returns rooms for a specific cinema.
func (h *Handler) ListRooms(c echo.Context) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cinemaID := c.Param("id")

	count, err := h.db.Collection("cinemas").CountDocuments(ctx, bson.M{"_id": cinemaID})
	if err != nil || count == 0 {
		return c.JSON(http.StatusNotFound, models.ErrorResponse{
			Error:   "not_found",
			Message: "Cinema not found",
		})
	}

	filter := bson.M{"cinema_id": cinemaID}
	if roomType := c.QueryParam("type"); roomType != "" {
		filter["type"] = roomType
	}

	cursor, err := h.db.Collection("rooms").Find(ctx, filter)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to fetch rooms",
		})
	}
	defer cursor.Close(ctx)

	var rooms []models.Room
	if err := cursor.All(ctx, &rooms); err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to decode rooms",
		})
	}

	if rooms == nil {
		rooms = []models.Room{}
	}

	return c.JSON(http.StatusOK, models.RoomListResponse{
		Rooms: rooms,
		Total: len(rooms),
	})
}

// CreateRoom creates a new room in a cinema.
func (h *Handler) CreateRoom(c echo.Context) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cinemaID := c.Param("id")

	count, err := h.db.Collection("cinemas").CountDocuments(ctx, bson.M{"_id": cinemaID})
	if err != nil || count == 0 {
		return c.JSON(http.StatusNotFound, models.ErrorResponse{
			Error:   "not_found",
			Message: "Cinema not found",
		})
	}

	var req models.CreateRoomRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error:   "invalid_request",
			Message: "Invalid request body",
		})
	}

	if err := req.Validate(); err != nil {
		return c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error:   "validation_error",
			Message: err.Error(),
		})
	}

	room := models.Room{
		ID:           "room_" + uuid.New().String()[:8],
		CinemaID:     cinemaID,
		Name:         req.Name,
		RoomNumber:   req.RoomNumber,
		Capacity:     req.Capacity,
		Type:         req.Type,
		SeatLayoutID: req.SeatLayoutID,
	}

	_, err = h.db.Collection("rooms").InsertOne(ctx, room)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:   "database_error",
			Message: "Failed to create room",
		})
	}

	return c.JSON(http.StatusCreated, room)
}

// Ping is a health check endpoint.
func (h *Handler) Ping(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{"status": "pong"})
}
