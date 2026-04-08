package routes

import (
	"cinemas/services/payment/internal/api"

	"github.com/labstack/echo"
)

// PaymentAPI ...
func PaymentAPI(app *echo.Group, repo api.Repository) {
	app.POST("/makePurchase", repo.RegisterPurchase)
	app.GET("/:id", repo.GetPurchaseByID)
	app.POST("/:id/refund", repo.RefundPayment)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
