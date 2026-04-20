package routes

import (
	"cinemas/services/cinema/internal/api"

	"github.com/labstack/echo/v4"
)

// Setup configures all routes for the cinema service.
func Setup(e *echo.Echo, h *api.Handler) {
	e.GET("/ping", h.Ping)
	// Kubernetes health endpoints
	e.GET("/health/live", h.Ping)
	e.GET("/health/ready", h.Ping)

	cinemas := e.Group("/cinemas")
	cinemas.GET("", h.ListCinemas)
	cinemas.GET("/:id", h.GetCinema)
	cinemas.POST("", h.CreateCinema)
	cinemas.GET("/:id/rooms", h.ListRooms)
	cinemas.POST("/:id/rooms", h.CreateRoom)
}
