# Diagrams ASCII Backup

**Purpose**: Backup of original ASCII diagrams for compatibility with text-only environments.  
**Date**: 2026-04-26  
**Related Documents**:
- [Committee Review](./monorepo-committee-review-2026-04.md)
- [Migration Plan](../operations/monorepo-migration-plan.md)

---

## Table of Contents

1. [Architecture Diagrams](#architecture-diagrams)
2. [Migration Diagrams](#migration-diagrams)
3. [Flow Diagrams](#flow-diagrams)
4. [Structure Diagrams](#structure-diagrams)

---

## Architecture Diagrams

### ARCH-001: Final Approved Architecture (3 Monorepos + Harness)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              HARNESS                                     │
│                    (Governance, Orchestration, Standards)                │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                   Orchestrates & Governs
                                  │
        ┌─────────────────────────┼─────────────────────────────────────┐
        ▼                         ▼                                     ▼
┌───────────────┐         ┌───────────────┐                     ┌───────────────┐
│ services-repo │         │ platform-repo │                     │  infra-repo   │
├───────────────┤         ├───────────────┤                     ├───────────────┤
│ /services/    │         │ /.harness/    │                     │ /terraform/   │
│ /contracts/   │         │ /security/    │                     │ /kubernetes/  │
│ /packages/    │         │ /images/      │                     │ /helm/        │
│ /quality/     │         │ /tooling/     │                     │ /operations/  │
│ /data/        │         │ /testing/     │                     │               │
│ /docs/        │         │ /docs/        │                     │ /docs/        │
├───────────────┤         ├───────────────┤                     ├───────────────┤
│ Dev Teams     │         │ Platform Team │                     │ Infra + SRE   │
│ DBA (gates)   │         │ Security Team │                     │ Ops Team      │
│ QA (unit/int) │         │ QA (e2e/perf) │                     │               │
└───────────────┘         └───────────────┘                     └───────────────┘
```

---

### ARCH-002: Harness Platform Layer

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           HARNESS PLATFORM                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │     CI      │  │     CD      │  │   STO       │  │    SRM      │    │
│  │  Pipelines  │  │   GitOps    │  │  Security   │  │ Reliability │    │
│  │             │  │   ArgoCD    │  │  Scanning   │  │    SLOs     │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         │                │                │                │            │
│  ┌──────┴────────────────┴────────────────┴────────────────┴──────┐    │
│  │                    GOVERNANCE LAYER                             │    │
│  │  • Policy-as-Code (OPA)     • RBAC                             │    │
│  │  • Audit Trail              • Secrets Management               │    │
│  │  • Approval Gates           • Cost Management                  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### ARCH-003: Repository Ecosystem Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        REPOSITORIOS DEL ECOSISTEMA                       │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  services-repo  │  │  platform-repo  │  │   infra-repo    │
│                 │  │                 │  │                 │
│ • Microservices │  │ • CI/CD pipes   │  │ • Terraform     │
│ • Contracts     │  │ • Templates     │  │ • K8s manifests │
│ • Shared libs   │  │ • Docker bases  │  │ • Helm charts   │
│ • Unit/Integ    │  │ • DevContainer  │  │ • Cloud configs │
│ • Migrations    │  │ • Generators    │  │                 │
│ • API docs      │  │ • E2E tests     │  │                 │
│                 │  │ • Perf tests    │  │                 │
│  Team: Devs     │  │  Team: Platform │  │  Team: Infra    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
        ▼                                         ▼
┌─────────────────┐                     ┌─────────────────┐
│  security-repo  │                     │    ops-repo     │
│   (REJECTED)    │                     │   (REJECTED)    │
│                 │                     │                 │
│ Merged into     │                     │ Merged into     │
│ platform-repo   │                     │ infra-repo      │
└─────────────────┘                     └─────────────────┘
```

---

## Migration Diagrams

### MIG-001: Current State to Target State

```
CURRENT STATE                           TARGET STATE
─────────────                           ────────────

┌─────────────────────┐                 ┌─────────────────┐
│   cinema-monorepo   │                 │  services-repo  │
│                     │                 │  (Dev Teams)    │
│ • services/         │───────────────► └─────────────────┘
│ • platform/         │                         │
│ • .harness/         │                         │
│ • .devcontainer/    │                 ┌─────────────────┐
│ • tests/            │───────────────► │  platform-repo  │
│ • docs/             │                 │  (Platform)     │
│                     │                 └─────────────────┘
│                     │                         │
│                     │                 ┌─────────────────┐
│                     │───────────────► │   infra-repo    │
│                     │                 │  (Infra + SRE)  │
└─────────────────────┘                 └─────────────────┘
                                                │
                                        ┌───────┴───────┐
                                        │    HARNESS    │
                                        │  (Governance) │
                                        └───────────────┘
```

---

### MIG-002: Migration Timeline

```
Week 1-2     Week 3-4     Week 5-6     Week 7-8     Week 9       Week 10
────────     ────────     ────────     ────────     ──────       ───────
   │            │            │            │            │            │
   ▼            ▼            ▼            ▼            ▼            ▼
┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
│Phase 1 │  │Phase 2 │  │Phase 3 │  │Phase 4 │  │Phase 5 │  │Phase 6 │
│Found-  │  │Services│  │Platform│  │ Infra  │  │Valid-  │  │Cleanup │
│ation   │  │Extract │  │Extract │  │Extract │  │ation   │  │& Docs  │
└────────┘  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘
    │            │            │            │            │            │
    └────────────┴────────────┴────────────┴────────────┴────────────┘
                                    │
                              10 WEEKS TOTAL
```

---

### MIG-003: Phased Risk Level

```
Risk Level by Phase
═══════════════════

Phase 1 ████░░░░░░░░░░░░░░░░  LOW        (No production changes)
Phase 2 ████████░░░░░░░░░░░░  MEDIUM     (Code extraction)
Phase 3 ████████████░░░░░░░░  MED-HIGH   (CI/CD changes)
Phase 4 ████████████████░░░░  HIGH       (Infra changes)
Phase 5 ████████████████████  CRITICAL   (Cutover)
Phase 6 ████░░░░░░░░░░░░░░░░  LOW        (Documentation)

Legend: █ = Risk intensity
```

---

## Flow Diagrams

### FLOW-001: Cross-Repository Dependencies

```
                    ┌─────────────────┐
                    │  security-repo  │
                    │   (policies)    │
                    └────────┬────────┘
                             │ consumed by
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ services-repo │    │ platform-repo │    │  infra-repo   │
│               │    │               │    │               │
│ BUILD_TIME:   │    │ BUILD_TIME:   │    │ PLAN_TIME:    │
│ • SAST policy │    │ • Pipe policy │    │ • Sentinel    │
│ • SCA policy  │    │ • Image scan  │    │ • OPA for TF  │
└───────┬───────┘    └───────┬───────┘    └───────────────┘
        │                    │
        │   DEPLOY           │
        └──────────┬─────────┘
                   ▼
           ┌─────────────┐
           │  ops-repo   │
           │             │
           │ RUNTIME:    │
           │ • Monitors  │
           │ • Alerts    │
           │ • Runbooks  │
           └─────────────┘
```

---

### FLOW-002: SERVICE.yaml Contract Flow

```
┌─────────────────┐
│  services-repo  │
│                 │
│  SERVICE.yaml   │──────┐
│  (contract)     │      │
└─────────────────┘      │
                         ▼
                   ┌─────────────────┐
                   │  Platform reads │
                   │  SERVICE.yaml   │
                   │  to determine:  │
                   │  - language     │
                   │  - deps         │
                   │  - build steps  │
                   │  - scan policy  │
                   └────────┬────────┘
                            │
                            │ Triggers deploy to
                            ▼
                   ┌─────────────────┐
                   │   infra-repo    │
                   │                 │
                   │  K8s manifests  │
                   │  expect:        │
                   │  - image tag    │
                   │  - config maps  │
                   │  - secrets ref  │
                   └─────────────────┘
```

---

### FLOW-003: Harness GitOps Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                                HARNESS                                  │
│                                                                         │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐           │
│   │  Pipelines  │      │  Policies   │      │  Secrets    │           │
│   │  Templates  │      │  OPA/Rego   │      │  Connectors │           │
│   │  Triggers   │      │  RBAC       │      │  Delegates  │           │
│   └─────────────┘      └─────────────┘      └─────────────┘           │
│                                                                         │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                      GitOps: Reads configs from repos
                                     │
        ┌────────────────────────────┼────────────────────────┐
        │                            │                        │
        ▼                            ▼                        ▼
┌───────────────┐            ┌───────────────┐        ┌───────────────┐
│ services-repo │            │ platform-repo │        │  infra-repo   │
│               │            │               │        │               │
│ SERVICE.yaml ─┼────────────┼─► Pipelines   │        │               │
│               │            │   consume     │        │               │
│               │            │               │        │               │
│               │            │ Security ─────┼────────┼─► TF Policies │
│               │            │ Policies      │        │               │
│               │            │               │        │               │
│               │            │               │        │ SLOs ─────────┼─► Harness SRM
│               │            │               │        │ Dashboards    │
└───────────────┘            └───────────────┘        └───────────────┘
```

---

## Structure Diagrams

### STRUCT-001: Current Repository Structure

```
/workspace
├── .harness/              # CI/CD pipelines, templates, policies, triggers
├── .devcontainer/         # Development container configuration
├── platform/
│   ├── docker/            # Dockerfiles per stack
│   ├── deploy/            # k8s, compose, harness, hashicorp
│   ├── config/            # Configurations
│   └── scripts/           # Taskfile scripts
├── services/              # 12 microservices (7 Go, 3 Java, 1 Python, 1 Node)
├── tests/                 # Integration, performance tests
├── docs/                  # Documentation
├── Taskfile.yml           # Task runner
└── go.work                # Go workspace
```

---

### STRUCT-002: Target services-repo Structure

```
services-repo/
├── services/
│   └── {service}/
│       ├── cmd/
│       ├── internal/
│       ├── api/                 # OpenAPI spec
│       ├── tests/               # Unit tests
│       ├── db/
│       │   └── migrations/      # ⚠️ Requires @dba-team approval
│       ├── Dockerfile
│       ├── Makefile
│       └── SERVICE.yaml
│
├── contracts/                   # Shared API contracts
│   ├── openapi/
│   ├── protobuf/
│   └── asyncapi/
│
├── packages/                    # Shared libraries
│   ├── go/
│   ├── java/
│   └── python/
│
├── quality/
│   ├── integration/
│   ├── fixtures/
│   └── mocks/
│
├── docs/
│   ├── api/
│   └── architecture/
│
├── CODEOWNERS
├── go.work
└── Taskfile.yml
```

---

### STRUCT-003: Target platform-repo Structure

```
platform-repo/
├── .harness/
│   ├── pipelines/
│   │   ├── ci/
│   │   └── cd/
│   ├── templates/
│   ├── triggers/
│   └── inputsets/
│
├── security/
│   ├── policies/
│   │   ├── opa/
│   │   │   ├── pipeline/
│   │   │   ├── kubernetes/
│   │   │   └── terraform/
│   │   └── harness/
│   ├── scanning/
│   │   ├── sast/
│   │   ├── sca/
│   │   ├── container/
│   │   └── secrets/
│   ├── compliance/
│   └── threat-models/
│
├── images/
│   ├── base-go/
│   ├── base-java/
│   ├── base-python/
│   └── ci-runner/
│
├── tooling/
│   ├── devcontainer/
│   ├── generators/
│   ├── compose/
│   └── scripts/
│
├── testing/
│   ├── e2e/
│   └── performance/
│
├── CODEOWNERS
└── CHANGELOG.md
```

---

### STRUCT-004: Target infra-repo Structure

```
infra-repo/
├── terraform/
│   ├── modules/
│   │   ├── gke-cluster/
│   │   ├── cloud-sql/
│   │   ├── vpc/
│   │   ├── iam/
│   │   └── secrets/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── policies/
│
├── kubernetes/
│   ├── base/
│   ├── overlays/
│   └── crds/
│
├── helm/
│   ├── charts/
│   └── values/
│
├── operations/
│   ├── observability/
│   │   ├── dashboards/
│   │   ├── alerts/
│   │   └── slos/
│   ├── runbooks/
│   ├── playbooks/
│   ├── chaos/
│   ├── cost/
│   └── oncall/
│
├── CODEOWNERS
└── CHANGELOG.md
```

---

### STRUCT-005: Executive Summary Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA FINAL                            │
│                                                                  │
│  3 Monorepos + Harness Platform                                 │
│                                                                  │
│  ┌─────────┐    ┌──────────┐    ┌─────────┐                    │
│  │Services │    │ Platform │    │  Infra  │                    │
│  │  Repo   │    │   Repo   │    │  Repo   │                    │
│  │         │    │          │    │         │                    │
│  │ +Code   │    │ +CI/CD   │    │ +IaC    │                    │
│  │ +Data   │    │ +Security│    │ +Ops    │                    │
│  │ +Quality│    │ +DevEx   │    │ +SRE    │                    │
│  └─────────┘    └──────────┘    └─────────┘                    │
│       │              │               │                          │
│       └──────────────┴───────────────┘                          │
│                      │                                          │
│                      ▼                                          │
│              ┌──────────────┐                                   │
│              │   HARNESS    │                                   │
│              │  Governance  │                                   │
│              │  Standards   │                                   │
│              │  Visibility  │                                   │
│              └──────────────┘                                   │
│                                                                  │
│  ✓ Separation of Concerns                                       │
│  ✓ Team Autonomy                                                │
│  ✓ Centralized Governance                                       │
│  ✓ Compliance Ready                                             │
│  ✓ Scalable                                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

### STRUCT-006: Success Criteria Box

```
┌────────────────────────────────────────────────────────────────┐
│                     SUCCESS CRITERIA                            │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SERVICE.yaml as contract between repos                     │
│     └─► Platform-repo reads metadata to configure pipelines    │
│                                                                 │
│  2. CODEOWNERS strict enforcement on critical paths            │
│     └─► /security/* requires @security-team                    │
│     └─► /operations/* requires @sre-team                       │
│     └─► /services/*/db/* requires @dba-team                    │
│                                                                 │
│  3. Harness Policy Sets enforce compliance                      │
│     └─► No deploy without security scan passing                │
│     └─► No prod deploy without approval gate                   │
│     └─► No pipeline without required steps                     │
│                                                                 │
│  4. Versioning semantico in platform-repo                      │
│     └─► Templates versioned (v1.0.0, v1.1.0)                   │
│     └─► Security policies versioned                            │
│                                                                 │
│  5. Documentation hub in Harness                                │
│     └─► Links to docs from each repo                           │
│     └─► Centralized onboarding                                 │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

---

## Usage Notes

- These ASCII diagrams are provided as backup for environments that don't support Mermaid rendering
- For best visual experience, use the Mermaid versions in the main documents
- ASCII diagrams should be viewed with a monospace font
- Minimum terminal/editor width: 80 characters recommended

---

**Document Version**: 1.0  
**Last Updated**: 2026-04-26
