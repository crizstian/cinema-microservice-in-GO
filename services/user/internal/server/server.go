package server

import (
	"fmt"

	"cinemas/services/user/internal/api"
	errs "cinemas/services/user/internal/errors"
	"cinemas/services/user/internal/metrics"
	"cinemas/services/user/internal/middleware"
	"cinemas/services/user/internal/routes"

	"github.com/labstack/echo"
	mw "github.com/labstack/echo/middleware"
)

// Start initializes and starts the HTTP server
func Start(config map[string]interface{}) error {
	e := echo.New()
	e.HideBanner = true
	e.HTTPErrorHandler = errs.HTTPErrorHandler

	// Middleware
	e.Use(mw.Logger())
	e.Use(mw.Recover())
	e.Use(mw.CORS())

	// Prometheus metrics middleware and endpoint
	e.Use(metrics.Middleware())
	e.GET("/metrics", metrics.Handler())

	// Health check
	routes.HealthyAPI(e)

	// Get repository and JWT config
	repo := config["repo"].(api.Repository)

	// Get JWT config from repository if it implements the interface
	var jwtConfig *middleware.JWTConfig
	if apiWithConfig, ok := repo.(*api.API); ok {
		jwtConfig = apiWithConfig.GetJWTConfig()
	} else {
		jwtConfig = middleware.DefaultConfig()
	}

	// User routes
	userGroup := e.Group("/users")
	routes.UserAPI(userGroup, repo, jwtConfig)

	// Start server
	port := config["port"].(int)
	return e.Start(fmt.Sprintf(":%d", port))
}
