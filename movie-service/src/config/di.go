package config

import (
	"cinemas-microservices/movie-service/src/db"
)

// DI ...
type DI struct {
	Database       *db.MongoConnection
	ServerSettings map[string]interface{}
}

// InitDI ...
func InitDI(di chan *DI) {
	settings := LoadEnvSettings()

	// start db connection
	conn := make(chan *db.MongoConnection)
	go db.MongoDB(settings["dbSettings"].(db.MongoReplicaSet), conn)

	// return di object
	di <- &DI{
		Database:       <-conn,
		ServerSettings: settings["serverSettings"].(map[string]interface{}),
	}
}
