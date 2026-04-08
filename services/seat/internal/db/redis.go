package db

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"cinemas/services/seat/internal/models"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	// HoldTTL is the default TTL for seat holds (5 minutes)
	HoldTTL = 5 * time.Minute
	// HoldKeyPrefix is the prefix for hold keys
	HoldKeyPrefix = "hold:"
	// SeatHoldKeyPrefix is the prefix for seat hold status keys
	SeatHoldKeyPrefix = "seat_hold:"
)

// RedisClient wraps the Redis client with seat-specific operations
type RedisClient struct {
	client *redis.Client
}

// NewRedisClient creates a new Redis client
func NewRedisClient(addr, password string, db int) (*RedisClient, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return &RedisClient{client: client}, nil
}

// Close closes the Redis connection
func (r *RedisClient) Close() error {
	return r.client.Close()
}

// seatHoldKey generates the key for a seat's hold status
func seatHoldKey(showtimeID, seatID string) string {
	return fmt.Sprintf("%s%s:%s", SeatHoldKeyPrefix, showtimeID, seatID)
}

// holdKey generates the key for a hold
func holdKey(holdID string) string {
	return HoldKeyPrefix + holdID
}

// HoldSeats atomically holds multiple seats for a session
// Returns error if any seat is already held
func (r *RedisClient) HoldSeats(ctx context.Context, showtimeID string, seatIDs []string, sessionID string) (*models.Hold, []models.UnavailableSeat, error) {
	holdID := uuid.New().String()
	expiresAt := time.Now().Add(HoldTTL)

	// Use a transaction with WATCH to prevent race conditions
	txf := func(tx *redis.Tx) error {
		// Check if any seats are already held
		unavailable := make([]models.UnavailableSeat, 0)
		for _, seatID := range seatIDs {
			key := seatHoldKey(showtimeID, seatID)
			val, err := tx.Get(ctx, key).Result()
			if err != nil && err != redis.Nil {
				return fmt.Errorf("failed to check seat %s: %w", seatID, err)
			}
			if err != redis.Nil {
				// Seat is already held
				var existingHold struct {
					SessionID string    `json:"session_id"`
					ExpiresAt time.Time `json:"expires_at"`
				}
				if err := json.Unmarshal([]byte(val), &existingHold); err == nil {
					unavailable = append(unavailable, models.UnavailableSeat{
						SeatID:    seatID,
						Status:    models.SeatStatusHeld,
						HeldBy:    existingHold.SessionID,
						HeldUntil: &existingHold.ExpiresAt,
					})
				}
			}
		}

		if len(unavailable) > 0 {
			return fmt.Errorf("seats unavailable: %v", unavailable)
		}

		// All seats are available, create the hold
		_, err := tx.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
			// Set hold for each seat
			for _, seatID := range seatIDs {
				key := seatHoldKey(showtimeID, seatID)
				holdData, _ := json.Marshal(map[string]interface{}{
					"hold_id":    holdID,
					"session_id": sessionID,
					"expires_at": expiresAt,
				})
				pipe.Set(ctx, key, holdData, HoldTTL)
			}

			// Store the hold metadata
			hold := models.Hold{
				HoldID:     holdID,
				ShowtimeID: showtimeID,
				SeatIDs:    seatIDs,
				SessionID:  sessionID,
				ExpiresAt:  expiresAt,
				CreatedAt:  time.Now(),
			}
			holdData, _ := json.Marshal(hold)
			pipe.Set(ctx, holdKey(holdID), holdData, HoldTTL)

			return nil
		})
		return err
	}

	// Build the list of keys to watch
	watchKeys := make([]string, len(seatIDs))
	for i, seatID := range seatIDs {
		watchKeys[i] = seatHoldKey(showtimeID, seatID)
	}

	// Execute the transaction with optimistic locking
	err := r.client.Watch(ctx, txf, watchKeys...)
	if err != nil {
		// Check if it's a conflict error
		if err.Error()[:17] == "seats unavailable" {
			// Re-check to get the unavailable seats
			unavailable := make([]models.UnavailableSeat, 0)
			for _, seatID := range seatIDs {
				key := seatHoldKey(showtimeID, seatID)
				val, checkErr := r.client.Get(ctx, key).Result()
				if checkErr == nil {
					var existingHold struct {
						SessionID string    `json:"session_id"`
						ExpiresAt time.Time `json:"expires_at"`
					}
					if json.Unmarshal([]byte(val), &existingHold) == nil {
						unavailable = append(unavailable, models.UnavailableSeat{
							SeatID:    seatID,
							Status:    models.SeatStatusHeld,
							HeldBy:    existingHold.SessionID,
							HeldUntil: &existingHold.ExpiresAt,
						})
					}
				}
			}
			return nil, unavailable, nil
		}
		return nil, nil, err
	}

	return &models.Hold{
		HoldID:     holdID,
		ShowtimeID: showtimeID,
		SeatIDs:    seatIDs,
		SessionID:  sessionID,
		ExpiresAt:  expiresAt,
		CreatedAt:  time.Now(),
	}, nil, nil
}

// GetHold retrieves a hold by ID
func (r *RedisClient) GetHold(ctx context.Context, holdID string) (*models.Hold, error) {
	val, err := r.client.Get(ctx, holdKey(holdID)).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get hold: %w", err)
	}

	var hold models.Hold
	if err := json.Unmarshal([]byte(val), &hold); err != nil {
		return nil, fmt.Errorf("failed to unmarshal hold: %w", err)
	}

	return &hold, nil
}

// ReleaseHold releases a hold and frees the seats
func (r *RedisClient) ReleaseHold(ctx context.Context, holdID string) (*models.Hold, error) {
	hold, err := r.GetHold(ctx, holdID)
	if err != nil {
		return nil, err
	}
	if hold == nil {
		return nil, nil
	}

	// Delete all seat holds and the hold metadata
	pipe := r.client.Pipeline()
	for _, seatID := range hold.SeatIDs {
		pipe.Del(ctx, seatHoldKey(hold.ShowtimeID, seatID))
	}
	pipe.Del(ctx, holdKey(holdID))

	if _, err := pipe.Exec(ctx); err != nil {
		return nil, fmt.Errorf("failed to release hold: %w", err)
	}

	return hold, nil
}

// GetSeatHoldStatus checks if a seat is currently held
func (r *RedisClient) GetSeatHoldStatus(ctx context.Context, showtimeID, seatID string) (*models.UnavailableSeat, error) {
	key := seatHoldKey(showtimeID, seatID)
	val, err := r.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get seat hold status: %w", err)
	}

	var holdData struct {
		SessionID string    `json:"session_id"`
		ExpiresAt time.Time `json:"expires_at"`
	}
	if err := json.Unmarshal([]byte(val), &holdData); err != nil {
		return nil, fmt.Errorf("failed to unmarshal seat hold: %w", err)
	}

	return &models.UnavailableSeat{
		SeatID:    seatID,
		Status:    models.SeatStatusHeld,
		HeldBy:    holdData.SessionID,
		HeldUntil: &holdData.ExpiresAt,
	}, nil
}

// GetHeldSeats returns all held seats for a showtime
func (r *RedisClient) GetHeldSeats(ctx context.Context, showtimeID string) (map[string]*models.UnavailableSeat, error) {
	pattern := fmt.Sprintf("%s%s:*", SeatHoldKeyPrefix, showtimeID)
	keys, err := r.client.Keys(ctx, pattern).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to get held seats: %w", err)
	}

	result := make(map[string]*models.UnavailableSeat)
	for _, key := range keys {
		val, err := r.client.Get(ctx, key).Result()
		if err != nil {
			continue
		}

		var holdData struct {
			SessionID string    `json:"session_id"`
			ExpiresAt time.Time `json:"expires_at"`
		}
		if err := json.Unmarshal([]byte(val), &holdData); err != nil {
			continue
		}

		// Extract seatID from key (format: seat_hold:showtimeID:seatID)
		seatID := key[len(SeatHoldKeyPrefix)+len(showtimeID)+1:]
		result[seatID] = &models.UnavailableSeat{
			SeatID:    seatID,
			Status:    models.SeatStatusHeld,
			HeldBy:    holdData.SessionID,
			HeldUntil: &holdData.ExpiresAt,
		}
	}

	return result, nil
}
