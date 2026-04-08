# E2E Test Runner
# Builds and runs integration tests inside a container
FROM golang:1.24-alpine

WORKDIR /tests

# Install git for go modules
RUN apk add --no-cache git

# Copy go.mod and go.sum first for better caching
COPY ../../../tests/integration/go.mod ../../../tests/integration/go.sum ./
RUN go mod download

# Copy test files
COPY ../../../tests/integration/ .

# Set environment defaults (can be overridden at runtime)
ENV GOWORK=off
ENV USER_SERVICE_URL=http://user:8004
ENV MOVIE_SERVICE_URL=http://movie:8000
ENV CINEMA_SERVICE_URL=http://cinema:8085
ENV SHOWTIME_SERVICE_URL=http://showtime:3003
ENV SEAT_SERVICE_URL=http://seat:3004
ENV PAYMENT_SERVICE_URL=http://payment:8000
ENV BOOKING_SERVICE_URL=http://booking:8082
ENV NOTIFICATION_SERVICE_URL=http://notification:8000

# Run tests
CMD ["go", "test", "-v", "./..."]
