package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"cinemas/services/user/internal/api"
	"cinemas/services/user/internal/db"
	"cinemas/services/user/internal/server"

	log "github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/mongo"
)

// App holds application dependencies and state
type App struct {
	client    *mongo.Client
	mongoConn *db.MongoConnection
	config    *AppConfig
	exitFunc  func(int)
}

// AppConfig holds application configuration
type AppConfig struct {
	ServicePort       int
	ConnectionTimeout time.Duration
	ShutdownTimeout   time.Duration
}

// DBConnector interface for database connection
type DBConnector interface {
	Connect(c chan *db.MongoConnection)
}

// DefaultDBConnector uses the real db.MongoDB function
type DefaultDBConnector struct{}

func (d *DefaultDBConnector) Connect(c chan *db.MongoConnection) {
	db.MongoDB(c)
}

// NewApp creates a new application instance
func NewApp() *App {
	return &App{
		exitFunc: os.Exit,
		config: &AppConfig{
			ConnectionTimeout: 30 * time.Second,
			ShutdownTimeout:   10 * time.Second,
		},
	}
}

// LoadConfig loads configuration from environment variables
func (app *App) LoadConfig() error {
	port, ok := os.LookupEnv("SERVICE_PORT")
	if !ok {
		return fmt.Errorf("SERVICE_PORT environment variable not found")
	}

	p, err := strconv.Atoi(port)
	if err != nil {
		return fmt.Errorf("SERVICE_PORT is not a valid number: %w", err)
	}

	app.config.ServicePort = p
	return nil
}

// Initialize connects to MongoDB
func (app *App) Initialize(connector DBConnector) error {
	connChan := make(chan *db.MongoConnection, 1)

	go connector.Connect(connChan)

	select {
	case mongoConn := <-connChan:
		if mongoConn == nil {
			return fmt.Errorf("MongoDB connection returned nil")
		}
		if mongoConn.Err != nil {
			return fmt.Errorf("an error occurred connecting to the DB: %w", mongoConn.Err)
		}
		app.mongoConn = mongoConn
		app.client = mongoConn.Client
		return nil

	case <-time.After(app.config.ConnectionTimeout):
		return fmt.Errorf("MongoDB connection timeout (%v)", app.config.ConnectionTimeout)
	}
}

// StartServer initializes and starts the HTTP server
func (app *App) StartServer(errorChan chan error) error {
	if app.mongoConn == nil {
		return fmt.Errorf("MongoDB connection not initialized")
	}

	log.Info("Connected to DB")
	log.Info("Starting User Service now...")

	repo, err := api.Connect(app.mongoConn.Database)
	if err != nil {
		return fmt.Errorf("failed to connect to API: %w", err)
	}

	go func() {
		if err := server.Start(map[string]interface{}{
			"port": app.config.ServicePort,
			"repo": repo,
		}); err != nil {
			errorChan <- fmt.Errorf("server startup error: %w", err)
		}
	}()

	return nil
}

// Shutdown gracefully shuts down the application
func (app *App) Shutdown() error {
	if app.client == nil {
		log.Info("Application stopped (no client to disconnect)")
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), app.config.ShutdownTimeout)
	defer cancel()

	if err := app.client.Disconnect(ctx); err != nil {
		return fmt.Errorf("error disconnecting from MongoDB: %w", err)
	}

	log.Info("Application stopped")
	return nil
}

// Run starts the application and blocks until shutdown
func (app *App) Run(connector DBConnector) error {
	log.Info("--- User Service ---")
	log.Info("Connecting to users repository...")

	if err := app.LoadConfig(); err != nil {
		return err
	}

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	if err := app.Initialize(connector); err != nil {
		return err
	}

	errorChan := make(chan error, 1)
	if err := app.StartServer(errorChan); err != nil {
		return err
	}

	select {
	case err := <-errorChan:
		app.Shutdown()
		return fmt.Errorf("server error: %w", err)

	case <-quit:
		log.Info("\nShutting down gracefully...")
		return app.Shutdown()
	}
}

func main() {
	app := NewApp()

	if err := app.Run(&DefaultDBConnector{}); err != nil {
		log.Errorln(err)
		os.Exit(1)
	}
}
