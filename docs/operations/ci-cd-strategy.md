# CI/CD Strategy: Digest-Based Container Pipeline

## Overview

This document describes the CI/CD pipeline strategy for Cinema Microservices, optimized for:

- **Agility**: Fast feedback loops for developers
- **Traceability**: Complete audit trail linking scans to releases
- **Cost Efficiency**: Single build/scan per PR, zero redundancy

## Pipeline Version

**Current:** v3.2 (Monorepo Optimized)
- 2 stages (Validate+Build / Release)
- 5 step groups with looping strategy for monorepo
- 2 GitHub status calls
- 1 consolidated PR comment with multi-service digests
- 7 security scanners (Harness SAST/SCA/Container, Snyk Code/Container, Trivy, Gitleaks)

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CI/CD PIPELINE FLOW (v3.2 Monorepo)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PR Open (build mode)                 PR Merge (full mode)                  │
│  ════════════════════                 ════════════════════                  │
│                                                                             │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │  STAGE 1: Validate and Build    │  │  STAGE 2: Release               │  │
│  │  (~5 minutes)                   │  │  (~3 minutes)                   │  │
│  ├─────────────────────────────────┤  ├─────────────────────────────────┤  │
│  │                                 │  │                                 │  │
│  │  ┌─ StepGroup: Code Quality ──┐ │  │  ┌─ StepGroup: Release ───────┐ │  │
│  │  │ [parallel]                 │ │  │  │ [repeat: SERVICES]         │ │  │
│  │  │ • Lint & Format            │ │  │  │  1. Fetch PR Digest        │ │  │
│  │  │ • Complexity Analysis      │ │  │  │  2. Semantic Version       │ │  │
│  │  │ • Code Duplication         │ │  │  │  3. Build Binary           │ │  │
│  │  └────────────────────────────┘ │  │  │  4. Build Container        │ │  │
│  │                                 │  │  │  5. Verify Digest → FAIL   │ │  │
│  │  ┌─ StepGroup: Security ──────┐ │  │  │  6. Push to Registry       │ │  │
│  │  │ [parallel]                 │ │  │  │  7. Create Git Tag         │ │  │
│  │  │ • Harness SAST (Semgrep)   │ │  │  └────────────────────────────┘ │  │
│  │  │ • Harness SCA              │ │  │                                 │  │
│  │  │ • Snyk Code                │ │  │  ┌─ StepGroup: Summary ───────┐ │  │
│  │  │ • Gitleaks (secrets)       │ │  │  │ • GitHub Status            │ │  │
│  │  └────────────────────────────┘ │  │  └────────────────────────────┘ │  │
│  │                                 │  │                                 │  │
│  │  ┌─ StepGroup: Tests ─────────┐ │  └─────────────────────────────────┘  │
│  │  │ [repeat: SERVICES]         │ │                                       │
│  │  │ [parallel per service]     │ │           ▲                           │
│  │  │ • Unit Tests + Coverage    │ │           │                           │
│  │  │ • OpenAPI Validation       │ │    sha256:abc123 (per service)        │
│  │  │ • Contract Tests (Pact)    │ │           │                           │
│  │  └────────────────────────────┘ │           │                           │
│  │                                 │           │                           │
│  │  ┌─ StepGroup: Build ─────────┐ │           │                           │
│  │  │ [repeat: SERVICES]         │ │           │                           │
│  │  │ • Build Binary             ├─┼───────────┘                           │
│  │  │ • Build Container          │ │                                       │
│  │  │ • Capture Digest           │ │                                       │
│  │  │ [parallel container scans] │ │                                       │
│  │  │   • Trivy                  │ │                                       │
│  │  │   • Harness Container SCA  │ │                                       │
│  │  │   • Snyk Container         │ │                                       │
│  │  └────────────────────────────┘ │                                       │
│  │                                 │                                       │
│  │  ┌─ StepGroup: Summary ───────┐ │                                       │
│  │  │ • Security Gate            │ │                                       │
│  │  │ • PR Comment (all digests) │ │                                       │
│  │  │ • GitHub Status            │ │                                       │
│  │  └────────────────────────────┘ │                                       │
│  │                                 │                                       │
│  └─────────────────────────────────┘                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Step Groups and Looping Strategy

| Step Group | Looping | Parallelism | Description |
|------------|---------|-------------|-------------|
| Code Quality | No | 3 parallel steps | Lint, complexity, duplication (all services) |
| Security Scans | No | 4 parallel steps | Repo-wide SAST, SCA, Snyk, Gitleaks |
| Service Tests | `repeat: SERVICES` | 3 parallel per service | Unit, OpenAPI, Contract tests |
| Build Services | `repeat: SERVICES` | 3 parallel scans | Binary, container, security scans |
| Summary | No | 1 step | Security gate, PR comment, status |

---

## Digest-Based Optimization

### The Problem

Traditional pipelines rebuild and rescan containers on both PR Open and PR Merge, causing:

| Issue | Impact |
|-------|--------|
| Redundant builds | +3 minutes per merge |
| Redundant scans | +2 minutes per merge |
| Increased costs | 2x compute per PR |
| Audit mismatch | PR scan ≠ release tag |

### The Solution

Use the **image digest** (SHA256 hash of image contents) to link PR scans to releases:

```
┌─────────────────────────────────────────────────────────────────┐
│                    DIGEST-BASED FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PR Open:                                                       │
│    Build Image ─────► sha256:abc123def456...                   │
│    Scan Image ──────► Report: "sha256:abc123 - 0 critical"     │
│    Store ───────────► PR metadata: {digest, report_url}        │
│                                                                 │
│  PR Merge:                                                      │
│    Build Image ─────► sha256:abc123def456... (cache hit)       │
│    Compare ─────────► PR digest == Build digest?               │
│      │                                                          │
│      ├─ YES ────────► Skip scan, reuse PR report               │
│      │                Tag as v1.2.3, Push                       │
│      │                                                          │
│      └─ NO ─────────► Something changed, rescan                │
│                       Tag as v1.2.3, Push                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Works

Docker images are **content-addressable**:

```bash
# Same Dockerfile + same dependencies = same digest
$ docker inspect movie-service:pr-123 --format='{{.Id}}'
sha256:abc123def456...

$ docker inspect movie-service:v1.2.3 --format='{{.Id}}'
sha256:abc123def456...  # Identical!
```

The digest is deterministic. If the build inputs don't change, the digest is identical.

---

## Audit Trail & Traceability

### Compliance Requirements

| Requirement | How We Meet It |
|-------------|----------------|
| Scanned before release | Container scan on PR Open blocks merge |
| Scan matches release | Digest links PR scan to released image |
| Immutable evidence | Scan reports stored in Harness/artifact storage |
| Version correlation | Git tag + Docker tag + scan report aligned |

### Audit Flow Example

```
1. PR #142 opened (feature/add-caching)
   └─ Build: sha256:abc123def456
   └─ Scan: 0 critical, 2 medium
   └─ Report: https://harness.io/scans/report-142

2. PR #142 merged to main
   └─ Build: sha256:abc123def456 (cache hit, same digest)
   └─ Digest match: ✓ Skip scan
   └─ Tag: movie-service:v1.3.0
   └─ Push to registry
   └─ Git tag: movie-v1.3.0

3. Auditor asks: "Was v1.3.0 scanned?"
   └─ Registry: movie-service:v1.3.0 = sha256:abc123def456
   └─ Scan report: sha256:abc123def456 scanned on PR #142
   └─ Correlation: ✓ Same digest = same image = scanned
```

### Stored Artifacts

| Artifact | Location | Retention |
|----------|----------|-----------|
| Scan report (SARIF) | Harness STO | 1 year |
| Image digest | PR comment + Git tag | Permanent |
| SBOM | Harness STO | 1 year |
| Build logs | Harness | 90 days |

---

## Developer Workflow

### PR Open: Fast Feedback

```bash
# Developer creates PR
$ git checkout -b feature/add-redis-cache
$ git push origin feature/add-redis-cache

# Pipeline runs (~5 min total):
# ✓ Code quality checks
# ✓ Unit tests
# ✓ Security scans (code + container)
# 
# Result: PR status check (pass/fail)
```

### Handling Vulnerabilities

Developers own the full stack and are responsible for fixing:

| Vulnerability Type | Developer Action |
|--------------------|------------------|
| Code issue (SAST) | Fix code in PR |
| Secret detected | Remove + rotate credential |
| Dependency CVE | Update go.mod |
| Base image CVE | Update Dockerfile: `FROM alpine:3.22` |
| Dockerfile misconfig | Fix Dockerfile instructions |

**Example: Fixing a base image CVE**

```dockerfile
# Before: Vulnerable
ARG ALPINE_VERSION=3.21
FROM alpine:${ALPINE_VERSION}

# After: Patched
ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION}
```

### PR Merge: Release

```bash
# PR approved and merged
$ gh pr merge 142

# Pipeline runs (~4 min):
# ✓ Semantic version: v1.3.0
# ✓ Build (cache hit)
# ✓ Digest verification
# ✓ Push to registry
# ✓ Git tag created
```

---

## Pipeline Configuration

### Trigger Rules

| Event | RUN_MODE | Stages Executed |
|-------|----------|-----------------|
| PR opened/updated | `build` | Validate Code + Validate Container |
| PR merged to main | `full` | Build and Release |
| Manual (main branch) | `full` | Build and Release |

### Stage Conditions

```yaml
# Validate Code - Always on PR
when:
  condition: <+pipeline.variables.RUN_MODE> != "full"

# Validate Container - PR with build
when:
  condition: <+pipeline.variables.RUN_MODE> == "build"

# Build and Release - Merge only
when:
  condition: <+pipeline.variables.RUN_MODE> == "full"
```

### Digest Storage

The digest is stored in multiple locations for redundancy:

1. **PR Comment**: Posted by pipeline for visibility
2. **Harness Output Variable**: Used by merge pipeline
3. **Git Tag Annotation**: Permanent record

```bash
# Git tag includes digest
$ git tag -a movie-v1.3.0 -m "Release v1.3.0
Image: docker.io/crizstian/movie-service:v1.3.0
Digest: sha256:abc123def456
Scan: https://harness.io/scans/report-142"
```

---

## Security Gates

### PR Open Gates (Blocks Merge)

| Check | Threshold | Blocking? |
|-------|-----------|-----------|
| SAST (Semgrep) | 0 critical | Yes |
| Secrets (Gitleaks) | 0 secrets | Yes |
| Code SCA | 0 critical | Yes |
| Container Scan | 0 critical, ≤5 high | Yes |
| Unit Tests | 80% coverage | Yes |

### PR Merge Gates (Blocks Push)

| Check | Threshold | Blocking? |
|-------|-----------|-----------|
| Digest mismatch | Must match | Triggers rescan |
| Container Scan (if rescan) | 0 critical | Yes |

---

## Cost Analysis

### Before (Redundant Pipeline)

```
PR Open:
  └─ Build Binary:    ~60s
  └─ Build Image:     ~90s
  └─ Container Scan:  ~60s
  
PR Merge:
  └─ Build Binary:    ~60s  (redundant)
  └─ Build Image:     ~90s  (redundant)
  └─ Container Scan:  ~60s  (redundant)
  └─ Push:            ~30s

Total: ~450s (7.5 min)
Redundant: ~210s (3.5 min)
```

### After (Digest-Based Pipeline)

```
PR Open:
  └─ Build Binary:    ~60s
  └─ Build Image:     ~90s
  └─ Container Scan:  ~60s
  
PR Merge:
  └─ Build Binary:    ~10s  (cache hit)
  └─ Build Image:     ~10s  (cache hit)
  └─ Digest Check:    ~1s
  └─ Push:            ~30s

Total: ~260s (4.3 min)
Saved: ~190s per PR (42% reduction)
```

### Monthly Savings Estimate

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| PRs/month | 100 | 100 | - |
| Build minutes | 750 | 430 | 320 min |
| Cost @ $0.008/min | $6.00 | $3.44 | $2.56/month |

---

## Implementation Checklist

- [x] Update CI-Unified-v3.yaml with digest capture
- [x] Add digest verification step in Build and Release stage
- [x] Configure PR comment with digest info
- [x] Store scan reports with digest reference
- [x] Update Git tag creation to include digest
- [ ] Add Dockerfile linting (hadolint) to Validate Code
- [x] Configure cache intelligence for optimal cache hits
- [ ] Test digest consistency across builds

---

## Implementation Details

### Stage 2: Validate Container (PR Open)

**New Steps Added:**

1. **Capture Image Digest** (`capture_digest`)
   - Loads tarball into Docker
   - Extracts digest with `docker inspect --format='{{.Id}}'`
   - Stores as output variable

2. **Post Digest to PR** (`post_digest_to_pr`)
   - Posts structured comment to PR with digest
   - Uses marker `<!-- HARNESS_DIGEST:sha256:... -->` for parsing
   - Includes scan status summary

### Stage 3: Build and Release (PR Merge)

**New Steps Added:**

1. **Fetch PR Digest** (`fetch_pr_digest`)
   - Finds PR associated with merge commit
   - Parses PR comments for digest marker
   - Returns empty if no digest found (triggers full scan)

2. **Build Image** (modified)
   - Builds to tarball first (no direct push)
   - Uses `PLUGIN_NO_PUSH: "true"`

3. **Verify Digest and Push** (`verify_digest_push`)
   - Loads built image
   - Compares PR digest with build digest
   - If match: skips scan, pushes directly
   - If mismatch: logs warning, pushes (scan integration pending)

4. **Create Git Tag** (enhanced)
   - Creates annotated tag with digest info
   - Tag message includes image, digest, and commit

### PR Comment Format

```markdown
## 🐳 Container Build & Scan Summary

| Service | Digest | Scan Status |
|---------|--------|-------------|
| movie | `sha256:abc123...` | true |

<details>
<summary>Full Digest (click to expand)</summary>

\`\`\`
sha256:abc123def456...
\`\`\`

</details>

---
**Commit:** abc1234
**Execution:** [View Pipeline](https://app.harness.io/...)

<!-- HARNESS_DIGEST:sha256:abc123def456... -->
```

### Git Tag Format

```
movie-v1.3.0

Release v1.3.0

Image: crizstian/movie-service:v1.3.0
Digest: sha256:abc123def456...
Commit: abc1234567890
```

---

## Troubleshooting

### Digest Mismatch on Merge

**Symptom**: PR merge triggers rescan instead of skipping

**Causes**:
1. Dependency updated between PR open and merge
2. Base image tag changed (e.g., `alpine:3.21` got new layers)
3. Build timestamp embedded in binary

**Solutions**:
1. Pin exact dependency versions in go.mod
2. Use digest-pinned base images: `alpine@sha256:...`
3. Ensure reproducible builds (no timestamps in ldflags)

### Cache Miss on Merge

**Symptom**: Full rebuild instead of cache hit

**Causes**:
1. Cache expired (TTL)
2. Different build machine
3. Dockerfile changed

**Solutions**:
1. Increase cache TTL in Harness settings
2. Ensure Cache Intelligence is enabled
3. Expected behavior if Dockerfile changed

---

## References

- [Harness Cache Intelligence](https://developer.harness.io/docs/continuous-integration/use-ci/caching-ci-data/cache-intelligence)
- [Docker Content Addressability](https://docs.docker.com/registry/spec/manifest-v2-2/)
- [OCI Image Spec](https://github.com/opencontainers/image-spec)
- [SLSA Build Provenance](https://slsa.dev/provenance)
