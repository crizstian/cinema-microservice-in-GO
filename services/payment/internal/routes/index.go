package routes

import (
	"cinemas/services/payment/internal/api"

	"github.com/labstack/echo"
)

// API ...
func API(app *echo.Group, repo api.Repository) {
	PaymentAPI(app, repo)
}
