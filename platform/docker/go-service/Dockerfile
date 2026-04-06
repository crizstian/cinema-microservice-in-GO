# Build arguments with sensible defaults
ARG GO_VERSION=1.23
ARG ALPINE_VERSION=3.19

FROM golang:${GO_VERSION} AS builder

ARG SERVICE_NAME

WORKDIR /build

COPY . .

RUN go mod download && go mod verify 

RUN CGO_ENABLED=0 GOOS=linux \
    go build -a \
    -installsuffix cgo \
    -ldflags="-w -s" \
    -o app \
    ./cmd/${SERVICE_NAME}

# ============================================================
# Stage 3: Runtime (Final Image)
# ============================================================
FROM alpine:${ALPINE_VERSION}

ARG SERVICE_NAME
ARG SERVICE_PORT

# Metadata
LABEL maintainer="Cristian Ramirez <cristian@cinema.dev>"
LABEL description="Cinema ${SERVICE_NAME} microservice"
LABEL version="${SERVICE_NAME}-v0.1.0"

# Create non-root user for security
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /build/app /app/service

# Set ownership of working directory
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE ${SERVICE_PORT}

# Run application
ENTRYPOINT ["/app/service"]