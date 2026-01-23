package routes

import (
	"cinemas/services/booking/internal/api"

	"github.com/labstack/echo"
)

// BookingAPI ...
func BookingAPI(app *echo.Group, repo api.Repository) {
	app.POST("/", repo.MakeBooking)
	app.GET("/:orderId", repo.GetOrderByID)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
