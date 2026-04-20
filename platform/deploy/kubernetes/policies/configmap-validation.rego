# OPA Policy: ConfigMap Validation for Cinema Platform
# This policy validates that required configuration values are present and valid
# before deployment to prevent runtime failures.
#
# Usage in Harness:
# - Create Policy Set with this file
# - Apply to Pipeline as "On Run" policy
# - Set action to "Error and exit" on failure

package kubernetes.configmap

import future.keywords.in
import future.keywords.if

# Deny deployment if database.replica is empty or missing
deny[msg] {
    input.values.database.replica == ""
    msg := "DENIED: database.replica cannot be empty. MongoDB replica set name is required (e.g., 'rs0')."
}

deny[msg] {
    not input.values.database.replica
    msg := "DENIED: database.replica is missing. MongoDB replica set name is required."
}

# Deny if database servers not configured
deny[msg] {
    input.values.database.servers == ""
    msg := "DENIED: database.servers cannot be empty."
}

deny[msg] {
    not input.values.database.servers
    msg := "DENIED: database.servers is missing."
}

# Deny if database credentials missing
deny[msg] {
    input.values.database.user == ""
    msg := "DENIED: database.user cannot be empty."
}

deny[msg] {
    input.values.database.password == ""
    msg := "DENIED: database.password cannot be empty."
}

# Deny if service port is invalid
deny[msg] {
    port := input.values.port
    port < 1024
    msg := sprintf("DENIED: port %d is invalid. Must be >= 1024.", [port])
}

deny[msg] {
    port := input.values.port
    port > 65535
    msg := sprintf("DENIED: port %d is invalid. Must be <= 65535.", [port])
}

# Deny if namespace doesn't match environment
deny[msg] {
    env := input.values.environment
    ns := input.values.namespace
    expected := sprintf("cinema-%s", [env])
    ns != expected
    msg := sprintf("DENIED: namespace '%s' doesn't match environment '%s'. Expected '%s'.", [ns, env, expected])
}

# Deny if autoscaling minReplicas > maxReplicas
deny[msg] {
    min := input.values.autoscaling.minReplicas
    max := input.values.autoscaling.maxReplicas
    min > max
    msg := sprintf("DENIED: autoscaling.minReplicas (%d) cannot be greater than maxReplicas (%d).", [min, max])
}

# Deny if production has less than 2 minReplicas
deny[msg] {
    input.values.environment == "prod"
    input.values.autoscaling.minReplicas < 2
    msg := "DENIED: Production environment requires at least 2 minReplicas for high availability."
}

# Deny if production PDB minAvailable is 0
deny[msg] {
    input.values.environment == "prod"
    input.values.pdb.minAvailable == 0
    msg := "DENIED: Production environment requires pdb.minAvailable > 0 for availability."
}

# Warn if debug logging in production
warn[msg] {
    input.values.environment == "prod"
    input.values.observability.logLevel == "debug"
    msg := "WARNING: Debug logging is enabled in production. Consider using 'info' or 'warn'."
}

# Warn if resource limits not set
warn[msg] {
    not input.values.resources.limits.cpu
    msg := "WARNING: CPU limits not set. Consider setting limits to prevent resource exhaustion."
}

warn[msg] {
    not input.values.resources.limits.memory
    msg := "WARNING: Memory limits not set. Consider setting limits to prevent OOM issues."
}
