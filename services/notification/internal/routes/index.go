package routes

import (
	"cinemas/services/notification/internal/api"

	"github.com/labstack/echo"
)

// API ...
func API(app *echo.Group, repo api.Repository) {
	NotificationAPI(app, repo)
}
