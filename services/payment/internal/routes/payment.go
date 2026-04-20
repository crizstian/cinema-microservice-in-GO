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

// HealthyAPI registers health check endpoints
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
	// Kubernetes health endpoints
	app.GET("/health/live", api.PingAPI)
	app.GET("/health/ready", api.PingAPI)
}
