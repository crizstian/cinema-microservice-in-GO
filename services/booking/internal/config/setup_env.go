package config

import (
	"cinemas/services/booking/internal/client"
	"cinemas/services/booking/internal/db"
	"errors"
	"fmt"
	"os"
	"strconv"

	log "github.com/sirupsen/logrus"
)

// LoadEnvSettings ...
func LoadEnvSettings() map[string]interface{} {

	conn, err := initDBEnvironment()
	if err != nil {
		log.Errorln(err.Error())
		os.Exit(1)
	}

	p, err := initServerEnvironment()
	if err != nil {
		log.Errorln(err.Error())
		os.Exit(1)
	}

	c, err := InitClient()
	if err != nil {
		log.Errorln(err.Error())
		os.Exit(1)
	}

	err2 := initUpstreamsURIEnvironment(c)
	if err2 != nil {
		log.Errorln(err2.Error())
		os.Exit(1)
	}

	tr, err := initTracingEnvironment()
	if err != nil {
		log.Errorln(err.Error())
		os.Exit(1)
	}

	return map[string]interface{}{
		"dbSettings": *conn,
		"serverSettings": map[string]interface{}{
			"port": p,
		},
		"apiClient": c,
		"tracing":   tr,
	}
}

func initTracingEnvironment() (string, error) {
	tr, trok := os.LookupEnv("TRACER_URL")

	if !trok {
		log.Warn("NO TRACER_URL defined, falling back to localhost")
		return "localhost:6831", nil
	}

	return tr, nil
}

// initUpstreamsURIEnvironment ...
func initUpstreamsURIEnvironment(c *Client) error {
	pu, puok := os.LookupEnv("PAYMENT_URL")
	nu, nuok := os.LookupEnv("NOTIFICATION_URL")
	su, suok := os.LookupEnv("SEAT_SERVICE_URL")
	stu, stuok := os.LookupEnv("SHOWTIME_SERVICE_URL")

	if !puok {
		return errors.New("[ERROR] NO PAYMENT_URL defined")
	}

	if !nuok {
		return errors.New("[ERROR] NO NOTIFICATION_URL defined")
	}

	// Seat and showtime URLs are optional but recommended
	if !suok {
		su = "http://localhost:3004"
		log.Warn("SEAT_SERVICE_URL not defined, using default: " + su)
	}

	if !stuok {
		stu = "http://localhost:3003"
		log.Warn("SHOWTIME_SERVICE_URL not defined, using default: " + stu)
	}

	c.API.SetBasePaymentURL(pu)
	c.API.SetNotificationURL(nu)
	c.API.SetBaseSeatURL(su)
	c.API.SetBaseShowtimeURL(stu)

	log.WithFields(log.Fields{
		"payment_url":      c.API.GetBasePaymentURL(),
		"notification_url": c.API.GetNotificationURL(),
		"seat_url":         c.API.GetBaseSeatURL(),
		"showtime_url":     c.API.GetBaseShowtimeURL(),
	}).Info("External services configured")

	return nil
}

// initServerEnvironment ...
func initServerEnvironment() (int, error) {
	sp, spok := os.LookupEnv("SERVICE_PORT")

	if !spok {
		return -1, errors.New("[ERROR] NO SERVICE_PORT defined")
	}

	port, perr := strconv.Atoi(sp)

	if perr != nil {
		return -1, errors.New("[ERROR] SERVICE_PORT not valid")
	}

	return port, nil
}

// initDBEnvironment ...
func initDBEnvironment() (*db.Config, error) {
	// Use modern configuration loader
	cfg, err := db.LoadConfigFromEnv()
	if err != nil {
		return nil, fmt.Errorf("[ERROR] Failed to load MongoDB configuration: %w", err)
	}
	return cfg, nil
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
		return nil, errors.New(fmt.Errorf("[ERROR] API Client could not be generated \n %v", err).Error())
	}

	f := &Client{
		API: client.Operations{
			Client: c,
		},
	}

	return f, nil
}
