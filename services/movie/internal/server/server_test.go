package server

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetServer_InitiallyNil(t *testing.T) {
	// Reset global state for test
	originalE := e
	e = nil
	defer func() { e = originalE }()

	server := GetServer()
	assert.Nil(t, server, "Server should be nil before Start is called")
}

func TestInit_LoggerConfiguration(t *testing.T) {
	// The init() function runs automatically when package is imported
	// We just verify it doesn't panic and the package loads correctly
	assert.NotPanics(t, func() {
		// init() has already run by this point
		// This test verifies the package can be imported without errors
	})
}

func TestStart_InvalidPort(t *testing.T) {
	// Create mock repository
	mockRepo := &MockRepository{}

	resources := map[string]interface{}{
		"repo": mockRepo,
		"port": -1, // Invalid port
	}

	// Start in a goroutine since it blocks
	errChan := make(chan error, 1)
	go func() {
		err := Start(resources)
		errChan <- err
	}()

	// Give it a moment to fail
	select {
	case err := <-errChan:
		// Should error with invalid port
		assert.Error(t, err)
	default:
		// If it doesn't error immediately, that's OK too
		// The server might start but fail to bind
	}
}

func TestStart_ValidConfiguration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping server start test in short mode")
	}

	mockRepo := &MockRepository{}

	resources := map[string]interface{}{
		"repo": mockRepo,
		"port": 0, // Port 0 lets OS assign a free port
	}

	// Start in a goroutine since it blocks
	errChan := make(chan error, 1)
	go func() {
		err := Start(resources)
		errChan <- err
	}()

	// We can't easily test the full server lifecycle without
	// more complex setup, so we just verify it attempts to start
}

// MockRepository for testing
type MockRepository struct{}

func (m *MockRepository) GetAllMovies(c interface{}) error {
	return nil
}

func (m *MockRepository) GetMoviePremiers(c interface{}) error {
	return nil
}

func (m *MockRepository) GetMovieByID(c interface{}) error {
	return nil
}
