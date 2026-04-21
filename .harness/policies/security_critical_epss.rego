# =============================================================================
# OPA Policy: Security Gate for SCA and SAST
# Bloquea pipeline basado en severidad, EPSS (SCA) y reachability (SAST)
# =============================================================================
#
# Esta policy evalúa DOS tipos de findings:
#
# 1. SCA (Software Composition Analysis) - Vulnerabilidades en dependencias
#    - Usa EPSS Score para priorización
#    - EPSS: probabilidad de explotación en los próximos 30 días (0.0 - 1.0)
#
# 2. SAST (Static Application Security Testing) - Vulnerabilidades en código
#    - Usa Reachability para priorización
#    - reachable = el código vulnerable se ejecuta realmente
#
# Input Structure (Harness STO):
# - input[_].name == "securityTestData" -> outcome.issues[]
# - SCA: issue.issueType == "SCA", tiene details.epss
# - SAST: issue.issueType == "SAST", tiene details.reachability
# =============================================================================

package security.sto.critical_epss

import future.keywords.in
import future.keywords.if
import future.keywords.contains

# =============================================================================
# Configuración de umbrales
# =============================================================================

# EPSS thresholds (para SCA)
epss_high_threshold := 0.5
epss_very_high_threshold := 0.7
epss_medium_threshold := 0.3

# Máximos permitidos
max_critical_issues := 0
max_critical_reachable := 0

# =============================================================================
# Helper: Obtener issues del input de Harness STO
# =============================================================================

# Obtener el objeto securityTestData del input array
security_test_data := data_obj {
    some i
    input[i].name == "securityTestData"
    data_obj := input[i]
}

# Obtener todos los issues
issues := security_test_data.outcome.issues

# Filtrar por tipo
sca_issues := [issue | issue := issues[_]; issue.issueType == "SCA"]
sast_issues := [issue | issue := issues[_]; issue.issueType == "SAST"]

# =============================================================================
# DENY RULES - SCA (Software Composition Analysis)
# =============================================================================

# Denegar: Critical SCA con EPSS alto
deny[msg] {
    issue := sca_issues[_]
    lower(issue.details.severityCode) == "critical"
    issue.details.epss > epss_high_threshold

    cve := get_cve(issue.details.referenceIdentifiers)

    msg := sprintf(
        "BLOCKED [SCA]: Critical vulnerability '%s' (%s) has high exploit probability (EPSS: %.2f). Fix: %s",
        [issue.details.libraryName, cve, issue.details.epss, get_fix(issue)]
    )
}

# Denegar: High SCA con EPSS muy alto
deny[msg] {
    issue := sca_issues[_]
    lower(issue.details.severityCode) == "high"
    issue.details.epss > epss_very_high_threshold

    cve := get_cve(issue.details.referenceIdentifiers)

    msg := sprintf(
        "BLOCKED [SCA]: High severity '%s' (%s) has very high EPSS (%.2f). Treat as critical.",
        [issue.details.libraryName, cve, issue.details.epss]
    )
}

# =============================================================================
# DENY RULES - SAST (Static Application Security Testing)
# =============================================================================

# Denegar: Critical SAST que es reachable
deny[msg] {
    issue := sast_issues[_]
    lower(issue.details.severityCode) == "critical"
    lower(issue.details.reachability) == "reachable"

    cwe := get_cwe(issue.details.referenceIdentifiers)
    loc := get_location(issue)

    msg := sprintf(
        "BLOCKED [SAST]: Critical REACHABLE vulnerability '%s' (%s) at %s. Code path is exploitable.",
        [issue.details.title, cwe, loc]
    )
}

# Denegar: Contar críticos reachable excede límite
deny[msg] {
    critical_reachable := count([i |
        i := sast_issues[_]
        lower(i.details.severityCode) == "critical"
        lower(i.details.reachability) == "reachable"
    ])

    critical_reachable > max_critical_reachable

    msg := sprintf(
        "BLOCKED [SAST]: Found %d critical REACHABLE vulnerabilities. Maximum allowed: %d.",
        [critical_reachable, max_critical_reachable]
    )
}

# Denegar: High SAST reachable (código de alta severidad que se ejecuta)
deny[msg] {
    issue := sast_issues[_]
    lower(issue.details.severityCode) == "high"
    lower(issue.details.reachability) == "reachable"

    cwe := get_cwe(issue.details.referenceIdentifiers)
    loc := get_location(issue)

    msg := sprintf(
        "BLOCKED [SAST]: High severity REACHABLE vulnerability '%s' (%s) at %s.",
        [issue.details.title, cwe, loc]
    )
}

# =============================================================================
# DENY RULES - Conteos generales
# =============================================================================

# Denegar: Total de críticos excede límite
deny[msg] {
    critical_count := count([i |
        i := issues[_]
        lower(i.details.severityCode) == "critical"
    ])

    critical_count > max_critical_issues

    msg := sprintf(
        "BLOCKED: Found %d total critical vulnerabilities. Maximum allowed: %d.",
        [critical_count, max_critical_issues]
    )
}

# =============================================================================
# WARNING RULES - SCA
# =============================================================================

# Warn: High SCA con EPSS moderado
warn[msg] {
    issue := sca_issues[_]
    lower(issue.details.severityCode) == "high"
    issue.details.epss > epss_medium_threshold
    issue.details.epss <= epss_high_threshold

    cve := get_cve(issue.details.referenceIdentifiers)

    msg := sprintf(
        "WARNING [SCA]: High severity '%s' (%s) has moderate EPSS (%.2f). Consider prioritizing.",
        [issue.details.libraryName, cve, issue.details.epss]
    )
}

# Warn: Medium SCA con EPSS alto
warn[msg] {
    issue := sca_issues[_]
    lower(issue.details.severityCode) == "medium"
    issue.details.epss > epss_high_threshold

    cve := get_cve(issue.details.referenceIdentifiers)

    msg := sprintf(
        "WARNING [SCA]: Medium severity '%s' (%s) has high EPSS (%.2f). Review recommended.",
        [issue.details.libraryName, cve, issue.details.epss]
    )
}

# Warn: SCA con exploit conocido
warn[msg] {
    issue := sca_issues[_]
    issue.exploitability == "yes"

    cve := get_cve(issue.details.referenceIdentifiers)

    msg := sprintf(
        "WARNING [SCA]: Vulnerability '%s' (%s) has known exploit. Priority fix recommended.",
        [issue.details.libraryName, cve]
    )
}

# =============================================================================
# WARNING RULES - SAST
# =============================================================================

# Warn: Medium SAST reachable
warn[msg] {
    issue := sast_issues[_]
    lower(issue.details.severityCode) == "medium"
    lower(issue.details.reachability) == "reachable"

    cwe := get_cwe(issue.details.referenceIdentifiers)
    loc := get_location(issue)

    msg := sprintf(
        "WARNING [SAST]: Medium severity REACHABLE '%s' (%s) at %s.",
        [issue.details.title, cwe, loc]
    )
}

# Warn: Critical/High SAST unreachable (menor prioridad pero revisar)
warn[msg] {
    issue := sast_issues[_]
    lower(issue.details.severityCode) == "critical"
    lower(issue.details.reachability) == "unreachable"

    cwe := get_cwe(issue.details.referenceIdentifiers)

    msg := sprintf(
        "WARNING [SAST]: Critical but UNREACHABLE '%s' (%s). Lower priority but should be fixed.",
        [issue.details.title, cwe]
    )
}

# =============================================================================
# Helper Functions
# =============================================================================

# Extraer primer CVE de referenceIdentifiers (para SCA)
get_cve(refs) = result {
    cves := [sprintf("CVE-%s", [ref.id]) | ref := refs[_]; ref.type == "cve"]
    count(cves) > 0
    result := cves[0]
} else = "N/A"

# Extraer primer CWE de referenceIdentifiers (para SAST)
get_cwe(refs) = result {
    cwes := [sprintf("CWE-%s", [ref.id]) | ref := refs[_]; ref.type == "cwe"]
    count(cwes) > 0
    result := cwes[0]
} else = "N/A"

# Obtener ubicación del issue (file:line)
get_location(issue) = loc {
    occ := issue.occurrences[0]
    loc := sprintf("%s:%d", [occ.fileName, occ.lineNumber])
} else = "unknown"

# Obtener fix disponible
get_fix(issue) = fix {
    occ := issue.occurrences[0]
    fix := occ.remediationSteps
} else = "No fix available"

# =============================================================================
# Utility Functions
# =============================================================================

# Contar issues por severidad y tipo
count_by_severity_type(sev, issue_type) = cnt {
    cnt := count([i |
        i := issues[_]
        lower(i.details.severityCode) == lower(sev)
        i.issueType == issue_type
    ])
}

# Contar reachable por severidad
count_reachable_by_severity(sev) = cnt {
    cnt := count([i |
        i := sast_issues[_]
        lower(i.details.severityCode) == lower(sev)
        lower(i.details.reachability) == "reachable"
    ])
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Security Gate for SCA and SAST",
    "description": "Blocks pipeline based on severity, EPSS (SCA) and reachability (SAST)",
    "version": "3.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "sto", "epss", "sast", "sca", "reachability"],
    "supported_scanners": ["Snyk", "Qwiet/ShiftLeft", "Semgrep", "Checkmarx"]
}
