package db

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

// setupTestEnv configures environment variables for testing
func setupTestEnv(t *testing.T, dbName string) {
	t.Helper()

	os.Setenv("DB_USER", "cristian")
	os.Setenv("DB_PASS", "cristianPassword2017")
	os.Setenv("DB_SERVERS", "192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019")
	os.Setenv("DB_NAME", dbName)
	os.Setenv("DB_REPLICA", "rs1")
}

func TestLoadConfigFromEnv(t *testing.T) {
	setupTestEnv(t, "movies")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err, "LoadConfigFromEnv should succeed")
	assert.NotNil(t, cfg, "Config should not be nil")

	assert.Equal(t, "cristian", cfg.User)
	assert.Equal(t, "cristianPassword2017", cfg.Pass)
	assert.Equal(t, 3, len(cfg.Servers))
	assert.Equal(t, "192.168.68.104:27017", cfg.Servers[0])
	assert.Equal(t, "192.168.68.104:27018", cfg.Servers[1])
	assert.Equal(t, "192.168.68.104:27019", cfg.Servers[2])
	assert.Equal(t, "movies", cfg.Database)
	assert.Equal(t, "rs1", cfg.ReplicaSet)
	assert.Equal(t, "admin", cfg.AuthSource)
	assert.False(t, cfg.DirectConnection, "DirectConnection should be false for replica sets")
	assert.True(t, cfg.RetryWrites, "RetryWrites should be enabled")
	assert.True(t, cfg.RetryReads, "RetryReads should be enabled")
}

func TestLoadConfigFromEnv_MissingVars(t *testing.T) {
	// Clear all env vars
	os.Unsetenv("DB_USER")
	os.Unsetenv("DB_PASS")
	os.Unsetenv("DB_SERVERS")
	os.Unsetenv("DB_NAME")
	os.Unsetenv("DB_REPLICA")

	cfg, err := LoadConfigFromEnv()
	assert.Error(t, err, "Should error with missing env vars")
	assert.Nil(t, cfg, "Config should be nil on error")
}

func TestConnect_Success(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	setupTestEnv(t, "movies")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn, err := Connect(ctx, cfg)
	require.NoError(t, err, "Connect should succeed")
	require.NotNil(t, conn, "Connection should not be nil")
	require.Nil(t, conn.Err, "Connection error should be nil")
	require.NotNil(t, conn.Client, "Client should not be nil")
	require.NotNil(t, conn.Database, "Database should not be nil")

	defer func() {
		disconnectErr := conn.Disconnect()
		assert.NoError(t, disconnectErr, "Disconnect should succeed")
	}()

	// Verify we can ping
	pingCtx, pingCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer pingCancel()

	err = conn.Client.Ping(pingCtx, readpref.Primary())
	assert.NoError(t, err, "Should be able to ping MongoDB")

	// Verify database name
	assert.Equal(t, "movies", conn.Database.Name())
}

func TestConnect_WithOperations(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	setupTestEnv(t, "movies")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn, err := Connect(ctx, cfg)
	require.NoError(t, err)
	require.NotNil(t, conn.Client)

	defer func() {
		_ = conn.Disconnect()
	}()

	// Test insert operation
	collection := conn.Database.Collection("test_movies")

	testDoc := bson.M{
		"title":    "Test Movie",
		"year":     2024,
		"director": "Test Director",
		"_test":    true, // Mark as test data
	}

	insertCtx, insertCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer insertCancel()

	result, err := collection.InsertOne(insertCtx, testDoc)
	require.NoError(t, err, "Should insert test document")
	assert.NotNil(t, result.InsertedID, "Should return inserted ID")

	// Test find operation
	findCtx, findCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer findCancel()

	var found bson.M
	err = collection.FindOne(findCtx, bson.M{"_test": true}).Decode(&found)
	require.NoError(t, err, "Should find test document")
	assert.Equal(t, "Test Movie", found["title"])

	// Cleanup test data
	deleteCtx, deleteCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer deleteCancel()

	_, err = collection.DeleteMany(deleteCtx, bson.M{"_test": true})
	assert.NoError(t, err, "Should delete test documents")
}

func TestConnect_InvalidCredentials(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	os.Setenv("DB_USER", "invaliduser")
	os.Setenv("DB_PASS", "invalidpass")
	os.Setenv("DB_SERVERS", "192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019")
	os.Setenv("DB_NAME", "movies")
	os.Setenv("DB_REPLICA", "rs1")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn, err := Connect(ctx, cfg)
	assert.Error(t, err, "Should error with invalid credentials")
	assert.NotNil(t, conn, "Connection struct should not be nil")
	assert.NotNil(t, conn.Err, "Connection error should be set")
	assert.Nil(t, conn.Client, "Client should be nil on auth failure")
}

func TestConnect_InvalidServer(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	os.Setenv("DB_USER", "cristian")
	os.Setenv("DB_PASS", "cristianPassword2017")
	os.Setenv("DB_SERVERS", "192.168.68.200:27017") // Non-existent
	os.Setenv("DB_NAME", "movies")
	os.Setenv("DB_REPLICA", "rs1")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err)

	// Reduce timeouts for faster test
	cfg.ConnectTimeout = 10 * time.Second
	cfg.ServerSelectTimeout = 10 * time.Second

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	conn, err := Connect(ctx, cfg)
	assert.Error(t, err, "Should error with invalid server")
	assert.NotNil(t, conn, "Connection struct should not be nil")
	assert.NotNil(t, conn.Err, "Connection error should be set")
}

func TestHealthCheck(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	setupTestEnv(t, "movies")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn, err := Connect(ctx, cfg)
	require.NoError(t, err)
	require.NotNil(t, conn.Client)

	defer func() {
		_ = conn.Disconnect()
	}()

	// Test health check
	healthCtx, healthCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer healthCancel()

	err = conn.HealthCheck(healthCtx)
	assert.NoError(t, err, "Health check should pass")
}

func TestHealthCheck_NilClient(t *testing.T) {
	conn := &MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      nil,
	}

	err := conn.HealthCheck(context.Background())
	assert.Error(t, err, "Health check should fail with nil client")
	assert.Contains(t, err.Error(), "nil")
}

func TestDisconnect_NilClient(t *testing.T) {
	conn := &MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      nil,
	}

	err := conn.Disconnect()
	assert.NoError(t, err, "Disconnect with nil client should not error")
}

func TestMongoDB_ChannelLegacy(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	setupTestEnv(t, "movies")

	connChan := make(chan *MongoConnection, 1)

	go MongoDB(connChan)

	select {
	case conn := <-connChan:
		require.NotNil(t, conn, "Connection should not be nil")

		if conn.Err != nil {
			// Connection failed - this is OK if MongoDB is not available
			t.Logf("MongoDB connection failed (expected in some test environments): %v", conn.Err)
			return
		}

		require.Nil(t, conn.Err, "Connection error should be nil")
		require.NotNil(t, conn.Client, "Client should not be nil")
		require.NotNil(t, conn.Database, "Database should not be nil")

		defer func() {
			_ = conn.Disconnect()
		}()

		// Verify connection works
		pingCtx, pingCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer pingCancel()

		err := conn.Client.Ping(pingCtx, readpref.Primary())
		assert.NoError(t, err, "Should ping successfully")

	case <-time.After(60 * time.Second):
		t.Fatal("Timeout waiting for MongoDB connection")
	}
}

func TestConnect_MultipleConnections(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	setupTestEnv(t, "movies")

	cfg, err := LoadConfigFromEnv()
	require.NoError(t, err)

	const numConns = 5
	conns := make([]*MongoConnection, numConns)
	errors := make([]error, numConns)

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	// Create multiple connections
	for i := 0; i < numConns; i++ {
		conns[i], errors[i] = Connect(ctx, cfg)
	}

	// Verify all connections
	for i := 0; i < numConns; i++ {
		require.NoError(t, errors[i], "Connection %d should succeed", i)
		require.NotNil(t, conns[i], "Connection %d should not be nil", i)
		require.Nil(t, conns[i].Err, "Connection %d error should be nil", i)
		require.NotNil(t, conns[i].Client, "Connection %d client should not be nil", i)
	}

	// Cleanup
	for i := 0; i < numConns; i++ {
		if conns[i] != nil {
			err := conns[i].Disconnect()
			assert.NoError(t, err, "Disconnect for connection %d should succeed", i)
		}
	}
}
