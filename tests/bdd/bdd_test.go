package bdd

import (
	"os"
	"testing"

	"github.com/cucumber/godog"
	"github.com/cucumber/godog/colors"
	"github.com/crizstian/cinema-microservices/tests/bdd/steps"
)

var opts = godog.Options{
	Output:      colors.Colored(os.Stdout),
	Format:      "pretty",
	Paths:       []string{"features"},
	Randomize:   0,
	Concurrency: 1,
}

func init() {
	// Allow overriding format via environment
	if format := os.Getenv("GODOG_FORMAT"); format != "" {
		opts.Format = format
	}

	// Allow filtering by tags
	if tags := os.Getenv("GODOG_TAGS"); tags != "" {
		opts.Tags = tags
	}
}

func InitializeScenario(ctx *godog.ScenarioContext) {
	tc := steps.NewTestContext()

	// Register all step definitions
	steps.RegisterCommonSteps(ctx, tc)
	steps.RegisterBookingSteps(ctx, tc)
	steps.RegisterMovieSteps(ctx, tc)

	// Reset context before each scenario
	ctx.Before(func(ctx *godog.ScenarioContext, sc *godog.Scenario) {
		tc = steps.NewTestContext()
		steps.RegisterCommonSteps(ctx, tc)
		steps.RegisterBookingSteps(ctx, tc)
		steps.RegisterMovieSteps(ctx, tc)
	})
}

func TestFeatures(t *testing.T) {
	suite := godog.TestSuite{
		ScenarioInitializer: InitializeScenario,
		Options:             &opts,
	}

	if suite.Run() != 0 {
		t.Fatal("BDD tests failed")
	}
}
