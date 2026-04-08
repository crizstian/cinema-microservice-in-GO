package routes

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

type MockRepository struct {
	mock.Mock
}

func (m *MockRepository) ListShowtimes(c echo.Context) error {
	args := m.Called(c)
	return args.Error(0)
}

func (m *MockRepository) GetShowtime(c echo.Context) error {
	args := m.Called(c)
	return args.Error(0)
}

func (m *MockRepository) CreateShowtime(c echo.Context) error {
	args := m.Called(c)
	return args.Error(0)
}

func (m *MockRepository) UpdateShowtime(c echo.Context) error {
	args := m.Called(c)
	return args.Error(0)
}

func (m *MockRepository) CancelShowtime(c echo.Context) error {
	args := m.Called(c)
	return args.Error(0)
}

func TestShowtimeAPI_RoutesRegistered(t *testing.T) {
	e := echo.New()
	mockRepo := new(MockRepository)

	group := e.Group("/showtimes")
	ShowtimeAPI(group, mockRepo)

	routes := e.Routes()

	expectedPaths := map[string]bool{
		"/showtimes":     false,
		"/showtimes/:id": false,
	}

	for _, route := range routes {
		if _, ok := expectedPaths[route.Path]; ok {
			expectedPaths[route.Path] = true
		}
	}

	for path, found := range expectedPaths {
		assert.True(t, found, "Route %s should be registered", path)
	}
}

func TestHealthyAPI_PingRoute(t *testing.T) {
	e := echo.New()
	HealthyAPI(e)

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), "pong")
}
