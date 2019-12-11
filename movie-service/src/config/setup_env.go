package config

import (
	"cinemas-microservices/movie-service/src/db"
	"errors"
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

	return map[string]interface{}{
		"dbSettings": *conn,
		"serverSettings": map[string]interface{}{
			"port": p,
		},
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
func initDBEnvironment() (*db.MongoReplicaSet, error) {

	u, uok := os.LookupEnv("DB_USER")
	p, pok := os.LookupEnv("DB_PASS")
	s, sok := os.LookupEnv("DB_SERVERS")
	n, nok := os.LookupEnv("DB_NAME")
	r, rok := os.LookupEnv("DB_REPLICA")

	if !uok {
		return nil, errors.New("[ERROR] NO DB_USER defined")
	}
	if !pok {
		return nil, errors.New("[ERROR] NO DB_PASS defined")
	}
	if !sok {
		return nil, errors.New("[ERROR] NO DB_SERVERS defined")
	}
	if !nok {
		return nil, errors.New("[ERROR] NO DB_NAME defined")
	}
	if !rok {
		return nil, errors.New("[ERROR] NO DB_REPLICA defined")
	}

	return &db.MongoReplicaSet{
		User:       u,
		Pass:       p,
		Servers:    s,
		Db:         n,
		ReplicaSet: r,
		AuthSource: "authSource=admin",
	}, nil
}
