package provider

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/pact-foundation/pact-go/v2/models"
	"github.com/pact-foundation/pact-go/v2/provider"
)

// TestPaymentProviderPact verifies that payment-service fulfills
// the contract defined by booking-service (consumer).
//
// To run this test:
// 1. First run the consumer tests to generate the pact files
// 2. Start the payment-service
// 3. Run: go test -v ./contracts/provider/... -run TestPaymentProviderPact
func TestPaymentProviderPact(t *testing.T) {
	// Skip if not running provider verification
	if os.Getenv("PACT_PROVIDER_VERIFICATION") != "true" {
		t.Skip("Set PACT_PROVIDER_VERIFICATION=true to run provider verification")
	}

	// Get the path to pact files
	pactDir := os.Getenv("PACT_DIR")
	if pactDir == "" {
		pactDir = filepath.Join("..", "..", "..", "contracts")
	}

	// Provider service URL
	providerURL := os.Getenv("PROVIDER_URL")
	if providerURL == "" {
		providerURL = "http://localhost:3001"
	}

	verifier := provider.NewVerifier()

	err := verifier.VerifyProvider(t, provider.VerifyRequest{
		Provider:        "payment-service",
		ProviderBaseURL: providerURL,
		PactFiles: []string{
			filepath.Join(pactDir, "booking-service-payment-service.json"),
		},
		StateHandlers: models.StateHandlers{
			"a valid credit card": func(setup bool, state models.ProviderState) (models.ProviderStateResponse, error) {
				// Set up test data for valid credit card scenario
				fmt.Println("Setting up: valid credit card scenario")
				// In a real test, you might seed test data here
				return models.ProviderStateResponse{}, nil
			},
			"an invalid payment amount": func(setup bool, state models.ProviderState) (models.ProviderStateResponse, error) {
				fmt.Println("Setting up: invalid payment amount scenario")
				return models.ProviderStateResponse{}, nil
			},
			"an existing successful charge": func(setup bool, state models.ProviderState) (models.ProviderStateResponse, error) {
				fmt.Println("Setting up: existing charge for refund scenario")
				// In production, you would create a test charge here
				return models.ProviderStateResponse{}, nil
			},
		},
		// Optional: Publish results to Pact Broker
		// PublishVerificationResults: true,
		// ProviderVersion: os.Getenv("GIT_COMMIT"),
	})

	if err != nil {
		t.Fatalf("Provider verification failed: %v", err)
	}
}

// TestPaymentProviderWithMockDB uses state handlers to set up mock scenarios
// This is useful for testing without a real database
func TestPaymentProviderWithMockDB(t *testing.T) {
	if os.Getenv("PACT_PROVIDER_MOCK") != "true" {
		t.Skip("Set PACT_PROVIDER_MOCK=true to run mock provider verification")
	}

	// This would start a mock payment service with predefined responses
	// For now, skip actual implementation
	t.Skip("Mock provider verification not implemented yet")
}
