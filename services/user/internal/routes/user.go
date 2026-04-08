package routes

import (
	"cinemas/services/user/internal/api"
	"cinemas/services/user/internal/middleware"

	"github.com/labstack/echo"
)

// UserAPI sets up user routes
func UserAPI(app *echo.Group, repo api.Repository, jwtConfig *middleware.JWTConfig) {
	// Public routes (no auth required)
	app.POST("/register", repo.Register)
	app.POST("/login", repo.Login)
	app.POST("/refresh", repo.Refresh)

	// Protected routes (auth required)
	protected := app.Group("")
	protected.Use(middleware.JWTMiddleware(jwtConfig))

	protected.POST("/logout", repo.Logout)
	protected.GET("/me", repo.GetProfile)
	protected.PUT("/me", repo.UpdateProfile)
	protected.GET("/me/bookings", repo.GetBookings)
}

// HealthyAPI sets up health check route
func HealthyAPI(app *echo.Echo) {
	app.GET("/ping", api.PingAPI)
}
