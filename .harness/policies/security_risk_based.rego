# =============================================================================
# OPA Policy: Risk-Based Security Evaluation
# Evalúa riesgo combinando múltiples factores
# =============================================================================
#
# Factores evaluados:
# 1. Severidad base (CVSS)
# 2. EPSS Score (probabilidad de exploit) - solo SCA
# 3. Reachability (¿el código vulnerable es alcanzable?) - solo SAST
# 4. Fix disponible
# 5. Tipo de issue (SCA vs SAST)
#
# Input Structure (Harness STO):
# - input[_].name == "securityTestData" -> outcome.issues[]
# - SCA: tiene details.epss
# - SAST: tiene details.reachability
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

# Máximo de issues de alto riesgo permitidos
max_high_risk_issues := 3

# Pesos para cálculo de riesgo
weights := {
    "severity": 0.35,
    "epss": 0.25,
    "reachability": 0.25,
    "fix_available": 0.15
}

# =============================================================================
# Helpers: Obtener datos del input
# =============================================================================

security_test_data := data_obj {
    some i
    input[i].name == "securityTestData"
    data_obj := input[i]
}

issues := security_test_data.outcome.issues

sca_issues := [issue | issue := issues[_]; issue.issueType == "SCA"]
sast_issues := [issue | issue := issues[_]; issue.issueType == "SAST"]

# =============================================================================
# Regla principal
# =============================================================================

# Denegar si el risk score de un issue es muy alto
deny[msg] {
    issue := issues[_]
    score := calculate_risk_score(issue)
    score >= block_risk_threshold

    ref := get_reference(issue)
    loc := get_location(issue)

    msg := sprintf(
        "BLOCKED: Issue '%s' (%s) at %s has risk score %.2f (threshold: %.2f). Type: %s",
        [issue.details.title, ref, loc, score, block_risk_threshold, issue.issueType]
    )
}

# Denegar si hay demasiados issues de alto riesgo
deny[msg] {
    high_risk_count := count([i |
        i := issues[_]
        calculate_risk_score(i) >= warn_risk_threshold
    ])

    high_risk_count > max_high_risk_issues

    msg := sprintf(
        "BLOCKED: Found %d high-risk vulnerabilities. Maximum allowed: %d.",
        [high_risk_count, max_high_risk_issues]
    )
}

# =============================================================================
# Warnings
# =============================================================================

warn[msg] {
    issue := issues[_]
    score := calculate_risk_score(issue)

    score >= warn_risk_threshold
    score < block_risk_threshold

    msg := sprintf(
        "WARNING: Issue '%s' has elevated risk score %.2f. Consider prioritizing.",
        [issue.details.title, score]
    )
}

# =============================================================================
# Cálculo de Risk Score
# =============================================================================

# Función principal de cálculo de riesgo
calculate_risk_score(issue) = score {
    # Componente de severidad (0-10)
    sev_score := severity_score(issue.details.severityCode)

    # Componente de EPSS o reachability (0-10)
    exploit_score := exploitability_score(issue)

    # Componente de fix disponible (0-10)
    fix_score := fix_availability_score(issue)

    # Calcular score ponderado (normalizado a 10)
    total_weight := weights.severity + weights.epss + weights.fix_available
    score := ((sev_score * weights.severity) +
              (exploit_score * weights.epss) +
              (fix_score * weights.fix_available)) * 10 / total_weight
}

# Mapeo de severidad a score
severity_score(sev) = 10 { lower(sev) == "critical" }
severity_score(sev) = 7.5 { lower(sev) == "high" }
severity_score(sev) = 5 { lower(sev) == "medium" }
severity_score(sev) = 2.5 { lower(sev) == "low" }
severity_score(sev) = 0 { lower(sev) == "info" }
severity_score(sev) = 5 {
    not lower(sev) in ["critical", "high", "medium", "low", "info"]
}

# Score de explotabilidad (EPSS para SCA, reachability para SAST)
exploitability_score(issue) = score {
    issue.issueType == "SCA"
    epss := issue.details.epss
    score := epss * 10  # EPSS va de 0-1, escalamos a 0-10
}

exploitability_score(issue) = 10 {
    issue.issueType == "SAST"
    lower(issue.details.reachability) == "reachable"
}

exploitability_score(issue) = 3 {
    issue.issueType == "SAST"
    lower(issue.details.reachability) == "unreachable"
}

exploitability_score(issue) = 5 {
    issue.issueType == "SAST"
    not issue.details.reachability
}

exploitability_score(issue) = 5 {
    not issue.issueType in ["SCA", "SAST"]
}

# Score de disponibilidad de fix (invertido - menor riesgo si hay fix)
fix_availability_score(issue) = 3 {
    issue.details.fixAvailable == true
}

fix_availability_score(issue) = 8 {
    issue.details.fixAvailable == false
}

fix_availability_score(issue) = 5 {
    not issue.details.fixAvailable
}

# =============================================================================
# Helpers
# =============================================================================

# Obtener referencia (CVE para SCA, CWE para SAST)
get_reference(issue) = ref {
    issue.issueType == "SCA"
    refs := issue.details.referenceIdentifiers
    cves := [sprintf("CVE-%s", [r.id]) | r := refs[_]; r.type == "cve"]
    count(cves) > 0
    ref := cves[0]
} else = ref {
    issue.issueType == "SAST"
    refs := issue.details.referenceIdentifiers
    cwes := [sprintf("CWE-%s", [r.id]) | r := refs[_]; r.type == "cwe"]
    count(cwes) > 0
    ref := cwes[0]
} else = "N/A"

# Obtener ubicación
get_location(issue) = loc {
    occ := issue.occurrences[0]
    loc := sprintf("%s:%d", [occ.fileName, occ.lineNumber])
} else = "unknown"

# =============================================================================
# Análisis y reportes
# =============================================================================

# Resumen de riesgo
risk_summary := {
    "total_issues": count(issues),
    "sca_issues": count(sca_issues),
    "sast_issues": count(sast_issues),
    "high_risk_issues": count([i | i := issues[_]; calculate_risk_score(i) >= warn_risk_threshold]),
    "blocking_issues": count([i | i := issues[_]; calculate_risk_score(i) >= block_risk_threshold]),
    "average_risk_score": avg_risk_score,
    "max_risk_score": max_risk_score
}

# Score promedio
avg_risk_score := result {
    count(issues) > 0
    result := sum([calculate_risk_score(i) | i := issues[_]]) / count(issues)
} else = 0

# Score máximo
max_risk_score := result {
    count(issues) > 0
    scores := [calculate_risk_score(i) | i := issues[_]]
    result := max(scores)
} else = 0

# Top issues por riesgo
top_risk_issues := [{"title": i.details.title, "type": i.issueType, "risk_score": calculate_risk_score(i)} |
    i := issues[_]
    calculate_risk_score(i) >= warn_risk_threshold
]

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Risk-Based Security Evaluation",
    "description": "Evaluates security risk using multiple weighted factors",
    "version": "2.0.0",
    "author": "Harness SE Team",
    "factors": ["severity", "epss/reachability", "fix_available"],
    "thresholds": {
        "block": block_risk_threshold,
        "warn": warn_risk_threshold
    },
    "tags": ["security", "sto", "risk", "epss", "reachability"],
    "input_schema": "Harness STO securityTestData format"
}
