package main

import (
	"cinemas-microservices/booking-service/src/api"
	"cinemas-microservices/booking-service/src/config"
	"cinemas-microservices/booking-service/src/server"
	"fmt"
	"os"
	"os/signal"

	"gopkg.in/mgo.v2"

	log "github.com/sirupsen/logrus"
)

var s *mgo.Session

func main() {
	log.Info("--- Booking Service ---")

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
	log.Info("Connected to Booking Service DB")
	log.Info("Connecting to booking repository...")

	s = di.Database.Session

	r, err := api.Connect(di.Database.DB, di.APIClient)

	if err != nil {
		mainErrorHandler(fmt.Sprintf("[ERROR] Could not connect to Repo -> %s", err))
	}

	log.Info("Connected to Booking Repository")
	log.Info("Starting Booking Service now ...")

	server.Start(map[string]interface{}{
		"ss":   di.ServerSettings,
		"repo": r,
	}, se)
}

func mainErrorHandler(msg string) {
	log.Errorln(msg)
	s.Close()
	os.Exit(1)
}
