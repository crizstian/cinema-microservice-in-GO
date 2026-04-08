package main

import (
	"cinemas/services/payment/internal/api"
	"cinemas/services/payment/internal/config"
	"cinemas/services/payment/internal/server"
	"context"
	"fmt"
	"os"
	"os/signal"
	"time"

	"go.mongodb.org/mongo-driver/mongo"

	log "github.com/sirupsen/logrus"
)

var client *mongo.Client

func main() {
	log.Info("--- Payment Service ---")

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
			fmt.Println(q)
			server.Shutdown(client)
		case se := <-serverError:
			log.Infof(fmt.Sprintf("[ERROR] an error happend in the server, %v", se))
			server.Shutdown(client)
		}
	}
}

func startServer(di *config.DI, se chan error) {
	log.Info("Connected to Payment Service DB")
	log.Info("Connecting to payment repository...")

	client = di.Database.Client

	r, err := api.Connect(di.Database.Database, di.Stripe, di.MockMode)

	if err != nil {
		mainErrorHandler(fmt.Sprintf("[ERROR] Could not connect to Repo -> %s", err))
	}

	log.Info("Connected to Payment Repository")
	log.Info("Starting Payment Service now ...")

	server.Start(map[string]interface{}{
		"port": di.ServerSettings["port"].(int),
		"repo": r,
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
