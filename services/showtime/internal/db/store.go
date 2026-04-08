package db

import (
	"context"
	"time"

	"cinemas/services/showtime/internal/models"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// MongoStore implements ShowtimeStore using MongoDB
type MongoStore struct {
	db         *mongo.Database
	collection *mongo.Collection
}

// NewMongoStore creates a new MongoDB store
func NewMongoStore(db *mongo.Database) *MongoStore {
	return &MongoStore{
		db:         db,
		collection: db.Collection("showtimes"),
	}
}

// List returns a paginated list of showtimes
func (s *MongoStore) List(query models.ListShowtimesQuery) (*models.ShowtimeList, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	filter := bson.M{}
	if query.MovieID != "" {
		filter["movie_id"] = query.MovieID
	}
	if query.CinemaID != "" {
		filter["cinema_id"] = query.CinemaID
	}
	if query.Status != "" {
		filter["status"] = query.Status
	}
	if query.Date != "" {
		// Parse date and filter by that day
		if t, err := time.Parse("2006-01-02", query.Date); err == nil {
			start := t
			end := t.Add(24 * time.Hour)
			filter["start_time"] = bson.M{
				"$gte": start,
				"$lt":  end,
			}
		}
	}

	// Count total
	total, err := s.collection.CountDocuments(ctx, filter)
	if err != nil {
		return nil, err
	}

	// Apply pagination
	skip := int64((query.Page - 1) * query.Limit)
	limit := int64(query.Limit)

	opts := options.Find().
		SetSkip(skip).
		SetLimit(limit).
		SetSort(bson.D{{Key: "start_time", Value: 1}})

	cursor, err := s.collection.Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var showtimes []models.Showtime
	if err := cursor.All(ctx, &showtimes); err != nil {
		return nil, err
	}

	// If no results, return empty array instead of nil
	if showtimes == nil {
		showtimes = []models.Showtime{}
	}

	totalPages := int(total) / query.Limit
	if int(total)%query.Limit > 0 {
		totalPages++
	}

	return &models.ShowtimeList{
		Data: showtimes,
		Pagination: models.Pagination{
			Page:       query.Page,
			Limit:      query.Limit,
			Total:      int(total),
			TotalPages: totalPages,
		},
	}, nil
}

// Get returns a showtime by ID
func (s *MongoStore) Get(id string) (*models.Showtime, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var showtime models.Showtime
	err := s.collection.FindOne(ctx, bson.M{"_id": id}).Decode(&showtime)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return nil, models.ErrShowtimeNotFound
		}
		return nil, err
	}

	return &showtime, nil
}

// Create inserts a new showtime
func (s *MongoStore) Create(showtime *models.Showtime) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := s.collection.InsertOne(ctx, showtime)
	return err
}

// Update modifies an existing showtime
func (s *MongoStore) Update(id string, showtime *models.Showtime) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := s.collection.ReplaceOne(ctx, bson.M{"_id": id}, showtime)
	return err
}

// CheckRoomConflict checks if a room is already booked at the specified time
func (s *MongoStore) CheckRoomConflict(cinemaID string, roomNumber int, startTime, endTime time.Time, excludeID string) (bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	filter := bson.M{
		"cinema_id":   cinemaID,
		"room_number": roomNumber,
		"status":      bson.M{"$ne": models.StatusCancelled},
		"$or": []bson.M{
			{
				"start_time": bson.M{"$lt": endTime},
				"end_time":   bson.M{"$gt": startTime},
			},
		},
	}

	if excludeID != "" {
		filter["_id"] = bson.M{"$ne": excludeID}
	}

	count, err := s.collection.CountDocuments(ctx, filter)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}
