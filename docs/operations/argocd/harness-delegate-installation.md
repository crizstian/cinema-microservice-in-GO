# Harness Delegate Installation Guide

Complete guide for installing Harness Delegate, required for GitOps and CD operations.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation Methods](#installation-methods)
4. [Helm Installation (Recommended)](#helm-installation-recommended)
5. [Kubernetes Manifest Installation](#kubernetes-manifest-installation)
6. [Docker Installation](#docker-installation)
7. [Terraform Installation](#terraform-installation)
8. [Authentication Methods](#authentication-methods)
9. [GitOps Integration](#gitops-integration)
10. [Verification](#verification)
11. [Troubleshooting](#troubleshooting)

---

## Overview

### What is a Harness Delegate?

The Harness Delegate is a lightweight worker process installed in your infrastructure that:

- Communicates **outbound only** via HTTPS to Harness Platform
- Executes CI/CD tasks on your behalf
- Keeps secrets within your network
- Manages connections to clusters, repos, and cloud providers

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         YOUR INFRASTRUCTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────────────┐         ┌──────────────────────────────────┐     │
│   │ Harness Delegate │ ◄─────► │     Kubernetes Clusters          │     │
│   │  (Worker Pod)    │         │  • Dev (incluster)               │     │
│   └────────┬─────────┘         │  • Staging                       │     │
│            │                   │  • Prod                          │     │
│            │ HTTPS (443)       └──────────────────────────────────┘     │
│            │ Outbound Only                                              │
│            ▼                                                            │
│   ┌──────────────────┐         ┌──────────────────────────────────┐     │
│   │ Harness Platform │         │     GitOps Agent (ArgoCD)        │     │
│   │ (app.harness.io) │         │  • Syncs Applications            │     │
│   └──────────────────┘         │  • Manages Deployments           │     │
│                                └──────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Delegate vs GitOps Agent

| Component | Purpose | Required For |
|-----------|---------|--------------|
| **Delegate** | General worker for Harness tasks | CD, CI, Git operations, PR pipelines |
| **GitOps Agent** | ArgoCD-based deployment agent | GitOps sync, Application management |

**Note:** For full GitOps functionality (PR pipelines, Git operations), you need **both** Delegate and GitOps Agent.

---

## Prerequisites

### Resource Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 0.5 cores | 1+ cores |
| Memory | 2 GB | 4 GB |
| Storage | 1 GB | 10 GB |
| Replicas | 1 | 2+ (HA) |

### Network Requirements

Outbound HTTPS (443) access to:

| Endpoint | Purpose |
|----------|---------|
| `app.harness.io` | Harness SaaS (prod-1) |
| `app.harness.io/gratis` | Harness SaaS (prod-2) |
| `app3.harness.io` | Harness SaaS (prod-3) |
| `github.com` | Git operations |
| `hub.docker.com` | Container images |

### Kubernetes Requirements

```bash
# Verify cluster access
kubectl cluster-info
kubectl auth can-i create deployments --all-namespaces

# Verify Helm (for Helm installation)
helm version
```

### Generate Delegate Token

1. Go to **Harness** → **Account Settings** → **Account Resources** → **Delegates**
2. Click **Tokens** tab → **+ New Token**
3. Name: `cinema-delegate-token`
4. Copy and save the token securely

### Get Account ID

Extract from your Harness URL:
```
https://app.harness.io/ng/#/account/ACCOUNT_ID_HERE/...
```

---

## Installation Methods

| Method | Best For | Complexity |
|--------|----------|------------|
| **Helm** | Production, Kubernetes | Low |
| **Kubernetes YAML** | Custom configurations | Medium |
| **Docker** | Local testing, VMs | Low |
| **Terraform** | IaC, automation | Medium |

---

## Helm Installation (Recommended)

### Step 1: Add Helm Repository

```bash
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
helm repo update
helm search repo harness-delegate
```

### Step 2: Create Values File

```yaml
# delegate-values.yaml
# Harness Delegate Helm Values for Cinema Microservices

# Account configuration
accountId: "YOUR_ACCOUNT_ID"
delegateToken: "YOUR_DELEGATE_TOKEN"
managerEndpoint: "https://app.harness.io"
delegateName: "cinema-delegate"

# Deployment configuration
replicas: 2

# Resource limits
resources:
  limits:
    cpu: "1"
    memory: "4Gi"
  requests:
    cpu: "0.5"
    memory: "2Gi"

# Namespace
namespace: harness-delegate-ng

# Tags for delegate selection
tags: "cinema,kubernetes,gitops"

# Node selector (match your cluster config)
nodeSelector:
  owner: cristian-ramirez

tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "selatam_demo_space"
    effect: "NoSchedule"

# Init script for custom tools
initScript: |
  # Install additional tools
  microdnf install -y git
  
# Proxy configuration (if needed)
# proxy:
#   http: "http://proxy.example.com:8080"
#   https: "http://proxy.example.com:8080"
#   no: "localhost,127.0.0.1,.cluster.local"

# Auto-upgrade
upgrader:
  enabled: true

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

### Step 3: Install Delegate

```bash
# Create namespace
kubectl create namespace harness-delegate-ng

# Install with Helm
helm upgrade --install cinema-delegate \
  harness-delegate/harness-delegate-ng \
  --namespace harness-delegate-ng \
  --values delegate-values.yaml \
  --wait

# Verify pods
kubectl get pods -n harness-delegate-ng
```

### Step 4: Verify in Harness UI

1. Go to **Account Settings** → **Delegates**
2. Wait for delegate to appear (2-5 minutes)
3. Status should show **Connected**

---

## Kubernetes Manifest Installation

### Step 1: Download Manifest from Harness UI

1. Go to **Account Settings** → **Delegates** → **+ New Delegate**
2. Select **Kubernetes**
3. Download the YAML manifest

### Step 2: Customize Manifest

```yaml
# harness-delegate.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: harness-delegate-ng

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: harness-delegate-ng-cluster-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: harness-delegate-ng
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: v1
kind: Secret
metadata:
  name: cinema-delegate-token
  namespace: harness-delegate-ng
type: Opaque
data:
  DELEGATE_TOKEN: "YOUR_BASE64_ENCODED_TOKEN"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cinema-delegate
  namespace: harness-delegate-ng
  labels:
    harness.io/name: cinema-delegate
spec:
  replicas: 2
  selector:
    matchLabels:
      harness.io/name: cinema-delegate
  template:
    metadata:
      labels:
        harness.io/name: cinema-delegate
    spec:
      serviceAccountName: default
      containers:
        - name: delegate
          image: harness/delegate:24.04.82901
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
          resources:
            limits:
              cpu: "1"
              memory: "4Gi"
            requests:
              cpu: "0.5"
              memory: "2Gi"
          env:
            - name: JAVA_OPTS
              value: "-Xms1g -Xmx2g"
            - name: ACCOUNT_ID
              value: YOUR_ACCOUNT_ID
            - name: MANAGER_HOST_AND_PORT
              value: https://app.harness.io
            - name: DEPLOY_MODE
              value: KUBERNETES
            - name: DELEGATE_NAME
              value: cinema-delegate
            - name: DELEGATE_TYPE
              value: KUBERNETES
            - name: DELEGATE_TAGS
              value: "cinema,kubernetes,gitops"
            - name: DELEGATE_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cinema-delegate-token
                  key: DELEGATE_TOKEN
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3460
            initialDelaySeconds: 20
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3460
            initialDelaySeconds: 20
            periodSeconds: 10
```

### Step 3: Apply Manifest

```bash
# Encode token
export DELEGATE_TOKEN_B64=$(echo -n "YOUR_TOKEN" | base64)

# Replace placeholder and apply
sed "s/YOUR_BASE64_ENCODED_TOKEN/$DELEGATE_TOKEN_B64/g" harness-delegate.yaml | kubectl apply -f -

# Verify
kubectl get pods -n harness-delegate-ng
kubectl logs -f -n harness-delegate-ng -l harness.io/name=cinema-delegate
```

---

## Docker Installation

For local development or VM-based deployments.

```bash
# Run delegate container
docker run -d --name cinema-delegate \
  --cpus=1 \
  --memory=2g \
  -e DELEGATE_NAME=cinema-delegate \
  -e ACCOUNT_ID=YOUR_ACCOUNT_ID \
  -e DELEGATE_TOKEN=YOUR_DELEGATE_TOKEN \
  -e MANAGER_HOST_AND_PORT=https://app.harness.io \
  -e DELEGATE_TAGS="cinema,docker" \
  -e DELEGATE_TYPE=DOCKER \
  -e DEPLOY_MODE=DOCKER \
  harness/delegate:24.04.82901

# View logs
docker logs -f cinema-delegate

# Check status
docker ps
```

---

## Terraform Installation

```hcl
# main.tf
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

variable "harness_account_id" {
  description = "Harness Account ID"
  type        = string
}

variable "harness_delegate_token" {
  description = "Harness Delegate Token"
  type        = string
  sensitive   = true
}

resource "helm_release" "harness_delegate" {
  name             = "cinema-delegate"
  repository       = "https://app.harness.io/storage/harness-download/delegate-helm-chart/"
  chart            = "harness-delegate-ng"
  namespace        = "harness-delegate-ng"
  create_namespace = true

  set {
    name  = "accountId"
    value = var.harness_account_id
  }

  set_sensitive {
    name  = "delegateToken"
    value = var.harness_delegate_token
  }

  set {
    name  = "managerEndpoint"
    value = "https://app.harness.io"
  }

  set {
    name  = "delegateName"
    value = "cinema-delegate"
  }

  set {
    name  = "replicas"
    value = "2"
  }

  set {
    name  = "tags"
    value = "cinema\\,kubernetes\\,gitops"
  }
}
```

```bash
# Apply
terraform init
terraform apply \
  -var="harness_account_id=YOUR_ACCOUNT_ID" \
  -var="harness_delegate_token=YOUR_TOKEN"
```

---

## Authentication Methods

### Overview: Delegate vs Service Account

When connecting to Kubernetes clusters in Harness, you have two authentication options:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION METHODS                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────┐    ┌─────────────────────────────────┐ │
│  │  DELEGATE CREDENTIALS       │    │  SERVICE ACCOUNT TOKEN          │ │
│  │  (Inherited)                │    │  (Explicit)                     │ │
│  ├─────────────────────────────┤    ├─────────────────────────────────┤ │
│  │                             │    │                                 │ │
│  │  Delegate Pod               │    │  Kubernetes API                 │ │
│  │    ↓                        │    │    ↑                            │ │
│  │  Service Account            │    │  Service Account Token          │ │
│  │    ↓                        │    │    ↑                            │ │
│  │  RBAC (cluster-admin)       │    │  Harness Connector              │ │
│  │    ↓                        │    │    ↑                            │ │
│  │  Kubernetes API             │    │  Harness Platform               │ │
│  │                             │    │                                 │ │
│  └─────────────────────────────┘    └─────────────────────────────────┘ │
│                                                                          │
│  USE WHEN:                          USE WHEN:                           │
│  • Same cluster as delegate         • External clusters                 │
│  • Simplest setup                   • Cross-cluster deployments         │
│  • Agent has cluster-admin          • Docker delegates                  │
│  • In-cluster GitOps                • Specific namespace access         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Method 1: Delegate Credentials (Inherited)

The delegate uses its own Kubernetes service account permissions.

**Pros:**
- Simplest configuration
- No token management
- Automatic credential rotation

**Cons:**
- Requires delegate in target cluster
- Delegate needs cluster-admin role
- Not suitable for Docker delegates

**Configuration in Harness:**

1. **For Kubernetes Connector:**
   - Go to **Connectors** → **+ New Connector** → **Kubernetes Cluster**
   - Select **Use the credentials of a specific Harness Delegate**
   - Choose your delegate

2. **For GitOps Cluster:**
   - Go to **GitOps** → **Settings** → **Clusters** → **+ New Cluster**
   - Select **Use the credentials of a specific Harness GitOps Agent**
   - Choose your agent

**Required RBAC:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: harness-delegate-cluster-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: harness-delegate-ng
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

### Method 2: Service Account Token (Explicit)

Provide explicit credentials for cluster access.

**Pros:**
- Works with external clusters
- Fine-grained access control
- Works with Docker delegates
- Multi-cluster support

**Cons:**
- Token management required
- Manual rotation
- More configuration

**Create Service Account:**

```bash
# Create namespace (if needed)
kubectl create namespace harness-system

# Create service account
kubectl create serviceaccount harness-connector -n harness-system

# Create cluster role binding
kubectl create clusterrolebinding harness-connector-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=harness-system:harness-connector

# Generate long-lived token (Kubernetes 1.24+)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: harness-connector-token
  namespace: harness-system
  annotations:
    kubernetes.io/service-account.name: harness-connector
type: kubernetes.io/service-account-token
EOF

# Get token
kubectl get secret harness-connector-token -n harness-system \
  -o jsonpath='{.data.token}' | base64 -d

# Get CA certificate
kubectl get secret harness-connector-token -n harness-system \
  -o jsonpath='{.data.ca\.crt}' | base64 -d

# Get master URL
kubectl cluster-info | grep "Kubernetes control plane"
```

**Configuration in Harness:**

1. **For Kubernetes Connector:**
   - Select **Specify Master URL and Credentials**
   - Enter Master URL: `https://35.231.43.35`
   - Authentication: **Service Account**
   - Paste Service Account Token

2. **For GitOps Cluster:**
   - Select **Specify Kubernetes Cluster URL and credentials**
   - Enter Master URL
   - Select **Service Account** authentication
   - Paste token

### Comparison Table

| Aspect | Delegate Credentials | Service Account Token |
|--------|---------------------|----------------------|
| Setup complexity | Low | Medium |
| External clusters | No | Yes |
| Docker delegates | No | Yes |
| Token rotation | Automatic | Manual |
| Fine-grained RBAC | No (uses delegate SA) | Yes |
| GitOps same cluster | Recommended | Alternative |
| GitOps external cluster | Not possible | Required |
| CI Build infrastructure | Sometimes not compatible | Always works |

### Recommended Setup for Cinema Project

| Cluster | Environment | Auth Method | Reason |
|---------|-------------|-------------|--------|
| `incluster` | dev | Delegate Credentials | Same cluster as delegate |
| `incluster` | staging | Delegate Credentials | Same cluster as delegate |
| `seprod` | prod | Service Account Token | External cluster |

---

## GitOps Integration

### Delegate + GitOps Agent Relationship

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLUSTER: incluster                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Namespace: harness-delegate-ng        Namespace: argocd               │
│   ┌─────────────────────────┐          ┌─────────────────────────┐      │
│   │   Harness Delegate      │          │   GitOps Agent          │      │
│   │   ─────────────────     │          │   (ArgoCD)              │      │
│   │   • CD Pipeline steps   │          │   ─────────────────     │      │
│   │   • Git operations      │    ┌───► │   • App sync            │      │
│   │   • PR creation/merge   │    │     │   • Manifest render     │      │
│   │   • Artifact fetch      │    │     │   • Health check        │      │
│   └───────────┬─────────────┘    │     └─────────────────────────┘      │
│               │                  │                                       │
│               │  Triggers        │                                       │
│               └──────────────────┘                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### What Each Component Does in GitOps Pipeline

| Pipeline Step | Executed By | Component |
|---------------|-------------|-----------|
| `GitOpsUpdateReleaseRepo` | Delegate | Git operations (PR creation) |
| `MergePR` | Delegate | Git operations |
| `GitOpsFetchLinkedApps` | GitOps Agent | ArgoCD API |
| `GitOpsSync` | GitOps Agent | ArgoCD sync |

### Required Setup Order

1. **Install Harness Delegate** (this guide)
2. **Install GitOps Agent** (ArgoCD)
3. **Configure Repository** (Git connector)
4. **Configure Cluster** (using appropriate auth method)
5. **Create ApplicationSet**
6. **Create GitOps Service**
7. **Create Pipeline**

---

## Verification

### Check Delegate Status

```bash
# Kubernetes pods
kubectl get pods -n harness-delegate-ng
kubectl describe pod -n harness-delegate-ng -l harness.io/name=cinema-delegate

# Logs
kubectl logs -f -n harness-delegate-ng -l harness.io/name=cinema-delegate

# Health endpoint
kubectl port-forward -n harness-delegate-ng svc/cinema-delegate 3460:3460
curl http://localhost:3460/api/health
```

### Verify in Harness UI

1. **Account Settings** → **Delegates**
2. Check for:
   - Status: **Connected**
   - Heartbeat: **Recent** (< 1 minute)
   - Tags: `cinema,kubernetes,gitops`

### Test Delegate Connectivity

```bash
# Create test connector
# Harness UI → Connectors → + New Connector → Kubernetes Cluster
# Select delegate and verify connection
```

---

## Troubleshooting

### Common Issues

#### Delegate Pod CrashLoopBackOff

```bash
# Check resources
kubectl describe pod -n harness-delegate-ng <pod-name>
kubectl top pods -n harness-delegate-ng

# Increase resources in values.yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "1"
```

#### Delegate Not Appearing in UI

```bash
# Check logs for connection errors
kubectl logs -n harness-delegate-ng -l harness.io/name=cinema-delegate | grep -i error

# Verify network connectivity
kubectl exec -n harness-delegate-ng <pod-name> -- curl -v https://app.harness.io

# Check token
kubectl get secret -n harness-delegate-ng
```

#### Delegate Disconnected

```bash
# Check heartbeat
kubectl logs -n harness-delegate-ng -l harness.io/name=cinema-delegate | grep heartbeat

# Restart delegate
kubectl rollout restart deployment/cinema-delegate -n harness-delegate-ng
```

#### Authentication Failures

```bash
# For Service Account issues
kubectl auth can-i --as=system:serviceaccount:harness-system:harness-connector \
  create deployments --all-namespaces

# Verify token is valid
kubectl get secret harness-connector-token -n harness-system -o yaml
```

### Logs to Check

```bash
# Delegate logs
kubectl logs -n harness-delegate-ng -l harness.io/name=cinema-delegate --tail=100

# Filter for errors
kubectl logs -n harness-delegate-ng -l harness.io/name=cinema-delegate | grep -i "error\|fail\|exception"

# Docker delegate
docker logs cinema-delegate 2>&1 | tail -100
```

---

## Quick Reference

### Helm Commands

```bash
# Install
helm upgrade --install cinema-delegate harness-delegate/harness-delegate-ng \
  -n harness-delegate-ng --create-namespace -f delegate-values.yaml

# Upgrade
helm upgrade cinema-delegate harness-delegate/harness-delegate-ng \
  -n harness-delegate-ng -f delegate-values.yaml

# Uninstall
helm uninstall cinema-delegate -n harness-delegate-ng
```

### kubectl Commands

```bash
# Status
kubectl get pods -n harness-delegate-ng

# Logs
kubectl logs -f -n harness-delegate-ng -l harness.io/name=cinema-delegate

# Restart
kubectl rollout restart deployment/cinema-delegate -n harness-delegate-ng

# Describe
kubectl describe deployment/cinema-delegate -n harness-delegate-ng
```

---

## Sources

- [Delegate Installation Overview](https://developer.harness.io/docs/platform/delegates/install-delegates/overview/)
- [Install Delegate Tutorial](https://developer.harness.io/docs/platform/get-started/tutorials/install-delegate/)
- [Kubernetes Cluster Connector Settings](https://developer.harness.io/docs/platform/connectors/cloud-providers/ref-cloud-providers/kubernetes-cluster-connector-settings-reference/)
- [Harness GitOps Basics](https://developer.harness.io/docs/continuous-delivery/gitops/get-started/harness-git-ops-basics/)
