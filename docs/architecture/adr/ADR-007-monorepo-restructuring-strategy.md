# ADR-007: Monorepo Restructuring Strategy

## Status

**ACCEPTED** - 2026-04-26

## Context

The current monorepo contains multiple concerns that have grown organically:

- Application microservices (multi-language: Go, Java, Python)
- DevOps configurations (CI/CD pipelines, templates)
- Infrastructure as Code (Terraform, Kubernetes)
- Platform tooling (DevContainer, scripts)
- Quality assurance configurations
- Database configurations and migrations
- Security policies and scanning configurations
- Operations/SRE configurations (dashboards, alerts, runbooks)

As the organization scales, this single monorepo creates challenges:

1. **Ownership ambiguity**: Multiple teams modify the same repository
2. **Blast radius**: Changes in one area can affect unrelated areas
3. **CI complexity**: Single pipeline must handle all concerns
4. **Compliance**: Audit trails are harder to isolate
5. **Release cycles**: Different areas have different cadences

## Decision

**Split the current monorepo into 3 domain-specific monorepos**, unified by Harness as the central SDLC orchestration platform.

### Repository Structure

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  services-repo  │  │  platform-repo  │  │   infra-repo    │
│                 │  │                 │  │                 │
│ • Microservices │  │ • CI/CD         │  │ • Terraform     │
│ • Contracts     │  │ • Security      │  │ • Kubernetes    │
│ • Shared libs   │  │ • DevContainer  │  │ • Helm          │
│ • Quality tests │  │ • E2E/Perf      │  │ • Operations    │
│ • Data/DBA      │  │ • Base images   │  │ • Observability │
│                 │  │ • Tooling       │  │ • SRE           │
│                 │  │                 │  │                 │
│  Dev Teams      │  │  Platform Team  │  │  Infra + SRE    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Harness as Unifying Platform

Harness provides centralized governance across all repositories:

- **Policy-as-Code**: OPA policies enforced at pipeline level
- **Audit Trail**: Centralized logging of all changes
- **RBAC**: Unified access control
- **Secrets Management**: Single source for secrets
- **SRM**: Service Reliability Management consuming SLOs from infra-repo

## Rationale

### Why 3 repos instead of 5?

The committee evaluated splitting into 5 repos (adding security-repo and ops-repo), but consolidated to 3 based on:

| Proposal | Decision | Justification |
|----------|----------|---------------|
| Security → separate repo | Security → platform-repo | Pipelines consume policies; co-location reduces friction |
| DBA → separate repo | DBA → services-repo | Migrations tied to code; governance via CODEOWNERS |
| QA → separate repo | QA → distributed | Unit/integration in services, E2E/perf in platform |
| Ops → separate repo | Ops → infra-repo | Infra and observability change together |

### Why not stay as 1 monorepo?

- Different release cadences (services: continuous, infra: weekly, platform: bi-weekly)
- Different compliance requirements (infra needs stricter controls)
- Team autonomy (each team owns their repo)
- Simplified CI per repo

### Why not full polyrepo (1 repo per service)?

- Loses atomic cross-service refactoring
- Diamond dependency problem
- Harder to maintain consistency
- More overhead for small organization

## Consequences

### Positive

- Clear ownership (1 team = 1 repo primary owner)
- Simplified CI/CD per repository
- Independent release cycles
- Better compliance isolation
- Reduced blast radius

### Negative

- Cross-repo changes require coordination
- Initial migration effort
- Need for CONTRACT.yaml/SERVICE.yaml standards
- Tooling for cross-repo operations

### Mitigations

- SERVICE.yaml as contract between repos
- Harness Policy Sets enforce standards
- Semantic versioning for platform-repo templates
- Documentation hub in Harness

## Participants

| Role | Decision |
|------|----------|
| CTO | Approved |
| Staff Software Architect | Approved |
| Staff DevOps Engineer | Approved |
| Staff Platform Engineer | Approved |
| Security Lead | Approved with conditions |
| DBA Lead | Approved |
| QA Lead | Approved |
| Operations/SRE Lead | Approved |

## References

- [Committee Discussion Document](./monorepo-committee-review-2026-04.md)
- [Migration Plan](../operations/monorepo-migration-plan.md)
- [SERVICE.yaml Specification](./service-yaml-spec.md)
