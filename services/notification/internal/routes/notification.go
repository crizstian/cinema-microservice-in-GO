package routes

import (
	"cinemas/services/notification/internal/api"

	"github.com/labstack/echo"
)

// NotificationAPI ...
func NotificationAPI(app *echo.Group, repo api.Repository) {
	app.POST("/sendEmail", repo.SendEmail)
	app.POST("/sendSMS", repo.SendSMS)
}

// HealthyAPI registers health check endpoints
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
	// Kubernetes health endpoints
	app.GET("/health/live", api.PingAPI)
	app.GET("/health/ready", api.PingAPI)
}
