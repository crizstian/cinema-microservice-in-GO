package main

import (
	"cinemas/services/movie/internal/api"
	"cinemas/services/movie/internal/db"
	"cinemas/services/movie/internal/server"
	"context"
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	log "github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/mongo"
)

var client *mongo.Client

func main() {
	log.Info("--- Movies Service ---")
	log.Info("Connecting to movies repository...")

	// Channels con buffer para evitar deadlocks
	connChan := make(chan *db.MongoConnection, 1)
	errorChan := make(chan error, 1)
	quit := make(chan os.Signal, 1)

	// Notificar en caso de Ctrl+C o SIGTERM
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)

	// Goroutine 1: Conectar a MongoDB
	go db.MongoDB(connChan)

	var mongoConn *db.MongoConnection

	// Esperar conexión a MongoDB o error
	select {
	case mongoConn = <-connChan:
		if mongoConn == nil {
			mainErrorHandler("MongoDB connection returned nil")
		}
		if mongoConn.Err != nil {
			mainErrorHandler(fmt.Sprintf("An error occurred connecting to the DB: %s", mongoConn.Err.Error()))
		}
		startServer(mongoConn, errorChan)

	case err := <-errorChan:
		mainErrorHandler(fmt.Sprintf("Error during initialization: %s", err.Error()))

	case <-time.After(30 * time.Second):
		mainErrorHandler("MongoDB connection timeout (30 seconds)")

	case <-quit:
		log.Info("Interrupted before MongoDB connection established")
		os.Exit(0)
	}

	// Mantener la aplicación viva esperando errores o signal de cierre
	select {
	case err := <-errorChan:
		mainErrorHandler(fmt.Sprintf("Server error: %s", err.Error()))

	case <-quit:
		log.Info("\n✓ Shutting down gracefully...")
		gracefulShutdown()
	}
}

func startServer(mongoConn *db.MongoConnection, errorChan chan error) {
	log.Info("Connected to DB")
	log.Info("Starting Movie Service now...")

	// Asignar cliente global
	client = mongoConn.Client

	// Conectar a la API
	r, err := api.Connect(mongoConn.Database)
	if err != nil {
		mainErrorHandler(fmt.Sprintf("Failed to connect to API: %s", err.Error()))
	}

	// Obtener puerto del servicio
	port, pok := os.LookupEnv("SERVICE_PORT")
	if !pok {
		mainErrorHandler("SERVICE_PORT environment variable not found")
	}

	// Convertir puerto a número
	p, err := strconv.Atoi(port)
	if err != nil {
		mainErrorHandler("SERVICE_PORT is not a valid number")
	}

	// Iniciar servidor en goroutine separada
	go func() {
		if err := server.Start(map[string]interface{}{
			"port": p,
			"repo": r,
		}); err != nil {
			errorChan <- fmt.Errorf("server startup error: %w", err)
		}
	}()
}

func gracefulShutdown() {
	if client == nil {
		log.Info("✓ Application stopped")
		os.Exit(0)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := client.Disconnect(ctx); err != nil {
		log.Errorf("Error disconnecting from MongoDB: %v", err)
	}

	log.Info("✓ Application stopped")
	os.Exit(0)
}

func mainErrorHandler(msg string) {
	log.Errorln(msg)
	gracefulShutdown()
}
