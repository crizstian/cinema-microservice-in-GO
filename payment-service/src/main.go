package main

import (
	"cinemas-microservices/payment-service/src/api"
	"cinemas-microservices/payment-service/src/config"
	"cinemas-microservices/payment-service/src/server"
	"fmt"
	"os"
	"os/signal"

	"gopkg.in/mgo.v2"

	log "github.com/sirupsen/logrus"
)

var s *mgo.Session

func main() {
	log.Info("--- Payment Service ---")

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
			fmt.Println(q)
			server.Shutdown(s)
		case se := <-serverError:
			log.Infof(fmt.Sprintf("[ERROR] an error happend in the server, %v", se))
			server.Shutdown(s)
		}
	}
}

func startServer(di *config.DI, se chan error) {
	log.Info("Connected to Payment Service DB")
	log.Info("Connecting to payment repository...")

	s = di.Database.Session

	r, err := api.Connect(di.Database.DB, di.Stripe)

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
	s.Close()
	os.Exit(1)
}
