package routes

import (
	"cinemas-microservices/payment-service/src/api"

	"github.com/labstack/echo"
)

// PaymentAPI ...
func PaymentAPI(app *echo.Group, repo api.Repository) {
	app.POST("/v2/makePurchase", repo.RegisterPurchase)
	app.GET("/:id", repo.GetPurchaseByID)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
