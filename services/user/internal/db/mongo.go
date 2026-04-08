package db

import (
	"context"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

var once sync.Once

// MongoConnection holds the MongoDB connection details
type MongoConnection struct {
	Client   *mongo.Client
	Database *mongo.Database
	Err      error
}

// MongoDB establishes connection to MongoDB
func MongoDB(c chan *MongoConnection) {
	once.Do(func() {
		conn := connect()
		c <- conn
	})
}

func connect() *MongoConnection {
	user := os.Getenv("DB_USER")
	pass := os.Getenv("DB_PASS")
	servers := os.Getenv("DB_SERVERS")
	dbName := os.Getenv("DB_NAME")
	replica := os.Getenv("DB_REPLICA")

	// DB_SERVERS and DB_NAME are required; DB_USER/DB_PASS are optional (for no-auth mode)
	if servers == "" || dbName == "" {
		return &MongoConnection{
			Err: fmt.Errorf("missing required DB environment variables (DB_SERVERS, DB_NAME)"),
		}
	}

	hosts := strings.Split(servers, ",")
	var validHosts []string
	for _, h := range hosts {
		h = strings.TrimSpace(h)
		if h != "" {
			validHosts = append(validHosts, h)
		}
	}

	if len(validHosts) == 0 {
		return &MongoConnection{
			Err: fmt.Errorf("no valid MongoDB hosts found"),
		}
	}

	// Build connection URI (support no-auth mode when user/pass are empty)
	var uri string
	if user != "" && pass != "" {
		uri = fmt.Sprintf("mongodb://%s:%s@%s/%s",
			user, pass, strings.Join(validHosts, ","), dbName)
		log.Infof("Connecting to MongoDB: mongodb://%s:****@%s/%s", user, strings.Join(validHosts, ","), dbName)
	} else {
		uri = fmt.Sprintf("mongodb://%s/%s", strings.Join(validHosts, ","), dbName)
		log.Infof("Connecting to MongoDB (no-auth): mongodb://%s/%s", strings.Join(validHosts, ","), dbName)
	}

	if replica != "" {
		uri += fmt.Sprintf("?replicaSet=%s&readPreference=primaryPreferred", replica)
	}

	// Connection options
	clientOptions := options.Client().
		ApplyURI(uri).
		SetMinPoolSize(5).
		SetMaxPoolSize(100).
		SetConnectTimeout(30 * time.Second).
		SetSocketTimeout(60 * time.Second).
		SetRetryWrites(true).
		SetRetryReads(true)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return &MongoConnection{
			Err: fmt.Errorf("failed to connect to MongoDB: %w", err),
		}
	}

	// Ping to verify connection
	if err := pingWithRetry(ctx, client, 3); err != nil {
		return &MongoConnection{
			Err: fmt.Errorf("failed to ping MongoDB: %w", err),
		}
	}

	log.Info("Successfully connected to MongoDB")

	return &MongoConnection{
		Client:   client,
		Database: client.Database(dbName),
		Err:      nil,
	}
}

func pingWithRetry(ctx context.Context, client *mongo.Client, maxRetries int) error {
	var lastErr error

	readPrefs := []readpref.ReadPref{
		*readpref.Primary(),
		*readpref.PrimaryPreferred(),
		*readpref.Nearest(),
	}

	for _, rp := range readPrefs {
		for i := 0; i < maxRetries; i++ {
			if err := client.Ping(ctx, &rp); err != nil {
				lastErr = err
				log.Warnf("Ping attempt %d with %v failed: %v", i+1, rp.Mode(), err)
				time.Sleep(time.Duration(i+1) * time.Second)
				continue
			}
			return nil
		}
	}

	return lastErr
}
