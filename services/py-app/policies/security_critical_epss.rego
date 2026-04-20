# =============================================================================
# OPA Policy: Security Critical with EPSS Score
# Bloquea pipeline si hay vulnerabilidades críticas con alta probabilidad de exploit
# =============================================================================
#
# Esta policy evalúa:
# 1. Severidad de la vulnerabilidad (Critical, High)
# 2. EPSS Score (Exploit Prediction Scoring System)
# 3. Combinación de ambos para decisiones de bloqueo
#
# EPSS Score: 0.0 - 1.0 (probabilidad de explotación en los próximos 30 días)
# - > 0.5: Alta probabilidad de exploit
# - > 0.3: Probabilidad moderada
# - < 0.1: Baja probabilidad
# =============================================================================

package security.sto.critical_epss

import future.keywords.in
import future.keywords.if
import future.keywords.contains

# =============================================================================
# Configuración de umbrales
# =============================================================================

# Umbral de EPSS para considerar alta probabilidad de exploit
epss_high_threshold := 0.5

# Umbral de EPSS para probabilidad moderada
epss_medium_threshold := 0.3

# Máximo de issues críticos permitidos
max_critical_issues := 0

# Máximo de issues high con EPSS alto permitidos
max_high_epss_issues := 0

# =============================================================================
# Regla principal: DENY si hay críticos con EPSS alto
# =============================================================================

# Denegar si hay vulnerabilidades críticas con EPSS > 0.5
deny[msg] {
    # Obtener issues del scan
    issue := input.issues[_]

    # Verificar severidad crítica
    issue.severity == "CRITICAL"

    # Verificar EPSS alto
    issue.epss_score > epss_high_threshold

    msg := sprintf(
        "BLOCKED: Critical vulnerability '%s' (CVE: %s) has high exploit probability (EPSS: %.2f). Remediation required before merge.",
        [issue.title, issue.cve, issue.epss_score]
    )
}

# Denegar si hay más de N issues críticos (independiente de EPSS)
deny[msg] {
    # Contar issues críticos
    critical_count := count([issue | issue := input.issues[_]; issue.severity == "CRITICAL"])

    # Verificar umbral
    critical_count > max_critical_issues

    msg := sprintf(
        "BLOCKED: Found %d critical vulnerabilities. Maximum allowed: %d. Please remediate before proceeding.",
        [critical_count, max_critical_issues]
    )
}

# Denegar si hay issues HIGH con EPSS muy alto
deny[msg] {
    issue := input.issues[_]

    # Severidad High
    issue.severity == "HIGH"

    # EPSS muy alto (> 0.7)
    issue.epss_score > 0.7

    msg := sprintf(
        "BLOCKED: High severity vulnerability '%s' (CVE: %s) has very high exploit probability (EPSS: %.2f). Treat as critical.",
        [issue.title, issue.cve, issue.epss_score]
    )
}

# =============================================================================
# Reglas de WARNING (no bloquean, solo alertan)
# =============================================================================

# Advertir sobre issues HIGH con EPSS moderado
warn[msg] {
    issue := input.issues[_]

    issue.severity == "HIGH"
    issue.epss_score > epss_medium_threshold
    issue.epss_score <= epss_high_threshold

    msg := sprintf(
        "WARNING: High severity vulnerability '%s' (CVE: %s) has moderate exploit probability (EPSS: %.2f). Consider prioritizing.",
        [issue.title, issue.cve, issue.epss_score]
    )
}

# Advertir sobre issues MEDIUM con EPSS alto
warn[msg] {
    issue := input.issues[_]

    issue.severity == "MEDIUM"
    issue.epss_score > epss_high_threshold

    msg := sprintf(
        "WARNING: Medium severity vulnerability '%s' (CVE: %s) has high exploit probability (EPSS: %.2f). Review recommended.",
        [issue.title, issue.cve, issue.epss_score]
    )
}

# Advertir sobre vulnerabilidades con exploit conocido
warn[msg] {
    issue := input.issues[_]

    # Tiene exploit conocido
    issue.exploit_available == true

    msg := sprintf(
        "WARNING: Vulnerability '%s' (CVE: %s) has a known exploit available. Priority remediation recommended.",
        [issue.title, issue.cve]
    )
}

# =============================================================================
# Reglas auxiliares
# =============================================================================

# Contar issues por severidad
count_by_severity(sev) = count([i | i := input.issues[_]; i.severity == sev])

# Verificar si hay issues con fix disponible
has_fix_available(issue) {
    issue.fix_available == true
}

# Calcular score de riesgo combinado
risk_score(issue) = score {
    # Base score por severidad
    severity_score := severity_to_score(issue.severity)

    # Multiplicador por EPSS
    epss_multiplier := 1 + (issue.epss_score * 2)

    # Score final
    score := severity_score * epss_multiplier
}

# Mapeo de severidad a score numérico
severity_to_score(sev) = 4 { sev == "CRITICAL" }
severity_to_score(sev) = 3 { sev == "HIGH" }
severity_to_score(sev) = 2 { sev == "MEDIUM" }
severity_to_score(sev) = 1 { sev == "LOW" }
severity_to_score(sev) = 0 { sev == "INFO" }

# =============================================================================
# Metadata de la policy
# =============================================================================

metadata := {
    "name": "Security Critical with EPSS",
    "description": "Blocks pipeline if critical vulnerabilities with high EPSS score are found",
    "version": "1.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "sto", "epss", "critical"]
}
