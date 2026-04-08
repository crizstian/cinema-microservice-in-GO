package config

import (
	"cinemas/services/payment/internal/db"
	"log"

	"github.com/stripe/stripe-go/client"
)

// DI ...
type DI struct {
	Database       *db.MongoConnection
	ServerSettings map[string]interface{}
	Stripe         *client.API
	MockMode       bool
}

// InitDI ...
func InitDI(di chan *DI) {
	settings := GetServiceConfig()

	// start db connection: ahora MongoDB solo recibe el canal
	connChan := make(chan *db.MongoConnection)
	go db.MongoDB(connChan)

	// Esperar la conexión
	mongoConn := <-connChan
	if mongoConn.Err != nil {
		// Aquí puedes decidir si haces log.Fatal o devuelves nil y que
		// el caller maneje el error. Ejemplo con panic/log:
		log.Fatalf("Error connecting to Mongo in payment: %v", mongoConn.Err)
	}

	stripeSettings := settings["stripeSettings"].(StripeSettings)
	sc := &client.API{}
	sc.Init(stripeSettings.Secret, nil)

	// return di object
	di <- &DI{
		Database:       mongoConn,
		ServerSettings: settings["serverSettings"].(map[string]interface{}),
		Stripe:         sc,
		MockMode:       stripeSettings.MockMode,
	}
}
