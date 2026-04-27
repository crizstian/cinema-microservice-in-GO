# CD Multi-Service Deployment Strategy

## Overview

This document explains the technical decision behind using **repeat strategy with sequential execution** for deploying multiple Go microservices in the CICD-Go-ShiftLeft pipeline.

## Problem Statement

The CI Orchestrator detects which services changed in a PR and needs to pass this dynamic list to the CICD pipeline for deployment. The challenge is:

1. **Dynamic service list**: Services to deploy are determined at runtime by CI detection
2. **Schema validation**: Harness validates pipeline YAML at save time, not runtime
3. **Multi-service deployment**: Need to deploy multiple services to the same environment

## Options Evaluated

### Option 1: Multi-Service with `services.values` Array

```yaml
services:
  values:
    - serviceRef: bookingservice
    - serviceRef: movieservice
```

**Issue**: `services.values` expects a literal YAML array or `<+input>`. Dynamic expressions like `<+json.list(variable)>` fail schema validation with error:
```
Incorrect type. Expected "array"
```

**Verdict**: Not viable for dynamic service lists from parent pipeline.

### Option 2: JSON Array with `json.list()` Expression

```yaml
services:
  values: <+json.list(pipeline.variables.SERVICES_ARRAY)>
```

**Issue**: Harness schema validator expects an array type at save time. The `json.list()` function returns an array at runtime, but the schema sees a string expression.

**Verdict**: Schema validation fails at pipeline save.

### Option 3: Pipeline Stage Input Override

```yaml
# In CI-Orchestrator
inputs:
  stages:
    - stage:
        identifier: deploy_dev
        spec:
          services:
            values: <+expression>
```

**Issue**: When passing dynamic arrays via Pipeline stage inputs, the same schema validation applies. You cannot pass a dynamically-generated array through this mechanism.

**Verdict**: Same limitation as Option 1.

### Option 4: Repeat Strategy with Split (Selected)

```yaml
spec:
  service:
    serviceRef: <+repeat.item>
strategy:
  repeat:
    items: <+pipeline.variables.SERVICES_LIST.split(",")>
    maxConcurrency: 1
```

**Why it works**:
- Uses singular `service` (not `services`) which accepts expressions
- `repeat.items` supports the `.split(",")` expression
- `maxConcurrency: 1` ensures sequential deployment
- Documented pattern in Harness best practices

## Selected Strategy: Repeat with Sequential Execution

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       CI Orchestrator                            │
├─────────────────────────────────────────────────────────────────┤
│  1. Detect changed services: booking, movie                     │
│  2. Build Services List: bookingservice,movieservice            │
│  3. Pass SERVICES_LIST to child pipeline                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CICD-Go-ShiftLeft                            │
├─────────────────────────────────────────────────────────────────┤
│  Variable: SERVICES_LIST = "bookingservice,movieservice"        │
│                                                                 │
│  deploy_dev stage:                                              │
│    strategy:                                                    │
│      repeat:                                                    │
│        items: <+SERVICES_LIST.split(",")>                       │
│        maxConcurrency: 1                                        │
│                                                                 │
│    Iteration 1: serviceRef = bookingservice                     │
│      → Rolling Deploy → Health Check → Smoke Test               │
│                                                                 │
│    Iteration 2: serviceRef = movieservice                       │
│      → Rolling Deploy → Health Check → Smoke Test               │
└─────────────────────────────────────────────────────────────────┘
```

### Configuration

**CI-Orchestrator: Build Services List**
```yaml
- step:
    name: Build Services List
    identifier: build_services_list
    type: Run
    spec:
      command: |
        # Input: "booking,movie"
        # Output: "bookingservice,movieservice"
        SERVICES_LIST=$(echo "$GO_SERVICES" | sed 's/,/service,/g; s/$/service/')
        echo "SERVICES_LIST=$SERVICES_LIST" >> $HARNESS_OUTPUT_FILE
```

**CICD-Go-ShiftLeft: deploy_dev Stage**
```yaml
- stage:
    name: Deploy to DEV
    identifier: deploy_dev
    type: Deployment
    spec:
      deploymentType: Kubernetes
      service:
        serviceRef: <+repeat.item>
      environment:
        environmentRef: sandbox
        infrastructureDefinitions:
          - identifier: sesandboxkubernetes
      execution:
        steps:
          - step: K8sRollingDeploy
          - step: HTTP Liveness Check
          - step: HTTP Readiness Check
          - step: Smoke Test
        rollbackSteps:
          - step: K8sRollingRollback
    strategy:
      repeat:
        items: <+pipeline.variables.SERVICES_LIST.split(",")>
        maxConcurrency: 1
```

## Why `maxConcurrency: 1`?

| Value | Behavior | Use Case |
|-------|----------|----------|
| `1` | Sequential deployment | Safe rollout, dependency order respected |
| `2-N` | Parallel deployment | Faster but riskier, no dependency control |
| Omitted | All parallel | Maximum speed, highest risk |

We chose `maxConcurrency: 1` because:

1. **Service dependencies**: Some services may depend on others being deployed first
2. **Resource constraints**: Parallel deployments consume more cluster resources
3. **Debugging**: Sequential failures are easier to diagnose
4. **Rollback clarity**: Clear which service caused a failure

## Harness Documentation Reference

From [Harness CD Best Practices](https://developer.harness.io/docs/continuous-delivery/cd-onboarding/cd-best-practices):

> **How to use expressions or variables in repeat looping strategy?**
> 
> To pass a dynamic array as an input to the looping strategy of the next step, you can replace `<+execution.steps.ShellScript_1.output.outputVariables.ARRAY1>` with `<+<+execution.steps.ShellScript_1.output.outputVariables.ARRAY1>.split(",")>`. This change allows you to split the array into individual items using a comma as the delimiter.

## Trade-offs

### Advantages

| Benefit | Description |
|---------|-------------|
| Dynamic service selection | Services determined at runtime by CI detection |
| Sequential safety | One service at a time with `maxConcurrency: 1` |
| Per-service rollback | Each iteration has independent rollback |
| Expression support | Full support for `.split(",")` on string variables |
| Schema compliance | Passes Harness YAML validation |

### Limitations

| Limitation | Mitigation |
|------------|------------|
| Not "true" multi-service | Functionally equivalent with sequential execution |
| Stage name includes index | Use `nodeName: <+repeat.item>` for readable names |
| Separate executions per service | Each service gets its own execution context |

## Service Identifier Mapping

The CI Orchestrator detects service directory names (e.g., `booking`) but Harness service identifiers have a `service` suffix (e.g., `bookingservice`).

| CI Detection | Harness Service ID | Service Name |
|--------------|-------------------|--------------|
| booking | bookingservice | booking-service |
| movie | movieservice | movie-service |
| cinema | cinemaservice | cinema-service |
| user | userservice | user-service |
| showtime | showtimeservice | showtime-service |
| seat | seatservice | seat-service |
| payment | paymentservice | payment-service |
| notification | notificationservice | notification-service |

The transformation is done in the `Build Services List` step:
```bash
# Input: "booking,movie"
# Output: "bookingservice,movieservice"
SERVICES_LIST=$(echo "$GO_SERVICES" | sed 's/,/service,/g; s/$/service/')
```

## Conclusion

The **repeat strategy with `maxConcurrency: 1`** is the recommended Harness pattern for dynamic multi-service deployment when:

1. Service list is determined at runtime
2. Services need to be deployed sequentially
3. Parent pipeline passes services as a string variable

This approach is documented in Harness best practices, passes schema validation, and provides the flexibility needed for monorepo CI/CD pipelines.
