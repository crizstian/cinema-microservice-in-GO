package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"cinemas/services/showtime/internal/models"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockStore is a mock implementation of ShowtimeStore
type MockStore struct {
	mock.Mock
}

func (m *MockStore) List(query models.ListShowtimesQuery) (*models.ShowtimeList, error) {
	args := m.Called(query)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.ShowtimeList), args.Error(1)
}

func (m *MockStore) Get(id string) (*models.Showtime, error) {
	args := m.Called(id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.Showtime), args.Error(1)
}

func (m *MockStore) Create(showtime *models.Showtime) error {
	args := m.Called(showtime)
	return args.Error(0)
}

func (m *MockStore) Update(id string, showtime *models.Showtime) error {
	args := m.Called(id, showtime)
	return args.Error(0)
}

func (m *MockStore) CheckRoomConflict(cinemaID string, roomNumber int, startTime, endTime time.Time, excludeID string) (bool, error) {
	args := m.Called(cinemaID, roomNumber, startTime, endTime, excludeID)
	return args.Bool(0), args.Error(1)
}

// MockMovieClient is a mock implementation of MovieServiceClient
type MockMovieClient struct {
	mock.Mock
}

func (m *MockMovieClient) MovieExists(movieID string) (bool, error) {
	args := m.Called(movieID)
	return args.Bool(0), args.Error(1)
}

// MockWebhookSender is a mock implementation of WebhookSender
type MockWebhookSender struct {
	mock.Mock
}

func (m *MockWebhookSender) Send(event models.WebhookEvent) error {
	args := m.Called(event)
	return args.Error(0)
}

func setupTestAPI() (*API, *MockStore, *MockMovieClient, *MockWebhookSender) {
	store := new(MockStore)
	movieClient := new(MockMovieClient)
	webhookSender := new(MockWebhookSender)
	api := &API{
		Store:         store,
		MovieClient:   movieClient,
		WebhookSender: webhookSender,
	}
	return api, store, movieClient, webhookSender
}

func TestListShowtimes(t *testing.T) {
	api, store, _, _ := setupTestAPI()

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/showtimes?page=1&limit=10", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	expectedList := &models.ShowtimeList{
		Data: []models.Showtime{
			{ID: "sht_1", MovieID: "mov_1", Status: models.StatusScheduled},
		},
		Pagination: models.Pagination{Page: 1, Limit: 10, Total: 1, TotalPages: 1},
	}

	store.On("List", mock.AnythingOfType("models.ListShowtimesQuery")).Return(expectedList, nil)

	err := api.ListShowtimes(c)

	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, rec.Code)

	var result models.ShowtimeList
	json.Unmarshal(rec.Body.Bytes(), &result)
	assert.Equal(t, 1, len(result.Data))
}

func TestGetShowtime(t *testing.T) {
	api, store, _, _ := setupTestAPI()

	t.Run("found", func(t *testing.T) {
		e := echo.New()
		req := httptest.NewRequest(http.MethodGet, "/showtimes/sht_123", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetParamNames("id")
		c.SetParamValues("sht_123")

		expected := &models.Showtime{ID: "sht_123", MovieID: "mov_1"}
		store.On("Get", "sht_123").Return(expected, nil).Once()

		err := api.GetShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusOK, rec.Code)
	})

	t.Run("not found", func(t *testing.T) {
		e := echo.New()
		req := httptest.NewRequest(http.MethodGet, "/showtimes/sht_notfound", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetParamNames("id")
		c.SetParamValues("sht_notfound")

		store.On("Get", "sht_notfound").Return(nil, models.ErrShowtimeNotFound).Once()

		err := api.GetShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusNotFound, rec.Code)
	})
}

func TestCreateShowtime(t *testing.T) {
	api, store, movieClient, webhookSender := setupTestAPI()

	t.Run("success", func(t *testing.T) {
		e := echo.New()

		reqBody := models.CreateShowtimeRequest{
			MovieID:        "mov_123",
			CinemaID:       "cin_456",
			RoomNumber:     5,
			StartTime:      time.Now().Add(time.Hour),
			EndTime:        time.Now().Add(3 * time.Hour),
			Price:          models.Price{Regular: 12000},
			AvailableSeats: 150,
		}
		body, _ := json.Marshal(reqBody)

		req := httptest.NewRequest(http.MethodPost, "/showtimes", bytes.NewReader(body))
		req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		movieClient.On("MovieExists", "mov_123").Return(true, nil).Once()
		store.On("CheckRoomConflict", "cin_456", 5, mock.Anything, mock.Anything, "").Return(false, nil).Once()
		store.On("Create", mock.AnythingOfType("*models.Showtime")).Return(nil).Once()
		webhookSender.On("Send", mock.AnythingOfType("models.WebhookEvent")).Return(nil).Once()

		err := api.CreateShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusCreated, rec.Code)
	})

	t.Run("movie not found", func(t *testing.T) {
		e := echo.New()

		reqBody := models.CreateShowtimeRequest{
			MovieID:        "mov_notfound",
			CinemaID:       "cin_456",
			RoomNumber:     5,
			StartTime:      time.Now().Add(time.Hour),
			EndTime:        time.Now().Add(3 * time.Hour),
			Price:          models.Price{Regular: 12000},
			AvailableSeats: 150,
		}
		body, _ := json.Marshal(reqBody)

		req := httptest.NewRequest(http.MethodPost, "/showtimes", bytes.NewReader(body))
		req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		movieClient.On("MovieExists", "mov_notfound").Return(false, nil).Once()

		err := api.CreateShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusNotFound, rec.Code)
	})

	t.Run("room conflict", func(t *testing.T) {
		e := echo.New()

		reqBody := models.CreateShowtimeRequest{
			MovieID:        "mov_123",
			CinemaID:       "cin_456",
			RoomNumber:     5,
			StartTime:      time.Now().Add(time.Hour),
			EndTime:        time.Now().Add(3 * time.Hour),
			Price:          models.Price{Regular: 12000},
			AvailableSeats: 150,
		}
		body, _ := json.Marshal(reqBody)

		req := httptest.NewRequest(http.MethodPost, "/showtimes", bytes.NewReader(body))
		req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)

		movieClient.On("MovieExists", "mov_123").Return(true, nil).Once()
		store.On("CheckRoomConflict", "cin_456", 5, mock.Anything, mock.Anything, "").Return(true, nil).Once()

		err := api.CreateShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusConflict, rec.Code)
	})
}

func TestCancelShowtime(t *testing.T) {
	api, store, _, webhookSender := setupTestAPI()

	t.Run("success", func(t *testing.T) {
		e := echo.New()
		req := httptest.NewRequest(http.MethodDelete, "/showtimes/sht_123", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetParamNames("id")
		c.SetParamValues("sht_123")

		showtime := &models.Showtime{ID: "sht_123", Status: models.StatusScheduled}
		store.On("Get", "sht_123").Return(showtime, nil).Once()
		store.On("Update", "sht_123", mock.AnythingOfType("*models.Showtime")).Return(nil).Once()
		webhookSender.On("Send", mock.AnythingOfType("models.WebhookEvent")).Return(nil).Once()

		err := api.CancelShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusOK, rec.Code)
	})

	t.Run("already cancelled", func(t *testing.T) {
		e := echo.New()
		req := httptest.NewRequest(http.MethodDelete, "/showtimes/sht_cancelled", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetParamNames("id")
		c.SetParamValues("sht_cancelled")

		showtime := &models.Showtime{ID: "sht_cancelled", Status: models.StatusCancelled}
		store.On("Get", "sht_cancelled").Return(showtime, nil).Once()

		err := api.CancelShowtime(c)

		assert.NoError(t, err)
		assert.Equal(t, http.StatusConflict, rec.Code)
	})
}

func TestPingAPI(t *testing.T) {
	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/ping", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := PingAPI(c)

	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), "pong")
}
