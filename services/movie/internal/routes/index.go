package routes

import (
	"cinemas/services/movie/internal/api"

	"github.com/labstack/echo"
)

// API ...
func API(app *echo.Group, repo api.Repository) {
	MoviesAPI(app, repo)
}
