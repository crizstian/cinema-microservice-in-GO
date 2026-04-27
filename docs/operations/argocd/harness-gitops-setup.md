# Harness GitOps Configuration Guide

Complete guide for configuring GitOps elements in Harness Platform for the Cinema Microservices project.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Install GitOps Agent](#step-1-install-gitops-agent)
   - [Option A: Via Harness UI](#option-a-via-harness-ui)
   - [Option B: Via Terraform](#option-b-via-terraform)
   - [Option C: BYOA (Current Installation)](#option-c-byoa-bring-your-own-argocd---current-installation)
4. [Step 2: Configure Repository](#step-2-configure-repository)
5. [Step 3: Add Cluster](#step-3-add-cluster)
6. [Step 4: Create GitOps Application](#step-4-create-gitops-application)
7. [Step 5: Configure ApplicationSets](#step-5-configure-applicationsets)
8. [Step 6: Create GitOps Service](#step-6-create-gitops-service)
9. [Step 7: Create GitOps Pipeline](#step-7-create-gitops-pipeline)
10. [Verification](#verification)
11. [Troubleshooting](#troubleshooting)

---

## Overview

### Harness GitOps Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        HARNESS PLATFORM                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │  GitOps     │  │  GitOps     │  │  GitOps     │  │  GitOps     │    │
│  │  Agent      │  │  Repository │  │  Cluster    │  │  Application│    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         │                │                │                │            │
│         └────────────────┴────────────────┴────────────────┘            │
│                                   │                                      │
│                    ┌──────────────▼──────────────┐                      │
│                    │       GitOps Service        │                      │
│                    │   (Links Apps + Pipeline)   │                      │
│                    └──────────────┬──────────────┘                      │
│                                   │                                      │
│                    ┌──────────────▼──────────────┐                      │
│                    │      GitOps Pipeline        │                      │
│                    │  (Update → PR → Sync)       │                      │
│                    └─────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │     Kubernetes Cluster      │
                    │   (ArgoCD Agent Running)    │
                    └─────────────────────────────┘
```

### GitOps Entities Hierarchy

| Entity | Scope | Description |
|--------|-------|-------------|
| **Agent** | Account/Project | Worker process that executes GitOps operations |
| **Repository** | Project | Git repo containing manifests |
| **Cluster** | Project | Target Kubernetes cluster |
| **Application** | Project | Combines Repo + Cluster + Agent |
| **ApplicationSet** | Project | Generates multiple Applications |
| **Service** | Project | Harness CD service with GitOps enabled |
| **Environment** | Project | Target environment (dev, staging, prod) |
| **Pipeline** | Project | Orchestrates GitOps deployments |

---

## Prerequisites

### Platform Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Kubernetes Version | 1.32+ | 1.34+ |
| Nodes | 2 | 3+ |
| vCPUs per node | 2 | 4+ |
| Memory per node | 8 GB | 16 GB |
| Disk | 50 GB | 100 GB |

### Network Requirements

Outbound HTTPS (443) access to:
- `app.harness.io` - Harness Platform
- `github.com` - Git repositories
- `hub.docker.com` - Container images
- `harness.github.io` - Helm charts

### Harness Requirements

- [ ] Harness account with CD module enabled
- [ ] Project created (e.g., `CristianRamirez`)
- [ ] GitHub connector configured
- [ ] Docker Registry connector configured
- [ ] Service account with cluster-admin permissions

### Verify Cluster Access

```bash
# Verify kubectl access
kubectl cluster-info
kubectl get nodes

# Verify permissions
kubectl auth can-i create deployments --all-namespaces
kubectl auth can-i create clusterroles
```

---

## Step 1: Install GitOps Agent

The GitOps Agent is the core component that executes ArgoCD operations in your cluster.

### Option A: Via Harness UI

1. **Navigate to GitOps**
   ```
   Harness → Project → GitOps → Settings → GitOps Agents
   ```

2. **Create New Agent**
   - Click **+ New GitOps Agent**
   - Select **No** for "Do you have any existing Argo CD instances?"
   - Enter Agent name: `gitops`
   - Select Operator: `Argo`
   - Choose namespace: `argocd`

3. **Download Installation Files**
   - Select **Helm Chart** (recommended) or **YAML**
   - Download `override.yaml`

4. **Install in Cluster**
   ```bash
   # Add Harness GitOps Helm repo
   helm repo add gitops-agent https://harness.github.io/gitops-helm/
   helm repo update gitops-agent

   # Create namespace
   kubectl create namespace argocd

   # Install agent
   helm install argocd gitops-agent/gitops-helm \
     --namespace argocd \
     --values override.yaml \
     --wait
   ```

5. **Verify Agent Status**
   ```bash
   kubectl get pods -n argocd
   ```
   
   In Harness UI, verify agent shows **Healthy** and **Connected**.

### Option B: Via Terraform

```hcl
# Harness GitOps Agent via Terraform
resource "harness_platform_gitops_agent" "gitops" {
  identifier = "gitops"
  account_id = var.harness_account_id
  project_id = "CristianRamirez"
  org_id     = "sandbox"
  name       = "gitops"
  type       = "MANAGED_ARGO_PROVIDER"
  
  metadata {
    namespace         = "argocd"
    high_availability = false
  }
}

# Output the agent YAML for kubectl apply
output "agent_yaml" {
  value = harness_platform_gitops_agent.gitops.agent_yaml
}
```

### Option C: BYOA (Bring Your Own ArgoCD) - Current Installation

Para clusters con ArgoCD ya instalado, usamos el chart `gitops-helm-byoa`.

**Instalación actual en `se-latam-gke`:**

```bash
# 1. Add Harness GitOps BYOA repo
helm repo add gitops-agent-byoa https://harness.github.io/gitops-helm-byoa/
helm repo update gitops-agent-byoa

# 2. Create agent in Harness UI first
#    GitOps → Settings → Agents → + New GitOps Agent
#    - Select "Yes, I have an existing ArgoCD"
#    - Download the override.yaml file

# 3. Install the agent
helm install gitops-agent gitops-agent-byoa/gitops-helm-byoa \
  --values override-gitops.yaml \
  --namespace argocd

# 4. Verify installation
kubectl get pods -n argocd -l app.kubernetes.io/instance=gitops-agent
kubectl logs -n argocd -l app.kubernetes.io/instance=gitops-agent --tail=20
```

**Configuración actual (`override-gitops.yaml`):**

```yaml
harness:
  identity:
    accountIdentifier: EeRjnXTnS4GrLG5VNNJZUw
    orgIdentifier: sandbox
    projectIdentifier: CristianRamirez
    agentIdentifier: selatamgke        # Must match agent created in Harness UI

  secrets:
    agentSecret: <base64-encoded-key>   # Downloaded from Harness UI
    redisPassword: <redis-password>

  gitopsServerHost: https://app.harness.io/gratis/gitops
  createClusterRoles: true

  configMap:
    logLevel: DEBUG
    http:
      agentHttpTarget: https://app.harness.io/gitops
      tlsEnabled: false
    reconcile:
      appsetReconcile: true

argo-cd:
  enabled: false    # BYOA: ArgoCD already installed

agent:
  harnessName: se-latam-gke
  image:
    repository: docker.io/harness/gitops-agent
    tag: v0.115.0
  replicas: 1
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi

upgrader:
  enabled: true
  image: docker.io/harness/upgrader:latest
```

**Validación de conexión:**

```bash
# Check pod status (should be 1/1 Running)
kubectl get pods -n argocd -l app.kubernetes.io/instance=gitops-agent

# Check logs for successful connection
kubectl logs -n argocd -l app.kubernetes.io/instance=gitops-agent --tail=50 | grep -E "(Started|Connected|ERROR)"

# Expected output:
# "Started GitOps Agent"
# "Pod elected as leader"
# "Started leading"
```

**Troubleshooting BYOA:**

| Error | Causa | Solución |
|-------|-------|----------|
| `agent does not exist` | Agent no creado en UI o identifier incorrecto | Verificar agentIdentifier en Harness UI |
| `permission denied` | Secret inválido o expirado | Regenerar agent secret en Harness UI |
| `connection refused` | ArgoCD no instalado o healthz down | Verificar pods de ArgoCD: `kubectl get pods -n argocd` |

**Upgrade del agent:**

```bash
helm upgrade gitops-agent gitops-agent-byoa/gitops-helm-byoa \
  --values override-gitops.yaml \
  --namespace argocd
```

**Desinstalación:**

```bash
helm uninstall gitops-agent --namespace argocd
```

---

### Agent Configuration Options

```yaml
# override.yaml customizations
agent:
  name: gitops
  namespace: argocd

# High Availability
ha:
  enabled: true
  agent:
    replicas: 2
  redis:
    replicas: 3
  repoServer:
    replicas: 2

# Proxy configuration (if needed)
env:
  HTTPS_PROXY: "http://proxy.example.com:8080"
  HTTP_PROXY: "http://proxy.example.com:8080"
  NO_PROXY: "localhost,127.0.0.1,.cluster.local"

# Auto-updater
autoUpgrade:
  enabled: true
  schedule: "0 */4 * * *"  # Every 4 hours

# CRD management
crds:
  install: true
  keep: true  # Preserve CRDs on uninstall
```

---

## Step 2: Configure Repository

Add the Git repository containing your manifests.

### Via Harness UI

1. **Navigate to Repositories**
   ```
   GitOps → Settings → Repositories → + New Repository
   ```

2. **Configure Repository**
   - **Repository Type**: Git
   - **Repository Name**: `cinema-microservice-repo`
   - **GitOps Agent**: Select `gitops`
   - **Repository URL**: `https://github.com/crizstian/cinema-microservice-in-GO.git`

3. **Authentication**
   - **Connection Type**: HTTPS
   - **Authentication**: 
     - Anonymous (public repos)
     - Username/Password (private repos)
     - SSH Key

4. **Test Connection** → **Finish**

### Via API/CLI

```bash
# Create repository secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cinema-repo-creds
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

---

## Step 3: Add Cluster

Register target Kubernetes clusters for deployments.

### Via Harness UI

1. **Navigate to Clusters**
   ```
   GitOps → Settings → Clusters → + New Cluster
   ```

2. **Configure Cluster**
   - **Cluster Name**: `incluster` (for same cluster as agent)
   - **GitOps Agent**: Select `gitops`

3. **Connection Method**

   **Option A: Agent Credentials** (Same cluster)
   - Select "Use the credentials of a specific Harness GitOps Agent"
   - Agent manages connection automatically

   **Option B: Specific Credentials** (External cluster)
   - **Master URL**: `https://35.231.43.35`
   - **Authentication**: Service Account
   - **Service Account Token**: `<token>`
   - **CA Certificate**: `<base64-encoded-ca>`

4. **Target Namespace**: Leave empty for cluster-wide or specify namespace

5. **Validate Connection** → **Finish**

### Get Service Account Token

```bash
# Create service account for Harness
kubectl create serviceaccount harness-gitops -n kube-system

# Create cluster role binding
kubectl create clusterrolebinding harness-gitops-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:harness-gitops

# Get token (Kubernetes 1.24+)
kubectl create token harness-gitops -n kube-system --duration=8760h

# Get CA certificate
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

### Cluster Configuration for Cinema

| Cluster Name | Environment | Server Address | Namespace |
|--------------|-------------|----------------|-----------|
| `incluster` | dev | `https://kubernetes.default.svc` | `cinema-dev` |
| `incluster` | staging | `https://kubernetes.default.svc` | `cinema-staging` |
| `seprod` | prod | `https://35.231.43.35` | `cinema-prod` |

---

## Step 4: Create GitOps Application

Applications combine Repository, Cluster, and Agent to define deployments.

### Via Harness UI

1. **Navigate to Applications**
   ```
   GitOps → Applications → + New Application
   ```

2. **Basic Configuration**
   - **Application Name**: `booking-dev`
   - **GitOps Operator**: Argo
   - **GitOps Agent**: `gitops`

3. **Service & Environment**
   - **Service**: Create or select `booking-service-gitops`
   - **Environment**: Create or select `dev`

4. **Sync Policy**
   - **Sync Policy**: Automatic
   - **Prune**: Enabled
   - **Self Heal**: Enabled

5. **Source Configuration**
   - **Repository**: `cinema-microservice-repo`
   - **Revision**: `main`
   - **Path**: `platform/deploy/gitops/services/booking/overlays/dev`

6. **Destination**
   - **Cluster**: `incluster`
   - **Namespace**: `cinema-dev`

7. **Sync Options**
   - [x] Auto-Create Namespace
   - [x] Server-Side Apply
   - [x] Prune Last

### Application YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: booking-dev
  namespace: argocd
  labels:
    harness.io/serviceRef: booking-service-gitops
    harness.io/envRef: dev
spec:
  project: default
  source:
    repoURL: https://github.com/crizstian/cinema-microservice-in-GO.git
    targetRevision: main
    path: platform/deploy/gitops/services/booking/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: cinema-dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

---

## Step 5: Configure ApplicationSets

ApplicationSets enable managing multiple applications from a single definition.

### Via Harness UI

1. **Navigate to ApplicationSets**
   ```
   GitOps → ApplicationSets → + New ApplicationSet
   ```

2. **Basic Configuration**
   - **Name**: `cinema-services`
   - **GitOps Agent**: `gitops`

3. **Generator Type**
   - **Git Generator**: Auto-discover from config files
   - **List Generator**: Explicit list of parameters
   - **Matrix Generator**: Combine multiple generators

4. **Upload or Link YAML**
   - Point to: `platform/deploy/gitops/appsets/cinema-services-matrix.yaml`

### ApplicationSet Already Created

The ApplicationSet we created earlier is at:
`platform/deploy/gitops/appsets/cinema-services-matrix.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cinema-services
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - git:
              repoURL: https://github.com/crizstian/cinema-microservice-in-GO.git
              revision: main
              files:
                - path: "platform/deploy/gitops/cluster-config/*/config.json"
          - list:
              elements:
                - service: booking
                - service: cinema
                # ... more services
  template:
    metadata:
      name: '{{.service}}-{{.environment}}'
      labels:
        harness.io/serviceRef: '{{.service}}-service-gitops'
        harness.io/envRef: '{{.environment}}'
```

### Apply ApplicationSet

```bash
kubectl apply -f platform/deploy/gitops/appsets/cinema-services-matrix.yaml
```

---

## Step 6: Create GitOps Service

A GitOps-enabled Harness Service links to your ApplicationSet.

### Via Harness UI

1. **Navigate to Services**
   ```
   Project → Services → + New Service
   ```

2. **Basic Configuration**
   - **Name**: `cinema-services-gitops`
   - **Deployment Type**: Kubernetes
   - **Enable GitOps**: ✓ Yes

3. **GitOps Configuration**
   - Click **+ Add ApplicationSet Config**
   - **Agent**: `gitops`
   - **ApplicationSet**: `cinema-services`

4. **Manifests**
   - **Release Repo** (config files):
     - Connector: `CristianConnector`
     - Repo: `cinema-microservice-in-GO`
     - Branch: `main`
     - Path: `platform/deploy/gitops/cluster-config/<+cluster.name>/config.json`
   
   - **Deployment Repo** (ApplicationSet):
     - Path: `platform/deploy/gitops/appsets/cinema-services-matrix.yaml`

5. **Artifacts**
   - **Primary Artifact**: Docker Registry
   - **Image Path**: `crizstian/<+pipeline.variables.SERVICE_NAME>-service`
   - **Tag**: `<+input>`

6. **Variables**
   ```yaml
   - name: harness_service
     value: <+service.identifier>
   - name: environment  
     value: <+env.identifier>
   - name: image_tag
     value: <+artifact.tag>
   - name: replicas
     value: "1"
   ```

### Service YAML (Already Created)

Located at: `.harness/services/gitops/cinema-services.yaml`

---

## Step 7: Create GitOps Pipeline

Create a pipeline that orchestrates the GitOps deployment flow.

### Via Harness UI

1. **Navigate to Pipelines**
   ```
   Project → Pipelines → + Create Pipeline
   ```

2. **Pipeline Configuration**
   - **Name**: `Cinema GitOps Deploy`
   - **Store**: Inline or Git

3. **Add Stage: Deployment**
   - **Stage Name**: `Dev`
   - **Deployment Type**: Kubernetes
   - **GitOps Enabled**: ✓ Yes

4. **Service & Environment**
   - **Service**: `cinema-services-gitops`
   - **Environment**: `dev`
   - **GitOps Cluster**: `incluster`

5. **Execution Steps**

   | Step | Type | Description |
   |------|------|-------------|
   | 1 | GitOpsUpdateReleaseRepo | Update config.json, create PR |
   | 2 | HarnessApproval | Manual PR review |
   | 3 | MergePR | Merge approved PR |
   | 4 | GitOpsFetchLinkedApps | Get linked Applications |
   | 5 | GitOpsSync | Sync to cluster |

6. **Rollback Steps**

   | Step | Type | Description |
   |------|------|-------------|
   | 1 | RevertPR | Create revert commit |
   | 2 | MergePR | Merge revert |
   | 3 | GitOpsFetchLinkedApps | Get apps |
   | 4 | GitOpsSync | Sync rollback |

### Pipeline YAML (Already Created)

Located at: `.harness/pipelines/CD/CD-cinema-gitops.yaml`

### GitOps Step Types

| Step Type | Purpose |
|-----------|---------|
| `GitOpsUpdateReleaseRepo` | Updates config files in Git, creates PR |
| `GitOpsFetchLinkedApps` | Retrieves Applications linked to Service |
| `GitOpsSync` | Triggers ArgoCD sync |
| `MergePR` | Merges the GitOps PR |
| `RevertPR` | Creates revert commit for rollback |

---

## Verification

### Check All Components

```bash
# 1. Verify Agent
kubectl get pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# 2. Verify Applications
kubectl get applications -n argocd

# 3. Verify ApplicationSets  
kubectl get applicationsets -n argocd

# 4. Check sync status
argocd app list
argocd app get cinema-services
```

### Harness UI Verification

1. **GitOps → Agents**: Agent shows "Healthy"
2. **GitOps → Repositories**: Repository shows "Successful"
3. **GitOps → Clusters**: Cluster shows "Successful"
4. **GitOps → Applications**: Apps show sync status
5. **GitOps → ApplicationSets**: AppSet shows generated apps

### Test Pipeline Execution

1. Go to **Pipelines → Cinema GitOps Deploy**
2. Click **Run**
3. Select:
   - SERVICE_NAME: `booking`
   - artifact.tag: `v1.0.0`
4. Monitor execution

---

## Troubleshooting

### Agent Not Connecting

```bash
# Check agent logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Verify network connectivity
kubectl exec -n argocd -it <agent-pod> -- curl -v https://app.harness.io

# Check agent status
kubectl get pods -n argocd -o wide
```

### Repository Connection Failed

```bash
# Test Git access from agent
kubectl exec -n argocd -it <repo-server-pod> -- \
  git ls-remote https://github.com/crizstian/cinema-microservice-in-GO.git

# Check repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

### Application Sync Failed

```bash
# Get detailed status
argocd app get <app-name> --show-operation

# Check diff
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force --prune

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Pipeline Fails at GitOpsUpdateReleaseRepo

- Verify GitHub connector has write permissions
- Check branch protection rules allow PR creation
- Ensure config.json path matches cluster name expression

### Pipeline Fails at GitOpsSync

- Verify Application exists and is linked to Service
- Check `applicationRegex` matches Application names
- Ensure cluster credentials are valid

---

## Quick Reference

### Harness GitOps Entities Setup Order

```
1. Agent (must be first)
   ↓
2. Repository (requires Agent)
   ↓
3. Cluster (requires Agent)
   ↓
4. Application/ApplicationSet (requires all above)
   ↓
5. Service (GitOps enabled, links to Application)
   ↓
6. Pipeline (uses Service + Environment)
```

### Essential URLs

- Harness GitOps: `https://app.harness.io/ng/account/<account>/module/cd/orgs/<org>/projects/<project>/gitops`
- Agent Download: `https://harness.github.io/gitops-helm/`

### CLI Commands

```bash
# ArgoCD CLI
argocd login <harness-gitops-url> --sso
argocd app list
argocd app sync <app-name>
argocd app rollback <app-name> <revision>
```

---

## Sources

- [Harness CD GitOps Tutorial](https://developer.harness.io/docs/continuous-delivery/gitops/get-started/harness-cd-git-ops-quickstart/)
- [Harness GitOps Basics](https://developer.harness.io/docs/continuous-delivery/gitops/get-started/harness-git-ops-basics/)
- [Install Harness GitOps Agent](https://developer.harness.io/docs/continuous-delivery/gitops/gitops-entities/agents/install-a-harness-git-ops-agent/)
- [ApplicationSet Basics](https://developer.harness.io/docs/continuous-delivery/gitops/applicationsets/appset-basics/)
- [GitOps PR Pipelines](https://developer.harness.io/docs/continuous-delivery/gitops/pr-pipelines/pr-pipelines-basics/)
