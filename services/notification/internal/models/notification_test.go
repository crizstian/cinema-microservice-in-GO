package models

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestTicketModel(t *testing.T) {
	ticket := Ticket{
		OrderID:     "order-123",
		Description: "Test ticket",
		UserName:    "Test User",
		Email:       "test@example.com",
	}

	assert.Equal(t, "order-123", ticket.OrderID)
	assert.NotEmpty(t, ticket.Email)
	assert.True(t, strings.Contains(ticket.Email, "@"))
	assert.Equal(t, "Test User", ticket.UserName)
}

func TestEmailValidation(t *testing.T) {
	tests := []struct {
		email   string
		isValid bool
	}{
		{"test@example.com", true},
		{"user@domain.co", true},
		{"invalid", false},
		{"@example.com", false},
		{"test@", false},
		{"", false},
	}

	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			// Validación simple: debe tener @ con texto antes y después
			parts := strings.Split(tt.email, "@")
			isValid := len(parts) == 2 && len(parts[0]) > 0 && len(parts[1]) > 0
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
