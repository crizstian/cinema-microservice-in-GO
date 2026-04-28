package server

import (
	"cinemas/services/booking/internal/api"
	"cinemas/services/booking/internal/metrics"
	"cinemas/services/booking/internal/routes"
	"cinemas/services/booking/internal/tracing"
	"context"
	"os"
	"strconv"
	"time"

	"go.mongodb.org/mongo-driver/mongo"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	"github.com/opentracing/opentracing-go"
	log "github.com/sirupsen/logrus"
)

func init() {
	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)

	// Only log the warning severity or above.
	log.SetLevel(log.InfoLevel)
}

var e *echo.Echo

// Start initializes and starts the HTTP server.
func Start(r map[string]interface{}, se chan error) {

	// get server settings from dependecy injection
	ss := r["ss"].(map[string]interface{})

	e = echo.New()

	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: "method=${method}, uri=${uri}, status=${status}\n",
	}))

	e.Use(middleware.Recover())

	// Prometheus metrics middleware and endpoint
	e.Use(metrics.Middleware())
	e.GET("/metrics", metrics.Handler())

	span := r["tracer"].(opentracing.Tracer).StartSpan("booking-service")
	span.SetTag("booking-service", "Tracer started")
	defer span.Finish()

	ctx := opentracing.ContextWithSpan(context.Background(), span)

	e.Use(tracing.TraceWithConfig(tracing.TraceConfig{
		Context: ctx,
		Skipper: nil,
	}))

	app := e.Group("/booking")

	// Register API Routes, and register Repository handlers
	routes.API(app, r["repo"].(api.Repository))
	routes.HealthyAPI(e)

	// Start server
	go func() {
		if err := e.Start(":" + strconv.Itoa(ss["port"].(int))); err != nil {
			log.Info("shutting down the server")
			se <- err
		}
	}()
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
