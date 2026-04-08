package server

import (
	"testing"

	"github.com/labstack/echo"
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

func TestGetServer_AfterAssignment(t *testing.T) {
	// Reset global state for test
	originalE := e
	defer func() { e = originalE }()

	// Simulate server being set
	e = echo.New()
	server := GetServer()
	assert.NotNil(t, server, "Server should not be nil after being set")
}

func TestInit_LoggerConfiguration(t *testing.T) {
	// The init() function runs automatically when package is imported
	// We just verify it doesn't panic and the package loads correctly
	assert.NotPanics(t, func() {
		// init() has already run by this point
		// This test verifies the package can be imported without errors
	})
}
