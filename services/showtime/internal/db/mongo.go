package db

import (
	"context"
	"time"

	log "github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

// ConnectMongo establishes a connection to MongoDB
func ConnectMongo(uri, dbName string) (*mongo.Database, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	clientOptions := options.Client().
		ApplyURI(uri).
		SetMinPoolSize(5).
		SetMaxPoolSize(50).
		SetConnectTimeout(30 * time.Second).
		SetRetryWrites(true)

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return nil, err
	}

	// Ping to verify connection
	if err := client.Ping(ctx, readpref.Primary()); err != nil {
		// Try secondary
		if err := client.Ping(ctx, readpref.Nearest()); err != nil {
			log.Warnf("Could not ping MongoDB: %v (continuing anyway)", err)
		}
	}

	log.Info("Connected to MongoDB")
	return client.Database(dbName), nil
}
