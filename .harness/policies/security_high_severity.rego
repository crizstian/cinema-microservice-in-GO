# =============================================================================
# OPA Policy: Security High Severity Block
# Bloquea pipeline basado en conteo de vulnerabilidades por severidad
# =============================================================================
#
# Policy simple que evalúa únicamente:
# - Cantidad de issues por severidad
# - Umbrales configurables
#
# Input Structure (Harness STO):
# - input[_].name == "securityTestData" -> outcome.issues[]
# - input[_].name == "output" -> outcome.outputVariables (conteos)
# =============================================================================

package security.sto.high_severity

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuración de umbrales
# =============================================================================

# Máximo permitido por severidad
thresholds := {
    "critical": 0,    # Zero tolerance para críticos
    "high": 5,        # Máximo 5 high
    "medium": 20,     # Máximo 20 medium
    "low": 100        # Máximo 100 low
}

# =============================================================================
# Helpers: Obtener datos del input de Harness STO
# =============================================================================

# Obtener el objeto securityTestData
security_test_data := data_obj {
    some i
    input[i].name == "securityTestData"
    data_obj := input[i]
}

# Obtener el objeto output con conteos
output_data := data_obj {
    some i
    input[i].name == "output"
    data_obj := input[i]
}

# Obtener todos los issues
issues := security_test_data.outcome.issues

# Obtener conteos directos del output (más eficiente)
severity_counts := {
    "critical": to_number(output_data.outcome.outputVariables.CRITICAL),
    "high": to_number(output_data.outcome.outputVariables.HIGH),
    "medium": to_number(output_data.outcome.outputVariables.MEDIUM),
    "low": to_number(output_data.outcome.outputVariables.LOW),
    "total": to_number(output_data.outcome.outputVariables.TOTAL)
}

# =============================================================================
# Regla principal - usando conteos del output
# =============================================================================

# Denegar si se exceden los umbrales de Critical
deny[msg] {
    severity_counts.critical > thresholds.critical

    msg := sprintf(
        "BLOCKED: Found %d CRITICAL severity issues. Maximum allowed: %d.",
        [severity_counts.critical, thresholds.critical]
    )
}

# Denegar si se exceden los umbrales de High
deny[msg] {
    severity_counts.high > thresholds.high

    msg := sprintf(
        "BLOCKED: Found %d HIGH severity issues. Maximum allowed: %d.",
        [severity_counts.high, thresholds.high]
    )
}

# Denegar si se exceden los umbrales de Medium
deny[msg] {
    severity_counts.medium > thresholds.medium

    msg := sprintf(
        "BLOCKED: Found %d MEDIUM severity issues. Maximum allowed: %d.",
        [severity_counts.medium, thresholds.medium]
    )
}

# =============================================================================
# Reglas adicionales - usando issues detallados
# =============================================================================

# Denegar si hay issues críticos sin fix disponible
deny[msg] {
    issue := issues[_]

    lower(issue.details.severityCode) == "critical"
    issue.details.fixAvailable == false

    msg := sprintf(
        "BLOCKED: Critical vulnerability '%s' has no fix available. Manual review required.",
        [issue.details.title]
    )
}

# =============================================================================
# Warnings
# =============================================================================

# Advertir sobre nuevos issues críticos
warn[msg] {
    # Verificar si hay nuevos críticos
    new_critical := to_number(output_data.outcome.outputVariables.NEW_CRITICAL)
    new_critical > 0

    msg := sprintf(
        "WARNING: %d new critical vulnerabilities detected in this scan. Immediate attention required.",
        [new_critical]
    )
}

# Advertir sobre issues ignorados
warn[msg] {
    ignored := to_number(output_data.outcome.outputVariables.IGNORED)
    ignored > 0

    msg := sprintf(
        "WARNING: %d vulnerabilities are being ignored. Review ignore policies.",
        [ignored]
    )
}

# Advertir si hay muchos issues en total
warn[msg] {
    severity_counts.total > 50

    msg := sprintf(
        "WARNING: High vulnerability count (%d total). Consider security debt reduction.",
        [severity_counts.total]
    )
}

# =============================================================================
# Reportes auxiliares
# =============================================================================

# Resumen de issues por severidad
summary := {
    "critical": severity_counts.critical,
    "high": severity_counts.high,
    "medium": severity_counts.medium,
    "low": severity_counts.low,
    "total": severity_counts.total,
    "thresholds": thresholds,
    "status": get_status
}

# Determinar estado
get_status = "BLOCKED" {
    severity_counts.critical > thresholds.critical
}
get_status = "BLOCKED" {
    severity_counts.high > thresholds.high
}
get_status = "PASS" {
    severity_counts.critical <= thresholds.critical
    severity_counts.high <= thresholds.high
}

# Lista de issues críticos
critical_issues := [issue |
    issue := issues[_]
    lower(issue.details.severityCode) == "critical"
]

# Lista de issues con fix disponible
fixable_issues := [issue |
    issue := issues[_]
    issue.details.fixAvailable == true
]

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Security High Severity Block",
    "description": "Blocks pipeline based on vulnerability count thresholds by severity",
    "version": "2.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "sto", "severity", "threshold"],
    "input_schema": "Harness STO securityTestData and output format"
}
