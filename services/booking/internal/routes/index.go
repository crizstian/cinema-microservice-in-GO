package routes

import (
	"cinemas/services/booking/internal/api"

	"github.com/labstack/echo"
)

// API ...
func API(app *echo.Group, repo api.Repository) {
	BookingAPI(app, repo)
}
