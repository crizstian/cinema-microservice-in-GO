package config

import (
	"cinemas-microservices/booking-service/src/client"
	"cinemas-microservices/booking-service/src/db"
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"
)

// StripeSettings ...
type StripeSettings struct {
	Secret string
	Public string
}

// GetServiceConfig ...
func GetServiceConfig() map[string]interface{} {

	conn := db.MongoReplicaSet{}
	u, uok := os.LookupEnv("DB_USER")
	p, pok := os.LookupEnv("DB_PASS")
	s, sok := os.LookupEnv("DB_SERVERS")
	n, nok := os.LookupEnv("DB_NAME")
	r, rok := os.LookupEnv("DB_REPLICA")

	if !uok {
		log.Errorln("[ERROR] NO DB_USER defined")
		os.Exit(1)
	}
	if !pok {
		log.Errorln("[ERROR] NO DB_PASS defined")
		os.Exit(1)
	}
	if !sok {
		log.Errorln("[ERROR] NO DB_SERVERS defined")
		os.Exit(1)
	}
	if !nok {
		log.Errorln("[ERROR] NO DB_NAME defined")
		os.Exit(1)
	}
	if !rok {
		log.Errorln("[ERROR] NO DB_REPLICA defined")
		os.Exit(1)
	}

	conn.User = u
	conn.Pass = p
	conn.Servers = s
	conn.Db = n
	conn.ReplicaSet = r
	conn.AuthSource = "authSource=admin"

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

	c, err := InitClient()

	if err != nil {
		log.Errorln("[ERROR] API Client could not be generated")
		os.Exit(1)
	}

	pu, puok := os.LookupEnv("PAYMENT_URL")
	nu, nuok := os.LookupEnv("NOTIFICATION_URL")

	if !puok {
		log.Errorln("[ERROR] NO PAYMENT_URL defined")
		os.Exit(1)
	}

	if !nuok {
		log.Errorln("[ERROR] NO NOTIFICATION_URL defined")
		os.Exit(1)
	}

	c.API.SetBasePaymentURL(pu)
	c.API.SetNotificationURL(nu)

	log.Info("PAYMENT_URL IS: " + c.API.GetBasePaymentURL())
	log.Info("NOTIFICATION_URL URL IS: " + c.API.GetNotificationURL())

	return map[string]interface{}{
		"dbSettings": conn,
		"serverSettings": map[string]interface{}{
			"port": port,
		},
		"stripeSettings": st,
		"apiClient":      c,
	}
}

// Client ...
type Client struct {
	API             client.Services
	PaymentURL      string
	NotificationURL string
}

// InitClient ...
func InitClient() (*Client, error) {
	c, err := client.NewClient()

	if err != nil {
		return nil, err
	}

	f := &Client{
		API: client.Operations{
			Client: c,
		},
	}

	return f, nil
}
