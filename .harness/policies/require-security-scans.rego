# OPA Policy: Require Security Scans
# Ensures all pipelines include mandatory security scanning stages

package pipeline

# Deny pipelines without security scan stage
deny[msg] {
    input.pipeline.stages[_].stage.type != "SecurityTests"
    not has_security_stage
    msg := "Pipeline must include at least one SecurityTests stage for code scanning"
}

# Check if pipeline has security stage
has_security_stage {
    input.pipeline.stages[_].stage.type == "SecurityTests"
}

# Deny pipelines without container scan when building images
deny[msg] {
    has_docker_build
    not has_container_scan
    msg := "Pipelines that build Docker images must include container security scanning"
}

# Check for Docker build steps
has_docker_build {
    input.pipeline.stages[_].stage.spec.execution.steps[_].step.type == "BuildAndPushDockerRegistry"
}

has_docker_build {
    step := input.pipeline.stages[_].stage.spec.execution.steps[_].step
    step.type == "Run"
    contains(step.spec.command, "docker build")
}

# Check for container scan
has_container_scan {
    input.pipeline.stages[_].stage.spec.execution.steps[_].step.type == "AquaTrivy"
}

has_container_scan {
    input.pipeline.stages[_].stage.spec.execution.steps[_].stepGroup.steps[_].step.type == "AquaTrivy"
}

# Deny pipelines without Gitleaks
deny[msg] {
    not has_gitleaks
    msg := "Pipeline must include Gitleaks step for secret detection"
}

has_gitleaks {
    input.pipeline.stages[_].stage.spec.execution.steps[_].step.type == "Gitleaks"
}

# Deny pipelines without policy enforcement on security stages
deny[msg] {
    stage := input.pipeline.stages[_].stage
    stage.type == "SecurityTests"
    not stage.policySetRef
    msg := sprintf("SecurityTests stage '%s' must have policySetRef defined", [stage.name])
}

# Warn if ManualIntervention is not configured for security gates
warn[msg] {
    step := input.pipeline.stages[_].stage.spec.execution.steps[_].step
    contains(step.identifier, "evaluate")
    not has_manual_intervention(step)
    msg := sprintf("Security gate step '%s' should have ManualIntervention failure strategy", [step.name])
}

has_manual_intervention(step) {
    step.failureStrategies[_].onFailure.action.type == "ManualIntervention"
}

# Require approved templates for security stages
deny[msg] {
    stage := input.pipeline.stages[_].stage
    stage.type == "SecurityTests"
    stage.template
    not is_approved_template(stage.template.templateRef)
    msg := sprintf("Stage '%s' uses non-approved template: %s", [stage.name, stage.template.templateRef])
}

is_approved_template(ref) {
    approved := {"security_scan_code", "container_security_scan"}
    approved[ref]
}

# Deny direct push without security gate
deny[msg] {
    step := input.pipeline.stages[_].stage.spec.execution.steps[_].step
    step.type == "BuildAndPushDockerRegistry"
    not preceded_by_container_scan(step)
    msg := "BuildAndPushDockerRegistry must be preceded by container security scan"
}

preceded_by_container_scan(push_step) {
    # Simplified check - in real implementation, check step ordering
    has_container_scan
}
