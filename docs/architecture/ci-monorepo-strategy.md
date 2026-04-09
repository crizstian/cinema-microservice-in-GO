# CI/CD Strategy for Monorepo at Scale

> **AI Agent Context**: This document describes the CI/CD pipeline architecture for a polyglot monorepo that can scale to thousands of microservices. It covers the problem space, solution patterns, and implementation details.

**Last Updated**: 2026-04-09  
**Status**: Approved  
**Authors**: Platform Team

---

## Harness Core Principles

This strategy is built on Harness's four core principles:

| Principle | How This Strategy Delivers |
|-----------|---------------------------|
| **Standardization** | 1 pipeline per tech stack = same CI logic for all services |
| **Governance** | Platform team controls pipelines centrally; services cannot modify CI |
| **Velocity** | Matrix parallelism, Test Intelligence, caching, conditional execution |
| **Developer Experience** | Zero-config for new services; just create code, CI works automatically |

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Architecture](#solution-architecture)
4. [Pipeline Flows](#pipeline-flows)
5. [Conditional Execution Pattern](#conditional-execution-pattern)
6. [Complexity Analysis](#complexity-analysis)
7. [Phased Implementation](#phased-implementation)
8. [Scaling Analysis](#scaling-analysis)
9. [Implementation Guide](#implementation-guide)
10. [Manual Pipeline Execution](#manual-pipeline-execution)
11. [Decision Matrix](#decision-matrix)
12. [Applied Corrections](#applied-corrections)
13. [CI Stages vs StepGroups: Architectural Decision](#ci-stages-vs-stepgroups-architectural-decision)
14. [Multi-Language Service Detection](#multi-language-service-detection)
15. [Harness MCP Server Implementation](#harness-mcp-server-implementation)
16. [References](#references)

---

## Executive Summary

This document defines the CI/CD strategy for a **polyglot monorepo** containing microservices in multiple languages (Go, Java, Node.js, Python, etc.). The architecture uses a **Pipeline Chaining** pattern with an Orchestrator (parent) pipeline that spawns independent Child pipelines per affected service.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Trigger Strategy | 1 trigger per language | O(languages) not O(services) |
| Execution Model | Pipeline Chaining | Independent, non-blocking builds |
| Auto-Abort Scope | Orchestrator only | Child pipelines complete independently |
| Service Detection | Dynamic (git diff) | Zero-config for new services |

---

## Problem Statement

### The Monorepo Challenge

In a monorepo with multiple microservices, CI/CD must handle:

1. **Selective Building**: Only build services that changed
2. **Concurrent Development**: Multiple teams pushing to different services
3. **Independent Failures**: One service failure shouldn't block others
4. **Scale**: Support growth from 8 to 1000+ services

### The Auto-Abort Problem

Traditional CI setups use `autoAbortPreviousExecutions: true` to cancel outdated builds. This creates a critical issue in monorepos:

```
Timeline: PR #10 on branch feature/checkout
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━►

Push 1: Modifies movie + booking + payment
  [Pipeline]──►[Build movie]────────────────►
               [Build booking]──────────────►
               [Build payment]──────────────►
                                        ↑
Push 2: Typo fix in movie only          │
  [Pipeline]────────────────────────────┼──►[Build movie]────►
                                        │
                           ⚠️ ENTIRE Push 1 CANCELLED
                           ⚠️ booking build: CANCELLED
                           ⚠️ payment build: CANCELLED
                           
Result: booking and payment NEVER get built despite having changes
```

### Scenario Analysis

| # | Scenario | With autoAbort=true | Expected Behavior |
|---|----------|---------------------|-------------------|
| 1 | Push 1: A+B+C, Push 2: fix A | B,C cancelled | B,C should complete |
| 2 | Push 1: A, Push 2: B | A cancelled | Both should complete |
| 3 | Push 1: A, Push 2: A | First cancelled | Correct (same service) |
| 4 | PR #10: A, PR #11: B | Independent | Correct (different PRs) |
| 5 | Push 1: A+B+C, Push 2: D | A,B,C cancelled | A,B,C should complete |

**Scenarios 1, 2, and 5 fail with traditional auto-abort.**

---

## Solution Architecture

### Pattern: Pipeline Chaining with Independent Executions

The solution separates **detection** from **execution** using two pipeline tiers:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PIPELINE CHAINING ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    LAYER 1: TRIGGERS                               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │ │
│  │  │ Trigger: Go │  │Trigger: Java│  │Trigger: Node│                │ │
│  │  │ ^services/  │  │ ^services/  │  │ ^services/  │                │ │
│  │  │   go/.+     │  │   java/.+   │  │   node/.+   │                │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                │ │
│  └─────────┼────────────────┼────────────────┼───────────────────────┘ │
│            │                │                │                          │
│            ▼                ▼                ▼                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    LAYER 2: ORCHESTRATORS                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │ │
│  │  │Orchestrator │  │Orchestrator │  │Orchestrator │                │ │
│  │  │   Golang    │  │    Java     │  │    Node     │                │ │
│  │  │             │  │             │  │             │                │ │
│  │  │ • Detect    │  │ • Detect    │  │ • Detect    │                │ │
│  │  │ • Spawn N   │  │ • Spawn N   │  │ • Spawn N   │                │ │
│  │  │   children  │  │   children  │  │   children  │                │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                │ │
│  │         │                │                │                        │ │
│  │  autoAbort=true   autoAbort=true   autoAbort=true                 │ │
│  │  (only affects    (only affects    (only affects                  │ │
│  │   orchestrator)    orchestrator)    orchestrator)                 │ │
│  └─────────┼────────────────┼────────────────┼───────────────────────┘ │
│            │                │                │                          │
│            ▼                ▼                ▼                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    LAYER 3: CHILD PIPELINES                        │ │
│  │                                                                     │ │
│  │  Each child pipeline:                                              │ │
│  │  • Has unique execution ID                                         │ │
│  │  • Runs independently                                              │ │
│  │  • Cannot be cancelled by new orchestrator runs                    │ │
│  │  • Reports status back to PR                                       │ │
│  │                                                                     │ │
│  │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐     │ │
│  │  │ movie │ │booking│ │payment│ │ seat  │ │ user  │ │  ...  │     │ │
│  │  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘ └───────┘     │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### How It Solves the Auto-Abort Problem

```
Push 1: movie + booking + payment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━►

[Orchestrator #1]─►[API: Spawn movie]────►[Child: movie]─────────►[COMPLETE ✓]
                   [API: Spawn booking]──►[Child: booking]───────►[COMPLETE ✓]
                   [API: Spawn payment]──►[Child: payment]───────►[COMPLETE ✓]
                   ▲
                   │ Orchestrator completes quickly (just spawns)
                   │ Children run independently with their own execution IDs

Push 2: fix typo in movie
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━►

[Orchestrator #1: CANCELLED] ← Only orchestrator cancelled, children continue!
                   │
                   │         [Child: movie from Push 1]────────►[COMPLETE ✓]
                   │         [Child: booking]──────────────────►[COMPLETE ✓]
                   │         [Child: payment]──────────────────►[COMPLETE ✓]
                   │
[Orchestrator #2]──┴─►[API: Spawn movie]──►[Child: movie v2]───►[COMPLETE ✓]
                      (only movie detected as changed)

Result: ALL services build successfully
        movie builds twice (correct - it changed twice)
        booking and payment build once (correct - changed once)
```

---

## Pipeline Flows

### Diagram 1: Orchestrator Pipeline (Parent)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR PIPELINE: CI-Golang                      │
│                    Identifier: CI_golang_orchestrator                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  TRIGGER                                                           │ │
│  │  • Event: PR (Open, Reopen, Synchronize, Close/Merge)              │ │
│  │  • Condition: changedFiles matches ^services/go/.+                 │ │
│  │  • autoAbortPreviousExecutions: true                               │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 1: Detect Changed Services                                  │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 1.1: Fetch PR Files                                    │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Call GitHub API: GET /repos/{owner}/{repo}/pulls/{pr}/files│ │ │
│  │  │  • Handle pagination (100 files per page)                    │  │ │
│  │  │  • Output: List of all changed file paths                    │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 1.2: Extract Service Names                             │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Filter: files matching services/go/{service}/*            │  │ │
│  │  │  • Extract: unique service directory names                   │  │ │
│  │  │  • Output Variables:                                         │  │ │
│  │  │    - SERVICES: "movie,booking,payment"                       │  │ │
│  │  │    - SERVICES_JSON: ["movie","booking","payment"]            │  │ │
│  │  │    - SERVICE_COUNT: 3                                        │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 1.3: Validate Services Exist                           │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Verify each detected service has go.mod                   │  │ │
│  │  │  • Skip deleted services                                     │  │ │
│  │  │  • Fail fast if invalid structure detected                   │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 2: Spawn Child Pipelines                                    │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 2.1: Trigger Child Pipeline (Loop)                     │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  FOR each SERVICE in SERVICES:                               │  │ │
│  │  │    │                                                         │  │ │
│  │  │    ├─► POST /pipeline/api/pipeline/execute/{child_pipeline}  │  │ │
│  │  │    │   Body:                                                 │  │ │
│  │  │    │   {                                                     │  │ │
│  │  │    │     "SERVICE_NAME": "{service}",                        │  │ │
│  │  │    │     "COMMIT_SHA": "<+codebase.commitSha>",              │  │ │
│  │  │    │     "PR_NUMBER": "<+codebase.prNumber>",                │  │ │
│  │  │    │     "BRANCH": "<+codebase.sourceBranch>",               │  │ │
│  │  │    │     "PR_STATE": "<+trigger.payload.pull_request.state>",│  │ │
│  │  │    │     "IS_MERGED": "<+trigger.payload.merged>"            │  │ │
│  │  │    │   }                                                     │  │ │
│  │  │    │                                                         │  │ │
│  │  │    ├─► Store execution ID for tracking                       │  │ │
│  │  │    │                                                         │  │ │
│  │  │    └─► Log: "Spawned child pipeline for {service}"           │  │ │
│  │  │                                                              │  │ │
│  │  │  END FOR                                                     │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 2.2: Summary Report                                    │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Output: Number of child pipelines spawned                 │  │ │
│  │  │  • Output: List of execution IDs                             │  │ │
│  │  │  • Note: Does NOT wait for children to complete              │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  COMPLETION                                                        │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │  • Orchestrator completes in ~30-60 seconds                        │ │
│  │  • Children continue running independently                         │ │
│  │  • If new push arrives, only this orchestrator is cancelled        │ │
│  │  • Children from previous run continue to completion               │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Diagram 2: Child Pipeline (Golang Service)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CHILD PIPELINE: CI-Golang-Service                     │
│                    Identifier: CI_golang_service                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  INPUT VARIABLES (from Orchestrator)                               │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │  • SERVICE_NAME: "movie"                                           │ │
│  │  • COMMIT_SHA: "abc123..."                                         │ │
│  │  • PR_NUMBER: "42"                                                 │ │
│  │  • BRANCH: "feature/add-ratings"                                   │ │
│  │  • PR_STATE: "open" | "closed"                                     │ │
│  │  • IS_MERGED: "true" | "false"                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 1: Setup                                                    │ │
│  │  Condition: Always                                                 │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 1.1: Git Clone                                         │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Clone repo at specific COMMIT_SHA                         │  │ │
│  │  │  • Sparse checkout: services/go/{SERVICE_NAME}/**            │  │ │
│  │  │  • Depth: 1 (shallow clone for speed)                        │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 1.2: Load Service Config (Optional)                    │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Read services/go/{SERVICE_NAME}/ci.yaml if exists         │  │ │
│  │  │  • Override defaults with service-specific config            │  │ │
│  │  │  • Export: COVERAGE_THRESHOLD, SKIP_SECURITY, etc.           │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Step 1.3: Dependency Cache                                  │  │ │
│  │  │  ────────────────────────────────────────────────────────────│  │ │
│  │  │  • Restore: go mod cache from previous builds                │  │ │
│  │  │  • Key: go-{SERVICE_NAME}-{hash(go.sum)}                     │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 2: Code Quality                                             │ │
│  │  Condition: PR_STATE == "open"                                     │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌─────────────────────────┐  ┌─────────────────────────┐          │ │
│  │  │  Step 2.1: Format      │  │  Step 2.2: Lint         │          │ │
│  │  │  ──────────────────────│  │  ──────────────────────│          │ │
│  │  │  • gofmt -d .          │  │  • golangci-lint run   │          │ │
│  │  │  • goimports check     │  │  • timeout: 5m         │          │ │
│  │  │  • Fail on diff        │  │  • Config: .golangci   │          │ │
│  │  └─────────────────────────┘  └─────────────────────────┘          │ │
│  │               │                          │                          │ │
│  │               └────────────┬─────────────┘                          │ │
│  │                            ▼                                        │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 2.3: Security Scans (Parallel)                        │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │ │
│  │  │  │   Semgrep   │  │    OWASP    │  │    gosec    │          │   │ │
│  │  │  │  (SAST)     │  │  Dep-Check  │  │  (Go sec)   │          │   │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 3: Tests                                                    │ │
│  │  Condition: PR_STATE == "open"                                     │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 3.1: Unit Tests (Parallel with 3.2)                   │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • go test -v -race -short -coverprofile=coverage.out ./... │   │ │
│  │  │  • Generate JUnit XML report                                │   │ │
│  │  │  • Upload test results to Harness                           │   │ │
│  │  │  • Intelligence Mode: enabled (test selection)              │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 3.2: Benchmark Tests (Parallel with 3.1)              │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • go test -bench=. -benchmem -run=^$ ./...                 │   │ │
│  │  │  • Compare with baseline (if exists)                        │   │ │
│  │  │  • Flag performance regressions                             │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 3.3: Coverage Check                                   │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Parse coverage.out                                       │   │ │
│  │  │  • Compare against COVERAGE_THRESHOLD (default: 80%)        │   │ │
│  │  │  • Fail if below threshold                                  │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 4: PR Feedback                                              │ │
│  │  Condition: PR_STATE == "open"                                     │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 4.1: Post PR Comment                                  │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Summary: Tests passed, coverage %, security findings     │   │ │
│  │  │  • Link to full pipeline execution                          │   │ │
│  │  │  • Approve/Request changes based on results                 │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 5: Build & Push                                             │ │
│  │  Condition: IS_MERGED == "true"                                    │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 5.1: Generate Version                                 │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Read current tag from repo                               │   │ │
│  │  │  • Apply SemVer rules based on branch pattern:              │   │ │
│  │  │    - *release* → MAJOR+1 (v2.0.0)                           │   │ │
│  │  │    - *update*  → MINOR+1 (v1.1.0)                           │   │ │
│  │  │    - *fix*     → PATCH+1 (v1.0.1)                           │   │ │
│  │  │  • Output: NEW_VERSION                                      │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 5.2: Build Binary                                     │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • CGO_ENABLED=0 GOOS=linux GOARCH=amd64                    │   │ │
│  │  │  • go build -ldflags="-s -w" -o {SERVICE_NAME}              │   │ │
│  │  │  • Output: Statically linked binary                         │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 5.3: Build & Push Docker Image                        │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Dockerfile: platform/docker/go-service/Dockerfile        │   │ │
│  │  │  • Tags: {NEW_VERSION}, latest                              │   │ │
│  │  │  • Registry: configured per environment                     │   │ │
│  │  │  • Caching: enabled                                         │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 6: Container Security                                       │ │
│  │  Condition: IS_MERGED == "true"                                    │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 6.1: Grype Vulnerability Scan                         │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Scan built image for CVEs                                │   │ │
│  │  │  • Fail on HIGH/CRITICAL vulnerabilities                    │   │ │
│  │  │  • Generate SBOM                                            │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  STAGE 7: Release                                                  │ │
│  │  Condition: IS_MERGED == "true" AND NEW_VERSION != "N/A"           │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 7.1: Create Git Tag                                   │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Tag format: {SERVICE_NAME}-{NEW_VERSION}                 │   │ │
│  │  │  • Example: movie-v1.2.3                                    │   │ │
│  │  │  • Push tag to repo                                         │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  Step 7.2: Generate Release Notes                           │   │ │
│  │  │  ───────────────────────────────────────────────────────────│   │ │
│  │  │  • Extract commits since last tag                           │   │ │
│  │  │  • Format as changelog                                      │   │ │
│  │  │  • Create GitHub/Harness release                            │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Conditional Execution Pattern (Shift-Left Security)

### Principle: Security Gates BEFORE Merge

The pipeline uses **Shift-Left Security** - security scans run during PR validation to **block vulnerabilities before they reach main**. Code that passes validation is already secure; the merge stage only compiles and publishes.

```
┌─────────────────────────────────────────────────────────────────────────┐
│              SHIFT-LEFT SECURITY: PR STATE MATRIX                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PR STATE: OPEN (Draft, Ready for Review, Synchronize)                  │
│  ═══════════════════════════════════════════════════════════════════    │
│  Goal: BLOCK vulnerabilities before merge (shift-left)                  │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   Format    │  │    Lint     │  │  SECURITY   │  │    Test     │    │
│  │   Check     │  │  (Quality)  │  │   SCANS     │  │   (Unit)    │    │
│  │             │  │             │  │             │  │             │    │
│  │  gofmt -d   │  │ golangci-   │  │  Semgrep    │  │ go test     │    │
│  │             │  │ lint run    │  │  OWASP      │  │ -race -v    │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
│        │                │                │                │             │
│        └────────────────┴────────────────┴────────────────┘             │
│                                   │                                      │
│                                   ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  GATE: If ANY security issue found → BLOCK MERGE                │    │
│  │  • Semgrep: fail_on_severity: high                              │    │
│  │  • OWASP: fail on known vulnerabilities                         │    │
│  │  • Pipeline fails → PR cannot be merged                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ⏱️  Target: < 5 minutes (includes security scans)                      │
│  🔒 Security: FULL scan suite - vulnerabilities blocked early           │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PR STATE: MERGED (Close with merge)                                    │
│  ═══════════════════════════════════════════════════════════════════    │
│  Goal: Compile and publish (code already validated and secure)          │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                     │
│  │  Generate   │  │   Build     │  │   Release   │                     │
│  │  Version    │  │   & Push    │  │   (Tag)     │                     │
│  │             │  │             │  │             │                     │
│  │  SemVer     │  │ Docker      │  │  Git Tag    │                     │
│  │  from branch│  │ build/push  │  │  v1.2.3     │                     │
│  └─────────────┘  └─────────────┘  └─────────────┘                     │
│        │                │                │                              │
│        └────────────────┴────────────────┘                              │
│                                   │                                      │
│                                   ▼                                      │
│                    ┌─────────────────────────────┐                      │
│                    │   Production Artifact       │                      │
│                    │   registry/service:v1.2.3   │                      │
│                    └─────────────────────────────┘                      │
│                                                                          │
│  ⏱️  Target: < 5 minutes (no security scans needed)                     │
│  ✅ Security: Already validated in PR Open stage                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why Shift-Left Security?

| Traditional (Scan on Merge) | Shift-Left (Scan on PR Open) |
|-----------------------------|------------------------------|
| Vulnerabilities reach main branch | Vulnerabilities blocked before merge |
| Fix requires new PR | Fix in same PR |
| Post-mortem security | Preventive security |
| Developers notified late | Developers notified early |
| Merge first, scan later | Scan first, merge if clean |

### Implementation in Harness

```yaml
# Shift-Left Security: Scans in PR Open stage
stages:
  - stage:
      name: Validate and Secure  # Security scans HERE
      when:
        condition: <+trigger.payload.pull_request.state> == "open"
      steps:
        - Format, Lint
        - Semgrep (fail_on_severity: high)  # BLOCKS merge if issues
        - OWASP Dependency Check            # BLOCKS merge if vulnerable deps
        - Unit Tests, Coverage

  - stage:
      name: Build and Release  # NO security scans - just build
      when:
        condition: <+trigger.payload.action> == "closed" && <+trigger.payload.pull_request.merged> == true
      steps:
        - Generate Version
        - Build Binary
        - Build & Push Docker
        - Create Release Tag
```

### Step Distribution by PR State (Shift-Left)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    STEP DISTRIBUTION BY PR STATE                        │
│                    (Shift-Left Security Pattern)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STEP                          │ PR OPEN │ PR MERGED │ RATIONALE        │
│  ═════════════════════════════════════════════════════════════════════  │
│                                                                          │
│  Code Format Check             │   ✅    │    ❌     │ Fast, catch early │
│  Linting (golangci-lint)       │   ✅    │    ❌     │ Fast, catch early │
│  ─────────────────────────────────────────────────────────────────────  │
│  SAST Scan (Semgrep)           │   ✅    │    ❌     │ SHIFT-LEFT: Block │
│  Dependency Scan (OWASP)       │   ✅    │    ❌     │ SHIFT-LEFT: Block │
│  ─────────────────────────────────────────────────────────────────────  │
│  Unit Tests                    │   ✅    │    ❌     │ Must pass to merge│
│  Test Coverage Check           │   ✅    │    ❌     │ Enforce standards │
│  Benchmark Tests               │   ✅    │    ❌     │ Detect regressions│
│  ─────────────────────────────────────────────────────────────────────  │
│  Generate Version (SemVer)     │   ❌    │    ✅     │ Only on release   │
│  Build Binary                  │   ❌    │    ✅     │ Only on release   │
│  Build & Push Docker           │   ❌    │    ✅     │ Only on release   │
│  Create Git Tag                │   ❌    │    ✅     │ Only on release   │
│                                                                          │
│  ═════════════════════════════════════════════════════════════════════  │
│  TOTAL STEPS                   │    8    │     4     │                   │
│  TARGET TIME                   │  < 5m   │   < 5m    │                   │
│  SECURITY SCANS                │   ✅    │    ❌     │ Shift-left!       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Difference from Traditional Pattern

| Aspect | Traditional | Shift-Left (Current) |
|--------|-------------|----------------------|
| **Semgrep** | PR Merged | **PR Open** |
| **OWASP** | PR Merged | **PR Open** |
| **Grype** | PR Merged | Removed (no image in PR) |
| **Merge gate** | None | Security scans block merge |
| **Build stage** | Scan + Build | Build only (already secure) |

### Edge Cases

| Scenario | Behavior | Rationale |
|----------|----------|-----------|
| PR reopened | Run PR Open steps | New iteration cycle |
| PR synchronized (new push) | Run PR Open steps | Validate new changes |
| PR closed without merge | No steps | Nothing to validate |
| Direct push to main | Run PR Merged steps | Treat as implicit merge |
| Force push to main | Blocked by branch protection | Governance |

---

## Complexity Analysis

### Is This Over-Engineered?

| Component | Verdict | Analysis |
|-----------|---------|----------|
| **Pipeline Chaining** | ⚠️ Depends | Justified if >20 services or multi-language. For 8 Go services, simpler approach works. |
| **1 Child per Tech Stack** | ✅ Correct | Single Responsibility. Each language has its own tooling. |
| **Matrix execution** | ✅ Correct | Efficient parallelism, no better alternative. |
| **GitHub API for detection** | ⚠️ Simplify | Harness has native `<+trigger.payload>`. API call is redundant. |
| **Multiple Security Scans** | ⚠️ Review | Semgrep + OWASP + gosec + Grype = 4 scans. Consolidate to 2. |
| **Conditional PR/Merge** | ✅ Correct | Essential pattern for velocity + security balance. |

### Simplification Recommendations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SIMPLIFICATION OPPORTUNITIES                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  CURRENT (Complex)              →    SIMPLIFIED                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  GitHub API call for files      →    <+trigger.payload.commits[*]>      │
│  (pagination, auth, parsing)         Native Harness expression          │
│                                                                          │
│  4 security scanners            →    2 scanners                         │
│  Semgrep + OWASP + gosec + Grype     Semgrep (SAST) + Grype (container) │
│                                                                          │
│  Orchestrator + N Children      →    Single pipeline with matrix        │
│  (for 8 Go services)                 (until 20+ services)               │
│                                                                          │
│  Full clone per service         →    Sparse checkout                    │
│  (downloads entire repo)             (only service directory)           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### What's Missing (Add for Robustness)

| Feature | Priority | Impact | Harness Feature |
|---------|----------|--------|-----------------|
| **Test Intelligence** | P0 | Reduces test time 40-80% | Native TI |
| **Caching per service** | P0 | Faster builds | Native caching |
| **Flaky Test Detection** | P1 | Reduces false negatives | Native TI |
| **Build Metrics** | P1 | Visibility into trends | Dashboards |
| **PR Size Warning** | P2 | Quality gate | Custom step |

### What to Remove/Defer

| Feature | Recommendation | Rationale |
|---------|---------------|-----------|
| **gosec in PR** | Remove | Redundant with golangci-lint security rules |
| **Grype in PR** | Move to merge only | No image exists in PR |
| **OWASP in PR** | Move to merge only | Slow, not blocking |
| **Benchmark comparison** | Make optional | Only for perf-critical services |

---

## Phased Implementation

### Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASED IMPLEMENTATION ROADMAP                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  PHASE 1                 PHASE 2                 PHASE 3                │
│  Current State           Multi-Language          Enterprise Scale       │
│  (8 Go services)         (20+ services)          (100+ services)        │
│                                                                          │
│  ┌─────────────┐        ┌─────────────┐        ┌─────────────┐         │
│  │   Single    │        │ Orchestrator│        │ Orchestrator│         │
│  │  Pipeline   │   ──▶  │      +      │   ──▶  │      +      │         │
│  │  CI-Golang  │        │  Children   │        │  Children   │         │
│  │             │        │ (per stack) │        │   + Registry│         │
│  └─────────────┘        └─────────────┘        └─────────────┘         │
│                                                                          │
│  Trigger: 1             Trigger: 1              Trigger: 1              │
│  Pipelines: 1           Pipelines: 1+N          Pipelines: 1+N          │
│  Complexity: Low        Complexity: Medium      Complexity: High        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Single Pipeline (Current - 8 Go Services)

**When:** 1-20 services, single language

**Architecture:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 1: SINGLE PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Pipeline: CI-Golang                                               │ │
│  │  Trigger: PR on services/go/**                                     │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Stage 1: Detect Services (inline, no API call)              │  │ │
│  │  │  • Parse <+trigger.payload.commits[*].modified>              │  │ │
│  │  │  • Filter: services/go/{service}/*                           │  │ │
│  │  │  • Output: SERVICES = ["movie", "booking"]                   │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                              │                                      │ │
│  │                              ▼                                      │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Stage 2: Validate (PR Open)                                 │  │ │
│  │  │  when: <+trigger.payload.pull_request.state> == "open"       │  │ │
│  │  │  strategy: matrix { service: <+stage1.SERVICES> }            │  │ │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │  │ │
│  │  │  │   Format   │ │    Lint    │ │    Test    │ │  Coverage  │ │  │ │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘ │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                              │                                      │ │
│  │                              ▼                                      │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Stage 3: Build & Release (PR Merged)                        │  │ │
│  │  │  when: <+trigger.payload.action> == "closed" &&              │  │ │
│  │  │        <+trigger.payload.pull_request.merged> == true        │  │ │
│  │  │  strategy: matrix { service: <+stage1.SERVICES> }            │  │ │
│  │  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │  │ │
│  │  │  │  Security  │ │   Build    │ │   Grype    │ │  Release   │ │  │ │
│  │  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘ │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  Files: 1 pipeline YAML                                                 │
│  Maintenance: Minimal                                                   │
│  Scalability: Up to ~20 services                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Features:**
- [x] Single pipeline with integrated trigger
- [x] Inline service detection (no GitHub API)
- [x] Matrix execution for parallelism
- [x] Conditional stages (PR Open vs Merged)
- [x] Test Intelligence enabled
- [x] Caching enabled
- [x] Sparse checkout

**Files needed:** 1 (`CI-Golang.yaml`)

### Phase 2: Orchestrator + Children (20+ Services or Multi-Language)

**When:** Adding Java/Node OR exceeding 20 services

**Architecture:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PHASE 2: ORCHESTRATOR + CHILDREN                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Pipeline: CI-Orchestrator (with trigger)                         │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │  Stage 1: Detect & Route                                          │ │
│  │  • Classify changes by tech stack                                 │ │
│  │  • GO_SERVICES, JAVA_SERVICES, NODE_SERVICES                      │ │
│  │  • Spawn child pipeline per tech stack with services list         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│          ┌───────────────────┼───────────────────┐                      │
│          ▼                   ▼                   ▼                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │ CI-Golang    │    │  CI-Java     │    │  CI-Node     │              │
│  │              │    │              │    │              │              │
│  │ Input:       │    │ Input:       │    │ Input:       │              │
│  │ SERVICES[]   │    │ SERVICES[]   │    │ SERVICES[]   │              │
│  │ PR_STATE     │    │ PR_STATE     │    │ PR_STATE     │              │
│  │              │    │              │    │              │              │
│  │ Matrix exec  │    │ Matrix exec  │    │ Matrix exec  │              │
│  │ per service  │    │ per service  │    │ per service  │              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│                                                                          │
│  Files: 1 orchestrator + N children (4 total for 3 languages)          │
│  Maintenance: Low (changes in 1 child affect all services of that lang)│
│  Scalability: Unlimited                                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Migration from Phase 1:**
1. Rename `CI-Golang.yaml` to `children/CI-Golang.yaml`
2. Add input variables (SERVICES, PR_STATE)
3. Create `CI-Orchestrator.yaml` with trigger
4. Move trigger from child to orchestrator

### Phase 3: Enterprise Scale (100+ Services)

**When:** 100+ services, multiple teams, compliance requirements

**Additional features:**
- Service Registry (`platform/service-registry.yaml`)
- Dependency graph (test affected dependents)
- Distributed caching
- Compliance gates per service tier
- Team-based notifications

---

## Scaling Analysis

### Comparison: N Triggers vs Pipeline Chaining

| Metric | N Triggers (1 per service) | Pipeline Chaining |
|--------|---------------------------|-------------------|
| **YAML Files** | O(n) | O(1) per language |
| **Add New Service** | Create trigger + config | Nothing (auto-detected) |
| **Global CI Change** | Modify n files | Modify 1 file |
| **Maintenance Burden** | High (drift risk) | Low (centralized) |
| **Debugging** | Simple (isolated) | Medium (need to trace chains) |
| **Execution Independence** | Full | Full |
| **Resource Usage** | High (duplicate logic) | Optimized (shared stages) |

### Scaling Projections

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SCALING: 10 → 1000 SERVICES                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  YAML FILES TO MAINTAIN:                                                │
│  ════════════════════════════════════════════════════════════════════   │
│                                                                          │
│  N Triggers Strategy:                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  10 services   │████████████████████                         10 │    │
│  │  100 services  │████████████████████████████████████████    100 │    │
│  │  1000 services │████████████████████████████████████████   1000 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Pipeline Chaining (3 languages):                                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  10 services   │██████████                                    9 │    │
│  │  100 services  │██████████                                    9 │    │
│  │  1000 services │██████████                                    9 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  TIME TO ADD NEW SERVICE:                                               │
│  ════════════════════════════════════════════════════════════════════   │
│                                                                          │
│  N Triggers:                                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  1. Create service code                              │  30 min  │    │
│  │  2. Create trigger YAML                              │  15 min  │    │
│  │  3. PR review for trigger                            │  1-24 hr │    │
│  │  4. Merge and verify                                 │  15 min  │    │
│  │  ─────────────────────────────────────────────────────────────  │    │
│  │  Total: 1+ hours to 1+ day                                      │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Pipeline Chaining:                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  1. Create service code in services/go/{name}/       │  30 min  │    │
│  │  2. Push to PR                                       │   1 min  │    │
│  │  3. CI automatically detects and builds              │   0 min  │    │
│  │  ─────────────────────────────────────────────────────────────  │    │
│  │  Total: ~31 minutes (zero CI config needed)                     │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  CONSISTENCY GUARANTEE:                                                 │
│  ════════════════════════════════════════════════════════════════════   │
│                                                                          │
│  N Triggers: Each team can modify their trigger → DRIFT                 │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Team A: golang:1.22, coverage 80%, full security scans         │    │
│  │  Team B: golang:1.21, coverage 60%, no security scans ⚠️        │    │
│  │  Team C: golang:1.23-rc, coverage 90%, custom lint rules        │    │
│  │  Result: Inconsistent quality, hard to enforce standards        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Pipeline Chaining: Single source of truth → CONSISTENCY               │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  All Teams: golang:1.22, coverage 80%, full security scans      │    │
│  │  Exceptions: Configured via services/{name}/ci.yaml             │    │
│  │  Result: Platform team controls standards centrally             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Resource Efficiency

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PR modifies 5 services: movie, booking, payment, user, notification    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  N Triggers (5 separate pipeline executions):                           │
│  ─────────────────────────────────────────────────────────────────────  │
│  [Pipeline 1: movie]                                                    │
│    └─► Clone repo (full) ─► Detect ─► Build ─► Test ─► ...             │
│  [Pipeline 2: booking]                                                  │
│    └─► Clone repo (full) ─► Detect ─► Build ─► Test ─► ...             │
│  [Pipeline 3: payment]                                                  │
│    └─► Clone repo (full) ─► Detect ─► Build ─► Test ─► ...             │
│  [Pipeline 4: user]                                                     │
│    └─► Clone repo (full) ─► Detect ─► Build ─► Test ─► ...             │
│  [Pipeline 5: notification]                                             │
│    └─► Clone repo (full) ─► Detect ─► Build ─► Test ─► ...             │
│                                                                          │
│  Resources: 5 full clones, 5 detection phases (redundant)              │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                          │
│  Pipeline Chaining (1 orchestrator + 5 children):                       │
│  ─────────────────────────────────────────────────────────────────────  │
│  [Orchestrator]                                                         │
│    └─► Clone (shallow) ─► Detect ALL services ─► Spawn 5 children      │
│                                                                          │
│  [Child 1: movie]        ─► Sparse clone ─► Build ─► Test ─► ...       │
│  [Child 2: booking]      ─► Sparse clone ─► Build ─► Test ─► ...       │
│  [Child 3: payment]      ─► Sparse clone ─► Build ─► Test ─► ...       │
│  [Child 4: user]         ─► Sparse clone ─► Build ─► Test ─► ...       │
│  [Child 5: notification] ─► Sparse clone ─► Build ─► Test ─► ...       │
│                                                                          │
│  Resources: 1 detection phase, 5 sparse clones (faster, less data)     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Guide

### Directory Structure

```
.harness/
├── pipelines/
│   ├── orchestrators/
│   │   ├── golang-orchestrator.yaml      # Go services orchestrator
│   │   ├── java-orchestrator.yaml        # Java services orchestrator
│   │   └── node-orchestrator.yaml        # Node services orchestrator
│   │
│   └── children/
│       ├── golang-service.yaml           # Go service build template
│       ├── java-service.yaml             # Java service build template
│       └── node-service.yaml             # Node service build template
│
└── triggers/
    ├── golang-pr.yaml                    # Trigger for services/go/**
    ├── java-pr.yaml                      # Trigger for services/java/**
    └── node-pr.yaml                      # Trigger for services/node/**
```

### Configuration Files

Each service can optionally override defaults via `ci.yaml`:

```yaml
# services/go/movie/ci.yaml
build:
  go_version: "1.22"           # Override Go version
  
test:
  coverage_threshold: 85       # Higher than default 80%
  skip_benchmark: false
  
security:
  skip_semgrep: false
  skip_owasp: false
  
deploy:
  replicas: 3
  memory: "512Mi"
```

### Adding a New Language

To add support for a new language (e.g., Rust):

1. Create orchestrator: `.harness/pipelines/orchestrators/rust-orchestrator.yaml`
2. Create child pipeline: `.harness/pipelines/children/rust-service.yaml`
3. Create trigger: `.harness/triggers/rust-pr.yaml`
4. Create service directory: `services/rust/`

Total files needed: **3**

---

## Manual Pipeline Execution

While pipelines are triggered automatically via PRs, manual execution is useful for:
- **Testing**: Validate pipeline changes without creating a PR
- **Demos**: Run specific scenarios on demand
- **Debugging**: Re-run with specific services or branches

### InputSets Strategy

We use **InputSets by scenario** (not by service):

| InputSet | Purpose | Stage Executed |
|----------|---------|----------------|
| `validate_single_service` | Test code quality + security | Validate |
| `validate_multiple_services` | Test monorepo looping | Validate |
| `build_single_service` | Test Docker build + tags | Build |
| `full_pipeline_test` | Test both stages | Both |

**Why not 1 InputSet per service?**
- Services are runtime inputs, not hardcoded
- Adding a new service = 0 InputSet changes
- Scenarios (validate/build) are more useful groupings
- Less duplication, easier maintenance

### Execution Methods

**Method 1: Taskfile (recommended)**
```bash
# Validate booking service on step-1 branch
task pipeline:run SERVICE=booking BRANCH=step-1

# Build booking service (simulates merged PR)
task pipeline:run SERVICE=booking STAGE=build

# Validate multiple services
task pipeline:run:multi SERVICES=booking,movie,payment

# Check execution status
task pipeline:status EXEC_ID=xxxxx
```

**Method 2: Harness UI**
1. Pipelines → CI_Golang_v2 → Run
2. Select InputSet (e.g., `validate_single_service`)
3. Fill runtime inputs (branch, service)
4. Run Pipeline

**Method 3: Harness MCP (Claude Code)**
```
# Via MCP
harness_execute(
  resource_type="pipeline",
  resource_id="CI_Golang_v2",
  action="run",
  body={
    "inputSetRefs": ["validate_single_service"],
    "runtimeInputs": {
      "properties.ci.codebase.build.spec.branch": "step-1",
      "variables.SERVICES_JSON": "[\"booking\"]"
    }
  }
)
```

### Stage Execution Logic

The pipeline uses conditional execution based on PR state:

```
PR_STATE=open          → Validate stage runs (code quality, tests)
PR_STATE=closed
  + PR_MERGED=true     → Build stage runs (Docker, tags)
  + PR_MERGED=false    → Skip (PR rejected)
```

See: [.harness/inputsets/CI/README.md](../../.harness/inputsets/CI/README.md)

---

## Decision Matrix

### When to Use Each Pattern

| Scenario | Recommended Pattern | Rationale |
|----------|-------------------|-----------|
| < 5 services, single language | N Triggers | Simpler, overhead not justified |
| 5-50 services, single language | Pipeline Chaining | Starts to see scaling benefits |
| 50+ services, any languages | Pipeline Chaining | Essential for maintainability |
| Multi-language monorepo | Pipeline Chaining | 1 orchestrator per language |
| Strict per-service config | N Triggers or Hybrid | If services are truly independent |
| Platform team manages CI | Pipeline Chaining | Centralized control |
| Each team manages own CI | N Triggers | Full autonomy |

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Matrix with autoAbort | Cancels unrelated services | Use Pipeline Chaining |
| Single mega-pipeline | Too complex, slow | Split by language |
| Trigger per service | Doesn't scale | Consolidate to orchestrator |
| No service detection | Builds everything every time | Implement git diff detection |
| Hardcoded service list | Manual updates needed | Dynamic detection |

---

## Applied Corrections

The following corrections were identified and applied in the v2 pipeline:

### Critical Fixes

| Issue | Original (Broken) | Corrected | Impact |
|-------|-------------------|-----------|--------|
| **Merge condition** | `state == "merged"` | `action == "closed" && merged == true` | Build/Release stages now execute |
| **Typo in condition** | `pull_req.state` | `pull_request.state` | Condition evaluates correctly |
| **Go version** | `golang:1.24` | `golang:1.22` | Builds succeed (1.24 doesn't exist) |
| **Truncated paths** | `services/<` | `services/<+matrix.service>` | Build finds correct service |
| **Hardcoded service** | `workspace: movie` | `workspace: <+matrix.service>` | All services get scanned |
| **Disabled security** | `condition: "false"` | Removed or enabled | Security scans run |

### GitHub Webhook Payload Reference

Understanding GitHub's PR webhook payload is critical for correct conditions:

```
┌─────────────────────────────────────────────────────────────────────────┐
│              GITHUB PR WEBHOOK PAYLOAD STRUCTURE                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Event: Pull Request                                                    │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  PR Opened:                                                             │
│  {                                                                       │
│    "action": "opened",                                                  │
│    "pull_request": {                                                    │
│      "state": "open",                                                   │
│      "merged": false                                                    │
│    }                                                                     │
│  }                                                                       │
│                                                                          │
│  PR Synchronized (new push):                                            │
│  {                                                                       │
│    "action": "synchronize",                                             │
│    "pull_request": {                                                    │
│      "state": "open",                                                   │
│      "merged": false                                                    │
│    }                                                                     │
│  }                                                                       │
│                                                                          │
│  PR Merged:                                                             │
│  {                                                                       │
│    "action": "closed",          ← NOT "merged"!                         │
│    "pull_request": {                                                    │
│      "state": "closed",         ← NOT "merged"!                         │
│      "merged": true             ← This is the merge indicator           │
│    }                                                                     │
│  }                                                                       │
│                                                                          │
│  PR Closed (without merge):                                             │
│  {                                                                       │
│    "action": "closed",                                                  │
│    "pull_request": {                                                    │
│      "state": "closed",                                                 │
│      "merged": false                                                    │
│    }                                                                     │
│  }                                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Correct Harness Conditions

```yaml
# PR is Open (for validation steps)
when:
  condition: <+trigger.payload.pull_request.state> == "open"

# PR was Merged (for build/release steps)
when:
  condition: >-
    <+trigger.payload.action> == "closed" && 
    <+trigger.payload.pull_request.merged> == true

# PR was Closed without merge (for cleanup, if needed)
when:
  condition: >-
    <+trigger.payload.action> == "closed" && 
    <+trigger.payload.pull_request.merged> == false
```

---

## CI Stages vs StepGroups: Architectural Decision

### The Question

The child pipeline (`CI_Golang_v2`) uses **separate CI Stages** for Validate and Build/Release instead of **StepGroups** within a single stage. This is a deliberate architectural choice.

### Comparison

```
┌─────────────────────────────────────────────────────────────────────────┐
│              OPTION A: MULTIPLE CI STAGES (Current Implementation)      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Stage: Validate (CI Stage)                                        │ │
│  │  when: PR_STATE == "open"                                          │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │Initialize│ │  Format  │ │   Lint   │ │   Test   │ │ Coverage │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Stage: Build & Release (CI Stage)                                 │ │
│  │  when: PR merged                                                   │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │ Security │ │ Version  │ │  Build   │ │  Docker  │ │ Release  │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│              OPTION B: SINGLE CI STAGE WITH STEPGROUPS                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Stage: CI (Single CI Stage)                                       │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  StepGroup: Validate (when: PR open)                         │  │ │
│  │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │  │ │
│  │  │  │  Init  │ │ Format │ │  Lint  │ │  Test  │ │Coverage│     │  │ │
│  │  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘     │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  StepGroup: Build & Release (when: PR merged)                │  │ │
│  │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │  │ │
│  │  │  │Security│ │Version │ │ Build  │ │ Docker │ │Release │     │  │ │
│  │  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘     │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Pros and Cons

| Aspect | Multiple CI Stages | Single Stage + StepGroups |
|--------|-------------------|---------------------------|
| **Stage-level conditions** | ✅ Native `when:` at stage level | ⚠️ Must use `when:` on each StepGroup |
| **Caching isolation** | ✅ Each stage has its own cache config | ❌ Shared cache config for entire stage |
| **Failure isolation** | ✅ Stage failure doesn't affect other stages | ⚠️ StepGroup failure may affect stage |
| **Parallelism** | ✅ Stages can run in parallel (if no dependency) | ❌ StepGroups are sequential within stage |
| **Resource allocation** | ✅ Different infrastructure per stage | ❌ Same infrastructure for entire stage |
| **Harness UI visibility** | ✅ Clear stage boundaries in execution view | ⚠️ Nested view, harder to navigate |
| **Retry granularity** | ✅ Can retry individual stage | ⚠️ Must retry from StepGroup start |
| **Build Intelligence** | ✅ Per-stage intelligence settings | ❌ Single setting for entire stage |
| **Pipeline complexity** | ⚠️ More YAML, more stages | ✅ Compact YAML, fewer stages |
| **Shared state** | ⚠️ Must pass variables between stages | ✅ Variables shared within stage |

### Recommendation

| Scenario | Recommended Approach |
|----------|---------------------|
| **Independent execution phases** (Validate vs Build) | **Multiple CI Stages** |
| **Logically grouped steps** (Format + Lint together) | **StepGroups within a Stage** |
| **Different infrastructure needs** (tests vs Docker build) | **Multiple CI Stages** |
| **Need to skip entire phase** (skip Build on PR Open) | **Multiple CI Stages** |
| **Simple sequential flow** (all steps always run) | **Single Stage + StepGroups** |

### Current Implementation Choice

We use **Multiple CI Stages** because:

1. **Validate** and **Build/Release** are fundamentally different phases with different conditions
2. Each stage can have its own caching strategy optimized for its workload
3. Stage-level `when:` conditions make the intent clear and maintainable
4. The Harness UI shows clear progression through distinct phases
5. Failed builds are easier to retry at the appropriate boundary

---

## Multi-Language Service Detection

### The Challenge

The orchestrator must route services to the correct child pipeline based on technology stack. Currently, the detection script filters `services/*` but doesn't differentiate between Go, Java, or Node services.

### Solution: Language-Aware Detection

```
┌─────────────────────────────────────────────────────────────────────────┐
│              LANGUAGE DETECTION STRATEGIES                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STRATEGY 1: Directory Convention (Recommended)                         │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  Directory structure:                                                   │
│  services/                                                              │
│  ├── go/                    ← Go services                               │
│  │   ├── movie/                                                         │
│  │   ├── booking/                                                       │
│  │   └── payment/                                                       │
│  ├── java/                  ← Java services                             │
│  │   ├── notification/                                                  │
│  │   └── analytics/                                                     │
│  └── node/                  ← Node.js services                          │
│      ├── frontend/                                                      │
│      └── gateway/                                                       │
│                                                                          │
│  Detection: changedFiles filter by path prefix                          │
│  • ^services/go/.+   → CI_Golang_Orchestrator                           │
│  • ^services/java/.+ → CI_Java_Orchestrator                             │
│  • ^services/node/.+ → CI_Node_Orchestrator                             │
│                                                                          │
│  Pros: ✅ Simple, explicit, no file inspection needed                   │
│  Cons: ⚠️ Requires directory restructuring if flat today                │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STRATEGY 2: Manifest File Detection (Current Monorepo)                 │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  Directory structure (flat):                                            │
│  services/                                                              │
│  ├── movie/          ← go.mod exists → Go                               │
│  ├── booking/        ← go.mod exists → Go                               │
│  ├── notification/   ← pom.xml exists → Java                            │
│  └── frontend/       ← package.json exists → Node                       │
│                                                                          │
│  Detection logic in orchestrator:                                       │
│  ```bash                                                                │
│  for service in $SERVICES; do                                           │
│    if [ -f "services/$service/go.mod" ]; then                          │
│      GO_SERVICES="$GO_SERVICES,$service"                               │
│    elif [ -f "services/$service/pom.xml" ]; then                       │
│      JAVA_SERVICES="$JAVA_SERVICES,$service"                           │
│    elif [ -f "services/$service/package.json" ]; then                  │
│      NODE_SERVICES="$NODE_SERVICES,$service"                           │
│    fi                                                                   │
│  done                                                                   │
│  ```                                                                    │
│                                                                          │
│  Pros: ✅ Works with flat structure, auto-detects language              │
│  Cons: ⚠️ Requires repo clone to inspect files                         │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STRATEGY 3: Service Registry (Enterprise Scale)                        │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  File: platform/service-registry.yaml                                   │
│  ```yaml                                                                │
│  services:                                                              │
│    movie:                                                               │
│      language: go                                                       │
│      path: services/movie                                               │
│      team: streaming                                                    │
│    notification:                                                        │
│      language: java                                                     │
│      path: services/notification                                        │
│      team: engagement                                                   │
│  ```                                                                    │
│                                                                          │
│  Pros: ✅ Full metadata, team routing, custom configs                   │
│  Cons: ⚠️ Must maintain registry (potential drift)                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Recommended Implementation for Current Monorepo

Since the current monorepo has a flat `services/` structure with Go services, implement **Strategy 2** in the orchestrator:

```yaml
# In CI_Golang_Orchestrator - detect_services stage
- step:
    type: Run
    name: Classify Services by Language
    identifier: classify_services
    spec:
      shell: Bash
      command: |
        GO_SERVICES=""
        JAVA_SERVICES=""
        NODE_SERVICES=""
        UNKNOWN_SERVICES=""
        
        for service in $(echo "$SERVICES" | tr ',' ' '); do
          if [ -f "services/$service/go.mod" ]; then
            GO_SERVICES="${GO_SERVICES}${GO_SERVICES:+,}$service"
          elif [ -f "services/$service/pom.xml" ] || [ -f "services/$service/build.gradle" ]; then
            JAVA_SERVICES="${JAVA_SERVICES}${JAVA_SERVICES:+,}$service"
          elif [ -f "services/$service/package.json" ]; then
            NODE_SERVICES="${NODE_SERVICES}${NODE_SERVICES:+,}$service"
          else
            UNKNOWN_SERVICES="${UNKNOWN_SERVICES}${UNKNOWN_SERVICES:+,}$service"
            echo "WARNING: Unknown language for service: $service"
          fi
        done
        
        # Convert to JSON arrays for matrix strategy
        GO_SERVICES_JSON=$(echo "$GO_SERVICES" | tr ',' '\n' | jq -R -s -c 'split("\n") | map(select(length > 0))')
        JAVA_SERVICES_JSON=$(echo "$JAVA_SERVICES" | tr ',' '\n' | jq -R -s -c 'split("\n") | map(select(length > 0))')
        NODE_SERVICES_JSON=$(echo "$NODE_SERVICES" | tr ',' '\n' | jq -R -s -c 'split("\n") | map(select(length > 0))')
        
        echo "Go services: $GO_SERVICES_JSON"
        echo "Java services: $JAVA_SERVICES_JSON"
        echo "Node services: $NODE_SERVICES_JSON"
        
        export GO_SERVICES_JSON JAVA_SERVICES_JSON NODE_SERVICES_JSON
      outputVariables:
        - name: GO_SERVICES_JSON
        - name: JAVA_SERVICES_JSON
        - name: NODE_SERVICES_JSON
```

Then conditionally trigger child pipelines:

```yaml
# Stage: Trigger Go Services
- stage:
    name: Trigger Go Pipelines
    type: Pipeline
    when:
      condition: <+pipeline.stages.detect_services.spec.execution.steps.classify_services.output.outputVariables.GO_SERVICES_JSON> != "[]"
    spec:
      pipeline: CI_Golang_v2
      # ... inputs

# Stage: Trigger Java Services  
- stage:
    name: Trigger Java Pipelines
    type: Pipeline
    when:
      condition: <+pipeline.stages.detect_services.spec.execution.steps.classify_services.output.outputVariables.JAVA_SERVICES_JSON> != "[]"
    spec:
      pipeline: CI_Java_v2
      # ... inputs
```

---

## Harness MCP Server Implementation

### Implemented Pipeline Architecture

The following architecture was deployed using the Harness MCP Server:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DEPLOYED ARCHITECTURE (2 Pipelines)                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  TRIGGER: golang-services-orchestrator-trigger                     │ │
│  │  Type: GitHub PR Webhook                                           │ │
│  │  Events: Open, Reopen, Synchronize, Close                          │ │
│  │  Conditions:                                                        │ │
│  │    • changedFiles: ^services/.+ (regex)                            │ │
│  │    • targetBranch: step-1, main                                    │ │
│  │  Auto-abort: true (only affects orchestrator, not children)        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│                                    ▼                                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  PIPELINE 1: CI_Golang_Orchestrator (Parent)                       │ │
│  │  Identifier: CI_Golang_Orchestrator                                │ │
│  │  Tags: type=orchestrator                                           │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  Stage 1: Detect Services                                          │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  • Clone repo (shallow)                                       │  │ │
│  │  │  • Call GitHub API: GET /pulls/{pr}/files                     │  │ │
│  │  │  • Filter: services/{service}/*                               │  │ │
│  │  │  • Extract unique service names                               │  │ │
│  │  │  • Output: SERVICES_JSON, PR_STATE, PR_ACTION, PR_MERGED      │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  Stage 2: Trigger Service Pipelines (Pipeline Chaining)            │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  Type: Pipeline Stage                                         │  │ │
│  │  │  Target: CI_Golang_v2                                         │  │ │
│  │  │  Strategy: matrix { service: SERVICES_JSON }                  │  │ │
│  │  │  Max Concurrency: 3                                           │  │ │
│  │  │  Inputs passed to child:                                      │  │ │
│  │  │    • SERVICE_NAME: <+matrix.service>                          │  │ │
│  │  │    • PR_STATE, PR_ACTION, PR_MERGED                           │  │ │
│  │  │    • Codebase: PR number from trigger                         │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                    │                                     │
│            ┌───────────────────────┼───────────────────────┐            │
│            │ (per service)         │                       │            │
│            ▼                       ▼                       ▼            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  PIPELINE 2: CI_Golang_v2 (Child)                                  │ │
│  │  Identifier: CI_Golang_v2                                          │ │
│  │  Tags: type=child                                                  │ │
│  │  ══════════════════════════════════════════════════════════════════│ │
│  │                                                                     │ │
│  │  Input Variables:                                                  │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  • SERVICE_NAME: The service to build (e.g., "movie")        │  │ │
│  │  │  • PR_STATE: "open" or "closed"                              │  │ │
│  │  │  • PR_ACTION: "opened", "synchronize", "closed"              │  │ │
│  │  │  • PR_MERGED: "true" or "false"                              │  │ │
│  │  │  • GO_VERSION: "1.22" (default)                              │  │ │
│  │  │  • COVERAGE_THRESHOLD: "80" (default)                        │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  Stage 1: Validate (when: PR_STATE == "open")                      │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │  │ │
│  │  │  │Initialize│→│  Format  │→│   Lint   │→│Unit Tests│        │  │ │
│  │  │  │go mod    │ │  gofmt   │ │golangci- │ │go test   │        │  │ │
│  │  │  │download  │ │  check   │ │lint run  │ │-race -v  │        │  │ │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │  │ │
│  │  │       │                                        │             │  │ │
│  │  │       ▼                                        ▼             │  │ │
│  │  │  ┌──────────┐                           ┌──────────┐        │  │ │
│  │  │  │ Coverage │                           │Benchmarks│        │  │ │
│  │  │  │  >= 80%  │                           │ go test  │        │  │ │
│  │  │  │  check   │                           │ -bench=. │        │  │ │
│  │  │  └──────────┘                           └──────────┘        │  │ │
│  │  │                                                              │  │ │
│  │  │  Features: Test Intelligence, JUnit reports, Caching        │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                    │                                │ │
│  │                                    ▼                                │ │
│  │  Stage 2: Build & Release (when: PR merged)                        │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │  │ │
│  │  │  │ Semgrep  │→│ Generate │→│  Build   │→│  Docker  │        │  │ │
│  │  │  │ Security │ │ SemVer   │ │  Binary  │ │Build/Push│        │  │ │
│  │  │  │   Scan   │ │ Version  │ │CGO=0 amd │ │ cramirez │        │  │ │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │  │ │
│  │  │                                    │                         │  │ │
│  │  │       ┌────────────────────────────┼────────────────┐       │  │ │
│  │  │       ▼                            ▼                ▼       │  │ │
│  │  │  ┌──────────┐              ┌──────────┐      ┌──────────┐   │  │ │
│  │  │  │  Grype   │              │  Create  │      │   DinD   │   │  │ │
│  │  │  │Container │              │ Release  │      │Background│   │  │ │
│  │  │  │  Scan    │              │  Tag     │      │          │   │  │ │
│  │  │  └──────────┘              └──────────┘      └──────────┘   │  │ │
│  │  │                                                              │  │ │
│  │  │  SemVer: release* → MAJOR, update* → MINOR, fix* → PATCH   │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  │                                                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### MCP Commands Executed

```python
# 1. Create Child Pipeline (Service)
harness_create(
    resource_type="pipeline",
    org_id="sandbox",
    project_id="CristianRamirez",
    body={
        "yamlPipeline": """
        pipeline:
          identifier: CI_Golang_v2
          name: CI - Golang Service v2
          tags: { type: child }
          variables:
            - name: SERVICE_NAME
              type: String
              required: true
              value: <+input>
            - name: PR_STATE
              type: String
              required: true
              value: <+input>
            # ... (full YAML in Harness)
          stages:
            - stage: Validate (when PR open)
            - stage: Build & Release (when PR merged)
        """
    }
)

# 2. Create Orchestrator Pipeline (Parent)
harness_create(
    resource_type="pipeline",
    org_id="sandbox",
    project_id="CristianRamirez",
    body={
        "yamlPipeline": """
        pipeline:
          identifier: CI_Golang_Orchestrator
          name: CI - Golang Orchestrator
          tags: { type: orchestrator }
          stages:
            - stage: Detect Services (CI Stage)
            - stage: Trigger Service Pipelines (Pipeline Stage)
              spec:
                pipeline: CI_Golang_v2
                strategy:
                  matrix:
                    service: <+SERVICES_JSON>
        """
    }
)

# 3. Create Trigger (points to Orchestrator)
harness_create(
    resource_type="trigger",
    org_id="sandbox",
    project_id="CristianRamirez",
    params={"pipeline_id": "CI_Golang_Orchestrator"},
    body={
        "name": "golang-services-orchestrator-trigger",
        "identifier": "golang_services_orchestrator_trigger",
        "enabled": True,
        "pipelineIdentifier": "CI_Golang_Orchestrator",
        "source": {
            "type": "Webhook",
            "spec": {
                "type": "Github",
                "spec": {
                    "type": "PullRequest",
                    "spec": {
                        "connectorRef": "CristianConnector",
                        "repoName": "cinema-microservice-in-GO",
                        "autoAbortPreviousExecutions": True,
                        "actions": ["Open", "Reopen", "Synchronize", "Close"],
                        "payloadConditions": [
                            {"key": "changedFiles", "operator": "Regex", "value": "^services/.+"},
                            {"key": "targetBranch", "operator": "In", "value": "step-1, main"}
                        ]
                    }
                }
            }
        }
    }
)

# 4. Verify deployment
harness_status(org_id="sandbox", project_id="CristianRamirez")
```

### Deployed Resources

| Resource | Identifier | Harness Link |
|----------|------------|--------------|
| Orchestrator Pipeline | `CI_Golang_Orchestrator` | [Open in Harness](https://app.harness.io/ng/account/EeRjnXTnS4GrLG5VNNJZUw/all/orgs/sandbox/projects/CristianRamirez/pipelines/CI_Golang_Orchestrator/pipeline-studio) |
| Service Pipeline | `CI_Golang_v2` | [Open in Harness](https://app.harness.io/ng/account/EeRjnXTnS4GrLG5VNNJZUw/all/orgs/sandbox/projects/CristianRamirez/pipelines/CI_Golang_v2/pipeline-studio) |
| Trigger | `golang_services_orchestrator_trigger` | [Open in Harness](https://app.harness.io/ng/account/EeRjnXTnS4GrLG5VNNJZUw/all/orgs/sandbox/projects/CristianRamirez/pipelines/CI_Golang_Orchestrator/triggers) |

### Pipeline Variables Reference

| Variable | Pipeline | Type | Default | Description |
|----------|----------|------|---------|-------------|
| `GO_VERSION` | Child | String | "1.22" | Go compiler version |
| `COVERAGE_THRESHOLD` | Child | String | "80" | Minimum coverage % |
| `SERVICE_NAME` | Child | String | `<+input>` | Service to build (from orchestrator) |
| `PR_STATE` | Child | String | `<+input>` | PR state: "open" or "closed" |
| `PR_ACTION` | Child | String | `<+input>` | PR action: "opened", "synchronize", "closed" |
| `PR_MERGED` | Child | String | `<+input>` | Whether PR was merged: "true" or "false" |

### Connectors and Secrets Required

| Resource | Type | Usage |
|----------|------|-------|
| `CristianConnector` | GitHub Connector | Repository access, PR webhooks |
| `CristianDocker` | Docker Registry | Push container images |
| `account.harnessImage` | Account Connector | Pull Harness base images |
| `harnessToken` | Secret | Harness API for tag creation |

---

## Semantic Versioning per Service

### The Challenge

In a monorepo with independent services, a global version (e.g., `v1.2.3`) doesn't work because:
- Services evolve at different rates
- A breaking change in `movie` shouldn't bump `booking`'s version
- Teams need independent release cycles

### Solution: Service-Prefixed Tags + Conventional Commits with Scope

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SEMANTIC VERSIONING PER SERVICE                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  TAG FORMAT: {service}-v{major}.{minor}.{patch}                         │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  Examples:                                                              │
│    movie-v1.2.3                                                         │
│    booking-v2.0.1                                                       │
│    payment-v1.0.0                                                       │
│                                                                          │
│  Each service has its own independent version history:                  │
│    $ git tag -l "movie-v*"                                              │
│    movie-v1.0.0                                                         │
│    movie-v1.1.0                                                         │
│    movie-v1.2.0                                                         │
│    movie-v1.2.1                                                         │
│    movie-v1.2.2                                                         │
│    movie-v1.2.3  ← current                                              │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  COMMIT FORMAT: {type}({service}): {description}                        │
│  ═══════════════════════════════════════════════════════════════════    │
│                                                                          │
│  Examples:                                                              │
│    feat(movie): add rating system           → movie MINOR bump          │
│    fix(booking): handle timezone correctly  → booking PATCH bump        │
│    feat(payment)!: new payment API          → payment MAJOR bump        │
│    chore(movie): update dependencies        → movie PATCH bump          │
│                                                                          │
│  Bump Rules:                                                            │
│  ─────────────────────────────────────────────────────────────────────  │
│    {type}({service})!: or BREAKING CHANGE  →  MAJOR (X.0.0)            │
│    feat({service}):                        →  MINOR (x.Y.0)            │
│    fix|perf|refactor({service}):           →  PATCH (x.y.Z)            │
│    No scoped commit found                  →  PATCH (default)          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation in Pipeline

```yaml
# Step: Semantic Version (runs per service in matrix)
- step:
    name: Semantic Version
    identifier: semantic_version
    spec:
      command: |
        SERVICE="<+repeat.item>"  # e.g., "movie"
        
        # 1. Get latest tag for THIS service only
        LATEST_TAG=$(git tag -l "${SERVICE}-v*" --sort=-v:refname | head -1)
        # Result: movie-v1.2.2
        
        # 2. Extract current version
        VERSION="${LATEST_TAG#${SERVICE}-v}"  # 1.2.2
        
        # 3. Analyze commits with scope matching this service
        #    Only commits like "feat(movie):" affect movie's version
        if echo "$COMMITS" | grep -qE "feat\($SERVICE\)!:"; then
          BUMP="major"
        elif echo "$COMMITS" | grep -qE "feat\($SERVICE\):"; then
          BUMP="minor"
        else
          BUMP="patch"
        fi
        
        # 4. Calculate new version and tag
        NEW_VERSION="v1.2.3"  # calculated
        TAG_NAME="${SERVICE}-${NEW_VERSION}"  # movie-v1.2.3
```

### Benefits

| Aspect | Global Version | Service-Prefixed Tags |
|--------|---------------|----------------------|
| **Independence** | ❌ All services bump together | ✅ Each service independent |
| **Rollback** | ❌ Complex (affects all) | ✅ `git checkout movie-v1.2.2` |
| **History** | ❌ Mixed across services | ✅ `git tag -l "movie-v*"` |
| **Docker tags** | ❌ Same version for all | ✅ `movie:v1.2.3`, `booking:v2.0.1` |
| **Breaking changes** | ❌ Bumps all services | ✅ Only affected service |
| **Release frequency** | ❌ Coordinated releases | ✅ Independent releases |

### Git Tag History Example

```
$ git tag -l --sort=-creatordate | head -20
payment-v1.0.1      ← payment released today
movie-v1.2.3        ← movie released yesterday
booking-v2.0.1      ← booking released 3 days ago
movie-v1.2.2        ← movie hotfix last week
notification-v1.0.0 ← notification first release
movie-v1.2.1
movie-v1.2.0
booking-v2.0.0      ← booking breaking change
movie-v1.1.0
booking-v1.5.0
...
```

### Docker Image Tags

Each service's Docker image uses its independent version:

```bash
# Images in registry
docker.io/cramirez/movie:v1.2.3
docker.io/cramirez/movie:latest
docker.io/cramirez/booking:v2.0.1
docker.io/cramirez/booking:latest
docker.io/cramirez/payment:v1.0.1
docker.io/cramirez/payment:latest
```

---

## References

- [Harness Pipeline Chaining Documentation](https://developer.harness.io/docs/platform/pipelines/pipeline-chaining/)
- [Harness Triggers](https://developer.harness.io/docs/platform/triggers/triggering-pipelines/)
- [Monorepo CI/CD Best Practices](https://monorepo.tools/)
- [ADR-006: dev:up vs test:e2e](./adr/ADR-006-dev-up-vs-test-e2e.md)
- [GitHub Webhooks: Pull Request Events](https://docs.github.com/en/webhooks/webhook-events-and-payloads#pull_request)

---

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2026-04-08 | Platform Team | Initial version |
| 2026-04-08 | Platform Team | Added Applied Corrections and MCP Server Prompt sections |
| 2026-04-08 | Platform Team | Added GitHub webhook payload reference |
| 2026-04-08 | Platform Team | **Major update**: Implemented 2-pipeline architecture with Pipeline Chaining |
| 2026-04-08 | Platform Team | Added CI Stages vs StepGroups architectural decision section |
| 2026-04-08 | Platform Team | Added Multi-Language Service Detection strategies |
| 2026-04-08 | Platform Team | Updated MCP commands to reflect deployed orchestrator + child pipeline |
| 2026-04-08 | Platform Team | **Shift-Left Security**: Moved security scans (Semgrep, OWASP) to PR Open stage |
| 2026-04-08 | Platform Team | Removed trigger from child pipeline - only orchestrator has triggers |
| 2026-04-08 | Platform Team | Build stage now only compiles/pushes - no security scans (already validated) |
| 2026-04-09 | Platform Team | **Language Agnostic Orchestrator**: Renamed CI_Golang_Orchestrator to CI_Orchestrator |
| 2026-04-09 | Platform Team | Orchestrator now uses `<+trigger.payload.commits>` (native Harness) instead of GitHub API |
| 2026-04-09 | Platform Team | Implemented STRATEGY 2: Manifest File Detection (go.mod, pom.xml, package.json) |
| 2026-04-09 | Platform Team | Child pipeline (CI_Golang_v2) now receives services as INPUT - no detection |
| 2026-04-09 | Platform Team | **Semantic Versioning per Service**: Service-prefixed tags + Conventional Commits with scope |
| 2026-04-09 | Platform Team | Tag format: `{service}-v{major}.{minor}.{patch}` (e.g., `movie-v1.2.3`) |
| 2026-04-09 | Platform Team | Commit format: `{type}({service}): description` (e.g., `feat(movie): add ratings`) |
| 2026-04-09 | Platform Team | Updated Docker connector to CristianDocker |
| 2026-04-09 | Platform Team | **v2.5**: Added Benchmark Tests, Contract Tests, API Validation (Spectral) |
| 2026-04-09 | Platform Team | All test types now use `type: Test` with JUnit reports + Test Intelligence |
| 2026-04-09 | Platform Team | **v2.6**: Replaced Format/Lint with Complexity Analysis + Code Duplication |
| 2026-04-09 | Platform Team | Complexity Analysis uses `gocyclo` (threshold: 15, blocking) |
| 2026-04-09 | Platform Team | Code Duplication uses `dupl` (threshold: 100 tokens, warning only) |
| 2026-04-09 | Platform Team | **Repeatable Lab System**: Added demo scenarios and exercise framework |
| 2026-04-09 | Platform Team | See: `docs/demo-blocks/CI/REPEATABLE_LAB_SYSTEM.md` |
| 2026-04-09 | Platform Team | **Manual Execution**: Added InputSets for manual pipeline execution |
| 2026-04-09 | Platform Team | InputSets by scenario (validate/build) not by service - better maintainability |
| 2026-04-09 | Platform Team | Added Taskfile tasks: `pipeline:run`, `pipeline:run:multi`, `pipeline:status` |
| 2026-04-09 | Platform Team | See: `.harness/inputsets/CI/README.md` |
| 2026-04-09 | Platform Team | **v2.7**: Simplified variables for manual+auto compatibility |
| 2026-04-09 | Platform Team | Replaced PR_STATE/PR_ACTION/PR_MERGED with single RUN_MODE (validate\|build\|full) |
| 2026-04-09 | Platform Team | Replaced SERVICES_JSON array with SERVICES comma-separated string |
| 2026-04-09 | Platform Team | Added VERSION_BUMP variable for explicit version control |
| 2026-04-09 | Platform Team | Simplified InputSets: validate_service, build_service, full_pipeline |
