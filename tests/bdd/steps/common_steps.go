package steps

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/cucumber/godog"
)

// TestContext holds state between steps
type TestContext struct {
	client       *http.Client
	ctx          context.Context
	baseURLs     map[string]string
	accessToken  string
	sessionID    string
	lastResponse *http.Response
	lastBody     []byte
	lastError    error

	// State from previous steps
	movieID    string
	showtimeID string
	holdID     string
	bookingID  string
	orderID    string
	seats      []string
}

// NewTestContext creates a new test context with default values
func NewTestContext() *TestContext {
	return &TestContext{
		client: &http.Client{Timeout: 30 * time.Second},
		ctx:    context.Background(),
		baseURLs: map[string]string{
			"user":         getEnv("USER_SERVICE_URL", "http://localhost:8004"),
			"movie":        getEnv("MOVIE_SERVICE_URL", "http://localhost:8000"),
			"cinema":       getEnv("CINEMA_SERVICE_URL", "http://localhost:8085"),
			"showtime":     getEnv("SHOWTIME_SERVICE_URL", "http://localhost:3003"),
			"seat":         getEnv("SEAT_SERVICE_URL", "http://localhost:3004"),
			"payment":      getEnv("PAYMENT_SERVICE_URL", "http://localhost:8001"),
			"booking":      getEnv("BOOKING_SERVICE_URL", "http://localhost:8082"),
			"notification": getEnv("NOTIFICATION_SERVICE_URL", "http://localhost:8002"),
		},
		sessionID: fmt.Sprintf("sess_bdd_%d", time.Now().UnixNano()),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// HTTP Helpers
func (tc *TestContext) get(service, path string) error {
	url := tc.baseURLs[service] + path
	req, err := http.NewRequestWithContext(tc.ctx, "GET", url, nil)
	if err != nil {
		return err
	}

	if tc.accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+tc.accessToken)
	}
	req.Header.Set("Accept", "application/json")

	tc.lastResponse, tc.lastError = tc.client.Do(req)
	if tc.lastError != nil {
		return tc.lastError
	}

	tc.lastBody, _ = io.ReadAll(tc.lastResponse.Body)
	tc.lastResponse.Body.Close()
	return nil
}

func (tc *TestContext) post(service, path string, payload interface{}) error {
	url := tc.baseURLs[service] + path
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(tc.ctx, "POST", url, bytes.NewBuffer(body))
	if err != nil {
		return err
	}

	if tc.accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+tc.accessToken)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	tc.lastResponse, tc.lastError = tc.client.Do(req)
	if tc.lastError != nil {
		return tc.lastError
	}

	tc.lastBody, _ = io.ReadAll(tc.lastResponse.Body)
	tc.lastResponse.Body.Close()
	return nil
}

func (tc *TestContext) getJSONField(field string) (interface{}, error) {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return nil, err
	}

	parts := strings.Split(field, ".")
	var current interface{} = result
	for _, part := range parts {
		if m, ok := current.(map[string]interface{}); ok {
			current = m[part]
		} else {
			return nil, fmt.Errorf("field %s not found", field)
		}
	}
	return current, nil
}

// Common Step Definitions

func (tc *TestContext) elSistemaDeCineEstaFuncionando() error {
	services := []string{"movie", "booking", "seat", "showtime"}
	for _, svc := range services {
		if err := tc.get(svc, "/"); err != nil {
			return fmt.Errorf("service %s not responding: %w", svc, err)
		}
		if tc.lastResponse.StatusCode >= 500 {
			return fmt.Errorf("service %s returned %d", svc, tc.lastResponse.StatusCode)
		}
	}
	return nil
}

func (tc *TestContext) soyUnUsuarioRegistradoConEmail(email string) error {
	tc.sessionID = fmt.Sprintf("sess_%s_%d", strings.Split(email, "@")[0], time.Now().UnixNano())
	return nil
}

func (tc *TestContext) deberiaRecibirCodigo(expectedCode int) error {
	if tc.lastResponse == nil {
		return fmt.Errorf("no response received")
	}
	if tc.lastResponse.StatusCode != expectedCode {
		return fmt.Errorf("expected status %d, got %d. Body: %s",
			expectedCode, tc.lastResponse.StatusCode, string(tc.lastBody))
	}
	return nil
}

func (tc *TestContext) deberiaVerAlMenosNPeliculas(minCount int) error {
	movies, err := tc.getJSONField("movies")
	if err != nil {
		return err
	}

	movieList, ok := movies.([]interface{})
	if !ok {
		return fmt.Errorf("movies is not an array")
	}

	if len(movieList) < minCount {
		return fmt.Errorf("expected at least %d movies, got %d", minCount, len(movieList))
	}
	return nil
}

func (tc *TestContext) esperarNSegundos(seconds int) error {
	time.Sleep(time.Duration(seconds) * time.Second)
	return nil
}

// Register common steps
func RegisterCommonSteps(ctx *godog.ScenarioContext, tc *TestContext) {
	// System state
	ctx.Step(`^que el sistema de cine está funcionando$`, tc.elSistemaDeCineEstaFuncionando)
	ctx.Step(`^soy un usuario registrado con email "([^"]*)"$`, tc.soyUnUsuarioRegistradoConEmail)
	ctx.Step(`^que soy un usuario registrado con email "([^"]*)"$`, tc.soyUnUsuarioRegistradoConEmail)

	// Response assertions
	ctx.Step(`^debería recibir código (\d+)$`, tc.deberiaRecibirCodigo)
	ctx.Step(`^debería ver al menos (\d+) películas?$`, tc.deberiaVerAlMenosNPeliculas)

	// Time
	ctx.Step(`^espero (\d+) segundos$`, tc.esperarNSegundos)
}
