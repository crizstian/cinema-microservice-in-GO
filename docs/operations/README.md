# Operations Guide - Cinema Ticketing System

> **AI Agent Context**: This document covers CI/CD pipelines, deployment strategies, and infrastructure management. The project uses **Harness CI** for pipelines with Test Intelligence support.

**Last Updated**: 2026-04-08  
**CI/CD Platform**: Harness  
**Container Registry**: ghcr.io

---

## Table of Contents

1. [CI/CD Overview](#cicd-overview)
2. [Harness Pipelines](#harness-pipelines)
3. [Centralized Configuration](#centralized-configuration)
4. [Deployment](#deployment)
5. [Docker Infrastructure](#docker-infrastructure)
6. [Monitoring](#monitoring)
7. [Runbooks](#runbooks)

---

## CI/CD Overview

### Pipeline Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐       │
│  │  Lint   │──▶│  Test   │──▶│  Build  │──▶│  Push   │──▶│ Deploy  │       │
│  │ OpenAPI │   │  Unit   │   │  Image  │   │Registry │   │ Staging │       │
│  └─────────┘   │Contract │   └─────────┘   └─────────┘   └────┬────┘       │
│                │  Integ  │                                     │            │
│                └─────────┘                                     ▼            │
│                                                           ┌─────────┐       │
│                                                           │  E2E    │       │
│                                                           │  Tests  │       │
│                                                           └────┬────┘       │
│                                                                │            │
│                                                                ▼            │
│                                                           ┌─────────┐       │
│                                                           │ Deploy  │       │
│                                                           │  Prod   │       │
│                                                           │(manual) │       │
│                                                           └─────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Triggers

| Trigger | Pipeline | Conditions |
|---------|----------|------------|
| Push to `main` | Full CI + Deploy Staging | Always |
| Pull Request | CI (no deploy) | Always |
| Push to `services/**` | Service-specific CI | Path filter |
| Tag `v*.*.*` | Full CI + Deploy Prod | Approval required |

---

## Harness Pipelines

### Test Intelligence

Harness **Test Intelligence** optimizes test execution by analyzing code changes:

- **ML-based selection**: Only runs affected tests
- **Call graph analysis**: Understands code dependencies
- **Up to 80% faster**: Reduces pipeline time significantly

Configuration:

```yaml
- step:
    type: RunTests
    spec:
      runOnlySelectedTests: true  # Enable Test Intelligence
      intelligenceMode: true
```

### Main Pipeline

```yaml
pipeline:
  name: Cinema Services CI
  identifier: cinema_services_ci
  projectIdentifier: cinema_microservices
  orgIdentifier: default
  
  properties:
    ci:
      codebase:
        connectorRef: github_connector
        repoName: cinema-microservices
        build: <+input>

  stages:
    # ============================================================
    # STAGE 1: Lint & Validate
    # ============================================================
    - stage:
        name: Lint
        identifier: lint
        type: CI
        spec:
          cloneCodebase: true
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          execution:
            steps:
              - step:
                  type: Run
                  name: Lint OpenAPI Specs
                  identifier: lint_openapi
                  spec:
                    shell: Sh
                    command: |
                      npm install -g @stoplight/spectral-cli
                      spectral lint services/*/api/openapi.yaml
              
              - step:
                  type: Run
                  name: Go Lint
                  identifier: lint_go
                  spec:
                    connectorRef: dockerhub
                    image: golangci/golangci-lint:v1.55
                    shell: Sh
                    command: |
                      for svc in booking movie payment notification; do
                        cd services/$svc
                        golangci-lint run ./...
                        cd ../..
                      done

    # ============================================================
    # STAGE 2: Unit Tests (with Test Intelligence)
    # ============================================================
    - stage:
        name: Unit Tests
        identifier: unit_tests
        type: CI
        spec:
          cloneCodebase: true
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          execution:
            steps:
              - parallel:
                  - step:
                      type: RunTests
                      name: Test Booking
                      identifier: test_booking
                      spec:
                        connectorRef: dockerhub
                        image: golang:1.22-alpine
                        language: Go
                        buildTool: Go
                        args: "-v -short -cover ./..."
                        packages: ./services/booking/...
                        runOnlySelectedTests: true
                        reports:
                          type: JUnit
                          spec:
                            paths:
                              - "**/*-junit.xml"
                  
                  - step:
                      type: RunTests
                      name: Test Movie
                      identifier: test_movie
                      spec:
                        connectorRef: dockerhub
                        image: golang:1.22-alpine
                        language: Go
                        buildTool: Go
                        args: "-v -short -cover ./..."
                        packages: ./services/movie/...
                        runOnlySelectedTests: true
                  
                  - step:
                      type: RunTests
                      name: Test Payment
                      identifier: test_payment
                      spec:
                        connectorRef: dockerhub
                        image: golang:1.22-alpine
                        language: Go
                        buildTool: Go
                        args: "-v -short -cover ./..."
                        packages: ./services/payment/...
                        runOnlySelectedTests: true
                  
                  - step:
                      type: RunTests
                      name: Test Notification
                      identifier: test_notification
                      spec:
                        connectorRef: dockerhub
                        image: golang:1.22-alpine
                        language: Go
                        buildTool: Go
                        args: "-v -short -cover ./..."
                        packages: ./services/notification/...
                        runOnlySelectedTests: true

    # ============================================================
    # STAGE 3: Contract Tests
    # ============================================================
    - stage:
        name: Contract Tests
        identifier: contract_tests
        type: CI
        spec:
          cloneCodebase: true
          execution:
            steps:
              - step:
                  type: Run
                  name: Install Pact
                  identifier: install_pact
                  spec:
                    shell: Sh
                    command: |
                      go install github.com/pact-foundation/pact-go/v2@latest
                      pact-go install
              
              - step:
                  type: RunTests
                  name: Consumer Tests
                  identifier: consumer_tests
                  spec:
                    language: Go
                    buildTool: Go
                    args: "-v ./contracts/consumer/..."
                    packages: ./services/booking/contracts/consumer
                    runOnlySelectedTests: true
              
              - parallel:
                  - step:
                      type: RunTests
                      name: Verify Payment
                      identifier: verify_payment
                      spec:
                        language: Go
                        buildTool: Go
                        args: "-v ./contracts/provider/..."
                        packages: ./services/payment/contracts/provider
                        envVariables:
                          PACT_PROVIDER_VERIFICATION: "true"

    # ============================================================
    # STAGE 4: Build & Push Images
    # ============================================================
    - stage:
        name: Build Images
        identifier: build_images
        type: CI
        spec:
          cloneCodebase: true
          execution:
            steps:
              - parallel:
                  - step:
                      type: BuildAndPushDockerRegistry
                      name: Build Booking
                      identifier: build_booking
                      spec:
                        connectorRef: ghcr_connector
                        repo: ghcr.io/cinema-app/booking
                        tags:
                          - <+pipeline.sequenceId>
                          - latest
                        dockerfile: platform/docker/go-service/Dockerfile
                        context: .
                        buildArgs:
                          SERVICE_NAME: booking
                          VERSION: <+pipeline.sequenceId>
                  
                  - step:
                      type: BuildAndPushDockerRegistry
                      name: Build Movie
                      identifier: build_movie
                      spec:
                        connectorRef: ghcr_connector
                        repo: ghcr.io/cinema-app/movie
                        tags:
                          - <+pipeline.sequenceId>
                          - latest
                        dockerfile: platform/docker/go-service/Dockerfile
                        buildArgs:
                          SERVICE_NAME: movie
                  
                  # ... repeat for other services

    # ============================================================
    # STAGE 5: Deploy to Staging
    # ============================================================
    - stage:
        name: Deploy Staging
        identifier: deploy_staging
        type: Deployment
        spec:
          deploymentType: Kubernetes
          service:
            serviceRef: cinema_services
          environment:
            environmentRef: staging
          execution:
            steps:
              - step:
                  type: K8sRollingDeploy
                  name: Rolling Deploy
                  identifier: rolling_deploy
                  spec:
                    skipDryRun: false

    # ============================================================
    # STAGE 6: E2E Tests
    # ============================================================
    - stage:
        name: E2E Tests
        identifier: e2e_tests
        type: CI
        spec:
          execution:
            steps:
              - step:
                  type: Run
                  name: Run E2E Tests
                  identifier: run_e2e
                  spec:
                    shell: Sh
                    command: |
                      cd tests/e2e
                      go test -v -tags=e2e ./...
        when:
          pipelineStatus: Success
          condition: <+stage.deploy_staging.status> == "SUCCESS"

    # ============================================================
    # STAGE 7: Deploy to Production (Manual Approval)
    # ============================================================
    - stage:
        name: Deploy Production
        identifier: deploy_production
        type: Deployment
        spec:
          deploymentType: Kubernetes
          environment:
            environmentRef: production
        when:
          pipelineStatus: Success
          condition: <+trigger.type> == "Tag"
        approval:
          type: Manual
          spec:
            approvers:
              userGroups:
                - devops_leads
            timeout: 24h
```

### Pipeline Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `HARNESS_API_KEY` | Harness API token | Secret |
| `STRIPE_KEY` | Stripe test key | Secret |
| `GHCR_TOKEN` | GitHub Container Registry | Secret |

---

## Centralized Configuration

All service configuration is managed from a single source of truth: `config/services.yaml`.

### Quick Reference

```bash
# Generate all config files
task config:all

# Generate platform/deploy/docker-compose/.env for Docker Compose
task config:generate

# Generate Harness service definitions
task config:harness

# Show current configuration
task config:show
```

### Configuration Flow

| Environment | Source | Generated Files |
|-------------|--------|-----------------|
| Local (Docker Compose) | `config/services.yaml` | `platform/deploy/docker-compose/.env` |
| Remote (K8s + Harness) | `config/services.yaml` | `platform/deploy/harness/services/*.yaml` |
| K8s Values | Harness serviceVariables | Templates use `<+serviceVariables.*>` expressions |

### Service Ports

| Service | Port | Database |
|---------|------|----------|
| booking | 8001 | booking |
| movie | 8002 | movie |
| cinema | 8003 | cinema |
| user | 8004 | user |
| seat | 8005 | seat |
| showtime | 8006 | showtime |
| payment | 8007 | payment |
| notification | 8008 | notification |

**Full documentation**: [Configuration Guide](./configuration-guide.md)

---

## Deployment

### Deployment Options

| Environment | Method | Configuration |
|-------------|--------|---------------|
| Local | Docker Compose | `platform/deploy/docker-compose/` |
| Staging | Kubernetes | Harness pipeline |
| Production | Kubernetes | Harness + approval |

### Docker Compose (Local)

```bash
# Generate configuration first
task config:generate

# Start all services (uses platform/deploy/docker-compose/.env)
task dev:up

# Or manually with env file
docker compose --env-file platform/deploy/docker-compose/.env --profile dev up -d

# Start specific service
docker compose --env-file platform/deploy/docker-compose/.env --profile dev up -d booking

# View logs
task dev:logs SERVICE=booking

# Stop all
task dev:down

# Reset (including volumes)
docker compose --env-file platform/deploy/docker-compose/.env --profile dev down -v
```

> **Note**: Always use `platform/deploy/docker-compose/.env` to ensure ports match the centralized configuration.

**Full documentation**: [Docker Compose Deployment Guide](./docker-compose-deployment-guide.md)

### Kubernetes Deployment

Service manifests in `platform/deploy/k8s/`:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: booking
  labels:
    app: booking
spec:
  replicas: 2
  selector:
    matchLabels:
      app: booking
  template:
    metadata:
      labels:
        app: booking
    spec:
      containers:
        - name: booking
          image: ghcr.io/cinema-app/booking:latest
          ports:
            - containerPort: 8000
          env:
            - name: DB_SERVERS
              valueFrom:
                configMapKeyRef:
                  name: mongodb-config
                  key: servers
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
```

**Full documentation**: [Kubernetes Deployment Guide](./kubernetes-deployment-guide.md)

---

## Docker Infrastructure

### Centralized Dockerfile

All Go services use the same Dockerfile at `platform/docker/go-service/Dockerfile`:

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

ARG SERVICE_NAME
ARG VERSION=dev

WORKDIR /build
COPY services/${SERVICE_NAME}/ .
RUN go mod download
RUN CGO_ENABLED=0 go build -ldflags "-X main.Version=${VERSION}" \
    -o /app ./cmd/${SERVICE_NAME}

# Runtime stage
FROM alpine:3.19

RUN adduser -D -u 1000 appuser
COPY --from=builder /app /app

USER appuser
EXPOSE 8000

ENTRYPOINT ["/app"]
```

### Build Commands

```bash
# Using Taskfile
task build SERVICE=booking VERSION=1.0.0

# Using script
SERVICE=booking VERSION=1.0.0 platform/scripts/build-go-service.sh

# Direct Docker
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg VERSION=1.0.0 \
  -t cinema/booking:1.0.0 \
  .
```

### Image Tags

| Tag Pattern | Description |
|-------------|-------------|
| `latest` | Most recent build |
| `v1.2.3` | Semantic version |
| `{build-id}` | Pipeline build ID |
| `{commit-sha}` | Git commit SHA |

---

## Monitoring

### Health Checks

All services expose:

```
GET /health
Response: {"status": "ok", "service": "booking", "version": "1.0.0"}
```

### Logging

Structured JSON logs (Logrus):

```json
{
  "level": "info",
  "msg": "Request processed",
  "service": "booking",
  "trace_id": "abc123",
  "request_id": "req_xyz",
  "duration_ms": 45,
  "status": 200,
  "time": "2024-01-15T10:30:00Z"
}
```

### Metrics (Planned)

Prometheus metrics at `/metrics`:

```
# Service metrics
http_requests_total{service="booking", method="POST", status="200"}
http_request_duration_seconds{service="booking", method="POST"}

# Business metrics
bookings_created_total
payments_processed_total
seats_held_total
```

### Distributed Tracing (Planned)

OpenTelemetry + Jaeger for request tracing across services.

---

## Runbooks

### Service Not Starting

```bash
# Check container logs
docker logs booking

# Check if port is in use
lsof -i :8000

# Check environment variables
docker inspect booking | jq '.[0].Config.Env'
```

### MongoDB Connection Issues

```bash
# Check replica set status
docker exec mongo1 mongosh --eval "rs.status()"

# Check connectivity
docker exec booking ping mongo1

# Reinitialize replica set
docker exec mongo1 mongosh --eval "rs.initiate({...})"
```

### Pipeline Failure

1. Check Harness pipeline logs
2. Identify failing step
3. Run locally to reproduce:
   ```bash
   task test:unit SERVICE=<failing-service>
   ```
4. Fix and push

### Rollback Deployment

```bash
# Kubernetes rollback
kubectl rollout undo deployment/booking

# Or specify revision
kubectl rollout undo deployment/booking --to-revision=2
```

### Emergency Contacts

| Role | Contact |
|------|---------|
| On-call Engineer | Check PagerDuty |
| DevOps Lead | @devops-lead |
| SRE Team | #sre-support |

---

## Related Documentation

- [Architecture Overview](../architecture/README.md)
- [Development Guide](../development/README.md)
- [API Documentation](../api/README.md)
- [Contract Testing](../api/contracts.md)

### Operations Guides

- [Configuration Guide](./configuration-guide.md) - Centralized configuration system
- [Docker Compose Deployment Guide](./docker-compose-deployment-guide.md) - Local development setup
- [Kubernetes Deployment Guide](./kubernetes-deployment-guide.md) - K8s deployment with Harness
- [Debugging Runbook](./debugging-runbook.md) - Troubleshooting guide

---

## External Resources

- [Harness CI Documentation](https://developer.harness.io/docs/continuous-integration)
- [Harness Test Intelligence](https://developer.harness.io/docs/continuous-integration/use-ci/run-tests/ti-overview)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
