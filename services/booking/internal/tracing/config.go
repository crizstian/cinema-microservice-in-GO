package tracing

import (
	"context"
	"io"
	"net/http"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	"github.com/labstack/gommon/log"
	opentracing "github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/ext"
	"github.com/uber/jaeger-client-go"
)

const defaultComponentName = "echo/v4"

type (
	// TraceConfig defines the config for Trace middleware.
	TraceConfig struct {
		// Skipper defines a function to skip middleware.
		Skipper middleware.Skipper

		// OpenTracing Tracer instance which should be got before
		Context context.Context

		// componentName used for describing the tracing component name
		componentName string
	}
)

// Init creates a new instance of Jaeger tracer.
func Init(service, endpoint string) (opentracing.Tracer, io.Closer) {
	sender, err := jaeger.NewUDPTransport(endpoint, 10000)
	if err != nil {
		log.Error(err)
	}
	reporter := jaeger.NewRemoteReporter(sender)
	tracer, closer := jaeger.NewTracer("booking-service", jaeger.NewConstSampler(true), reporter)

	log.Info("Tracer has been initialized")

	return tracer, closer
}

// TraceWithConfig ...
func TraceWithConfig(config TraceConfig) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {

			req := c.Request()
			opname := "HTTP " + req.Method + " URL: " + c.Path()

			span, _ := opentracing.StartSpanFromContext(config.Context, opname)

			ext.SpanKindRPCClient.Set(span)
			ext.HTTPUrl.Set(span, req.URL.String())
			ext.HTTPMethod.Set(span, req.Method)
			span.Tracer().Inject(
				span.Context(),
				opentracing.HTTPHeaders,
				opentracing.HTTPHeadersCarrier(req.Header),
			)

			req = req.WithContext(opentracing.ContextWithSpan(req.Context(), span))
			c.SetRequest(req)

			defer func() {
				status := c.Response().Status
				committed := c.Response().Committed
				ext.HTTPStatusCode.Set(span, uint16(status))
				if status >= http.StatusInternalServerError || !committed {
					ext.Error.Set(span, true)
				}
				span.Finish()
			}()
			return next(c)
		}
	}
}
