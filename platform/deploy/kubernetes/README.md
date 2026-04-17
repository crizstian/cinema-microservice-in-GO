# Kubernetes Deployment

Templated Kubernetes manifests for deploying Cinema microservices.

## Structure

```
kubernetes/
├── base/templates/          # Base manifest templates
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   └── networkpolicy.yaml
├── services/                # Service-specific values
│   ├── booking/values.yaml
│   ├── movie/values.yaml
│   ├── cinema/values.yaml
│   ├── user/values.yaml
│   ├── seat/values.yaml
│   ├── showtime/values.yaml
│   ├── payment/values.yaml
│   └── notification/values.yaml
├── environments/            # Environment-specific values
│   ├── dev/values.yaml
│   ├── staging/values.yaml
│   └── prod/values.yaml
├── infrastructure/          # Supporting infrastructure
│   ├── mongodb/
│   ├── jaeger/
│   └── ingress-nginx/
├── scripts/                 # Deployment scripts
│   ├── render.sh
│   ├── render-all.sh
│   ├── apply.sh
│   ├── apply-all.sh
│   ├── diff.sh
│   └── delete.sh
└── rendered/               # Generated manifests (gitignored)
```

## Quick Start

### 1. Render manifests

```bash
# Render single service
./scripts/render.sh booking dev v1.0.0

# Render all services for an environment
./scripts/render-all.sh dev v1.0.0
```

### 2. Preview changes

```bash
# Diff against cluster
./scripts/diff.sh booking dev
```

### 3. Apply to cluster

```bash
# Dry run first
./scripts/apply.sh booking dev --dry-run

# Apply single service
./scripts/apply.sh booking dev

# Apply all services
./scripts/apply-all.sh dev
```

### 4. Delete service

```bash
./scripts/delete.sh booking dev
```

## Environments

| Environment | Namespace | Replicas | Resources | Use Case |
|-------------|-----------|----------|-----------|----------|
| `dev` | cinema-dev | 1 | Minimal | Local/dev cluster |
| `staging` | cinema-staging | 2 | Moderate | Pre-production |
| `prod` | cinema-prod | 3 | Full | Production |

## Infrastructure Setup

Deploy infrastructure components first:

```bash
# 1. Ingress Controller
kubectl apply -f infrastructure/ingress-nginx/

# 2. MongoDB (set secrets first)
export MONGO_ROOT_USER=admin
export MONGO_ROOT_PASS=<password>
export MONGO_KEYFILE=$(openssl rand -base64 756)
export STORAGE_CLASS=standard
envsubst < infrastructure/mongodb/statefulset.yaml | kubectl apply -f -

# 3. Jaeger
export INGRESS_DOMAIN=dev.local
envsubst < infrastructure/jaeger/jaeger.yaml | kubectl apply -f -
```

## Template Variables

Templates use `${VARIABLE}` syntax, rendered via `envsubst`.

### Service Values
- `SERVICE_NAME`: Service identifier
- `SERVICE_PORT`: Container port
- `DB_NAME`: Database name
- `CPU_REQUEST`, `MEMORY_REQUEST`: Resource requests
- `CPU_LIMIT`, `MEMORY_LIMIT`: Resource limits
- `HPA_MIN_REPLICAS`, `HPA_MAX_REPLICAS`: Scaling bounds

### Environment Values
- `ENVIRONMENT`: dev|staging|prod
- `NAMESPACE`: Kubernetes namespace
- `IMAGE_REGISTRY`: Docker registry
- `VERSION`: Image tag
- `DB_SERVERS`, `DB_USER`, `DB_PASS`: Database config
- `INGRESS_HOST`: Ingress hostname
- `LOG_LEVEL`: debug|info|warn|error

## Best Practices

1. **Never use `latest` tag in production** - Always specify explicit versions
2. **Use namespaces** - Each environment has its own namespace
3. **Resource limits** - All containers have requests and limits
4. **Health checks** - Liveness and readiness probes configured
5. **Security context** - Non-root user, read-only filesystem
6. **Network policies** - Restrict inter-service communication
7. **PodDisruptionBudget** - Ensure availability during updates
8. **Anti-affinity** - Spread pods across nodes/zones

## CI/CD Integration

```yaml
# Example: Harness pipeline step
- step:
    name: Deploy to K8s
    type: Run
    spec:
      command: |
        cd platform/deploy/kubernetes
        ./scripts/render-all.sh ${ENVIRONMENT} ${VERSION}
        ./scripts/apply-all.sh ${ENVIRONMENT}
```

## Taskfile Commands

```bash
# Render manifests
task k8s:render SERVICE=booking ENV=dev VERSION=v1.0.0
task k8s:render:all ENV=dev VERSION=v1.0.0

# Apply to cluster
task k8s:apply SERVICE=booking ENV=dev
task k8s:apply:all ENV=dev

# Show diff
task k8s:diff SERVICE=booking ENV=dev

# Delete service
task k8s:delete SERVICE=booking ENV=dev
```
