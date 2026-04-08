package db

import (
	"context"
	"fmt"
	"time"

	"cinemas/services/seat/internal/models"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// MongoClient wraps MongoDB operations for seat service
type MongoClient struct {
	db *mongo.Database
}

// NewMongoClient creates a new MongoDB client
func NewMongoClient(uri, dbName string) (*MongoClient, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(uri))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to MongoDB: %w", err)
	}

	if err := client.Ping(ctx, nil); err != nil {
		return nil, fmt.Errorf("failed to ping MongoDB: %w", err)
	}

	db := client.Database(dbName)

	// Create indexes
	mc := &MongoClient{db: db}
	if err := mc.createIndexes(ctx); err != nil {
		return nil, fmt.Errorf("failed to create indexes: %w", err)
	}

	return mc, nil
}

// createIndexes creates necessary indexes for the collections
func (m *MongoClient) createIndexes(ctx context.Context) error {
	// Index for reservations
	_, err := m.db.Collection("reservations").Indexes().CreateMany(ctx, []mongo.IndexModel{
		{
			Keys:    bson.D{{Key: "showtime_id", Value: 1}, {Key: "seat_ids", Value: 1}},
			Options: options.Index().SetUnique(true),
		},
		{
			Keys: bson.D{{Key: "booking_id", Value: 1}},
		},
		{
			Keys: bson.D{{Key: "hold_id", Value: 1}},
		},
	})
	if err != nil {
		return err
	}

	// Index for room layouts
	_, err = m.db.Collection("room_layouts").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "room_id", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	return err
}

// Database returns the underlying MongoDB database
func (m *MongoClient) Database() *mongo.Database {
	return m.db
}

// CreateReservation creates a new reservation from a hold
func (m *MongoClient) CreateReservation(ctx context.Context, hold *models.Hold, bookingID string) (*models.Reservation, error) {
	reservation := &models.Reservation{
		ReservationID: uuid.New().String(),
		BookingID:     bookingID,
		ShowtimeID:    hold.ShowtimeID,
		SeatIDs:       hold.SeatIDs,
		SessionID:     hold.SessionID,
		ConfirmedAt:   time.Now(),
	}

	// Store with hold_id for idempotency check
	doc := bson.M{
		"reservation_id": reservation.ReservationID,
		"hold_id":        hold.HoldID,
		"booking_id":     reservation.BookingID,
		"showtime_id":    reservation.ShowtimeID,
		"seat_ids":       reservation.SeatIDs,
		"session_id":     reservation.SessionID,
		"confirmed_at":   reservation.ConfirmedAt,
	}

	_, err := m.db.Collection("reservations").InsertOne(ctx, doc)
	if err != nil {
		// Check if it's a duplicate key error (idempotent retry)
		if mongo.IsDuplicateKeyError(err) {
			// Return existing reservation
			return m.GetReservationByHoldID(ctx, hold.HoldID)
		}
		return nil, fmt.Errorf("failed to create reservation: %w", err)
	}

	return reservation, nil
}

// GetReservationByHoldID retrieves a reservation by hold ID (for idempotency)
func (m *MongoClient) GetReservationByHoldID(ctx context.Context, holdID string) (*models.Reservation, error) {
	var result struct {
		ReservationID string    `bson:"reservation_id"`
		BookingID     string    `bson:"booking_id"`
		ShowtimeID    string    `bson:"showtime_id"`
		SeatIDs       []string  `bson:"seat_ids"`
		SessionID     string    `bson:"session_id"`
		ConfirmedAt   time.Time `bson:"confirmed_at"`
	}

	err := m.db.Collection("reservations").FindOne(ctx, bson.M{"hold_id": holdID}).Decode(&result)
	if err == mongo.ErrNoDocuments {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get reservation: %w", err)
	}

	return &models.Reservation{
		ReservationID: result.ReservationID,
		BookingID:     result.BookingID,
		ShowtimeID:    result.ShowtimeID,
		SeatIDs:       result.SeatIDs,
		SessionID:     result.SessionID,
		ConfirmedAt:   result.ConfirmedAt,
	}, nil
}

// GetReservedSeats returns all reserved seats for a showtime
func (m *MongoClient) GetReservedSeats(ctx context.Context, showtimeID string) (map[string]bool, error) {
	cursor, err := m.db.Collection("reservations").Find(ctx, bson.M{"showtime_id": showtimeID})
	if err != nil {
		return nil, fmt.Errorf("failed to get reservations: %w", err)
	}
	defer cursor.Close(ctx)

	result := make(map[string]bool)
	for cursor.Next(ctx) {
		var res struct {
			SeatIDs []string `bson:"seat_ids"`
		}
		if err := cursor.Decode(&res); err != nil {
			continue
		}
		for _, seatID := range res.SeatIDs {
			result[seatID] = true
		}
	}

	return result, nil
}

// CreateRoomLayout creates a new room layout
func (m *MongoClient) CreateRoomLayout(ctx context.Context, layout *models.RoomLayout) error {
	layout.CreatedAt = time.Now()
	layout.UpdatedAt = time.Now()

	_, err := m.db.Collection("room_layouts").InsertOne(ctx, layout)
	if err != nil {
		if mongo.IsDuplicateKeyError(err) {
			return fmt.Errorf("room already exists: %s", layout.RoomID)
		}
		return fmt.Errorf("failed to create room layout: %w", err)
	}

	return nil
}

// GetRoomLayout retrieves a room layout by ID
func (m *MongoClient) GetRoomLayout(ctx context.Context, roomID string) (*models.RoomLayout, error) {
	var layout models.RoomLayout
	err := m.db.Collection("room_layouts").FindOne(ctx, bson.M{"room_id": roomID}).Decode(&layout)
	if err == mongo.ErrNoDocuments {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get room layout: %w", err)
	}

	return &layout, nil
}

// GetShowtimeRoomID gets the room ID for a showtime (stub - in real app would query showtime service)
func (m *MongoClient) GetShowtimeRoomID(ctx context.Context, showtimeID string) (string, error) {
	// In a real implementation, this would query a showtimes collection or service
	// For now, we'll use a simple mapping or default
	var result struct {
		RoomID string `bson:"room_id"`
	}
	err := m.db.Collection("showtimes").FindOne(ctx, bson.M{"showtime_id": showtimeID}).Decode(&result)
	if err == mongo.ErrNoDocuments {
		// Default room for testing
		return "room_001", nil
	}
	if err != nil {
		return "", fmt.Errorf("failed to get showtime: %w", err)
	}
	return result.RoomID, nil
}
