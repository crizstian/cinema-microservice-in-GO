package models

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMovieModel(t *testing.T) {
	movie := Movie{
		Title: "Inception",
		// Nota: el campo se llama "Format" (sin typo)
		Format: "IMAX",
	}

	assert.Equal(t, "Inception", movie.Title)
	assert.Equal(t, "IMAX", movie.Format)
	assert.NotEmpty(t, movie.Title)
}

func TestMovieValidation(t *testing.T) {
	tests := []struct {
		name    string
		movie   Movie
		isValid bool
	}{
		{
			name: "valid movie",
			movie: Movie{
				Title:  "Avatar",
				Format: "3D",
			},
			isValid: true,
		},
		{
			name: "empty title",
			movie: Movie{
				Title:  "",
				Format: "2D",
			},
			isValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.movie.Title != ""
			assert.Equal(t, tt.isValid, isValid)
		})
	}
}
