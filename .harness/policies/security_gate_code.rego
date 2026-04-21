# =============================================================================
# OPA Policy: Code Security Gate
# Evalua resultados agregados del step "Evaluate Code Security"
# =============================================================================
#
# Input Structure (desde Run step outputVariables):
# [
#   {
#     "name": "output",
#     "outcome": {
#       "outputVariables": {
#         "TOTAL_CRITICAL": "4",
#         "TOTAL_HIGH": "13",
#         "TOTAL_SECRETS": "14",
#         "GATE_PASSED": "false"
#       }
#     }
#   }
# ]
# =============================================================================

package security.gate.code

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuracion de umbrales
# =============================================================================

thresholds := {
    "critical": 0,
    "high": 5,
    "secrets": 0
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

# Extraer conteos del Run step
total_critical := to_num(output_data.outcome.outputVariables.TOTAL_CRITICAL)
total_high := to_num(output_data.outcome.outputVariables.TOTAL_HIGH)
total_secrets := to_num(output_data.outcome.outputVariables.TOTAL_SECRETS)
gate_passed := output_data.outcome.outputVariables.GATE_PASSED

# =============================================================================
# Reglas DENY
# =============================================================================

# Denegar si hay vulnerabilidades criticas
deny[msg] {
    total_critical > thresholds.critical

    msg := sprintf(
        "BLOCKED: Found %d CRITICAL vulnerabilities. Maximum allowed: %d",
        [total_critical, thresholds.critical]
    )
}

# Denegar si hay demasiadas high
deny[msg] {
    total_high > thresholds.high

    msg := sprintf(
        "BLOCKED: Found %d HIGH vulnerabilities. Maximum allowed: %d",
        [total_high, thresholds.high]
    )
}

# Denegar si hay secrets
deny[msg] {
    total_secrets > thresholds.secrets

    msg := sprintf(
        "BLOCKED: Found %d SECRETS exposed. Maximum allowed: %d",
        [total_secrets, thresholds.secrets]
    )
}

# =============================================================================
# Reglas WARN
# =============================================================================

# Advertir si high esta cerca del umbral
warn[msg] {
    total_high > (thresholds.high - 2)
    total_high <= thresholds.high

    msg := sprintf(
        "WARNING: HIGH vulnerabilities (%d) approaching threshold (%d).",
        [total_high, thresholds.high]
    )
}

# =============================================================================
# Resumen
# =============================================================================

summary := {
    "total_critical": total_critical,
    "total_high": total_high,
    "total_secrets": total_secrets,
    "thresholds": thresholds,
    "status": get_status
}

get_status = "BLOCKED" {
    total_critical > thresholds.critical
}
get_status = "BLOCKED" {
    total_high > thresholds.high
}
get_status = "BLOCKED" {
    total_secrets > thresholds.secrets
}
get_status = "PASSED" {
    total_critical <= thresholds.critical
    total_high <= thresholds.high
    total_secrets <= thresholds.secrets
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Code Security Gate",
    "description": "Evaluates aggregated security scan results from Run step",
    "version": "3.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "gate", "code"],
    "input_schema": "Run step outputVariables: TOTAL_CRITICAL, TOTAL_HIGH, TOTAL_SECRETS"
}
