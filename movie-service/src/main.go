package main

import (
	"cinemas-microservices/movie-service/src/api"
	"cinemas-microservices/movie-service/src/config"
	"cinemas-microservices/movie-service/src/server"
	"os"
	"os/signal"

	"gopkg.in/mgo.v2"

	log "github.com/sirupsen/logrus"
)

var s *mgo.Session

func main() {
	log.Info("--- Movies Service ---")
	log.Info("Connecting to movies repository...")

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
			log.Infof("Signal Interruption Received: %v", q)
			server.Shutdown(s)
		case se := <-serverError:
			log.Errorf("An error occured in the server, %v", se)
			server.Shutdown(s)
		}
	}
}

func startServer(di *config.DI, se chan error) {
	log.Info("Connected to Booking Service DB")

	s = di.Database.Session

	log.Info("Initializaing API Repository Configuration")
	r, err := api.Connect(di.Database.DB)

	if err != nil {
		mainErrorHandler("An error occured initializing the API Repository: " + err.Error())
	}

	log.Info("API Repository configuration completed")
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
