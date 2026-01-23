package config

import (
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"
)

// GetServiceConfig ...
func GetServiceConfig() map[string]interface{} {
	sp, spok := os.LookupEnv("SERVICE_PORT")

	if !spok {
		log.Errorln("[ERROR] NO SERVICE_PORT defined")
		os.Exit(1)
	}

	port, perr := strconv.Atoi(sp)

	if perr != nil {
		log.Errorln("[ERROR] SERVICE_PORT not valid")
		os.Exit(1)
	}

	e, eok := os.LookupEnv("EMAIL")
	ep, epok := os.LookupEnv("EMAIL_PASS")

	if !eok {
		log.Errorln("[ERROR] NO EMAIL for smtp configuration defined")
		os.Exit(1)
	}

	if !epok {
		log.Errorln("[ERROR] NO EMAIL_PASS for smtp configuration defined")
		os.Exit(1)
	}

	return map[string]interface{}{
		"serverSettings": map[string]interface{}{
			"port": port,
		},
		"smtpSettings": map[string]interface{}{
			"service": "gmail",
			"user":    e,
			"pass":    ep,
		},
	}
}
