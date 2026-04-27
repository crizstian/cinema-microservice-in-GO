# ArgoCD Installation Guide

Complete guide for installing ArgoCD on Kubernetes for the Cinema Microservices platform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Recommended: Helm Installation](#recommended-helm-installation)
4. [High Availability Setup](#high-availability-setup)
5. [Post-Installation Configuration](#post-installation-configuration)
6. [CLI Installation](#cli-installation)
7. [Integration with Harness GitOps](#integration-with-harness-gitops)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Kubernetes Cluster Requirements

| Component | Minimum | Recommended (HA) |
|-----------|---------|------------------|
| Kubernetes Version | 1.32+ | 1.34+ |
| Nodes | 1 | 3+ |
| CPU (total) | 2 cores | 4+ cores |
| Memory (total) | 4 GB | 8+ GB |
| Storage | 10 GB | 50+ GB (for repo caching) |

### Required Tools

```bash
# Verify kubectl
kubectl version --client

# Verify Helm (for Helm installation)
helm version

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### Network Requirements

| Port | Service | Description |
|------|---------|-------------|
| 443 | argocd-server | API/UI (HTTPS) |
| 80 | argocd-server | HTTP redirect |
| 8080 | argocd-server | gRPC (CLI) |
| 8082 | argocd-metrics | Prometheus metrics |
| 8083 | argocd-repo-server | Repo server metrics |

---

## Installation Methods

### Comparison

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Manifest (kubectl)** | Quick start, testing | Simple, official | Hard to customize |
| **Helm** | Production | Customizable, upgradable | Requires Helm |
| **Kustomize** | GitOps-native | Declarative | More complex |
| **Operator** | Enterprise | Lifecycle management | Heavier |

### Method 1: Quick Manifest Installation (Non-HA)

For testing and development only:

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### Method 2: HA Manifest Installation

For production without Helm:

```bash
# Create namespace
kubectl create namespace argocd

# Install HA version
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

---

## Recommended: Helm Installation

### Step 1: Add Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Step 2: Create Values File

Create `argocd-values.yaml`:

```yaml
# ArgoCD Helm Values for Cinema Microservices
# File: platform/deploy/gitops/argocd/values.yaml

global:
  domain: argocd.cinema.local

## Server Configuration
server:
  replicas: 2
  
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    hosts:
      - argocd.cinema.local
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.cinema.local

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Enable gRPC for CLI
  extraArgs:
    - --insecure  # Remove in production with proper TLS

## Controller Configuration
controller:
  replicas: 1
  
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

## Repo Server Configuration
repoServer:
  replicas: 2
  
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Enable Kustomize/Helm
  env:
    - name: ARGOCD_EXEC_TIMEOUT
      value: "5m"

## Redis (HA)
redis-ha:
  enabled: true
  replicas: 3
  
## Dex (OIDC/SSO)
dex:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 64Mi

## ApplicationSet Controller
applicationSet:
  enabled: true
  replicas: 2
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi

## Notifications Controller
notifications:
  enabled: true
  
  resources:
    requests:
      cpu: 50m
      memory: 64Mi

## Config
configs:
  params:
    # Application reconciliation timeout
    timeout.reconciliation: 180s
    
  cm:
    # Enable status badge
    statusbadge.enabled: "true"
    
    # Resource tracking method
    application.resourceTrackingMethod: annotation
    
    # Kustomize build options
    kustomize.buildOptions: --enable-helm --load-restrictor LoadRestrictionsNone

  rbac:
    policy.default: role:readonly
    policy.csv: |
      g, argocd-admins, role:admin
      g, developers, role:readonly

  secret:
    createSecret: true
```

### Step 3: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install with Helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd-values.yaml \
  --wait

# Verify installation
kubectl get pods -n argocd
kubectl get svc -n argocd
```

### Step 4: Get Initial Admin Password

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Save for later use
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
```

---

## High Availability Setup

### Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              Load Balancer               │
                    └─────────────────┬───────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │  ArgoCD Server    │   │  ArgoCD Server    │   │  ArgoCD Server    │
    │    (Replica 1)    │   │    (Replica 2)    │   │    (Replica 3)    │
    └─────────┬─────────┘   └─────────┬─────────┘   └─────────┬─────────┘
              │                       │                       │
              └───────────────────────┼───────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │  Redis Sentinel   │   │  Redis Sentinel   │   │  Redis Sentinel   │
    │    (Replica 1)    │   │    (Replica 2)    │   │    (Replica 3)    │
    └───────────────────┘   └───────────────────┘   └───────────────────┘
              │                       │                       │
              └───────────────────────┼───────────────────────┘
                                      │
                          ┌───────────▼───────────┐
                          │  Application          │
                          │  Controller           │
                          │  (Single Leader)      │
                          └───────────────────────┘
```

### HA Values Override

```yaml
# argocd-ha-values.yaml
server:
  replicas: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 5
  pdb:
    enabled: true
    minAvailable: 2
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app.kubernetes.io/name: argocd-server
          topologyKey: kubernetes.io/hostname

controller:
  replicas: 1  # Controller uses leader election
  env:
    - name: ARGOCD_CONTROLLER_REPLICAS
      value: "1"

repoServer:
  replicas: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 5
  pdb:
    enabled: true
    minAvailable: 2

redis-ha:
  enabled: true
  replicas: 3
  haproxy:
    enabled: true
    replicas: 3

applicationSet:
  replicas: 2
```

---

## Post-Installation Configuration

### 1. Access ArgoCD UI

```bash
# Option 1: Port Forward (Development)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Option 2: LoadBalancer (Cloud)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Option 3: Ingress (Recommended)
# Already configured in Helm values
```

### 2. Login via CLI

```bash
# Install CLI (see CLI Installation section)
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

# Change password
argocd account update-password
```

### 3. Add Git Repository

```bash
# Via CLI
argocd repo add https://github.com/crizstian/cinema-microservice-in-GO.git \
  --username git \
  --password $GITHUB_TOKEN \
  --name cinema-repo

# Via manifest
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cinema-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/crizstian/cinema-microservice-in-GO.git
  username: git
  password: ${GITHUB_TOKEN}
EOF
```

### 4. Add Kubernetes Cluster

```bash
# For external clusters
argocd cluster add <context-name> --name production

# Via manifest (service account method)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: prod-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: production
  server: https://35.231.43.35
  config: |
    {
      "bearerToken": "<service-account-token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-ca-cert>"
      }
    }
EOF
```

### 5. Create AppProject

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: cinema
  namespace: argocd
spec:
  description: Cinema Microservices Project
  
  sourceRepos:
    - https://github.com/crizstian/cinema-microservice-in-GO.git
  
  destinations:
    - namespace: cinema-*
      server: https://kubernetes.default.svc
    - namespace: cinema-*
      server: https://35.231.43.35
  
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
  
  roles:
    - name: developer
      description: Developer access
      policies:
        - p, proj:cinema:developer, applications, get, cinema/*, allow
        - p, proj:cinema:developer, applications, sync, cinema/*, allow
      groups:
        - developers
EOF
```

### 6. Bootstrap Applications

```bash
# Apply the bootstrap application created earlier
kubectl apply -f platform/deploy/gitops/argocd/apps/cinema-bootstrap.yaml

# Verify
argocd app list
```

---

## CLI Installation

### Linux

```bash
# Latest version
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Verify
argocd version --client
```

### macOS

```bash
# Homebrew
brew install argocd

# Or manual
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-arm64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

### Windows

```powershell
# Chocolatey
choco install argocd-cli

# Or Scoop
scoop install argocd
```

---

## Integration with Harness GitOps

### Register ArgoCD Agent

1. In Harness, go to **GitOps** > **Agents**
2. Click **+ New Agent**
3. Select **Existing ArgoCD** or **Harness Managed**
4. Copy the agent installation manifest
5. Apply to cluster:

```bash
kubectl apply -f harness-gitops-agent.yaml -n argocd
```

### Configure Repository in Harness

1. Go to **GitOps** > **Repositories**
2. Add repository with same credentials
3. Verify sync status

### Link ApplicationSets

The Harness GitOps service references ApplicationSets via labels:

```yaml
labels:
  harness.io/serviceRef: cinema-services-gitops
  harness.io/envRef: dev
  harness.io/buildRef: v1.0.0
```

---

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n argocd
kubectl describe pod <pod-name> -n argocd

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

#### Repository Connection Failed

```bash
# Test repository access
argocd repo list
argocd repo get https://github.com/crizstian/cinema-microservice-in-GO.git

# Check repo-server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

#### Application Sync Failed

```bash
# Get app status
argocd app get <app-name>

# Get detailed diff
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force --prune

# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

#### Out of Memory

```bash
# Increase controller memory
kubectl patch deployment argocd-application-controller -n argocd \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-application-controller","resources":{"limits":{"memory":"2Gi"}}}]}}}}'
```

### Health Checks

```bash
# API health
curl -k https://localhost:8080/api/v1/health

# Check all components
kubectl get pods -n argocd -o wide
argocd admin dashboard
```

---

## Quick Reference

### Essential Commands

```bash
# Login
argocd login <server> --username admin --password <password>

# List applications
argocd app list

# Sync application
argocd app sync <name>

# Get app details
argocd app get <name>

# Delete application
argocd app delete <name>

# Rollback
argocd app rollback <name> <revision>
```

### Useful Aliases

```bash
alias acd='argocd'
alias acda='argocd app'
alias acdal='argocd app list'
alias acdas='argocd app sync'
alias acdag='argocd app get'
```

---

## Sources

- [ArgoCD Official Installation Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [ArgoCD Complete Guide 2026](https://devtoolbox.dedyn.io/blog/argocd-complete-guide)
- [Setting up ArgoCD with Helm](https://www.arthurkoziel.com/setting-up-argocd-with-helm/)
