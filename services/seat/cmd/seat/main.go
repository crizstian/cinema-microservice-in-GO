package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"cinemas/services/seat/internal/api"
	"cinemas/services/seat/internal/config"
	"cinemas/services/seat/internal/db"
	"cinemas/services/seat/internal/metrics"
	"cinemas/services/seat/internal/routes"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	log "github.com/sirupsen/logrus"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Initialize MongoDB
	mongoClient, err := db.NewMongoClient(cfg.MongoURI, cfg.MongoDB)
	if err != nil {
		log.Fatalf("Failed to connect to MongoDB: %v", err)
	}
	log.Info("Connected to MongoDB")

	// Initialize Redis
	redisClient, err := db.NewRedisClient(cfg.RedisAddr, cfg.RedisPass, cfg.RedisDB)
	if err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}
	log.Info("Connected to Redis")

	// Create Echo instance
	e := echo.New()
	e.HideBanner = true

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Prometheus metrics middleware and endpoint
	e.Use(metrics.Middleware())
	e.GET("/metrics", metrics.Handler())

	// Initialize API
	seatAPI := api.NewAPI(redisClient, mongoClient)

	// Register routes
	routes.Register(e, seatAPI)

	// Graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan

		log.Info("Shutting down...")
		if err := redisClient.Close(); err != nil {
			log.Errorf("Error closing Redis: %v", err)
		}
		os.Exit(0)
	}()

	// Start server
	addr := fmt.Sprintf(":%s", cfg.Port)
	log.Infof("Starting seat service on %s", addr)
	if err := e.Start(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
