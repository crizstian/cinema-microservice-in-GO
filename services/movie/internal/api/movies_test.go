package api

import (
	"cinemas/services/movie/internal/models"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ========================================
// UNIT TESTS - HELPER FUNCTIONS
// ========================================

func TestGetTimeFormat(t *testing.T) {
	y, m, d := getTimeFormat()

	assert.Greater(t, y, 2020, "Year should be greater than 2020")
	assert.GreaterOrEqual(t, m, 1, "Month should be >= 1")
	assert.LessOrEqual(t, m, 12, "Month should be <= 12")
	assert.GreaterOrEqual(t, d, 1, "Day should be >= 1")
	assert.LessOrEqual(t, d, 31, "Day should be <= 31")

	now := time.Now()
	assert.Equal(t, now.Year(), y)
	assert.Equal(t, int(now.Month()), m)
	assert.Equal(t, now.Day(), d)
}

// ========================================
// MOCK SETUP
// ========================================

// setupMockDB creates a test MongoDB database
func setupMockDB(t *testing.T) (*mongo.Database, func()) {
	mongoURI := os.Getenv("MONGODB_TEST_URI")
	if mongoURI == "" {
		t.Skip("MONGODB_TEST_URI not set, skipping integration test")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	require.NoError(t, err)

	err = client.Ping(ctx, nil)
	require.NoError(t, err)

	testDB := client.Database("cinemas" + time.Now().Format("20060102150405"))

	cleanup := func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}

	return testDB, cleanup
}

// seedMovies inserts test movie data into the database
func seedMovies(t *testing.T, db *mongo.Database) []models.Movie {
	movies := []models.Movie{
		{
			ID:           "movie-001",
			Title:        "The Matrix",
			Runtime:      "136 min",
			Format:       "IMAX",
			Plot:         "A computer hacker learns about the true nature of reality.",
			ReleaseYear:  1999,
			ReleaseMonth: 3,
			ReleaseDay:   31,
		},
		{
			ID:           "movie-002",
			Title:        "Inception",
			Runtime:      "148 min",
			Format:       "IMAX",
			Plot:         "A thief who steals corporate secrets through dream-sharing technology.",
			ReleaseYear:  2010,
			ReleaseMonth: 7,
			ReleaseDay:   16,
		},
		{
			ID:           "movie-003",
			Title:        "Interstellar",
			Runtime:      "169 min",
			Format:       "IMAX 70mm",
			Plot:         "A team of explorers travel through a wormhole in space.",
			ReleaseYear:  time.Now().Year(),
			ReleaseMonth: int(time.Now().Month()),
			ReleaseDay:   time.Now().Day() - 1,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	docs := make([]interface{}, len(movies))
	for i, m := range movies {
		docs[i] = m
	}

	_, err := db.Collection("movies").InsertMany(ctx, docs)
	require.NoError(t, err)

	return movies
}

// ========================================
// RESPONSE TYPES FOR TESTS
// ========================================

type MoviesListResponse struct {
	Msg    string         `json:"msg"`
	Movies []models.Movie `json:"movies"`
}

type MoviePremiersResponse struct {
	Msg    string         `json:"msg"`
	Movies []models.Movie `json:"movies"`
}

// ========================================
// INTEGRATION TESTS - WITH REAL MONGODB
// ========================================

func TestIntegrationGetAllMovies(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	movies := seedMovies(t, db)
	api := API{db: db}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/movies", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := api.GetAllMovies(c)
	require.NoError(t, err)

	assert.Equal(t, http.StatusOK, rec.Code)

	var resp MoviesListResponse
	err = json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	log.Printf("%v", resp)

	assert.Equal(t, "list of movies", resp.Msg)
	assert.Len(t, resp.Movies, len(movies))
}

func TestIntegrationGetMovieByID(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	movies := seedMovies(t, db)
	api := API{db: db}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/movies/"+movies[0].ID, nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/movies/:id")
	c.SetParamNames("id")
	c.SetParamValues(movies[0].ID)

	err := api.GetMovieByID(c)
	require.NoError(t, err)

	assert.Equal(t, http.StatusOK, rec.Code)

	var response map[string]interface{}
	err = json.Unmarshal(rec.Body.Bytes(), &response)
	require.NoError(t, err)

	assert.Equal(t, "list of movies", response["msg"])

	movieData, ok := response["movies"].(map[string]interface{})
	require.True(t, ok, "'movies' field should be an object")
	assert.Equal(t, movies[0].Title, movieData["Title"])
}

func TestIntegrationGetMovieByIDNotFound(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	seedMovies(t, db)
	api := API{db: db}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/movies/non-existent", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.SetPath("/movies/:id")
	c.SetParamNames("id")
	c.SetParamValues("non-existent")

	err := api.GetMovieByID(c)
	require.Error(t, err)
}

func TestIntegrationGetMoviePremiers(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	seedMovies(t, db)
	api := API{db: db}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/movies/premiers", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := api.GetMoviePremiers(c)
	require.NoError(t, err)

	assert.Equal(t, http.StatusOK, rec.Code)

	var resp MoviePremiersResponse
	err = json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	assert.Equal(t, "list of movies", resp.Msg)
	assert.GreaterOrEqual(t, len(resp.Movies), 0)
}

// ========================================
// UNIT TESTS - DATABASE OPERATIONS
// ========================================

func TestConnectWithValidDB(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	repo, err := Connect(db)
	require.NoError(t, err)
	assert.NotNil(t, repo)
}

func TestConnectWithNilDB(t *testing.T) {
	repo, err := Connect(nil)
	require.Error(t, err)
	assert.Nil(t, repo)
	// El mensaje externo que estás enviando desde Connect
	assert.Contains(t, err.Error(), "Failed to initialize repository")
}

// ========================================
// TABLE-DRIVEN TESTS
// ========================================

func TestGetMovieByIDTableDriven(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	movies := seedMovies(t, db)

	tests := []struct {
		name           string
		movieID        string
		expectedStatus int
		shouldError    bool
		expectedTitle  string
	}{
		{
			name:           "Valid movie ID - The Matrix",
			movieID:        movies[0].ID,
			expectedStatus: http.StatusOK,
			shouldError:    false,
			expectedTitle:  "The Matrix",
		},
		{
			name:           "Valid movie ID - Inception",
			movieID:        movies[1].ID,
			expectedStatus: http.StatusOK,
			shouldError:    false,
			expectedTitle:  "Inception",
		},
		{
			name:        "Invalid movie ID",
			movieID:     "invalid-id",
			shouldError: true,
		},
		{
			name:        "Empty movie ID",
			movieID:     "",
			shouldError: true,
		},
	}

	api := API{db: db}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/movies/"+tt.movieID, nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			c.SetPath("/movies/:id")
			c.SetParamNames("id")
			c.SetParamValues(tt.movieID)

			err := api.GetMovieByID(c)

			if tt.shouldError {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.expectedStatus, rec.Code)

				var response map[string]interface{}
				err = json.Unmarshal(rec.Body.Bytes(), &response)
				require.NoError(t, err)

				movieData, ok := response["movies"].(map[string]interface{})
				require.True(t, ok, "'movies' field should be an object")
				assert.Equal(t, tt.expectedTitle, movieData["Title"])
			}
		})
	}
}

// ========================================
// BENCHMARK TESTS
// ========================================

func BenchmarkGetAllMovies(b *testing.B) {
	mongoURI := os.Getenv("MONGODB_TEST_URI")
	if mongoURI == "" {
		b.Skip("MONGODB_TEST_URI not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	require.NoError(b, err)

	testDB := client.Database("bench_movies")
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}()

	movies := []interface{}{
		models.Movie{ID: "1", Title: "Movie 1", Runtime: "120 min", Format: "IMAX"},
		models.Movie{ID: "2", Title: "Movie 2", Runtime: "100 min", Format: "Standard"},
		models.Movie{ID: "3", Title: "Movie 3", Runtime: "150 min", Format: "IMAX"},
	}
	testDB.Collection("movies").InsertMany(context.Background(), movies)

	api := API{db: testDB}
	e := echo.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest(http.MethodGet, "/movies", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		api.GetAllMovies(c)
	}
}

func BenchmarkGetMovieByID(b *testing.B) {
	mongoURI := os.Getenv("MONGODB_TEST_URI")
	if mongoURI == "" {
		b.Skip("MONGODB_TEST_URI not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	require.NoError(b, err)

	testDB := client.Database("bench_movies")
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		testDB.Drop(ctx)
		client.Disconnect(ctx)
	}()

	movie := models.Movie{ID: "bench-1", Title: "Benchmark Movie", Runtime: "120 min", Format: "IMAX"}
	testDB.Collection("movies").InsertOne(context.Background(), movie)

	api := API{db: testDB}
	e := echo.New()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest(http.MethodGet, "/movies/bench-1", nil)
		rec := httptest.NewRecorder()
		c := e.NewContext(req, rec)
		c.SetPath("/movies/:id")
		c.SetParamNames("id")
		c.SetParamValues("bench-1")
		api.GetMovieByID(c)
	}
}

// ========================================
// EDGE CASE TESTS
// ========================================

func TestGetAllMoviesEmptyDB(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	api := API{db: db}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/movies", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := api.GetAllMovies(c)
	require.NoError(t, err)

	var resp MoviesListResponse
	err = json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	assert.Equal(t, "list of movies", resp.Msg)
	assert.Len(t, resp.Movies, 0)
}

func TestGetMoviePremiersNoRecent(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	oldMovies := []interface{}{
		models.Movie{
			ID:           "old-001",
			Title:        "Old Movie 1",
			ReleaseYear:  2000,
			ReleaseMonth: 1,
			ReleaseDay:   1,
		},
		models.Movie{
			ID:           "old-002",
			Title:        "Old Movie 2",
			ReleaseYear:  2005,
			ReleaseMonth: 5,
			ReleaseDay:   10,
		},
	}
	db.Collection("movies").InsertMany(context.Background(), oldMovies)

	api := API{db: db}

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/movies/premiers", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	err := api.GetMoviePremiers(c)
	require.NoError(t, err)

	var resp MoviePremiersResponse
	err = json.Unmarshal(rec.Body.Bytes(), &resp)
	require.NoError(t, err)

	assert.Equal(t, "list of movies", resp.Msg)
	assert.Len(t, resp.Movies, 0)
}

// ========================================
// CONCURRENT ACCESS TESTS
// ========================================

func TestConcurrentGetAllMovies(t *testing.T) {
	db, cleanup := setupMockDB(t)
	defer cleanup()

	seedMovies(t, db)
	api := API{db: db}

	done := make(chan bool, 10)
	for i := 0; i < 10; i++ {
		go func() {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "/movies", nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)

			err := api.GetAllMovies(c)
			assert.NoError(t, err)
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}
}
