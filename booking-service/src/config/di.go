package config

import (
	"cinemas-microservices/booking-service/src/db"
	"cinemas-microservices/booking-service/src/tracing"

	"github.com/opentracing/opentracing-go"
)

// DI ...
type DI struct {
	Database       *db.MongoConnection
	ServerSettings map[string]interface{}
	APIClient      *Client
	Tracer         opentracing.Tracer
}

// InitDI ...
func InitDI(di chan *DI) {
	settings := LoadEnvSettings()

	// start db connection
	conn := make(chan *db.MongoConnection)
	go db.MongoDB(settings["dbSettings"].(db.MongoReplicaSet), conn)

	tracer, _ := tracing.Init("booking-service", settings["tracing"].(string))
	opentracing.SetGlobalTracer(tracer)

	// return di object
	di <- &DI{
		Database:       <-conn,
		ServerSettings: settings["serverSettings"].(map[string]interface{}),
		APIClient:      settings["apiClient"].(*Client),
		Tracer:         tracer,
	}
}
