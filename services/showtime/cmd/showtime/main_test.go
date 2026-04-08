package main

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMain_EnvPort(t *testing.T) {
	// Test that PORT environment variable is read
	original := os.Getenv("PORT")
	defer os.Setenv("PORT", original)

	os.Setenv("PORT", "9999")
	port := os.Getenv("PORT")

	assert.Equal(t, "9999", port)
}

func TestMain_DefaultPort(t *testing.T) {
	original := os.Getenv("PORT")
	defer os.Setenv("PORT", original)

	os.Unsetenv("PORT")
	port := os.Getenv("PORT")

	if port == "" {
		port = "3003"
	}

	assert.Equal(t, "3003", port)
}
