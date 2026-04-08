# Services Documentation - Cinema Ticketing System

> **AI Agent Context**: This document provides specifications for all microservices. Each service has an OpenAPI specification in `/services/{name}/api/openapi.yaml`. Use this document to understand service responsibilities, data models, and integration points.

**Last Updated**: 2026-04-08  
**Total Services**: 8 (4 production, 4 planned)

---

## Table of Contents

1. [Service Overview](#service-overview)
2. [Core Services](#production-services)
   - [movie-service](#movie-service)
   - [booking-service](#booking-service)
   - [payment-service](#payment-service)
   - [notification-service](#notification-service)
3. [Additional Services](#additional-services)
   - [user-service](#user-service)
   - [cinema-service](#cinema-service)
   - [showtime-service](#showtime-service)
   - [seat-service](#seat-service)
4. [Service Contracts](#service-contracts)
5. [Common Patterns](#common-patterns)

---

## Service Overview

### Service Matrix

| Service | Port | Status | OpenAPI Spec | Database | Dependencies |
|---------|------|--------|--------------|----------|--------------|
| movie | 8000 | Production | [openapi.yaml](../../services/movie/api/openapi.yaml) | MongoDB | None |
| booking | 8082 | Production | [openapi.yaml](../../services/booking/api/openapi.yaml) | MongoDB | payment, notification, seat, showtime |
| payment | 8001 | Production | [openapi.yaml](../../services/payment/api/openapi.yaml) | MongoDB | Stripe API (mock mode supported) |
| notification | 8002 | Production | [openapi.yaml](../../services/notification/api/openapi.yaml) | None | Gmail SMTP |
| user | 8004 | Production | [openapi.yaml](../../services/user/api/openapi.yaml) | MongoDB | Redis (sessions) |
| cinema | 8085 | Production | [openapi.yaml](../../services/cinema/api/openapi.yaml) | MongoDB | None |
| showtime | 3003 | Production | [openapi.yaml](../../services/showtime/api/openapi.yaml) | MongoDB | movie |
| seat | 3004 | Production | [openapi.yaml](../../services/seat/api/openapi.yaml) | MongoDB + Redis | showtime |

All 8 services pass E2E integration tests as of 2026-04-08.

### Service Directory Structure

Each service follows the standard Go layout:

```
services/{service-name}/
├── cmd/{service-name}/
│   └── main.go              # Entry point
├── internal/
│   ├── api/                 # HTTP handlers
│   │   └── {handler}_test.go
│   ├── models/              # Data structures
│   │   └── {model}_test.go
│   ├── db/                  # Database operations
│   ├── routes/              # Route definitions
│   ├── server/              # Server setup
│   └── service/             # Business logic
│       └── {service}_test.go
├── contracts/
│   ├── consumer/            # Pact consumer tests
│   └── provider/            # Pact provider tests
├── api/
│   └── openapi.yaml         # OpenAPI specification
├── go.mod
├── go.sum
└── README.md
```

---

## Production Services

### movie-service

**Purpose**: Movie catalog management (read-only operations).

**Port**: 8001  
**Status**: Production  
**OpenAPI**: [/services/movie/api/openapi.yaml](../../services/movie/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/movies/all` | List all movies |
| GET | `/movies/premieres` | Get recent releases (last 2 weeks) |
| GET | `/movies/:id` | Get movie by ID |

#### Data Model

```go
type Movie struct {
    ID          string `json:"id" bson:"_id"`
    Title       string `json:"title"`
    Description string `json:"description"`
    Image       string `json:"image"`
    Genre       string `json:"genre"`
    Director    string `json:"director"`
    ReleaseDate string `json:"releaseDate"`
    Duration    int    `json:"duration"`  // minutes
    Rating      string `json:"rating"`    // G, PG, PG-13, R
}
```

#### Configuration

```env
DB_USER=cristian
DB_PASS=cristianPassword2017
DB_SERVERS=mongo1:27017,mongo2:27017,mongo3:27017
DB_NAME=movies
DB_REPLICA=rs1
SERVICE_PORT=8000
```

---

### booking-service

**Purpose**: Orchestrates the ticket purchase flow (SAGA coordinator).

**Port**: 8000  
**Status**: Production  
**OpenAPI**: [/services/booking/api/openapi.yaml](../../services/booking/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/booking/` | Create new booking |
| GET | `/booking/:orderId` | Get booking by order ID |

#### Data Model

```go
type BookingRequest struct {
    UserMember CreditCard `json:"creditCard"`
    Movie      string     `json:"movie"`
    Schedule   string     `json:"schedule"`    // Showtime ID
    Seats      []string   `json:"seats"`       // e.g., ["A1", "A2"]
    Cinema     string     `json:"cinema"`
    Payment    float64    `json:"payment"`
    HoldID     string     `json:"hold_id"`     // From seat-service
}

type Ticket struct {
    OrderID       string     `json:"orderId"`
    UserMember    CreditCard `json:"creditCard"`
    Movie         string     `json:"movie"`
    Schedule      string     `json:"schedule"`
    Seats         []string   `json:"seats"`
    Cinema        string     `json:"cinema"`
    TotalPayment  float64    `json:"totalPayment"`
    PaymentStatus string     `json:"paymentStatus"`
    OrderDate     string     `json:"orderDate"`
}
```

#### SAGA Orchestration Flow

The booking service implements the SAGA pattern for distributed transaction coordination:

```
SAGA Steps:
1. Validate showtime (showtime-service)
2. Verify seat hold (seat-service) - validates hold exists and matches session
3. Process payment (payment-service)
4. Confirm reservation (seat-service) - converts hold to permanent reservation
5. Create ticket (MongoDB)
6. Send notification (notification-service) - non-critical, no compensation

Compensation Flow:
- If payment fails → Release hold
- If seat confirmation fails → Refund payment + Release hold
- If ticket creation fails → Manual reconciliation needed
```

#### Dependencies

- **payment-service**: Process credit card payments via Stripe (mock mode available)
- **notification-service**: Send confirmation emails
- **seat-service**: Verify holds and confirm reservations
- **showtime-service**: Validate showtime exists and is scheduled

---

### payment-service

**Purpose**: Process payments and refunds via Stripe.

**Port**: 8002  
**Status**: Production  
**OpenAPI**: [/services/payment/api/openapi.yaml](../../services/payment/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/payment/makePurchase` | Process payment |
| GET | `/payment/:id` | Get payment by ID |
| POST | `/payment/:id/refund` | Process refund |

#### Data Model

```go
type PaymentRequest struct {
    UserName    string  `json:"userName"`
    Currency    string  `json:"currency"`    // mxn, usd
    Number      string  `json:"number"`      // Card number
    CVC         string  `json:"cvc"`
    ExpMonth    string  `json:"exp_month"`
    ExpYear     string  `json:"exp_year"`
    Amount      int     `json:"amount"`      // In cents
    Description string  `json:"description"`
}

type PaymentResponse struct {
    User    string       `json:"user"`
    Amount  int          `json:"amount"`
    Charge  StripeCharge `json:"charge"`
    Version string       `json:"version"`
}

type StripeCharge struct {
    ID          string `json:"id"`           // ch_xxx
    Amount      int    `json:"amount"`
    Currency    string `json:"currency"`
    Status      string `json:"status"`       // succeeded, failed
    Description string `json:"description"`
    ReceiptURL  string `json:"receipt_url"`
}
```

#### Configuration

```env
STRIPE_KEY=sk_test_xxx
SERVICE_PORT=8000
```

---

### notification-service

**Purpose**: Send email and SMS notifications.

**Port**: 8003  
**Status**: Production  
**OpenAPI**: [/services/notification/api/openapi.yaml](../../services/notification/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/notification/sendEmail` | Send email notification |
| POST | `/notification/sendSMS` | Send SMS (stub) |

#### Data Model

```go
type EmailRequest struct {
    BookingID     string   `json:"booking_id"`
    ShowtimeID    string   `json:"showtime_id"`
    ReservationID string   `json:"reservation_id,omitempty"`
    MovieTitle    string   `json:"movie_title"`
    CinemaName    string   `json:"cinema_name"`
    RoomNumber    int      `json:"room_number"`
    StartTime     string   `json:"start_time"`
    Seats         []string `json:"seats"`
    TotalAmount   int      `json:"total_amount"`
    OrderID       string   `json:"order_id"`
    ReceiptURL    string   `json:"receipt_url,omitempty"`
    UserName      string   `json:"user_name"`
    Email         string   `json:"email"`
}

type EmailResponse struct {
    Msg       string `json:"msg"`
    MessageID string `json:"message_id,omitempty"`
}
```

#### Configuration

```env
EMAIL=your-email@gmail.com
EMAIL_PASS=your-app-password
SERVICE_PORT=8000
```

---

## Additional Services

### user-service

**Purpose**: User authentication and profile management.

**Port**: 8004  
**Status**: Production  
**OpenAPI**: [/services/user/api/openapi.yaml](../../services/user/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users/register` | Register new user |
| POST | `/users/login` | Authenticate user |
| POST | `/users/refresh` | Refresh JWT token |
| POST | `/users/logout` | Invalidate token |
| GET | `/users/me` | Get current user profile |
| PUT | `/users/me` | Update profile |
| GET | `/users/me/bookings` | Get user's booking history |
| DELETE | `/users/me` | Delete account |

#### Data Model

```go
type User struct {
    ID             string    `json:"id"`
    Email          string    `json:"email"`
    Name           string    `json:"name"`
    Phone          string    `json:"phone,omitempty"`
    PasswordHash   string    `json:"-"`
    MembershipType string    `json:"membership_type"` // regular, vip, loyal
    CreatedAt      time.Time `json:"created_at"`
    UpdatedAt      time.Time `json:"updated_at"`
}

type AuthToken struct {
    AccessToken  string `json:"access_token"`
    RefreshToken string `json:"refresh_token"`
    ExpiresIn    int    `json:"expires_in"`
    TokenType    string `json:"token_type"` // Bearer
}
```

---

### cinema-service

**Purpose**: Cinema and room catalog management.

**Port**: 8085  
**Status**: Production  
**OpenAPI**: [/services/cinema/api/openapi.yaml](../../services/cinema/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/cinemas` | List cinemas (filter by city) |
| GET | `/cinemas/:id` | Get cinema details |
| GET | `/cinemas/:id/rooms` | Get cinema rooms |
| POST | `/cinemas` | Create cinema (admin) |
| POST | `/cinemas/:id/rooms` | Create room (admin) |
| PUT | `/cinemas/:id` | Update cinema (admin) |

#### Data Model

```go
type Cinema struct {
    ID        string     `json:"id"`
    Name      string     `json:"name"`
    Address   string     `json:"address"`
    City      string     `json:"city"`
    Country   string     `json:"country"`
    Location  GeoPoint   `json:"location"`
    Amenities []string   `json:"amenities"` // parking, food_court, 3d, imax
    Rooms     []Room     `json:"rooms,omitempty"`
}

type Room struct {
    ID         string `json:"id"`
    CinemaID   string `json:"cinema_id"`
    Name       string `json:"name"`
    RoomNumber int    `json:"room_number"`
    Capacity   int    `json:"capacity"`
    Type       string `json:"type"` // standard, vip, imax, 4dx
}
```

---

### showtime-service

**Purpose**: Movie schedule and pricing management.

**Port**: 3003  
**Status**: Production  
**OpenAPI**: [/services/showtime/api/openapi.yaml](../../services/showtime/api/openapi.yaml)

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/showtimes` | List showtimes (filter by movie, cinema, date) |
| GET | `/showtimes/:id` | Get showtime details |
| POST | `/showtimes` | Create showtime (admin) |
| PUT | `/showtimes/:id` | Update showtime (admin) |
| DELETE | `/showtimes/:id` | Cancel showtime (admin) |

#### Data Model

```go
type Showtime struct {
    ID             string         `json:"id"`
    MovieID        string         `json:"movie_id"`
    CinemaID       string         `json:"cinema_id"`
    RoomNumber     int            `json:"room_number"`
    StartTime      time.Time      `json:"start_time"`
    EndTime        time.Time      `json:"end_time"`
    AvailableSeats int            `json:"available_seats"`
    Status         ShowtimeStatus `json:"status"` // scheduled, cancelled, completed
    Prices         PriceMap       `json:"prices"`
}

type PriceMap struct {
    Regular int `json:"regular"` // cents
    VIP     int `json:"vip"`
    Child   int `json:"child"`
}
```

---

### seat-service

**Purpose**: Seat availability, holds, and reservations.

**Port**: 3004  
**Status**: Production  
**OpenAPI**: [/services/seat/api/openapi.yaml](../../services/seat/api/openapi.yaml)

> **Critical**: This service prevents double-booking of seats through atomic Redis operations and temporary holds with TTL.

#### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/seats/availability` | Get seat map for showtime |
| POST | `/seats/hold` | Create temporary hold (5 min) |
| DELETE | `/seats/hold/:holdId` | Release hold |
| POST | `/seats/reserve` | Confirm reservation |
| GET | `/seats/layout/:roomId` | Get room layout (admin) |
| POST | `/seats/layout` | Create room layout (admin) |

#### Data Model

```go
type SeatMap struct {
    ShowtimeID string `json:"showtime_id"`
    RoomLayout Layout `json:"room_layout"`
    Seats      []Seat `json:"seats"`
}

type Seat struct {
    ID        string     `json:"id"`        // e.g., "A1"
    Row       string     `json:"row"`
    Number    int        `json:"number"`
    Type      SeatType   `json:"type"`      // regular, vip, wheelchair
    Status    SeatStatus `json:"status"`    // available, held, reserved
    HeldUntil *time.Time `json:"held_until,omitempty"`
    HeldBy    string     `json:"held_by,omitempty"` // session_id
}

type HoldRequest struct {
    ShowtimeID string   `json:"showtime_id"`
    SeatIDs    []string `json:"seat_ids"`
    SessionID  string   `json:"session_id"`
}

type HoldResponse struct {
    HoldID    string    `json:"hold_id"`
    Seats     []string  `json:"seats"`
    ExpiresAt time.Time `json:"expires_at"`
    TTL       int       `json:"ttl_seconds"`
}

type ReserveRequest struct {
    HoldID    string `json:"hold_id"`
    BookingID string `json:"booking_id"`
}
```

#### Concurrency Handling

```
Redis Keys:
  seat:hold:{showtime_id}:{seat_id} = {session_id, hold_id}
  TTL: 300 seconds (5 minutes)

Operations:
  - Hold: SETNX + TTL (atomic)
  - Release: DEL
  - Reserve: DEL hold + INSERT MongoDB reservation
```

---

## Service Contracts

### Consumer-Provider Relationships

| Consumer | Provider | Contract |
|----------|----------|----------|
| booking | payment | [booking-service-payment-service.json](../../contracts/) |
| booking | seat | [booking-service-seat-service.json](../../contracts/) |
| booking | showtime | [booking-service-showtime-service.json](../../contracts/) |
| booking | notification | [booking-service-notification-service.json](../../contracts/) |

### Contract Testing

See [API Documentation](../api/README.md) for:
- Pact consumer/provider tests
- Contract verification
- CI/CD integration

---

## Common Patterns

### Error Response Format

All services return errors in consistent format:

```json
{
  "type": "validation_error",
  "message": "Invalid seat ID format",
  "code": "INVALID_SEAT_ID",
  "details": {
    "field": "seat_ids[0]",
    "value": "invalid"
  }
}
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (validation) |
| 401 | Unauthorized |
| 404 | Not Found |
| 409 | Conflict (e.g., seat already held) |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

### Health Check

All services expose:

```
GET /health
Response: {"status": "ok", "service": "{name}", "version": "{version}"}
```

### Logging Format

Structured JSON logging (Logrus):

```json
{
  "level": "info",
  "msg": "Request processed",
  "service": "booking",
  "trace_id": "abc123",
  "request_id": "req_xyz",
  "duration_ms": 45,
  "status": 200
}
```

---

## Related Documentation

- [Architecture Overview](../architecture/README.md)
- [API Documentation](../api/README.md)
- [Development Guide](../development/README.md)
- [Contract Testing](../api/contracts.md)
