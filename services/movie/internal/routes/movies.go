package routes

import (
	"cinemas/services/movie/internal/api"

	"github.com/labstack/echo"
)

// MoviesAPI ...
func MoviesAPI(app *echo.Group, repo api.Repository) {
	// GET /movies - returns all movies (E2E test expects this)
	app.GET("", repo.GetAllMovies)
	app.GET("/all", repo.GetAllMovies)
	app.GET("/premieres", repo.GetMoviePremiers)
	app.GET("/:id", repo.GetMovieByID)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
