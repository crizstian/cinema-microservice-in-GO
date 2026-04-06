package integration_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type CreditCard struct {
	Number   string `json:"number"`
	CVC      string `json:"cvc"`
	ExpMonth string `json:"exp_month"`
	ExpYear  string `json:"exp_year"`
}

type User struct {
	Name       string     `json:"name"`
	LastName   string     `json:"lastName"`
	Email      string     `json:"email"`
	CreditCard CreditCard `json:"creditCard"`
	Membership string     `json:"membership"`
}

type MovieInfo struct {
	Title  string `json:"title"`
	Format string `json:"format"`
}

type Booking struct {
	City        string    `json:"city"`
	Cinema      string    `json:"cinema"`
	Movie       MovieInfo `json:"movie"`
	Schedule    string    `json:"schedule"`
	CinemaRoom  int       `json:"cinemaRoom"`
	Seats       []string  `json:"seats"`
	TotalAmount int       `json:"totalAmount"`
}

type BookingRequest struct {
	User    User    `json:"user"`
	Booking Booking `json:"booking"`
}

// opcional: shape esperado de respuesta
type BookingResponse struct {
	Msg     string                 `json:"msg"`
	OrderID string                 `json:"orderId"`
	Data    map[string]interface{} `json:"data"`
}

func TestBookingEndpoint(t *testing.T) {
	// Permite configurar la URL vía env, con default
	baseURL := os.Getenv("BOOKING_ENDPOINT_URL")
	if baseURL == "" {
		baseURL = "http://192.168.21.145:8300"
	}
	url := baseURL + "/booking/"

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	reqBody := BookingRequest{
		User: User{
			Name:     "Cristian",
			LastName: "Ramirez",
			Email:    "cristiano.rosetti@gmail.com",
			CreditCard: CreditCard{
				Number:   "4242424242424242",
				CVC:      "123",
				ExpMonth: "12",
				ExpYear:  "2030",
			},
			Membership: "7777888899990000",
		},
		Booking: Booking{
			City:   "Morelia",
			Cinema: "Plaza Morelia",
			Movie: MovieInfo{
				Title:  "Assasins Creed",
				Format: "IMAX",
			},
			Schedule:    "2026-01-25T19:00:00Z",
			CinemaRoom:  7,
			Seats:       []string{"45"},
			TotalAmount: 71,
		},
	}

	bodyBytes, err := json.Marshal(reqBody)
	require.NoError(t, err, "failed to marshal booking request")

	req, err := http.NewRequest(http.MethodPost, url, bytes.NewBuffer(bodyBytes))
	require.NoError(t, err, "failed to create request")
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	require.NoError(t, err, "request to booking endpoint failed")
	defer resp.Body.Close()

	// Validar status code
	assert.InDelta(t, 200, resp.StatusCode, 1, "expected 2xx status code")

	var respBody BookingResponse
	dec := json.NewDecoder(resp.Body)
	err = dec.Decode(&respBody)
	require.NoError(t, err, "failed to decode response JSON")

	// Asserts semánticos
	assert.NotEmpty(t, respBody.Msg, "response msg should not be empty")
	assert.NotContains(t, respBody.Msg, "error", "response msg should not contain error")

	// Si el servicio devuelve orderId, lo validamos
	if respBody.OrderID != "" {
		assert.Len(t, respBody.OrderID, 0, "override this with the expected min length if you have a format")
	}
}
