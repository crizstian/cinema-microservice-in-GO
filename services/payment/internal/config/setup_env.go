package config

import (
	"cinemas/services/payment/internal/db"
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"
)

// StripeSettings ...
type StripeSettings struct {
	Secret   string
	Public   string
	MockMode bool
}

// GetServiceConfig ...
func GetServiceConfig() map[string]interface{} {

	// Load MongoDB configuration using modern API
	conn, err := db.LoadConfigFromEnv()
	if err != nil {
		log.Fatalf("[ERROR] Failed to load MongoDB configuration: %v", err)
	}

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

	ss, ssok := os.LookupEnv("STRIPE_SECRET")
	stp, stpok := os.LookupEnv("STRIPE_PUBLIC")
	mockMode := os.Getenv("STRIPE_MOCK") == "true"
	st := StripeSettings{}

	if !ssok {
		log.Errorln("[ERROR] NO STRIPE_SECRET defined")
		os.Exit(1)
	}

	if !stpok {
		log.Errorln("[ERROR] NO STRIPE_PUBLIC defined")
		os.Exit(1)
	}

	st.Secret = ss
	st.Public = stp
	st.MockMode = mockMode

	if mockMode {
		log.Info("Stripe mock mode enabled - payments will return mock responses")
	}

	return map[string]interface{}{
		"dbSettings": conn,
		"serverSettings": map[string]interface{}{
			"port": port,
		},
		"stripeSettings": st,
	}
}
