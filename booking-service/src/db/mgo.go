package db

import (
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

// MongoConnection ...
type MongoConnection struct {
	DB      *mgo.Database
	Session *mgo.Session
}

// MongoDB ...
func MongoDB(options MongoReplicaSet, c chan *MongoConnection) {
	log.Info("connecting to db ....")

	url := "mongodb://" + options.User + ":" + options.Pass + "@" + options.Servers + "/" + options.Db + "?replicaSet=" + options.ReplicaSet + "&" + options.AuthSource

	session, err := mgo.Dial(url)

	if err != nil {
		log.Errorf("An error occured connecting to the DB, \n[ERROR] -> %s", err.Error())
		os.Exit(1)
	}

	c <- &MongoConnection{
		Session: session,
		DB:      session.DB(options.Db),
	}
}
