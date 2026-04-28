package server

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cinemas/services/showtime/internal/metrics"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	"github.com/sirupsen/logrus"
)

// Server represents the HTTP server
type Server struct {
	Echo   *echo.Echo
	Logger *logrus.Logger
	Port   string
}

// Config holds server configuration
type Config struct {
	Port string
}

// New creates a new server instance
func New(cfg Config) *Server {
	e := echo.New()
	e.HideBanner = true
	e.HidePort = true

	logger := logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{})

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Prometheus metrics middleware and endpoint
	e.Use(metrics.Middleware())
	e.GET("/metrics", metrics.Handler())

	port := cfg.Port
	if port == "" {
		port = "3003"
	}

	return &Server{
		Echo:   e,
		Logger: logger,
		Port:   port,
	}
}

// Start starts the server
func (s *Server) Start() error {
	s.Logger.Infof("Starting showtime service on port %s", s.Port)

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-quit
		s.Logger.Info("Shutting down server...")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := s.Echo.Shutdown(ctx); err != nil {
			s.Logger.Fatal(err)
		}
	}()

	return s.Echo.Start(":" + s.Port)
}

// Group returns a route group
func (s *Server) Group(prefix string) *echo.Group {
	return s.Echo.Group(prefix)
}
