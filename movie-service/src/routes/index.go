package routes

import (
	"cinemas-microservices/movie-service/src/api"

	"github.com/labstack/echo"
)

// API ...
func API(app *echo.Group, repo api.Repository) {
	MoviesAPI(app, repo)
}
