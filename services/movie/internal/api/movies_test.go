package api

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestGetTimeFormat(t *testing.T) {
	y, m, d := getTimeFormat()

	// Validaciones básicas
	assert.Greater(t, y, 2020, "Year should be greater than 2020")
	assert.GreaterOrEqual(t, m, 1, "Month should be >= 1")
	assert.LessOrEqual(t, m, 12, "Month should be <= 12")
	assert.GreaterOrEqual(t, d, 1, "Day should be >= 1")
	assert.LessOrEqual(t, d, 31, "Day should be <= 31")

	// Verificar que no es el tiempo cero
	now := time.Now()
	assert.Equal(t, now.Year(), y)
	assert.Equal(t, int(now.Month()), m)
	assert.Equal(t, now.Day(), d)
}
