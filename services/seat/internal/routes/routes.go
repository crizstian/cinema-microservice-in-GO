package routes

import (
	"cinemas/services/seat/internal/api"

	"github.com/labstack/echo"
)

// Register registers all routes for the seat service
func Register(e *echo.Echo, repo api.Repository) {
	// Health check
	e.GET("/ping", api.PingAPI)

	// Seat API group
	seats := e.Group("/seats")

	// Public endpoints
	seats.GET("/availability", repo.GetAvailability)
	seats.POST("/hold", repo.HoldSeats)
	seats.GET("/hold/:hold_id", repo.GetHold)
	seats.DELETE("/hold/:hold_id", repo.ReleaseHold)
	seats.POST("/reserve", repo.ReserveSeats)

	// Admin endpoints
	seats.POST("/layout", repo.CreateRoomLayout)
	seats.GET("/layout/:room_id", repo.GetRoomLayout)
}
