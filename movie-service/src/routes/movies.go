package routes

import (
	"cinemas-microservices/movie-service/src/api"

	"github.com/labstack/echo"
)

// MoviesAPI ...
func MoviesAPI(app *echo.Group, repo api.Repository) {
	app.GET("/all", repo.GetAllMovies)
	app.GET("/premieres", repo.GetMoviePremiers)
	app.GET("/:id", repo.GetMovieByID)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
