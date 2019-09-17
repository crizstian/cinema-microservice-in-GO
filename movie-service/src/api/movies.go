package api

import (
	errs "cinemas-microservices/movie-service/src/errors"
	"cinemas-microservices/movie-service/src/models"
	"errors"
	"net/http"
	"time"

	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"

	"github.com/labstack/echo"
)

// GetAllMovies ...
func (a API) GetAllMovies(c echo.Context) error {
	var mList []models.Movie

	err := a.db.C("movies").Find(bson.M{}).All(&mList)

	if err != nil {
		return errs.Send("external", "Failed GetAllMovies", err)
	}

	res := map[string]interface{}{
		"movies": mList,
		"msg":    "list of movies",
	}

	return c.JSON(http.StatusOK, res)
}

// GetMoviePremiers ...
func (a API) GetMoviePremiers(c echo.Context) error {
	y, m, d := getTimeFormat()

	var mList []models.Movie

	err := a.db.C("movies").Find(bson.M{
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
	}).All(&mList)

	if err != nil {
		return errs.Send("external", "Failed to GetMoviePremiers", err)
	}

	res := map[string]interface{}{
		"movies": mList,
		"msg":    "list of movies",
	}

	return c.JSON(http.StatusOK, res)
}

// GetMovieByID ...
func (a API) GetMovieByID(c echo.Context) error {
	var m models.Movie

	id := c.Param("id")
	// projection := bson.M{"_id": 0, "id": 1, "title": 1, "format": 1}
	query := bson.M{"id": id}

	err := a.db.C("movies").Find(query).One(&m)

	if err != nil {
		return errs.Send("external", "Failed to GetMovieByID", err)
	}

	res := map[string]interface{}{
		"movies": m,
		"msg":    "list of movies",
	}

	return c.JSON(http.StatusOK, res)
}

type (
	// API ...
	API struct {
		db *mgo.Database
	}

	// Repository ...
	Repository interface {
		GetAllMovies(c echo.Context) error
		GetMoviePremiers(c echo.Context) error
		GetMovieByID(c echo.Context) error
	}
)

// Connect ...
func Connect(db *mgo.Database) (Repository, error) {
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
