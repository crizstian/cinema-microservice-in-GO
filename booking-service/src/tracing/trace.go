package tracing

import (
	"fmt"
	"reflect"
	"runtime"

	"github.com/labstack/echo"
	"github.com/opentracing/opentracing-go"
)

// TraceFunction wraps funtion with opentracing span adding tags for the function name and caller details
func TraceFunction(ctx echo.Context, fn interface{}, params ...interface{}) (result []reflect.Value) {
	f := reflect.ValueOf(fn)
	if f.Type().NumIn() != len(params) {
		panic("incorrect number of parameters!")
	}
	inputs := make([]reflect.Value, len(params))
	for k, in := range params {
		inputs[k] = reflect.ValueOf(in)
	}
	pc, file, no, ok := runtime.Caller(1)
	details := runtime.FuncForPC(pc)
	name := runtime.FuncForPC(reflect.ValueOf(fn).Pointer()).Name()
	parentSpan := opentracing.SpanFromContext(ctx.Request().Context())
	sp := opentracing.StartSpan(
		"Function - "+name,
		opentracing.ChildOf(parentSpan.Context()))
	(opentracing.Tag{Key: "function", Value: name}).Set(sp)
	if ok {
		callerDetails := fmt.Sprintf("%s - %s#%d", details.Name(), file, no)
		(opentracing.Tag{Key: "caller", Value: callerDetails}).Set(sp)

	}
	defer sp.Finish()
	return f.Call(inputs)
}

// CreateChildSpan creates a new opentracing span adding tags for the span name and caller details.
// User must call defer `sp.Finish()`
func CreateChildSpan(ctx echo.Context, name string) opentracing.Span {
	pc, file, no, ok := runtime.Caller(1)
	details := runtime.FuncForPC(pc)
	parentSpan := opentracing.SpanFromContext(ctx.Request().Context())
	sp := opentracing.StartSpan(
		name,
		opentracing.ChildOf(parentSpan.Context()))
	(opentracing.Tag{Key: "name", Value: name}).Set(sp)
	if ok {
		callerDetails := fmt.Sprintf("%s - %s#%d", details.Name(), file, no)
		(opentracing.Tag{Key: "caller", Value: callerDetails}).Set(sp)

	}
	return sp
}
