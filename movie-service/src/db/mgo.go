package db

import (
	"fmt"
	"os"

	log "github.com/sirupsen/logrus"
	mgo "gopkg.in/mgo.v2"
)

// MongoReplicaSet ...
type MongoReplicaSet struct {
	User       string
	Pass       string
	Servers    string
	Db         string
	ReplicaSet string
	AuthSource string
}

var conn MongoReplicaSet

func init() {
	conn = MongoReplicaSet{}
	u, uok := os.LookupEnv("DB_USER")
	p, pok := os.LookupEnv("DB_PASS")
	s, sok := os.LookupEnv("DB_SERVERS")
	n, nok := os.LookupEnv("DB_NAME")
	r, rok := os.LookupEnv("DB_REPLICA")

	if !uok {
		fmt.Println("No DB user specified")
	}
	if !pok {
		fmt.Println("No DB pass specified")
	}
	if !sok {
		fmt.Println("No DB url specified")
	}
	if !nok {
		fmt.Println("No DB name specified")
	}
	if !rok {
		fmt.Println("No DB replica specified")
	}

	conn.User = u
	conn.Pass = p
	conn.Servers = s
	conn.Db = n
	conn.ReplicaSet = r
	conn.AuthSource = "authSource=admin"
}

// MongoConnection ...
type MongoConnection struct {
	DB  *mgo.Database
	Err error
}

// MongoDB ...
func MongoDB(c chan *MongoConnection) {
	log.Info("connecting to db ....")

	session, err := mgo.Dial("mongodb://" + conn.User + ":" + conn.Pass + "@" + conn.Servers + "/" + conn.Db + "?replicaSet=" + conn.ReplicaSet + "&" + conn.AuthSource)
	c <- &MongoConnection{
		DB:  session.DB(conn.Db),
		Err: err,
	}
}
