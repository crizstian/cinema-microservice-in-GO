package main

import (
	"cinemas-microservices/notification-service/src/api"
	"cinemas-microservices/notification-service/src/config"
	"cinemas-microservices/notification-service/src/server"
	"fmt"
	"os"
	"os/signal"

	log "github.com/sirupsen/logrus"
)

func main() {
	log.Info("--- Notification Service ---")

	di := make(chan *config.DI)
	quit := make(chan os.Signal)
	serverError := make(chan error)
	signal.Notify(quit, os.Interrupt)

	go config.InitDI(di)

	for i := 0; i < 3; i++ {
		select {
		case c := <-di:
			startServer(c, serverError)
		case q := <-quit:
			log.Warnf("Quiting service due to OS Signal = %s", q.String())
			server.Shutdown()
		case se := <-serverError:
			log.Errorf(fmt.Sprintf("An error happend in the server, %v", se))
			server.Shutdown()
		}
	}
}

func startServer(di *config.DI, se chan error) {
	log.Info("Connecting to notification repository...")

	r, err := api.Connect(di.SMTP)

	if err != nil {
		mainErrorHandler(fmt.Sprintf("API initialization had an error: -> %s", err))
	}

	log.Info("Connected to Notification Repository")
	log.Info("Starting Notification Service now ...")

	server.Start(map[string]interface{}{
		"port": di.ServerSettings["port"].(int),
		"repo": r,
	}, se)
}

func mainErrorHandler(msg string) {
	log.Errorln(msg)
	os.Exit(1)
}
