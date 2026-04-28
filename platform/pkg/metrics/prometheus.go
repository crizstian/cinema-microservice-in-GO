package metrics

import (
	"strconv"
	"time"

	"github.com/labstack/echo"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// HTTPRequestsTotal counts total HTTP requests
	HTTPRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	// HTTPRequestDuration measures HTTP request duration
	HTTPRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
		},
		[]string{"method", "path"},
	)

	// HTTPRequestsInFlight tracks current in-flight requests
	HTTPRequestsInFlight = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_requests_in_flight",
			Help: "Current number of HTTP requests being processed",
		},
	)

	// HTTPResponseSize tracks response sizes
	HTTPResponseSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_response_size_bytes",
			Help:    "HTTP response size in bytes",
			Buckets: []float64{100, 1000, 10000, 100000, 1000000},
		},
		[]string{"method", "path"},
	)
)

// Middleware returns an Echo middleware that collects Prometheus metrics
func Middleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Skip metrics endpoint
			if c.Path() == "/metrics" {
				return next(c)
			}

			start := time.Now()
			HTTPRequestsInFlight.Inc()

			err := next(c)

			HTTPRequestsInFlight.Dec()
			duration := time.Since(start).Seconds()

			status := c.Response().Status
			method := c.Request().Method
			path := c.Path()

			// Use route pattern if available, otherwise use path
			if path == "" {
				path = c.Request().URL.Path
			}

			// Record metrics
			HTTPRequestsTotal.WithLabelValues(method, path, strconv.Itoa(status)).Inc()
			HTTPRequestDuration.WithLabelValues(method, path).Observe(duration)
			HTTPResponseSize.WithLabelValues(method, path).Observe(float64(c.Response().Size))

			return err
		}
	}
}

// Handler returns the Prometheus HTTP handler for the /metrics endpoint
func Handler() echo.HandlerFunc {
	h := promhttp.Handler()
	return func(c echo.Context) error {
		h.ServeHTTP(c.Response(), c.Request())
		return nil
	}
}

// Register adds the /metrics endpoint to an Echo instance
func Register(e *echo.Echo) {
	e.GET("/metrics", Handler())
}

// RegisterWithMiddleware adds both the middleware and /metrics endpoint
func RegisterWithMiddleware(e *echo.Echo) {
	e.Use(Middleware())
	e.GET("/metrics", Handler())
}
