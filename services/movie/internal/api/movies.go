package api

import (
	errs "cinemas/services/movie/internal/errors"
	"cinemas/services/movie/internal/models"
	"context"
	"errors"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"

	"github.com/labstack/echo"
)

// GetAllMovies retrieves all movies from the database.
func (a API) GetAllMovies(c echo.Context) error {
	var mList []models.Movie

	ctx := context.TODO()

	cursor, err := a.db.Collection("movies").Find(ctx, bson.M{})
	if err != nil {
		return errs.Send("external", "Failed GetAllMovies", err)
	}
	defer cursor.Close(ctx)

	if err = cursor.All(ctx, &mList); err != nil {
		return errs.Send("external", "Failed to decode movies", err)
	}

	res := map[string]interface{}{
		"movies": mList,
		"msg":    "list of movies",
	}

	return c.JSON(http.StatusOK, res)
}

// GetMoviePremiers retrieves movies that premiered recently.
func (a API) GetMoviePremiers(c echo.Context) error {
	y, m, d := getTimeFormat()

	var mList []models.Movie

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	filter := bson.M{
		"releaseYear": bson.M{
			"$gt":  y - 1,
			"$lte": y,
		},
		"releaseMonth": bson.M{
			"$gte": m,
			"$lte": m + 1,
		},
		"releaseDay": bson.M{
			"$lte": d,
		},
	}

	cursor, err := a.db.Collection("movies").Find(ctx, filter)
	if err != nil {
		return errs.Send("external", "Failed to GetMoviePremiers", err)
	}
	defer cursor.Close(ctx)

	if err = cursor.All(ctx, &mList); err != nil {
		return errs.Send("external", "Failed to decode movie premiers", err)
	}

	res := map[string]interface{}{
		"movies": mList,
		"msg":    "list of movies",
	}

	return c.JSON(http.StatusOK, res)
}

// GetMovieByID retrieves a movie by its ID.
func (a API) GetMovieByID(c echo.Context) error {
	var m models.Movie

	id := c.Param("id")
	query := bson.M{"id": id}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err := a.db.Collection("movies").FindOne(ctx, query).Decode(&m)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return errs.Send("external", "Movie not found", err)
		}
		return errs.Send("external", "Failed to GetMovieByID", err)
	}

	res := map[string]interface{}{
		"movies": m,
		"msg":    "list of movies",
	}

	return c.JSON(http.StatusOK, res)
}

type (
	// API holds the database connection.
	API struct {
		db *mongo.Database
	}

	// Repository defines the movie repository interface.
	Repository interface {
		GetAllMovies(c echo.Context) error
		GetMoviePremiers(c echo.Context) error
		GetMovieByID(c echo.Context) error
	}
)

// Connect initializes the API with a database connection.
func Connect(db *mongo.Database) (Repository, error) {
	if db == nil {
		return nil, errs.Send("Internal", "Failed to initialize repository", errors.New("db object is empty"))
	}
	api := new(API)
	api.db = db

	return api, nil
}

func getTimeFormat() (int, int, int) {
	year, month, day := time.Now().Date()

	return year, int(month), day
}
