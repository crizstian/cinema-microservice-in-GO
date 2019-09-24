package routes

import (
	"cinemas-microservices/notification-service/src/api"

	"github.com/labstack/echo"
)

// API ...
func API(app *echo.Group, repo api.Repository) {
	NotificationAPI(app, repo)
}
