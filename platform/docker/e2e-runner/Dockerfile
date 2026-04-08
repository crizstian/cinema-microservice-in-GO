# E2E Test Runner
# Runs integration tests against the cinema microservices
FROM golang:1.24-alpine

WORKDIR /tests

RUN apk add --no-cache git

# Copy go.mod and go.sum first for caching
COPY tests/integration/go.mod tests/integration/go.sum ./
RUN go mod download

# Copy test files
COPY tests/integration/*.go ./

ENV GOWORK=off

CMD ["go", "test", "-v", "-timeout", "5m", "./..."]
