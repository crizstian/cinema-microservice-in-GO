package api

import (
	"net/http"

	"github.com/labstack/echo"
)

// PingAPI handles the health check endpoint
func PingAPI(c echo.Context) error {
	return c.String(http.StatusOK, "pong .../showtime v1/ ...response")
}
