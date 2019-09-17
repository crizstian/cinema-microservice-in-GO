package main

import (
	"cinemas-microservices/movie-service/src/api"
	"cinemas-microservices/movie-service/src/db"
	"cinemas-microservices/movie-service/src/server"
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"
)

func main() {
	log.Info("--- Movies Service ---")
	log.Info("Connecting to movies repository...")

	conn := make(chan *db.MongoConnection)

	go db.MongoDB(conn)

	select {
	case session := <-conn:
		if session.Err != nil {
			log.Errorf("An error occured connecting to the DB, [ERROR] -> %s", session.Err.Error())
		} else {
			log.Info("Connected to DB")
			log.Info("Starting Movie Service now ...")

			r, err := api.Connect(session.DB)

			if err != nil {
				log.Errorf("Main error: [ERROR] -> %s", err)
				os.Exit(1)
			}

			port, pok := os.LookupEnv("SERVICE_PORT")

			if !pok {
				log.Errorf("Main error: No SERVICE_PORT found")
				os.Exit(1)
			}

			p, err := strconv.Atoi(port)

			if err != nil {
				log.Errorf("Main error: No SERVICE_PORT found")
				os.Exit(1)
			}

			server.Start(map[string]interface{}{
				"port": p,
				"repo": r,
			})
		}
	}
}
