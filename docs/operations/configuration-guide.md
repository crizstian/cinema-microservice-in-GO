# Centralized Configuration Guide

> **AI Agent Context**: This document describes the single source of truth configuration system for service properties across local development (Docker Compose) and remote deployment (Kubernetes + Harness).

**Last Updated**: 2026-04-20

---

## Overview

All service configuration is centralized in `platform/config/services.yaml`. This file generates:

- `platform/deploy/docker-compose/.env` - Variables for Docker Compose (local development)
- `platform/deploy/harness/services/*.yaml` - Harness Service definitions (remote deployment)
- `platform/deploy/kubernetes/values/services/*.yaml` - Templates using Harness expressions

```
┌─────────────────────────────────────────────────────────────────┐
│                    platform/config/services.yaml                         │
│                    (SINGLE SOURCE OF TRUTH)                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                   task config:all
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐  ┌────────────────┐  ┌────────────────────┐
│  platform/deploy/docker-compose/.env   │  │ harness/       │  │ k8s values/        │
│  (local)      │  │ services/      │  │ (templates)        │
└───────────────┘  └────────────────┘  └────────────────────┘
```

---

## Quick Start

```bash
# Generate all configuration files
task config:all

# Or generate individually
task config:generate   # platform/deploy/docker-compose/.env only
task config:harness    # Harness services only

# Validate configuration
task config:validate

# Show current service ports
task config:show
```

---

## Configuration File

### platform/config/services.yaml

```yaml
services:
  movie:
    port: 8002
    dbName: movie
    image: crizstian/movie-service
    resources:
      cpu_request: 50m
      mem_request: 64Mi
      cpu_limit: 250m
      mem_limit: 256Mi
    dependencies:
      - cinema-service

  booking:
    port: 8001
    dbName: booking
    image: crizstian/booking-service
    resources:
      cpu_request: 100m
      mem_request: 128Mi
      cpu_limit: 500m
      mem_limit: 512Mi
    dependencies:
      - seat-service
      - payment-service
      - showtime-service
      - notification-service
  
  # ... other services
```

### Service Properties

| Property | Description | Example |
|----------|-------------|---------|
| `port` | Service HTTP port | `8002` |
| `dbName` | MongoDB database name | `movie` |
| `image` | Docker image name | `crizstian/movie-service` |
| `resources.cpu_request` | K8s CPU request | `50m` |
| `resources.mem_request` | K8s memory request | `64Mi` |
| `resources.cpu_limit` | K8s CPU limit | `250m` |
| `resources.mem_limit` | K8s memory limit | `256Mi` |
| `dependencies` | Service dependencies | `[cinema-service]` |

---

## Local Development Flow

### Generated: platform/deploy/docker-compose/.env

```bash
# Environment prefix (determines container naming: dev-*, test-*)
ENV_PREFIX=dev

# MongoDB connection (REQUIRED for dev profile)
# - dev profile: mongo1:27017 (3-node replica set)
# - test profile: mongo:27017 (single node)
MONGO_SERVERS=mongo1:27017

# Service Ports
MOVIE_PORT=8002
BOOKING_PORT=8001
CINEMA_PORT=8003
USER_PORT=8004
SEAT_PORT=8005
SHOWTIME_PORT=8006
PAYMENT_PORT=8007
NOTIFICATION_PORT=8008

# Database Names
MOVIE_DB=movie
BOOKING_DB=booking
# ...

# Images
MOVIE_IMAGE=crizstian/movie-service
BOOKING_IMAGE=crizstian/booking-service
# ...
```

> **IMPORTANTE**: Si `MONGO_SERVERS` no está configurado, los servicios usarán el default `mongo:27017` que solo existe en el profile `test`. Para el profile `dev`, debe ser `mongo1:27017`.

### Docker Compose Usage

Docker Compose uses variables from `platform/deploy/docker-compose/.env`:

```yaml
# docker-compose.yml
movie:
  image: ${MOVIE_IMAGE:-crizstian/movie-service}:${VERSION:-dev}
  ports:
    - "${MOVIE_PORT:-8002}:${MOVIE_PORT:-8002}"
  environment:
    SERVICE_PORT: "${MOVIE_PORT:-8002}"
    DB_NAME: "${MOVIE_DB:-movie}"
```

### Starting Local Environment

```bash
# Generate config (if not already done)
task config:generate

# Start with env file
task dev:up

# Or manually
docker compose --env-file platform/deploy/docker-compose/.env --profile dev up -d
```

---

## Remote Deployment Flow (Harness + K8s)

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 HARNESS SERVICE                                 │
│            (SOURCE OF TRUTH - REMOTE)                           │
│                                                                 │
│  variables:                                                     │
│    - port: "8002"                                               │
│    - dbName: "movie"                                            │
│    - cpu_request: "50m"                                         │
└───────────────────────────┬─────────────────────────────────────┘
                            │
            Harness resolves expressions
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│         values/services/movie.yaml (TEMPLATE)                   │
│                                                                 │
│  serviceName: <+service.name>                                   │
│  port: <+serviceVariables.port>                                 │
│  dbName: <+serviceVariables.dbName>                             │
│  version: <+artifact.tag>                                       │
│  resources:                                                     │
│    requests:                                                    │
│      cpu: <+serviceVariables.cpu_request>                       │
│      memory: <+serviceVariables.mem_request>                    │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              K8s Manifests (rendered)                           │
│                                                                 │
│  Deployment:                                                    │
│    containerPort: 8002                                          │
│    image: crizstian/movie-service:v0.0.3                        │
│    resources:                                                   │
│      requests: { cpu: 50m, memory: 64Mi }                       │
│                                                                 │
│  Service:                                                       │
│    port: 8002                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### K8s Values Templates

Values files use Harness expressions:

```yaml
# platform/deploy/kubernetes/values/services/movie.yaml
serviceName: <+service.name>
version: <+artifact.tag>

port: <+serviceVariables.port>
dbName: <+serviceVariables.dbName>

resources:
  requests:
    cpu: <+serviceVariables.cpu_request>
    memory: <+serviceVariables.mem_request>
  limits:
    cpu: <+serviceVariables.cpu_limit>
    memory: <+serviceVariables.mem_limit>
```

### Harness Service Definition

Generated in `platform/deploy/harness/services/`:

```yaml
# movie-service.yaml
service:
  name: movie-service
  identifier: movieservice
  serviceDefinition:
    type: Kubernetes
    spec:
      manifests:
        - manifest:
            identifier: templates
            type: K8sManifest
            spec:
              store:
                type: Github
                spec:
                  connectorRef: CristianConnector
                  paths:
                    - platform/deploy/kubernetes/templates/services/
                  repoName: cinema-microservice-in-GO
                  branch: <+pipeline.variables.branch>
              valuesPaths:
                - platform/deploy/kubernetes/values/base.yaml
                - platform/deploy/kubernetes/values/environments/<+env.name>.yaml
                - platform/deploy/kubernetes/values/services/movie.yaml
      artifacts:
        primary:
          sources:
            - identifier: artifact
              type: DockerRegistry
              spec:
                connectorRef: DockerCristian
                imagePath: crizstian/movie-service
                tag: <+input>
      variables:
        - name: port
          type: String
          value: "8002"
        - name: dbName
          type: String
          value: "movie"
        - name: cpu_request
          type: String
          value: "50m"
        - name: mem_request
          type: String
          value: "64Mi"
        - name: cpu_limit
          type: String
          value: "250m"
        - name: mem_limit
          type: String
          value: "256Mi"
```

### Pipeline Usage

Pipelines use `<+serviceVariables.*>` for agnostic orchestration:

```yaml
# Harness Pipeline step
- step:
    type: ShellScript
    name: Validate Service
    spec:
      script: |
        curl -sf http://<+service.name>:<+serviceVariables.port>/health/live
```

---

## Workflow: Changing Configuration

### Step 1: Edit platform/config/services.yaml

```yaml
# Change movie port from 8002 to 8010
services:
  movie:
    port: 8010  # Changed
    dbName: movie
    # ...
```

### Step 2: Regenerate Files

```bash
task config:all
```

### Step 3: Commit and Push

```bash
git add config/ platform/deploy/docker-compose/.env platform/deploy/harness/
git commit -m "chore(config): update movie port to 8010"
git push
```

### Step 4: Sync Harness (optional)

If using Harness API:

```bash
# Via MCP
harness_update(
  resource_type='service',
  resource_id='movieservice',
  body={yaml: '<content from platform/deploy/harness/services/movie-service.yaml>'}
)
```

---

## Service Port Reference

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

---

## Taskfile Commands

| Command | Description |
|---------|-------------|
| `task config:generate` | Generate `platform/deploy/docker-compose/.env` from `platform/config/services.yaml` |
| `task config:harness` | Generate Harness service definitions |
| `task config:all` | Generate both `platform/deploy/docker-compose/.env` and Harness services |
| `task config:validate` | Validate `platform/config/services.yaml` YAML syntax |
| `task config:show` | Display current service configuration |

---

## Troubleshooting

### Port Mismatch Between Local and Remote

```bash
# Regenerate all config
task config:all

# Verify ports match
task config:show
cat platform/deploy/docker-compose/.env | grep PORT
```

### Harness Service Variables Not Resolving

1. Check that `<+serviceVariables.*>` syntax is correct in values.yaml
2. Verify Harness Service has the variable defined
3. Check pipeline logs for expression resolution errors

### Docker Compose Not Using platform/deploy/docker-compose/.env

```bash
# Explicitly specify env file
docker compose --env-file platform/deploy/docker-compose/.env --profile dev up -d

# Or update dev:up task to include --env-file flag
```

---

## Related Documentation

- [Development Guide](../development/README.md)
- [Kubernetes Deployment Guide](./kubernetes-deployment-guide.md)
- [Operations Overview](./README.md)
