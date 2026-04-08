package db

import (
	"context"
	"fmt"
	"net"
	"os"
	"strings"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
	"go.mongodb.org/mongo-driver/event"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

var (
	// Global connection pool
	globalClient *mongo.Client
	globalMutex  sync.RWMutex
	once         sync.Once
)

// Config holds MongoDB connection configuration
type Config struct {
	User                string
	Pass                string
	Servers             []string
	Database            string
	ReplicaSet          string
	AuthSource          string
	DirectConnection    bool
	MaxPoolSize         uint64
	MinPoolSize         uint64
	ConnectTimeout      time.Duration
	ServerSelectTimeout time.Duration
	SocketTimeout       time.Duration
	MaxConnIdleTime     time.Duration
	HeartbeatInterval   time.Duration
	RetryWrites         bool
	RetryReads          bool
}

// MongoConnection encapsulates MongoDB client and database
type MongoConnection struct {
	Client   *mongo.Client
	Database *mongo.Database
	Err      error
}

// LoadConfigFromEnv loads MongoDB configuration from environment variables
func LoadConfigFromEnv() (*Config, error) {
	user := os.Getenv("DB_USER")
	pass := os.Getenv("DB_PASS")
	servers := os.Getenv("DB_SERVERS")
	dbName := os.Getenv("DB_NAME")
	replicaSet := os.Getenv("DB_REPLICA")

	// DB_SERVERS, DB_NAME, DB_REPLICA are required; DB_USER/DB_PASS are optional (for no-auth mode)
	if servers == "" || dbName == "" || replicaSet == "" {
		return nil, fmt.Errorf("missing required environment variables: DB_USER, DB_PASS, DB_SERVERS, DB_NAME, DB_REPLICA")
	}

	serverList := strings.Split(servers, ",")
	for i := range serverList {
		serverList[i] = strings.TrimSpace(serverList[i])
	}

	// Validate servers are reachable (basic DNS check)
	for _, server := range serverList {
		host := server
		if strings.Contains(server, ":") {
			host = strings.Split(server, ":")[0]
		}
		if err := validateHost(host); err != nil {
			log.Warnf("Server %s might not be reachable: %v", server, err)
		}
	}

	return &Config{
		User:                user,
		Pass:                pass,
		Servers:             serverList,
		Database:            dbName,
		ReplicaSet:          replicaSet,
		AuthSource:          "admin",
		DirectConnection:    false,
		MaxPoolSize:         100,
		MinPoolSize:         5,
		ConnectTimeout:      30 * time.Second,
		ServerSelectTimeout: 30 * time.Second,
		SocketTimeout:       60 * time.Second,
		MaxConnIdleTime:     5 * time.Minute,
		HeartbeatInterval:   10 * time.Second,
		RetryWrites:         true,
		RetryReads:          true,
	}, nil
}

// validateHost checks if a host is resolvable
func validateHost(host string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resolver := &net.Resolver{}
	_, err := resolver.LookupHost(ctx, host)
	return err
}

// Connect establishes a connection to MongoDB with proper error handling
func Connect(ctx context.Context, cfg *Config) (*MongoConnection, error) {
	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), cfg.ConnectTimeout)
		defer cancel()
	}

	// Build connection URI
	serversStr := strings.Join(cfg.Servers, ",")

	// Build URI with proper query parameters (support no-auth mode when user/pass are empty)
	var uri string
	if cfg.User != "" && cfg.Pass != "" {
		uri = fmt.Sprintf(
			"mongodb://%s:%s@%s/%s?replicaSet=%s&authSource=%s&w=majority&readPreference=primaryPreferred&maxPoolSize=%d&minPoolSize=%d",
			cfg.User,
			cfg.Pass,
			serversStr,
			cfg.Database,
			cfg.ReplicaSet,
			cfg.AuthSource,
			cfg.MaxPoolSize,
			cfg.MinPoolSize,
		)
		log.Infof("Connecting to MongoDB: mongodb://%s:****@%s/%s?replicaSet=%s",
			cfg.User, serversStr, cfg.Database, cfg.ReplicaSet)
	} else {
		uri = fmt.Sprintf(
			"mongodb://%s/%s?replicaSet=%s&w=majority&readPreference=primaryPreferred&maxPoolSize=%d&minPoolSize=%d",
			serversStr,
			cfg.Database,
			cfg.ReplicaSet,
			cfg.MaxPoolSize,
			cfg.MinPoolSize,
		)
		log.Infof("Connecting to MongoDB (no-auth): mongodb://%s/%s?replicaSet=%s",
			serversStr, cfg.Database, cfg.ReplicaSet)
	}

	// Create client options with defensive settings
	clientOpts := options.Client().
		ApplyURI(uri).
		SetDirect(cfg.DirectConnection).
		SetServerSelectionTimeout(cfg.ServerSelectTimeout).
		SetConnectTimeout(cfg.ConnectTimeout).
		SetSocketTimeout(cfg.SocketTimeout).
		SetMaxConnIdleTime(cfg.MaxConnIdleTime).
		SetHeartbeatInterval(cfg.HeartbeatInterval).
		SetRetryWrites(cfg.RetryWrites).
		SetRetryReads(cfg.RetryReads).
		SetCompressors([]string{"snappy", "zlib"}). // Remove zstd if causes issues
		SetServerMonitor(&event.ServerMonitor{
			ServerHeartbeatStarted: func(e *event.ServerHeartbeatStartedEvent) {
				log.Debugf("Heartbeat started for %s", e.ConnectionID)
			},
			ServerHeartbeatSucceeded: func(e *event.ServerHeartbeatSucceededEvent) {
				log.Debugf("Heartbeat succeeded for %s (duration: %v)", e.ConnectionID, e.Duration)
			},
			ServerHeartbeatFailed: func(e *event.ServerHeartbeatFailedEvent) {
				log.Warnf("Heartbeat failed for %s: %v", e.ConnectionID, e.Failure)
			},
		})

	// Add connection pool monitoring
	poolMonitor := &event.PoolMonitor{
		Event: func(evt *event.PoolEvent) {
			switch evt.Type {
			case event.ConnectionCreated:
				log.Debugf("Connection created in pool")
			case event.ConnectionClosed:
				log.Debugf("Connection closed in pool")
			case event.GetFailed:
				log.Warnf("Failed to get connection from pool: %v", evt.Reason)
			}
		},
	}
	clientOpts.SetPoolMonitor(poolMonitor)

	log.Info("Establishing MongoDB connection...")

	// Connect with proper error handling
	client, err := mongo.Connect(ctx, clientOpts)
	if err != nil {
		return &MongoConnection{
			Client:   nil,
			Database: nil,
			Err:      fmt.Errorf("failed to create MongoDB client: %w", err),
		}, err
	}

	// Ping with multiple attempts and fallback strategy
	log.Info("Pinging MongoDB to verify connection...")

	var pingErr error
	for attempt := 1; attempt <= 3; attempt++ {
		pingCtx, pingCancel := context.WithTimeout(context.Background(), 10*time.Second)

		// Try primary first
		pingErr = client.Ping(pingCtx, readpref.Primary())
		if pingErr == nil {
			pingCancel()
			log.Infof("Successfully connected to MongoDB primary (attempt %d)", attempt)
			break
		}

		log.Warnf("Failed to ping primary (attempt %d): %v", attempt, pingErr)

		// Try primaryPreferred as fallback
		pingErr = client.Ping(pingCtx, readpref.PrimaryPreferred())
		if pingErr == nil {
			pingCancel()
			log.Infof("Successfully connected to MongoDB (primaryPreferred, attempt %d)", attempt)
			break
		}

		log.Warnf("Failed to ping primaryPreferred (attempt %d): %v", attempt, pingErr)

		// Try nearest as last resort
		pingErr = client.Ping(pingCtx, readpref.Nearest())
		pingCancel()

		if pingErr == nil {
			log.Infof("Successfully connected to MongoDB nearest (attempt %d)", attempt)
			break
		}

		log.Warnf("Failed to ping nearest (attempt %d): %v", attempt, pingErr)

		if attempt < 3 {
			log.Infof("Retrying connection in 2 seconds...")
			time.Sleep(2 * time.Second)
		}
	}

	if pingErr != nil {
		log.Errorf("Failed to ping MongoDB after 3 attempts: %v", pingErr)

		// Proper cleanup on failure
		disconnectCtx, disconnectCancel := context.WithTimeout(context.Background(), 5*time.Second)
		if disconnectErr := client.Disconnect(disconnectCtx); disconnectErr != nil {
			log.Errorf("Error disconnecting failed client: %v", disconnectErr)
		}
		disconnectCancel()

		return &MongoConnection{
			Client:   nil,
			Database: nil,
			Err:      fmt.Errorf("failed to ping MongoDB: %w", pingErr),
		}, pingErr
	}

	log.Info("Successfully connected to MongoDB!")

	// Get database handle
	database := client.Database(cfg.Database)

	// Store globally for reuse
	globalMutex.Lock()
	globalClient = client
	globalMutex.Unlock()

	return &MongoConnection{
		Client:   client,
		Database: database,
		Err:      nil,
	}, nil
}

// ConnectOnce establishes a single global connection (singleton pattern)
func ConnectOnce(ctx context.Context, cfg *Config) (*MongoConnection, error) {
	var conn *MongoConnection
	var err error

	once.Do(func() {
		conn, err = Connect(ctx, cfg)
	})

	// If once already ran, use global client
	if conn == nil && globalClient != nil {
		globalMutex.RLock()
		defer globalMutex.RUnlock()

		conn = &MongoConnection{
			Client:   globalClient,
			Database: globalClient.Database(cfg.Database),
			Err:      nil,
		}
	}

	return conn, err
}

// MongoDB establishes a connection and sends result via channel (legacy compatibility)
func MongoDB(c chan *MongoConnection) {
	log.Info("Initializing MongoDB connection...")

	cfg, err := LoadConfigFromEnv()
	if err != nil {
		log.Errorf("Failed to load configuration: %v", err)
		c <- &MongoConnection{
			Client:   nil,
			Database: nil,
			Err:      err,
		}
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn, err := Connect(ctx, cfg)
	c <- conn
}

// Disconnect closes the MongoDB connection gracefully
func (mc *MongoConnection) Disconnect() error {
	if mc.Client == nil {
		return nil
	}

	log.Info("Disconnecting from MongoDB...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := mc.Client.Disconnect(ctx); err != nil {
		log.Errorf("Error during MongoDB disconnection: %v", err)
		return err
	}

	log.Info("Successfully disconnected from MongoDB")
	return nil
}

// HealthCheck performs a health check on the connection
func (mc *MongoConnection) HealthCheck(ctx context.Context) error {
	if mc.Client == nil {
		return fmt.Errorf("client is nil")
	}

	if ctx == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
	}

	return mc.Client.Ping(ctx, readpref.Primary())
}
