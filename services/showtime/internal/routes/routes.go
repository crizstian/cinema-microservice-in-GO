package routes

import (
	"cinemas/services/showtime/internal/api"

	"github.com/labstack/echo"
)

// ShowtimeAPI registers showtime routes
func ShowtimeAPI(app *echo.Group, repo api.Repository) {
	app.GET("", repo.ListShowtimes)
	app.GET("/:id", repo.GetShowtime)
	app.POST("", repo.CreateShowtime)
	app.PUT("/:id", repo.UpdateShowtime)
	app.DELETE("/:id", repo.CancelShowtime)
}

// HealthyAPI registers health check routes
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
	// Kubernetes health endpoints
	app.GET("/health/live", api.PingAPI)
	app.GET("/health/ready", api.PingAPI)
}
