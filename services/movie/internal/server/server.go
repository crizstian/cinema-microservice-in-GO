package server

import (
	"cinemas/services/movie/internal/api"
	"cinemas/services/movie/internal/metrics"
	"cinemas/services/movie/internal/routes"
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"go.mongodb.org/mongo-driver/mongo"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	log "github.com/sirupsen/logrus"
)

func init() {
	// Log as JSON instead of the default ASCII formatter.
	// log.SetFormatter(&log.JSONFormatter{})

	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)

	// Only log the warning severity or above.
	log.SetLevel(log.InfoLevel)
}

var e *echo.Echo

// Start initializes and starts the HTTP server.
func Start(r map[string]interface{}) error {
	e = echo.New()

	// Middleware de logging
	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: "method=${method}, uri=${uri}, status=${status}\n",
	}))
	e.Use(middleware.Recover())

	// Prometheus metrics middleware and endpoint
	e.Use(metrics.Middleware())
	e.GET("/metrics", metrics.Handler())

	// Grupo de rutas para /movies
	app := e.Group("/movies")

	// Registrar rutas
	routes.API(app, r["repo"].(api.Repository))
	routes.HealthyAPI(e)

	// Extraer puerto
	port := r["port"].(int)
	portStr := strconv.Itoa(port)

	log.Infof("Starting server on port %s", portStr)

	// Iniciar servidor (bloquea hasta que termine o haya error)
	if err := e.Start(":" + portStr); err != nil {
		return fmt.Errorf("server failed to start: %w", err)
	}

	return nil
}

// Shutdown gracefully shuts down the server and closes MongoDB connection.
func Shutdown(client *mongo.Client) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := e.Shutdown(ctx); err != nil {
		e.Logger.Fatal(err)
	}

	// Disconnect MongoDB client
	if client != nil {
		if err := client.Disconnect(ctx); err != nil {
			log.Errorf("Error disconnecting from MongoDB: %v", err)
		}
	}

	log.Warn("Server shutdown")
	os.Exit(1)
}

// GetServer returns the Echo server instance.
func GetServer() *echo.Echo {
	return e
}
