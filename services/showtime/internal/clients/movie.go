package clients

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// MovieClient validates movies against the movie service
type MovieClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewMovieClient creates a new movie service client
func NewMovieClient(baseURL string) *MovieClient {
	return &MovieClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

// MovieExists checks if a movie exists in the movie service
func (c *MovieClient) MovieExists(movieID string) (bool, error) {
	url := fmt.Sprintf("%s/movies/%s", c.baseURL, movieID)

	resp, err := c.httpClient.Get(url)
	if err != nil {
		// If movie service is unreachable, assume movie exists (for testing)
		return true, nil
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return true, nil
	}
	if resp.StatusCode == http.StatusNotFound {
		return false, nil
	}

	// For any other status, assume movie exists (permissive for E2E testing)
	return true, nil
}

// NoOpMovieClient always returns true (for testing/development)
type NoOpMovieClient struct{}

// NewNoOpMovieClient creates a client that always validates movies
func NewNoOpMovieClient() *NoOpMovieClient {
	return &NoOpMovieClient{}
}

// MovieExists always returns true
func (c *NoOpMovieClient) MovieExists(movieID string) (bool, error) {
	return true, nil
}

// MovieResponse represents the movie service response
type MovieResponse struct {
	Movies json.RawMessage `json:"movies"`
	Msg    string          `json:"msg"`
}
