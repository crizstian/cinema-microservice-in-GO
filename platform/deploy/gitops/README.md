# Cinema Microservices - GitOps Configuration

This directory contains the GitOps configuration for deploying Cinema microservices using ArgoCD and Harness GitOps.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GITOPS DEPLOYMENT FLOW                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────┐      ┌──────────────────┐      ┌────────────────┐ │
│  │ Harness Pipeline │ ──▶  │  Update config   │ ──▶  │  ArgoCD Sync   │ │
│  │ CD-cinema-gitops │      │  (PR workflow)   │      │  (Auto/Manual) │ │
│  └──────────────────┘      └──────────────────┘      └────────────────┘ │
│                                                                          │
│  cluster-config/           services/<svc>/           appsets/           │
│  └── <env>/                ├── base/                 └── cinema-        │
│      └── config.json       └── overlays/<env>/           services.yaml  │
│          (variables)           (kustomize)               (AppSet)       │
└─────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
platform/deploy/gitops/
├── README.md                           # This file
├── cluster-config/                     # Cluster configurations (Git Generator)
│   ├── dev/
│   │   └── config.json                 # Dev cluster variables
│   ├── staging/
│   │   └── config.json                 # Staging cluster variables
│   └── prod/
│       └── config.json                 # Production cluster variables
├── services/                           # Kustomize manifests per service
│   ├── booking/
│   │   ├── base/                       # Base manifests
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── hpa.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/                   # Environment-specific overlays
│   │       ├── dev/
│   │       ├── staging/
│   │       └── prod/
│   ├── cinema/
│   ├── movie/
│   ├── notification/
│   ├── payment/
│   ├── seat/
│   ├── showtime/
│   └── user/
├── appsets/                            # ArgoCD ApplicationSets
│   ├── cinema-services-matrix.yaml     # Matrix generator (cluster × service)
│   └── cinema-services-single-env.yaml # Simple list generator for dev
├── argocd/
│   └── apps/
│       └── cinema-bootstrap.yaml       # Bootstrap Application
└── scripts/
    └── generate-services.sh            # Script to regenerate service manifests
```

## Cluster Configuration

Each cluster has a `config.json` file with variables used by the ApplicationSet:

```json
{
  "cluster_name": "dev",
  "environment": "dev",
  "namespace": "cinema-dev",
  "server_address": "https://kubernetes.default.svc",
  "image_registry": "crizstian",
  "image_tag": "latest",
  "replicas": 1,
  "resources": { ... },
  "database": { ... },
  "nats": { ... }
}
```

### Adding a New Cluster

1. Create a new directory: `cluster-config/<cluster-name>/`
2. Add `config.json` with cluster-specific values
3. The ApplicationSet will auto-discover and create Applications

## Services

### Available Services

| Service | Port | Database | Dependencies |
|---------|------|----------|--------------|
| booking | 8001 | booking | seat, payment, showtime, notification |
| cinema | 8003 | cinema | - |
| movie | 8002 | movie | cinema |
| notification | 8008 | notification | - |
| payment | 8007 | payment | - |
| seat | 8005 | seat | showtime |
| showtime | 8006 | showtime | movie, cinema |
| user | 8004 | user | - |

### Kustomize Structure

Each service follows the Kustomize base/overlay pattern:

- **base/**: Common manifests (Deployment, Service, ConfigMap, HPA)
- **overlays/dev/**: Development overrides (1 replica, debug logging)
- **overlays/staging/**: Staging overrides (2 replicas, info logging)
- **overlays/prod/**: Production overrides (3 replicas, warn logging, node selectors)

### Regenerating Service Manifests

```bash
./scripts/generate-services.sh
```

## Harness Integration

### GitOps Service

The Harness GitOps service is defined in:
- `.harness/services/gitops/cinema-services.yaml`

It references:
- **ReleaseRepo**: `platform/deploy/gitops/cluster-config/<+cluster.name>/config.json`
- **DeploymentRepo**: `platform/deploy/gitops/appsets/cinema-services-matrix.yaml`

### GitOps Pipeline

The deployment pipeline is defined in:
- `.harness/pipelines/CD/CD-cinema-gitops.yaml`

**Stages:**
1. **Dev**: Deploy to development with PR approval
2. **Staging Gate**: Manual approval for staging
3. **Staging**: Deploy to staging
4. **Prod Gate**: Manual approval (2 approvers, no self-approve)
5. **Prod**: Deploy to production with final PR review

### Labels for Harness Tracking

All resources include labels for Harness GitOps integration:

```yaml
labels:
  harness.io/serviceRef: <service>-service-gitops
  harness.io/envRef: <environment>
  harness.io/buildRef: <image_tag>
```

## ArgoCD ApplicationSets

### Matrix Generator (Recommended)

`cinema-services-matrix.yaml` uses a matrix generator combining:
- **Git Generator**: Discovers clusters from `cluster-config/*/config.json`
- **List Generator**: Defines services to deploy

This creates Applications in the format: `<service>-<environment>`

### Single Environment Generator

`cinema-services-single-env.yaml` is a simpler approach for single environments.

## Deployment Workflow

### Via Harness Pipeline

1. Trigger pipeline with `SERVICE_NAME` and artifact tag
2. Pipeline updates `config.json` and creates PR
3. PR approval triggers merge
4. ArgoCD syncs automatically

### Manual Deployment

```bash
# Update image tag in overlay
cd platform/deploy/gitops/services/booking/overlays/dev
kustomize edit set image crizstian/booking-service:v1.0.1

# Commit and push
git add .
git commit -m "feat: update booking-service to v1.0.1"
git push

# ArgoCD will auto-sync (or manual sync via UI/CLI)
argocd app sync booking-dev
```

## Bootstrap

To deploy the ApplicationSets to ArgoCD:

```bash
kubectl apply -f platform/deploy/gitops/argocd/apps/cinema-bootstrap.yaml
```

This creates a meta-Application that manages all ApplicationSets.

## Validation

```bash
# Validate Kustomize build
kustomize build platform/deploy/gitops/services/booking/overlays/dev

# Validate all services
for svc in booking cinema movie notification payment seat showtime user; do
  echo "Validating $svc..."
  kustomize build platform/deploy/gitops/services/$svc/overlays/dev > /dev/null
done
```

## Troubleshooting

### Application Out of Sync

```bash
argocd app get <app-name>
argocd app diff <app-name>
argocd app sync <app-name> --force
```

### Config Not Updating

1. Check `config.json` was committed and pushed
2. Verify ApplicationSet generator is watching correct path
3. Check ArgoCD ApplicationSet controller logs

### Rollback

Via Harness pipeline rollback or manually:

```bash
argocd app rollback <app-name> <revision>
```
