package routes

import (
	"cinemas-microservices/booking-service/src/api"

	"github.com/labstack/echo"
)

// PaymentAPI ...
func PaymentAPI(app *echo.Group, repo api.Repository) {
	app.POST("/", repo.MakeBooking)
	app.GET("/:orderId", repo.GetOrderByID)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
