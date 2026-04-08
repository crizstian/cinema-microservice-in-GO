package api

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestIsValidEmail(t *testing.T) {
	tests := []struct {
		email    string
		expected bool
	}{
		{"test@example.com", true},
		{"user.name@domain.org", true},
		{"user+tag@example.co.uk", true},
		{"invalid", false},
		{"invalid@", false},
		{"@invalid.com", false},
		{"", false},
		{"spaces in@email.com", false},
		{"no@domain", false},
	}

	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			result := isValidEmail(tt.email)
			assert.Equal(t, tt.expected, result, "Email: %s", tt.email)
		})
	}
}

func TestGenerateUserID(t *testing.T) {
	id1 := generateUserID()
	id2 := generateUserID()

	// Should start with "usr_"
	assert.True(t, len(id1) > 4)
	assert.Equal(t, "usr_", id1[:4])

	// Should generate unique IDs
	assert.NotEqual(t, id1, id2)
}

func TestRandomString(t *testing.T) {
	s1 := randomString(10)
	s2 := randomString(10)

	assert.Len(t, s1, 10)
	assert.Len(t, s2, 10)

	// Different lengths
	s3 := randomString(5)
	assert.Len(t, s3, 5)

	s4 := randomString(20)
	assert.Len(t, s4, 20)
}

func TestConnect_NilDatabase(t *testing.T) {
	repo, err := Connect(nil)

	assert.Error(t, err)
	assert.Nil(t, repo)
}
