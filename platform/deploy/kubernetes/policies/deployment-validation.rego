# OPA Policy: Deployment Validation for Cinema Platform
# Validates rendered Kubernetes manifests before applying to cluster.
#
# Usage in Harness:
# - Apply after render step, before kubectl apply
# - Input: rendered YAML manifests

package kubernetes.deployment

import future.keywords.in
import future.keywords.if

# Deny if image tag is 'latest' in production
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    contains(container.image, ":latest")
    contains(input.metadata.namespace, "prod")
    msg := sprintf("DENIED: Container '%s' uses ':latest' tag in production. Use specific version tags.", [container.name])
}

# Deny if no resource requests defined
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests
    msg := sprintf("DENIED: Container '%s' has no resource requests defined.", [container.name])
}

# Deny if no liveness probe
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("DENIED: Container '%s' has no liveness probe defined.", [container.name])
}

# Deny if no readiness probe
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("DENIED: Container '%s' has no readiness probe defined.", [container.name])
}

# Deny if ConfigMap envFrom references non-existent configmap
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    envFrom := container.envFrom[_]
    envFrom.configMapRef
    not envFrom.configMapRef.optional
    msg := sprintf("DENIED: Container '%s' requires ConfigMap '%s' but optional=false. Ensure ConfigMap exists.", [container.name, envFrom.configMapRef.name])
}

# Deny if Secret envFrom references non-existent secret
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    envFrom := container.envFrom[_]
    envFrom.secretRef
    not envFrom.secretRef.optional
    msg := sprintf("DENIED: Container '%s' requires Secret '%s' but optional=false. Ensure Secret exists.", [container.name, envFrom.secretRef.name])
}

# Deny if ConfigMap has empty required values
deny[msg] {
    input.kind == "ConfigMap"
    input.data.DB_REPLICA == ""
    msg := "DENIED: ConfigMap has empty DB_REPLICA. This will cause application startup failure."
}

deny[msg] {
    input.kind == "ConfigMap"
    input.data.DB_SERVERS == ""
    msg := "DENIED: ConfigMap has empty DB_SERVERS. Database connection will fail."
}

# Deny HPA if minReplicas equals maxReplicas (pointless autoscaling)
deny[msg] {
    input.kind == "HorizontalPodAutoscaler"
    input.spec.minReplicas == input.spec.maxReplicas
    msg := sprintf("DENIED: HPA '%s' has minReplicas == maxReplicas. Autoscaling is pointless.", [input.metadata.name])
}

# Warn if no PDB exists for production deployments
warn[msg] {
    input.kind == "Deployment"
    contains(input.metadata.namespace, "prod")
    msg := "WARNING: Ensure PodDisruptionBudget exists for production deployment."
}
