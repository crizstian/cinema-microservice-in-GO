package models

import "time"

// UserRegistration represents the registration request
type UserRegistration struct {
	Name     string `json:"name" bson:"name"`
	Email    string `json:"email" bson:"email"`
	Password string `json:"password" bson:"-"` // Never store plain password
	Phone    string `json:"phone,omitempty" bson:"phone,omitempty"`
}

// UserLogin represents the login request
type UserLogin struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// UserProfile represents the user profile (response)
type UserProfile struct {
	ID             string    `json:"id" bson:"_id"`
	Name           string    `json:"name" bson:"name"`
	Email          string    `json:"email" bson:"email"`
	Phone          string    `json:"phone,omitempty" bson:"phone,omitempty"`
	MembershipType string    `json:"membership_type" bson:"membership_type"`
	CreatedAt      time.Time `json:"created_at" bson:"created_at"`
}

// User represents the full user document in MongoDB
type User struct {
	ID             string    `json:"id" bson:"_id"`
	Name           string    `json:"name" bson:"name"`
	Email          string    `json:"email" bson:"email"`
	Phone          string    `json:"phone,omitempty" bson:"phone,omitempty"`
	PasswordHash   string    `json:"-" bson:"password_hash"`
	MembershipType string    `json:"membership_type" bson:"membership_type"`
	CreatedAt      time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" bson:"updated_at"`
}

// UserUpdate represents the profile update request
type UserUpdate struct {
	Name     string `json:"name,omitempty"`
	Phone    string `json:"phone,omitempty"`
	Password string `json:"password,omitempty"`
}

// AuthToken represents JWT tokens response
type AuthToken struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
}

// RefreshRequest represents token refresh request
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

// AuthResponse represents login response with tokens and user
type AuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	TokenType    string       `json:"token_type"`
	ExpiresIn    int          `json:"expires_in"`
	User         *UserProfile `json:"user"`
}

// UserResponse represents user profile response
type UserResponse struct {
	User *UserProfile `json:"user"`
	Msg  string       `json:"msg"`
}

// BookingSummary represents a booking in history
type BookingSummary struct {
	OrderID     string    `json:"order_id" bson:"orderId"`
	MovieTitle  string    `json:"movie_title" bson:"movie_title"`
	Cinema      string    `json:"cinema" bson:"cinema"`
	Schedule    string    `json:"schedule" bson:"schedule"`
	Seats       []string  `json:"seats" bson:"seats"`
	TotalAmount int       `json:"total_amount" bson:"totalAmount"`
	CreatedAt   time.Time `json:"created_at" bson:"created_at"`
}

// BookingHistoryResponse represents paginated booking history
type BookingHistoryResponse struct {
	Bookings []BookingSummary `json:"bookings"`
	Total    int              `json:"total"`
	Limit    int              `json:"limit"`
	Offset   int              `json:"offset"`
}

// ToProfile converts User to UserProfile (excludes sensitive data)
func (u *User) ToProfile() *UserProfile {
	return &UserProfile{
		ID:             u.ID,
		Name:           u.Name,
		Email:          u.Email,
		Phone:          u.Phone,
		MembershipType: u.MembershipType,
		CreatedAt:      u.CreatedAt,
	}
}
