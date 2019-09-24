package config

import (
	"cinemas-microservices/notification-service/src/smtp"
)

// DI ...
type DI struct {
	SMTP           *smtp.Config
	ServerSettings map[string]interface{}
}

// InitDI ...
func InitDI(di chan *DI) {
	settings := GetServiceConfig()
	s := settings["smtpSettings"].(map[string]interface{})

	// return di object
	di <- &DI{
		ServerSettings: settings["serverSettings"].(map[string]interface{}),
		SMTP: &smtp.Config{
			User:     s["user"].(string),
			Password: s["pass"].(string),
		},
	}
}
