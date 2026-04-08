package routes

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// MockRepository implements api.Repository for testing
type MockRepository struct {
	GetAllMoviesCalled    bool
	GetMoviePremiersCalled bool
	GetMovieByIDCalled    bool
}

func (m *MockRepository) GetAllMovies(c echo.Context) error {
	m.GetAllMoviesCalled = true
	return c.JSON(http.StatusOK, map[string]string{"status": "ok"})
}

func (m *MockRepository) GetMoviePremiers(c echo.Context) error {
	m.GetMoviePremiersCalled = true
	return c.JSON(http.StatusOK, map[string]string{"status": "ok"})
}

func (m *MockRepository) GetMovieByID(c echo.Context) error {
	m.GetMovieByIDCalled = true
	return c.JSON(http.StatusOK, map[string]string{"status": "ok"})
}

func TestMoviesAPI_RoutesRegistered(t *testing.T) {
	e := echo.New()
	app := e.Group("/movies")
	mockRepo := &MockRepository{}

	MoviesAPI(app, mockRepo)

	routes := e.Routes()

	// Verify routes are registered
	routePaths := make(map[string]bool)
	for _, r := range routes {
		routePaths[r.Path] = true
	}

	assert.True(t, routePaths["/movies/all"], "Route /movies/all should be registered")
	assert.True(t, routePaths["/movies/premieres"], "Route /movies/premieres should be registered")
	assert.True(t, routePaths["/movies/:id"], "Route /movies/:id should be registered")
}

func TestMoviesAPI_GetAllMovies(t *testing.T) {
	e := echo.New()
	app := e.Group("/movies")
	mockRepo := &MockRepository{}

	MoviesAPI(app, mockRepo)

	req := httptest.NewRequest(http.MethodGet, "/movies/all", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.True(t, mockRepo.GetAllMoviesCalled, "GetAllMovies should be called")
}

func TestMoviesAPI_GetPremieres(t *testing.T) {
	e := echo.New()
	app := e.Group("/movies")
	mockRepo := &MockRepository{}

	MoviesAPI(app, mockRepo)

	req := httptest.NewRequest(http.MethodGet, "/movies/premieres", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.True(t, mockRepo.GetMoviePremiersCalled, "GetMoviePremiers should be called")
}

func TestMoviesAPI_GetMovieByID(t *testing.T) {
	e := echo.New()
	app := e.Group("/movies")
	mockRepo := &MockRepository{}

	MoviesAPI(app, mockRepo)

	req := httptest.NewRequest(http.MethodGet, "/movies/123", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.True(t, mockRepo.GetMovieByIDCalled, "GetMovieByID should be called")
}

func TestHealthyAPI_PingRoute(t *testing.T) {
	e := echo.New()

	HealthyAPI(e)

	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "pong", rec.Body.String())
}

func TestAPI_Integration(t *testing.T) {
	e := echo.New()
	app := e.Group("/movies")
	mockRepo := &MockRepository{}

	API(app, mockRepo)

	// Verify API function calls MoviesAPI and registers routes
	routes := e.Routes()
	routePaths := make(map[string]bool)
	for _, r := range routes {
		routePaths[r.Path] = true
	}

	assert.True(t, routePaths["/movies/all"], "Route /movies/all should be registered via API")
	assert.True(t, routePaths["/movies/premieres"], "Route /movies/premieres should be registered via API")
	assert.True(t, routePaths["/movies/:id"], "Route /movies/:id should be registered via API")
}

func TestHealthyAPI_MultipleRequests(t *testing.T) {
	e := echo.New()
	HealthyAPI(e)

	for i := 0; i < 5; i++ {
		req := httptest.NewRequest(http.MethodGet, "/ping", nil)
		rec := httptest.NewRecorder()
		e.ServeHTTP(rec, req)

		require.Equal(t, http.StatusOK, rec.Code)
		require.Equal(t, "pong", rec.Body.String())
	}
}

func TestMoviesAPI_MethodNotAllowed(t *testing.T) {
	e := echo.New()
	app := e.Group("/movies")
	mockRepo := &MockRepository{}

	MoviesAPI(app, mockRepo)

	// POST to a GET-only endpoint
	req := httptest.NewRequest(http.MethodPost, "/movies/all", nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)

	// Echo returns 405 Method Not Allowed
	assert.Equal(t, http.StatusMethodNotAllowed, rec.Code)
}
