# =============================================================================
# OPA Policy: Risk-Based Security Evaluation
# Evalúa riesgo combinando múltiples factores (similar al Yalo Risk Framework)
# =============================================================================
#
# Factores evaluados:
# 1. Severidad base (CVSS)
# 2. EPSS Score (probabilidad de exploit)
# 3. Reachability (¿el código vulnerable es alcanzable?)
# 4. Fix disponible
# 5. Edad del CVE
# 6. Ambiente (prod vs non-prod) - si está disponible
#
# Este approach es más cercano a lo que Yalo ya hace en su framework.
# =============================================================================

package security.sto.risk_based

import future.keywords.in
import future.keywords.if
import future.keywords.contains

# =============================================================================
# Configuración
# =============================================================================

# Umbral de risk score para bloquear
block_risk_threshold := 8.0

# Umbral de risk score para warning
warn_risk_threshold := 5.0

# Pesos para cálculo de riesgo
weights := {
    "severity": 0.30,
    "epss": 0.25,
    "reachability": 0.20,
    "fix_available": 0.15,
    "age": 0.10
}

# =============================================================================
# Regla principal
# =============================================================================

# Denegar si el risk score agregado es muy alto
deny[msg] {
    # Calcular risk score para cada issue
    issue := input.issues[_]
    score := calculate_risk_score(issue)

    # Verificar umbral
    score >= block_risk_threshold

    msg := sprintf(
        "BLOCKED: Issue '%s' (CVE: %s) has risk score %.2f (threshold: %.2f). Factors: severity=%s, EPSS=%.2f, reachable=%v",
        [issue.title, issue.cve, score, block_risk_threshold, issue.severity, issue.epss_score, issue.reachable]
    )
}

# Denegar si hay demasiados issues de alto riesgo
deny[msg] {
    # Contar issues con risk score alto
    high_risk_count := count([i |
        i := input.issues[_]
        calculate_risk_score(i) >= warn_risk_threshold
    ])

    # Más de 3 issues de alto riesgo
    high_risk_count > 3

    msg := sprintf(
        "BLOCKED: Found %d high-risk vulnerabilities. Maximum allowed: 3. Review and remediate.",
        [high_risk_count]
    )
}

# =============================================================================
# Warnings
# =============================================================================

warn[msg] {
    issue := input.issues[_]
    score := calculate_risk_score(issue)

    score >= warn_risk_threshold
    score < block_risk_threshold

    msg := sprintf(
        "WARNING: Issue '%s' has elevated risk score %.2f. Consider prioritizing.",
        [issue.title, score]
    )
}

# =============================================================================
# Cálculo de Risk Score
# =============================================================================

# Función principal de cálculo de riesgo
calculate_risk_score(issue) = score {
    # Componente de severidad (0-10)
    sev_score := severity_score(issue.severity)

    # Componente de EPSS (0-10)
    epss_component := issue.epss_score * 10

    # Componente de reachability (0-10)
    reach_score := reachability_score(issue)

    # Componente de fix disponible (0-10, menor si hay fix)
    fix_score := fix_availability_score(issue)

    # Componente de edad (0-10, mayor si es viejo sin fix)
    age_score := age_score_calc(issue)

    # Calcular score ponderado
    score := (
        (sev_score * weights.severity) +
        (epss_component * weights.epss) +
        (reach_score * weights.reachability) +
        (fix_score * weights.fix_available) +
        (age_score * weights.age)
    ) * 10 / (weights.severity + weights.epss + weights.reachability + weights.fix_available + weights.age)
}

# Mapeo de severidad a score
severity_score(sev) = 10 { sev == "CRITICAL" }
severity_score(sev) = 7.5 { sev == "HIGH" }
severity_score(sev) = 5 { sev == "MEDIUM" }
severity_score(sev) = 2.5 { sev == "LOW" }
severity_score(sev) = 0 { sev == "INFO" }
severity_score(sev) = 5 { not sev in ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"] }

# Score de reachability
reachability_score(issue) = 10 {
    issue.reachable == true
}
reachability_score(issue) = 3 {
    issue.reachable == false
}
reachability_score(issue) = 6 {
    not issue.reachable  # Unknown
}

# Score de disponibilidad de fix (invertido - menor riesgo si hay fix)
fix_availability_score(issue) = 3 {
    issue.fix_available == true
}
fix_availability_score(issue) = 8 {
    issue.fix_available == false
}
fix_availability_score(issue) = 5 {
    not issue.fix_available  # Unknown
}

# Score basado en edad
age_score_calc(issue) = score {
    issue.age_days > 90
    score := 10  # Muy viejo, alto riesgo
}
age_score_calc(issue) = score {
    issue.age_days > 30
    issue.age_days <= 90
    score := 7
}
age_score_calc(issue) = score {
    issue.age_days > 7
    issue.age_days <= 30
    score := 4
}
age_score_calc(issue) = score {
    issue.age_days <= 7
    score := 2  # Nuevo, bajo riesgo relativo
}
age_score_calc(issue) = 5 {
    not issue.age_days  # Unknown
}

# =============================================================================
# Análisis y reportes
# =============================================================================

# Resumen de riesgo
risk_summary := {
    "total_issues": count(input.issues),
    "high_risk_issues": count([i | i := input.issues[_]; calculate_risk_score(i) >= warn_risk_threshold]),
    "blocking_issues": count([i | i := input.issues[_]; calculate_risk_score(i) >= block_risk_threshold]),
    "average_risk_score": avg_risk_score,
    "max_risk_score": max_risk_score
}

# Score promedio
avg_risk_score := sum([calculate_risk_score(i) | i := input.issues[_]]) / count(input.issues) {
    count(input.issues) > 0
}
avg_risk_score := 0 {
    count(input.issues) == 0
}

# Score máximo
max_risk_score := max([calculate_risk_score(i) | i := input.issues[_]]) {
    count(input.issues) > 0
}
max_risk_score := 0 {
    count(input.issues) == 0
}

# Top 5 issues por riesgo
top_risk_issues := sort_by_risk(input.issues)

sort_by_risk(issues) = sorted {
    sorted := [{"issue": i, "risk_score": calculate_risk_score(i)} | i := issues[_]]
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Risk-Based Security Evaluation",
    "description": "Evaluates security risk using multiple weighted factors similar to enterprise risk frameworks",
    "version": "1.0.0",
    "author": "Harness SE Team",
    "factors": ["severity", "epss", "reachability", "fix_available", "age"],
    "thresholds": {
        "block": block_risk_threshold,
        "warn": warn_risk_threshold
    },
    "tags": ["security", "sto", "risk", "epss", "reachability"]
}
