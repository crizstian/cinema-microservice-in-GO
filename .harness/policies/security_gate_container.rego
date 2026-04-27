# =============================================================================
# OPA Policy: Container Security Gate
# Evalua resultados agregados del step "Evaluate Container Security"
# =============================================================================
#
# Input Structure (desde Run step outputVariables):
# [
#   {
#     "name": "output",
#     "outcome": {
#       "outputVariables": {
#         "CONTAINER_CRITICAL": "2",
#         "CONTAINER_HIGH": "5",
#         "CONTAINER_TOTAL": "15",
#         "PIPELINE_CRITICAL": "6",
#         "PIPELINE_HIGH": "18",
#         "CONTAINER_GATE_PASSED": "false"
#       }
#     }
#   }
# ]
# =============================================================================

package security.gate.container

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuracion de umbrales
# =============================================================================

# Umbrales para container
container_thresholds := {
    "critical": 0,
    "high": 3
}

# Umbrales para pipeline completo (code + container)
pipeline_thresholds := {
    "critical": 0,
    "high": 10
}

# =============================================================================
# Helpers
# =============================================================================

# Helper para convertir string a numero de forma segura
to_num(val) = result {
    result := to_number(val)
} else = 0

# Obtener output variables
output_data := data_obj {
    some i
    input[i].name == "output"
    data_obj := input[i]
}

# Extraer conteos del Run step - Container
container_critical := to_num(output_data.outcome.outputVariables.CONTAINER_CRITICAL)
container_high := to_num(output_data.outcome.outputVariables.CONTAINER_HIGH)
container_total := to_num(output_data.outcome.outputVariables.CONTAINER_TOTAL)

# Extraer conteos del Run step - Pipeline totals
pipeline_critical := to_num(output_data.outcome.outputVariables.PIPELINE_CRITICAL)
pipeline_high := to_num(output_data.outcome.outputVariables.PIPELINE_HIGH)

# Gate status del script
gate_passed := output_data.outcome.outputVariables.CONTAINER_GATE_PASSED

# =============================================================================
# Reglas DENY - Container
# =============================================================================

# Denegar si hay vulnerabilidades critical en container
deny[msg] {
    container_critical > container_thresholds.critical

    msg := sprintf(
        "BLOCKED [CONTAINER]: Found %d CRITICAL vulnerabilities in container. Maximum allowed: %d",
        [container_critical, container_thresholds.critical]
    )
}

# Denegar si hay demasiadas high en container
deny[msg] {
    container_high > container_thresholds.high

    msg := sprintf(
        "BLOCKED [CONTAINER]: Found %d HIGH vulnerabilities in container. Maximum allowed: %d",
        [container_high, container_thresholds.high]
    )
}

# =============================================================================
# Reglas DENY - Pipeline Total
# =============================================================================

# Denegar si el total del pipeline excede umbral de critical
deny[msg] {
    pipeline_critical > pipeline_thresholds.critical

    msg := sprintf(
        "BLOCKED [PIPELINE]: Total CRITICAL vulnerabilities (%d) exceed threshold (%d)",
        [pipeline_critical, pipeline_thresholds.critical]
    )
}

# Denegar si el total del pipeline excede umbral de high
deny[msg] {
    pipeline_high > pipeline_thresholds.high

    msg := sprintf(
        "BLOCKED [PIPELINE]: Total HIGH vulnerabilities (%d) exceed threshold (%d)",
        [pipeline_high, pipeline_thresholds.high]
    )
}

# =============================================================================
# Reglas WARN
# =============================================================================

# Advertir si container high esta cerca del umbral
warn[msg] {
    container_high > (container_thresholds.high - 2)
    container_high <= container_thresholds.high

    msg := sprintf(
        "WARNING [CONTAINER]: HIGH vulnerabilities (%d) approaching threshold (%d).",
        [container_high, container_thresholds.high]
    )
}

# Advertir si pipeline high esta cerca del umbral
warn[msg] {
    pipeline_high > (pipeline_thresholds.high - 3)
    pipeline_high <= pipeline_thresholds.high

    msg := sprintf(
        "WARNING [PIPELINE]: Total HIGH vulnerabilities (%d) approaching threshold (%d).",
        [pipeline_high, pipeline_thresholds.high]
    )
}

# =============================================================================
# Resumen
# =============================================================================

summary := {
    "container": {
        "critical": container_critical,
        "high": container_high,
        "total": container_total
    },
    "pipeline": {
        "critical": pipeline_critical,
        "high": pipeline_high
    },
    "thresholds": {
        "container": container_thresholds,
        "pipeline": pipeline_thresholds
    },
    "status": get_status
}

get_status = "BLOCKED" {
    container_critical > container_thresholds.critical
}
get_status = "BLOCKED" {
    container_high > container_thresholds.high
}
get_status = "BLOCKED" {
    pipeline_critical > pipeline_thresholds.critical
}
get_status = "BLOCKED" {
    pipeline_high > pipeline_thresholds.high
}
get_status = "PASSED" {
    container_critical <= container_thresholds.critical
    container_high <= container_thresholds.high
    pipeline_critical <= pipeline_thresholds.critical
    pipeline_high <= pipeline_thresholds.high
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Container Security Gate",
    "description": "Evaluates container and pipeline security from Run step output",
    "version": "3.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "gate", "container", "pipeline"],
    "input_schema": "Run step outputVariables: CONTAINER_CRITICAL, CONTAINER_HIGH, PIPELINE_CRITICAL, PIPELINE_HIGH"
}
