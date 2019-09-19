package main

import (
	"cinemas-microservices/movie-service/src/api"
	"cinemas-microservices/movie-service/src/db"
	"cinemas-microservices/movie-service/src/server"
	"fmt"
	"os"
	"os/signal"
	"strconv"

	"gopkg.in/mgo.v2"

	log "github.com/sirupsen/logrus"
)

var s *mgo.Session

func main() {
	log.Info("--- Movies Service ---")
	log.Info("Connecting to movies repository...")

	conn := make(chan *db.MongoConnection)
	quit := make(chan os.Signal)
	serverError := make(chan error)
	signal.Notify(quit, os.Interrupt)

	go db.MongoDB(conn)

	for i := 0; i < 3; i++ {
		select {
		case c := <-conn:
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

func startServer(session *db.MongoConnection, se chan error) {
	if session.Err != nil {
		mainErrorHandler(fmt.Sprintf("An error occured connecting to the DB, [ERROR] -> %s", session.Err.Error()))
	} else {
		log.Info("Connected to DB")
		log.Info("Starting Movie Service now ...")

		s = session.Session
		r, err := api.Connect(session.DB)

		if err != nil {
			mainErrorHandler(fmt.Sprintf("Main error: [ERROR] -> %s", err))
		}

		port, pok := os.LookupEnv("SERVICE_PORT")

		if !pok {
			mainErrorHandler(fmt.Sprintf("Main error: No SERVICE_PORT found"))
		}

		p, err := strconv.Atoi(port)

		if err != nil {
			mainErrorHandler(fmt.Sprintf("Main error: SERVICE_PORT is not a number"))
		}

		server.Start(map[string]interface{}{
			"port": p,
			"repo": r,
		}, se)
	}
}

func mainErrorHandler(msg string) {
	log.Errorln(msg)
	s.Close()
	os.Exit(1)
}
