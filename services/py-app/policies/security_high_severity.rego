# =============================================================================
# OPA Policy: Security High Severity Block
# Bloquea pipeline basado en conteo de vulnerabilidades por severidad
# =============================================================================
#
# Policy más simple que evalúa únicamente:
# - Cantidad de issues por severidad
# - Umbrales configurables
# =============================================================================

package security.sto.high_severity

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuración de umbrales
# =============================================================================

# Máximo permitido por severidad
thresholds := {
    "CRITICAL": 0,    # Zero tolerance para críticos
    "HIGH": 5,        # Máximo 5 high
    "MEDIUM": 20,     # Máximo 20 medium
    "LOW": 100        # Máximo 100 low
}

# =============================================================================
# Regla principal
# =============================================================================

# Denegar si se exceden los umbrales
deny[msg] {
    # Para cada severidad definida
    severity := ["CRITICAL", "HIGH", "MEDIUM", "LOW"][_]

    # Contar issues de esa severidad
    count_issues := count([i | i := input.issues[_]; i.severity == severity])

    # Obtener umbral
    threshold := thresholds[severity]

    # Verificar si excede
    count_issues > threshold

    msg := sprintf(
        "BLOCKED: Found %d %s severity issues. Maximum allowed: %d.",
        [count_issues, severity, threshold]
    )
}

# =============================================================================
# Reglas adicionales
# =============================================================================

# Denegar si hay issues críticos sin fix disponible
deny[msg] {
    issue := input.issues[_]

    issue.severity == "CRITICAL"
    issue.fix_available == false

    msg := sprintf(
        "BLOCKED: Critical vulnerability '%s' has no fix available. Manual review required.",
        [issue.title]
    )
}

# Advertir sobre issues antiguos no remediados
warn[msg] {
    issue := input.issues[_]

    # Issue con más de 30 días
    issue.age_days > 30

    # Severidad alta o crítica
    issue.severity in ["CRITICAL", "HIGH"]

    msg := sprintf(
        "WARNING: %s severity issue '%s' is %d days old. Consider prioritizing.",
        [issue.severity, issue.title, issue.age_days]
    )
}

# Advertir sobre nuevos issues críticos
warn[msg] {
    issue := input.issues[_]

    issue.severity == "CRITICAL"
    issue.is_new == true

    msg := sprintf(
        "WARNING: New critical vulnerability detected: '%s'. Immediate attention required.",
        [issue.title]
    )
}

# =============================================================================
# Reportes auxiliares
# =============================================================================

# Resumen de issues por severidad
summary := {
    "critical": count([i | i := input.issues[_]; i.severity == "CRITICAL"]),
    "high": count([i | i := input.issues[_]; i.severity == "HIGH"]),
    "medium": count([i | i := input.issues[_]; i.severity == "MEDIUM"]),
    "low": count([i | i := input.issues[_]; i.severity == "LOW"]),
    "total": count(input.issues)
}

# Lista de issues críticos
critical_issues := [issue |
    issue := input.issues[_]
    issue.severity == "CRITICAL"
]

# Lista de issues con fix disponible
fixable_issues := [issue |
    issue := input.issues[_]
    issue.fix_available == true
]

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Security High Severity Block",
    "description": "Blocks pipeline based on vulnerability count thresholds by severity",
    "version": "1.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "sto", "severity", "threshold"]
}
