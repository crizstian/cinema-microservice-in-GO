package config

import (
	"cinemas-microservices/booking-service/src/db"
)

// DI ...
type DI struct {
	Database       *db.MongoConnection
	ServerSettings map[string]interface{}
	APIClient      *Client
}

// InitDI ...
func InitDI(di chan *DI) {
	settings := GetServiceConfig()

	// start db connection
	conn := make(chan *db.MongoConnection)
	go db.MongoDB(settings["dbSettings"].(db.MongoReplicaSet), conn)

	// return di object
	di <- &DI{
		Database:       <-conn,
		ServerSettings: settings["serverSettings"].(map[string]interface{}),
		APIClient:      settings["apiClient"].(*Client),
	}
}
