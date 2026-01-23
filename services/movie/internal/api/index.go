package api

import (
	"net/http"

	"github.com/labstack/echo"
)

// PingAPI ...
func PingAPI(c echo.Context) error {
	return c.String(http.StatusOK, "pong")
}
