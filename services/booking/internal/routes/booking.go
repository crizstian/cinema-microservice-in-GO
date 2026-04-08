package routes

import (
	"cinemas/services/booking/internal/api"

	"github.com/labstack/echo"
)

// BookingAPI ...
func BookingAPI(app *echo.Group, repo api.Repository) {
	// Support both /booking and /booking/ for POST
	app.POST("", repo.MakeBooking)
	app.POST("/", repo.MakeBooking)
	app.GET("/:orderId", repo.GetOrderByID)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
