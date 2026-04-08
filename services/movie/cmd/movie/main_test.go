package main

import (
	"cinemas/services/movie/internal/api"
	"cinemas/services/movie/internal/db"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ========================================
// MOCK IMPLEMENTATIONS
// ========================================

// MockDBConnector implements DBConnector for testing
type MockDBConnector struct {
	connection *db.MongoConnection
	delay      time.Duration
}

func (m *MockDBConnector) Connect(c chan *db.MongoConnection) {
	if m.delay > 0 {
		time.Sleep(m.delay)
	}
	c <- m.connection
}

// NewMockDBConnector creates a mock connector with the given connection
func NewMockDBConnector(conn *db.MongoConnection) *MockDBConnector {
	return &MockDBConnector{connection: conn}
}

// NewMockDBConnectorWithDelay creates a mock connector with a delay
func NewMockDBConnectorWithDelay(conn *db.MongoConnection, delay time.Duration) *MockDBConnector {
	return &MockDBConnector{connection: conn, delay: delay}
}

// ========================================
// TEST HELPERS
// ========================================

// setupTestEnv sets up required environment variables for testing
func setupTestEnv(t *testing.T) func() {
	t.Helper()

	// Save original values
	origPort := os.Getenv("SERVICE_PORT")
	origUser := os.Getenv("DB_USER")
	origPass := os.Getenv("DB_PASS")
	origServers := os.Getenv("DB_SERVERS")
	origName := os.Getenv("DB_NAME")
	origReplica := os.Getenv("DB_REPLICA")

	// Set test values
	os.Setenv("SERVICE_PORT", "8080")
	os.Setenv("DB_USER", "testuser")
	os.Setenv("DB_PASS", "testpass")
	os.Setenv("DB_SERVERS", "localhost:27017")
	os.Setenv("DB_NAME", "testdb")
	os.Setenv("DB_REPLICA", "rs0")

	// Return cleanup function
	return func() {
		if origPort != "" {
			os.Setenv("SERVICE_PORT", origPort)
		} else {
			os.Unsetenv("SERVICE_PORT")
		}
		if origUser != "" {
			os.Setenv("DB_USER", origUser)
		} else {
			os.Unsetenv("DB_USER")
		}
		if origPass != "" {
			os.Setenv("DB_PASS", origPass)
		} else {
			os.Unsetenv("DB_PASS")
		}
		if origServers != "" {
			os.Setenv("DB_SERVERS", origServers)
		} else {
			os.Unsetenv("DB_SERVERS")
		}
		if origName != "" {
			os.Setenv("DB_NAME", origName)
		} else {
			os.Unsetenv("DB_NAME")
		}
		if origReplica != "" {
			os.Setenv("DB_REPLICA", origReplica)
		} else {
			os.Unsetenv("DB_REPLICA")
		}
	}
}

// ========================================
// UNIT TESTS - App Creation
// ========================================

func TestNewApp(t *testing.T) {
	app := NewApp()

	assert.NotNil(t, app)
	assert.NotNil(t, app.exitFunc)
	assert.NotNil(t, app.config)
	assert.Equal(t, 30*time.Second, app.config.ConnectionTimeout)
	assert.Equal(t, 10*time.Second, app.config.ShutdownTimeout)
	assert.Nil(t, app.client)
	assert.Nil(t, app.mongoConn)
}

func TestNewApp_ConfigDefaults(t *testing.T) {
	app := NewApp()

	assert.Equal(t, 0, app.config.ServicePort, "ServicePort should be 0 before LoadConfig")
	assert.Equal(t, 30*time.Second, app.config.ConnectionTimeout)
	assert.Equal(t, 10*time.Second, app.config.ShutdownTimeout)
}

// ========================================
// UNIT TESTS - LoadConfig
// ========================================

func TestLoadConfig_Success(t *testing.T) {
	cleanup := setupTestEnv(t)
	defer cleanup()

	app := NewApp()
	err := app.LoadConfig()

	assert.NoError(t, err)
	assert.Equal(t, 8080, app.config.ServicePort)
}

func TestLoadConfig_MissingPort(t *testing.T) {
	os.Unsetenv("SERVICE_PORT")

	app := NewApp()
	err := app.LoadConfig()

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "SERVICE_PORT environment variable not found")
}

func TestLoadConfig_InvalidPort(t *testing.T) {
	os.Setenv("SERVICE_PORT", "not-a-number")
	defer os.Unsetenv("SERVICE_PORT")

	app := NewApp()
	err := app.LoadConfig()

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "SERVICE_PORT is not a valid number")
}

func TestLoadConfig_PortZero(t *testing.T) {
	os.Setenv("SERVICE_PORT", "0")
	defer os.Unsetenv("SERVICE_PORT")

	app := NewApp()
	err := app.LoadConfig()

	assert.NoError(t, err)
	assert.Equal(t, 0, app.config.ServicePort)
}

func TestLoadConfig_PortNegative(t *testing.T) {
	os.Setenv("SERVICE_PORT", "-1")
	defer os.Unsetenv("SERVICE_PORT")

	app := NewApp()
	err := app.LoadConfig()

	assert.NoError(t, err)
	assert.Equal(t, -1, app.config.ServicePort)
}

// ========================================
// UNIT TESTS - Initialize
// ========================================

func TestInitialize_Success(t *testing.T) {
	app := NewApp()

	// Create mock connection (with nil client for unit test)
	mockConn := &db.MongoConnection{
		Client:   nil, // In real test, this would be a mock client
		Database: nil,
		Err:      nil,
	}
	connector := NewMockDBConnector(mockConn)

	err := app.Initialize(connector)

	assert.NoError(t, err)
	assert.NotNil(t, app.mongoConn)
	assert.Equal(t, mockConn, app.mongoConn)
}

func TestInitialize_NilConnection(t *testing.T) {
	app := NewApp()

	connector := NewMockDBConnector(nil)

	err := app.Initialize(connector)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "MongoDB connection returned nil")
}

func TestInitialize_ConnectionError(t *testing.T) {
	app := NewApp()

	mockConn := &db.MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      errors.New("connection refused"),
	}
	connector := NewMockDBConnector(mockConn)

	err := app.Initialize(connector)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "an error occurred connecting to the DB")
	assert.Contains(t, err.Error(), "connection refused")
}

func TestInitialize_Timeout(t *testing.T) {
	app := NewApp()
	app.config.ConnectionTimeout = 100 * time.Millisecond

	// Create connector that delays longer than timeout
	mockConn := &db.MongoConnection{}
	connector := NewMockDBConnectorWithDelay(mockConn, 200*time.Millisecond)

	err := app.Initialize(connector)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "MongoDB connection timeout")
}

// ========================================
// UNIT TESTS - StartServer
// ========================================

func TestStartServer_NoConnection(t *testing.T) {
	app := NewApp()
	// mongoConn is nil

	errorChan := make(chan error, 1)
	err := app.StartServer(errorChan)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "MongoDB connection not initialized")
}

func TestStartServer_NilDatabase(t *testing.T) {
	app := NewApp()
	app.mongoConn = &db.MongoConnection{
		Client:   nil,
		Database: nil, // nil database
		Err:      nil,
	}
	app.config.ServicePort = 8080

	errorChan := make(chan error, 1)
	err := app.StartServer(errorChan)

	// api.Connect(nil) returns error
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to connect to API")
}

// ========================================
// UNIT TESTS - Shutdown
// ========================================

func TestShutdown_NilClient(t *testing.T) {
	app := NewApp()
	app.client = nil

	err := app.Shutdown()

	assert.NoError(t, err)
}

func TestShutdown_WithMongoConnection(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This test would require a real MongoDB connection
	// For unit tests, we verify the nil case
}

// ========================================
// UNIT TESTS - API Connect
// ========================================

func TestAPIConnectWithNilDB(t *testing.T) {
	repo, err := api.Connect(nil)

	assert.Error(t, err)
	assert.Nil(t, repo)
}

// ========================================
// UNIT TESTS - DB Config
// ========================================

func TestDBConfigFromEnv(t *testing.T) {
	cleanup := setupTestEnv(t)
	defer cleanup()

	cfg, err := db.LoadConfigFromEnv()

	require.NoError(t, err)
	assert.NotNil(t, cfg)
	assert.Equal(t, "testuser", cfg.User)
	assert.Equal(t, "testpass", cfg.Pass)
	assert.Equal(t, "testdb", cfg.Database)
	assert.Equal(t, "rs0", cfg.ReplicaSet)
}

func TestDBConfigMissingVars(t *testing.T) {
	os.Unsetenv("DB_USER")
	os.Unsetenv("DB_PASS")
	os.Unsetenv("DB_SERVERS")
	os.Unsetenv("DB_NAME")
	os.Unsetenv("DB_REPLICA")

	cfg, err := db.LoadConfigFromEnv()

	assert.Error(t, err)
	assert.Nil(t, cfg)
	assert.Contains(t, err.Error(), "missing required environment variables")
}

// ========================================
// UNIT TESTS - MongoConnection
// ========================================

func TestMongoConnectionWithError(t *testing.T) {
	conn := &db.MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      os.ErrNotExist,
	}

	assert.NotNil(t, conn.Err)
	assert.Nil(t, conn.Client)
	assert.Nil(t, conn.Database)
}

func TestMongoConnectionDisconnectNil(t *testing.T) {
	conn := &db.MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      nil,
	}

	err := conn.Disconnect()

	assert.NoError(t, err)
}

func TestMongoConnectionHealthCheckNil(t *testing.T) {
	conn := &db.MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      nil,
	}

	err := conn.HealthCheck(nil)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "nil")
}

// ========================================
// TABLE-DRIVEN TESTS - Initialization Scenarios
// ========================================

func TestInitializationScenarios(t *testing.T) {
	tests := []struct {
		name        string
		setupEnv    func()
		cleanupEnv  func()
		expectError bool
		errorMsg    string
	}{
		{
			name: "Valid configuration",
			setupEnv: func() {
				os.Setenv("SERVICE_PORT", "8080")
			},
			cleanupEnv: func() {
				os.Unsetenv("SERVICE_PORT")
			},
			expectError: false,
		},
		{
			name: "Missing SERVICE_PORT",
			setupEnv: func() {
				os.Unsetenv("SERVICE_PORT")
			},
			cleanupEnv:  func() {},
			expectError: true,
			errorMsg:    "SERVICE_PORT environment variable not found",
		},
		{
			name: "Invalid port format",
			setupEnv: func() {
				os.Setenv("SERVICE_PORT", "abc")
			},
			cleanupEnv: func() {
				os.Unsetenv("SERVICE_PORT")
			},
			expectError: true,
			errorMsg:    "not a valid number",
		},
		{
			name: "Empty port",
			setupEnv: func() {
				os.Setenv("SERVICE_PORT", "")
			},
			cleanupEnv: func() {
				os.Unsetenv("SERVICE_PORT")
			},
			expectError: true,
			errorMsg:    "not a valid number",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setupEnv()
			defer tt.cleanupEnv()

			app := NewApp()
			err := app.LoadConfig()

			if tt.expectError {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errorMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// ========================================
// TABLE-DRIVEN TESTS - Connection Scenarios
// ========================================

func TestConnectionScenarios(t *testing.T) {
	tests := []struct {
		name        string
		connection  *db.MongoConnection
		expectError bool
		errorMsg    string
	}{
		{
			name:        "Nil connection",
			connection:  nil,
			expectError: true,
			errorMsg:    "MongoDB connection returned nil",
		},
		{
			name: "Connection with error",
			connection: &db.MongoConnection{
				Err: errors.New("auth failed"),
			},
			expectError: true,
			errorMsg:    "an error occurred connecting to the DB",
		},
		{
			name: "Valid connection",
			connection: &db.MongoConnection{
				Client:   nil, // nil for unit test
				Database: nil,
				Err:      nil,
			},
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := NewApp()
			connector := NewMockDBConnector(tt.connection)

			err := app.Initialize(connector)

			if tt.expectError {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errorMsg)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, app.mongoConn)
			}
		})
	}
}

// ========================================
// CONCURRENT TESTS
// ========================================

func TestConcurrentConfigLoad(t *testing.T) {
	cleanup := setupTestEnv(t)
	defer cleanup()

	done := make(chan bool, 10)

	for i := 0; i < 10; i++ {
		go func() {
			app := NewApp()
			err := app.LoadConfig()
			assert.NoError(t, err)
			assert.Equal(t, 8080, app.config.ServicePort)
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		select {
		case <-done:
			// OK
		case <-time.After(5 * time.Second):
			t.Fatal("Concurrent config load timed out")
		}
	}
}

func TestConcurrentDBConfigLoad(t *testing.T) {
	cleanup := setupTestEnv(t)
	defer cleanup()

	done := make(chan bool, 10)

	for i := 0; i < 10; i++ {
		go func() {
			cfg, err := db.LoadConfigFromEnv()
			assert.NoError(t, err)
			assert.NotNil(t, cfg)
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		select {
		case <-done:
			// OK
		case <-time.After(5 * time.Second):
			t.Fatal("Concurrent DB config load timed out")
		}
	}
}

// ========================================
// BENCHMARK TESTS
// ========================================

func BenchmarkNewApp(b *testing.B) {
	for i := 0; i < b.N; i++ {
		NewApp()
	}
}

func BenchmarkLoadConfig(b *testing.B) {
	os.Setenv("SERVICE_PORT", "8080")
	defer os.Unsetenv("SERVICE_PORT")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		app := NewApp()
		app.LoadConfig()
	}
}

func BenchmarkLoadDBConfig(b *testing.B) {
	os.Setenv("DB_USER", "testuser")
	os.Setenv("DB_PASS", "testpass")
	os.Setenv("DB_SERVERS", "localhost:27017")
	os.Setenv("DB_NAME", "testdb")
	os.Setenv("DB_REPLICA", "rs0")

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		db.LoadConfigFromEnv()
	}
}

// ========================================
// INTEGRATION TESTS (skipped in short mode)
// ========================================

func TestFullInitializationFlow(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	cleanup := setupTestEnv(t)
	defer cleanup()

	app := NewApp()

	// Load config
	err := app.LoadConfig()
	require.NoError(t, err)
	assert.Equal(t, 8080, app.config.ServicePort)

	// Initialize with mock connector
	mockConn := &db.MongoConnection{
		Client:   nil,
		Database: nil,
		Err:      nil,
	}
	connector := NewMockDBConnector(mockConn)

	err = app.Initialize(connector)
	require.NoError(t, err)
	assert.NotNil(t, app.mongoConn)

	// Shutdown
	err = app.Shutdown()
	assert.NoError(t, err)
}

func TestDefaultDBConnector(t *testing.T) {
	// Verify DefaultDBConnector implements DBConnector interface
	var connector DBConnector = &DefaultDBConnector{}
	assert.NotNil(t, connector)
}
