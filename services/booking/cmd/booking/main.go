// Demo MCP
package main

// Version: 1.0.0 - Multi-service GitOps deployment test

import (
	"cinemas/services/booking/internal/api"
	"cinemas/services/booking/internal/config"
	"cinemas/services/booking/internal/server"
	"context"
	"os"
	"os/signal"
	"time"

	"go.mongodb.org/mongo-driver/mongo"

	log "github.com/sirupsen/logrus"
)

var client *mongo.Client

func main() {
	log.Info("--- Booking Service ---")

	di := make(chan *config.DI)
	quit := make(chan os.Signal, 1)
	serverError := make(chan error)
	signal.Notify(quit, os.Interrupt)

	go config.InitDI(di)

	for i := 0; i < 3; i++ {
		select {
		case c := <-di:
			startServer(c, serverError)
		case q := <-quit:
			log.Infof("Signal Interruption Received: %v", q)
			server.Shutdown(client)
		case se := <-serverError:
			log.Errorf("An error occured in the server, %v", se)
			server.Shutdown(client)
		}
	}
}

func startServer(di *config.DI, se chan error) {
	log.Info("Connected to Booking Service DB")

	client = di.Database.Client

	log.Info("Initializaing API Repository Configuration")
	r, err := api.Connect(di.Database.Database, di.APIClient)

	if err != nil {
		mainErrorHandler("An error occured initializing the API Repository: " + err.Error())
	}

	log.Info("API Repository configuration completed")
	server.Start(map[string]interface{}{
		"ss":     di.ServerSettings,
		"repo":   r,
		"tracer": di.Tracer,
	}, se)
}

func mainErrorHandler(msg string) {
	log.Errorln(msg)
	if client != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := client.Disconnect(ctx); err != nil {
			log.Errorf("Error disconnecting from MongoDB: %v", err)
		}
	}
	os.Exit(1)
}
