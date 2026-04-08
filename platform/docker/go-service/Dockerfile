# ============================================================
# Common Dockerfile for all Go microservices
# Context must be the service directory (e.g., services/movie)
# Usage: docker build -f platform/docker/go-service/Dockerfile --build-arg SERVICE_NAME=movie services/movie
# ============================================================

ARG GO_VERSION=1.24
ARG ALPINE_VERSION=3.21

# ============================================================
# Stage 1: Builder
# ============================================================
FROM golang:${GO_VERSION}-alpine AS builder

ARG SERVICE_NAME
ARG VERSION=0.0.0-dev
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

WORKDIR /build

# Install git for go mod (some deps may need it)
RUN apk add --no-cache git

# Disable go workspace mode (each service builds independently)
ENV GOWORK=off

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . ./

# Build binary with version info
RUN CGO_ENABLED=0 GOOS=linux \
    go build -a \
    -installsuffix cgo \
    -ldflags="-w -s -X main.Version=${VERSION} -X main.CommitSHA=${COMMIT_SHA} -X main.BuildDate=${BUILD_DATE}" \
    -o /app \
    ./cmd/${SERVICE_NAME}

# ============================================================
# Stage 2: Runtime (Final Image)
# ============================================================
FROM alpine:${ALPINE_VERSION}

ARG SERVICE_NAME
ARG SERVICE_PORT=8000
ARG VERSION=0.0.0-dev
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

# OCI Standard Labels
LABEL org.opencontainers.image.title="cinema-${SERVICE_NAME}"
LABEL org.opencontainers.image.description="Cinema ${SERVICE_NAME} microservice"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${COMMIT_SHA}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.source="https://github.com/crizstian/cinema-microservices"
LABEL org.opencontainers.image.vendor="Cinema App"
LABEL org.opencontainers.image.authors="Cristian Ramirez <cristian@cinema.dev>"

# Install ca-certificates for HTTPS and wget for healthcheck
RUN apk add --no-cache ca-certificates wget

# Create non-root user for security
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app /app/service

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE ${SERVICE_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:${SERVICE_PORT}/health || exit 1

# Run application
ENTRYPOINT ["/app/service"]