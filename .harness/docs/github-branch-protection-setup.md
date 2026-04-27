# GitHub Branch Protection Setup

Configure GitHub to block merges until the Harness CI pipeline passes.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SINGLE ARTIFACT FLOW                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PR OPEN                    MERGE TO MAIN               DEPLOY              │
│  ────────                   ─────────────               ──────              │
│       │                          │                         │                │
│       ▼                          ▼                         │                │
│  ┌─────────────┐          ┌─────────────┐                  │                │
│  │  Stage 1    │          │  Stage 1    │                  │                │
│  │  Validate   │          │  Validate   │                  │                │
│  │  Code       │          │  Code       │                  │                │
│  └──────┬──────┘          └──────┬──────┘                  │                │
│         │                        │                         │                │
│         ▼                        ▼                         │                │
│  ┌─────────────┐          ┌─────────────┐                  │                │
│  │ GitHub      │          │  Stage 2    │                  │                │
│  │ Status      │          │  Build &    │                  │                │
│  │ ✅ or ❌    │          │  Scan       │                  │                │
│  └─────────────┘          └──────┬──────┘                  │                │
│         │                        │                         │                │
│         ▼                        ▼                         │                │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐         │
│  │ MERGE       │          │  Stage 3    │          │   SAME      │         │
│  │ BLOCKED     │◄─────────│  Push &     │─────────►│   IMAGE     │         │
│  │ until ✅    │          │  Release    │          │   v1.2.3    │         │
│  └─────────────┘          └──────┬──────┘          └─────────────┘         │
│                                  │                         │                │
│                                  ▼                         ▼                │
│                           ┌───────────┐            ┌───────────┐            │
│                           │ Git Tag   │            │ DEV       │            │
│                           │ v1.2.3    │            │ STAGING   │            │
│                           └───────────┘            │ PROD      │            │
│                                                    └───────────┘            │
│                                                                             │
│  KEY: One image, one tag (v1.2.3) - deployed to all environments           │
│       No rebuild, no retag - same artifact everywhere                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Event-Driven Execution

| Event | Trigger | Stages | Output |
|-------|---------|--------|--------|
| PR Open/Sync | Webhook | 1 | GitHub status (merge block/allow) |
| PR Merged | Push to main | 1, 2, 3 | Image v1.2.3 + Git tag |
| Manual | Run button | 1, 2, 3 | Full pipeline (bypass conditions) |

## Step 1: Configure Branch Protection

1. Go to: **Settings → Branches → Branch protection rules**
2. Click **Add branch protection rule**
3. Configure:

```
Branch name pattern: main

☑️ Require a pull request before merging
   ☑️ Require approvals: 1

☑️ Require status checks to pass before merging
   ☑️ Require branches to be up to date before merging
   
   Status checks that are required:
   ┌────────────────────────────────────────┐
   │ harness-ci/security-gate               │
   └────────────────────────────────────────┘

☑️ Do not allow bypassing the above settings
```

## Step 2: How It Works

The pipeline uses GitHub Commit Status API:

```
PR Open → Pipeline Start
    │
    ▼
Set Status: PENDING
    │
    ▼
Run Security Scans
    │
    ├─── PASS → Set Status: SUCCESS → Merge Enabled
    │
    └─── FAIL → Set Status: FAILURE → Merge Blocked
```

## Step 3: Verify Integration

1. Create a test PR
2. Check GitHub shows "pending" status
3. Wait for pipeline to complete
4. Verify merge button state matches result

## Troubleshooting

### Status not appearing

1. Check trigger fired: Harness → Executions
2. Check token permissions: `repo:status` scope required
3. Check connector has write access

### Status name mismatch

The pipeline uses this context:
```yaml
context: "harness-ci/security-gate"
```

Ensure branch protection requires exactly this name.

## Single Artifact Deployment

After merge, the image `v1.2.3` is pushed **once**. Deploy to any environment:

```bash
# Same image, different environments
kubectl set image deployment/booking booking=crizstian/booking-service:v1.2.3 -n dev
kubectl set image deployment/booking booking=crizstian/booking-service:v1.2.3 -n staging
kubectl set image deployment/booking booking=crizstian/booking-service:v1.2.3 -n prod
```

No rebuild, no retag - guaranteed identical artifact.
