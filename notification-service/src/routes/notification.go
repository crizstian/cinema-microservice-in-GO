package routes

import (
	"cinemas-microservices/notification-service/src/api"

	"github.com/labstack/echo"
)

// NotificationAPI ...
func NotificationAPI(app *echo.Group, repo api.Repository) {
	app.POST("/sendEmail", repo.SendEmail)
	app.POST("/sendSMS", repo.SendSMS)
}

// HealthyAPI ...
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
