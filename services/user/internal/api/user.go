package api

import (
	"context"
	"net/http"
	"regexp"
	"time"

	errs "cinemas/services/user/internal/errors"
	"cinemas/services/user/internal/middleware"
	"cinemas/services/user/internal/models"

	"github.com/labstack/echo"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

// API holds the database connection
type API struct {
	db        *mongo.Database
	jwtConfig *middleware.JWTConfig
}

// Repository defines the user repository interface
type Repository interface {
	Register(c echo.Context) error
	Login(c echo.Context) error
	Refresh(c echo.Context) error
	Logout(c echo.Context) error
	GetProfile(c echo.Context) error
	UpdateProfile(c echo.Context) error
	GetBookings(c echo.Context) error
}

// Connect initializes the API with a database connection
func Connect(db *mongo.Database) (Repository, error) {
	if db == nil {
		return nil, errs.Send("internal", "Failed to initialize repository", nil)
	}

	api := &API{
		db:        db,
		jwtConfig: middleware.DefaultConfig(),
	}

	return api, nil
}

// GetJWTConfig returns the JWT configuration
func (a *API) GetJWTConfig() *middleware.JWTConfig {
	return a.jwtConfig
}

// Register creates a new user account
func (a *API) Register(c echo.Context) error {
	var req models.UserRegistration
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Invalid request body",
			"type":  "user",
		})
	}

	// Validate email format
	if !isValidEmail(req.Email) {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Invalid email format",
			"type":  "user",
		})
	}

	// Validate password length
	if len(req.Password) < 8 {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Password must be at least 8 characters",
			"type":  "user",
		})
	}

	// Validate name
	if len(req.Name) < 2 {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Name must be at least 2 characters",
			"type":  "user",
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check if email already exists
	var existingUser models.User
	err := a.db.Collection("users").FindOne(ctx, bson.M{"email": req.Email}).Decode(&existingUser)
	if err == nil {
		return c.JSON(http.StatusConflict, map[string]interface{}{
			"error": "Email already registered",
			"type":  "user",
		})
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": "Failed to process password",
			"type":  "internal",
		})
	}

	// Create user
	now := time.Now()
	user := models.User{
		ID:             generateUserID(),
		Name:           req.Name,
		Email:          req.Email,
		Phone:          req.Phone,
		PasswordHash:   string(hashedPassword),
		MembershipType: "normal",
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	_, err = a.db.Collection("users").InsertOne(ctx, user)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": "Failed to create user",
			"type":  "internal",
		})
	}

	return c.JSON(http.StatusCreated, models.UserResponse{
		User: user.ToProfile(),
		Msg:  "User registered successfully",
	})
}

// Login authenticates a user and returns JWT tokens
func (a *API) Login(c echo.Context) error {
	var req models.UserLogin
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Invalid request body",
			"type":  "user",
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Find user by email
	var user models.User
	err := a.db.Collection("users").FindOne(ctx, bson.M{"email": req.Email}).Decode(&user)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"error": "Invalid email or password",
			"type":  "user",
		})
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"error": "Invalid email or password",
			"type":  "user",
		})
	}

	// Generate tokens
	accessToken, refreshToken, err := a.jwtConfig.GenerateTokenPair(user.ID, user.Email)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": "Failed to generate tokens",
			"type":  "internal",
		})
	}

	return c.JSON(http.StatusOK, models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    900, // 15 minutes
		User:         user.ToProfile(),
	})
}

// Refresh generates a new access token using refresh token
func (a *API) Refresh(c echo.Context) error {
	var req models.RefreshRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Invalid request body",
			"type":  "user",
		})
	}

	// Validate refresh token
	claims, err := a.jwtConfig.ValidateToken(req.RefreshToken)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"error": "Invalid or expired refresh token",
			"type":  "user",
		})
	}

	// Verify it's a refresh token
	if claims.Type != "refresh" {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"error": "Invalid token type",
			"type":  "user",
		})
	}

	// Generate new access token only
	accessToken, _, err := a.jwtConfig.GenerateTokenPair(claims.UserID, claims.Email)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": "Failed to generate token",
			"type":  "internal",
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"access_token": accessToken,
		"token_type":   "Bearer",
		"expires_in":   900,
	})
}

// Logout invalidates the current tokens
func (a *API) Logout(c echo.Context) error {
	// In a production system, you would add the token to a blacklist in Redis
	// For now, we just return success (client should discard tokens)
	return c.JSON(http.StatusOK, map[string]interface{}{
		"msg": "Logged out successfully",
	})
}

// GetProfile returns the current user's profile
func (a *API) GetProfile(c echo.Context) error {
	userID := c.Get("user_id").(string)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var user models.User
	err := a.db.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"error": "User not found",
			"type":  "user",
		})
	}

	return c.JSON(http.StatusOK, models.UserResponse{
		User: user.ToProfile(),
		Msg:  "User profile",
	})
}

// UpdateProfile updates the current user's profile
func (a *API) UpdateProfile(c echo.Context) error {
	userID := c.Get("user_id").(string)

	var req models.UserUpdate
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error": "Invalid request body",
			"type":  "user",
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Build update document
	update := bson.M{"updated_at": time.Now()}
	if req.Name != "" {
		if len(req.Name) < 2 {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"error": "Name must be at least 2 characters",
				"type":  "user",
			})
		}
		update["name"] = req.Name
	}
	if req.Phone != "" {
		update["phone"] = req.Phone
	}
	if req.Password != "" {
		if len(req.Password) < 8 {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"error": "Password must be at least 8 characters",
				"type":  "user",
			})
		}
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]interface{}{
				"error": "Failed to process password",
				"type":  "internal",
			})
		}
		update["password_hash"] = string(hashedPassword)
	}

	// Update user
	_, err := a.db.Collection("users").UpdateOne(
		ctx,
		bson.M{"_id": userID},
		bson.M{"$set": update},
	)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": "Failed to update profile",
			"type":  "internal",
		})
	}

	// Fetch updated user
	var user models.User
	err = a.db.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": "Failed to fetch updated profile",
			"type":  "internal",
		})
	}

	return c.JSON(http.StatusOK, models.UserResponse{
		User: user.ToProfile(),
		Msg:  "Profile updated successfully",
	})
}

// GetBookings returns the user's booking history
func (a *API) GetBookings(c echo.Context) error {
	// This would normally query the booking service or a denormalized collection
	// For now, return an empty list as bookings are stored in booking-service
	return c.JSON(http.StatusOK, models.BookingHistoryResponse{
		Bookings: []models.BookingSummary{},
		Total:    0,
		Limit:    10,
		Offset:   0,
	})
}

// Helper functions

func isValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}

func generateUserID() string {
	return "usr_" + randomString(12)
}

func randomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[time.Now().UnixNano()%int64(len(letters))]
		time.Sleep(time.Nanosecond)
	}
	return string(b)
}
