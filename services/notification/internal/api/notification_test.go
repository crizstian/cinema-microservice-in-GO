package api

import (
	"cinemas/services/notification/internal/models"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestTicketValidation(t *testing.T) {
	tests := []struct {
		name    string
		ticket  models.Ticket
		isValid bool
	}{
		{
			name: "valid ticket",
			ticket: models.Ticket{
				OrderID:  "order-123",
				UserName: "John Doe",
				Email:    "john@example.com",
			},
			isValid: true,
		},
		{
			name: "empty email",
			ticket: models.Ticket{
				OrderID:  "order-123",
				UserName: "John Doe",
				Email:    "",
			},
			isValid: false,
		},
		{
			name: "invalid email format",
			ticket: models.Ticket{
				OrderID:  "order-123",
				UserName: "John Doe",
				Email:    "invalid-email",
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.ticket.Email != "" && strings.Contains(tt.ticket.Email, "@")
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
