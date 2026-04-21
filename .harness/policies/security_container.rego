# =============================================================================
# OPA Policy: Container Security Enforcement
# Evalua findings de container scanning (AquaTrivy, Grype, etc.)
# =============================================================================
#
# Input Structure (Harness STO):
# - input[_].name == "securityTestData" -> outcome.issues[]
# - issueType == "CONTAINER" o target.type == "container"
# =============================================================================

package security.sto.container

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuracion
# =============================================================================

# Umbrales por severidad para container vulnerabilities
thresholds := {
    "critical": 0,    # Zero tolerance para critical en containers
    "high": 3,        # Maximo 3 high
    "medium": 15,     # Maximo 15 medium
    "low": 50         # Maximo 50 low
}

# Base images conocidas como problematicas
risky_base_images := [
    "alpine:3.14",
    "alpine:3.15",
    "debian:stretch",
    "debian:jessie",
    "ubuntu:16.04",
    "ubuntu:18.04",
    "python:2.7",
    "node:12",
    "node:14"
]

# =============================================================================
# Helpers
# =============================================================================

security_test_data := data_obj {
    some i
    input[i].name == "securityTestData"
    data_obj := input[i]
}

output_data := data_obj {
    some i
    input[i].name == "output"
    data_obj := input[i]
}

issues := security_test_data.outcome.issues

# Filtrar issues de container
container_issues := [issue |
    issue := issues[_]
    is_container_issue(issue)
]

# Detectar si es issue de container
is_container_issue(issue) {
    issue.issueType == "CONTAINER"
}
is_container_issue(issue) {
    issue.target.type == "container"
}
is_container_issue(issue) {
    # Trivy a veces reporta como SCA pero con layer info
    issue.details.layerId != ""
}

# Contar por severidad
count_by_severity(sev) = cnt {
    cnt := count([i |
        i := container_issues[_]
        lower(i.details.severityCode) == lower(sev)
    ])
}

# =============================================================================
# Reglas DENY
# =============================================================================

# Denegar si hay vulnerabilidades critical
deny[msg] {
    critical_count := count_by_severity("critical")
    critical_count > thresholds.critical

    msg := sprintf(
        "BLOCKED [CONTAINER]: Found %d CRITICAL vulnerabilities in container image. Maximum allowed: %d",
        [critical_count, thresholds.critical]
    )
}

# Denegar si hay demasiadas high
deny[msg] {
    high_count := count_by_severity("high")
    high_count > thresholds.high

    msg := sprintf(
        "BLOCKED [CONTAINER]: Found %d HIGH vulnerabilities in container image. Maximum allowed: %d",
        [high_count, thresholds.high]
    )
}

# Denegar vulnerabilidades critical con exploit conocido
deny[msg] {
    issue := container_issues[_]
    lower(issue.details.severityCode) == "critical"
    issue.exploitability == "yes"

    cve := get_cve(issue)

    msg := sprintf(
        "BLOCKED [CONTAINER]: Critical vulnerability %s in '%s' has known exploit. Immediate fix required.",
        [cve, issue.details.libraryName]
    )
}

# Denegar vulnerabilidades critical en OS packages (mas riesgosas)
deny[msg] {
    issue := container_issues[_]
    lower(issue.details.severityCode) == "critical"
    is_os_package(issue)

    cve := get_cve(issue)

    msg := sprintf(
        "BLOCKED [CONTAINER]: Critical OS-level vulnerability %s in '%s'. Update base image.",
        [cve, issue.details.libraryName]
    )
}

# =============================================================================
# Reglas WARN
# =============================================================================

# Advertir sobre base images riesgosas
warn[msg] {
    # Obtener base image del target o metadata
    base_image := security_test_data.outcome.target.baseImage

    some risky in risky_base_images
    contains(base_image, risky)

    msg := sprintf(
        "WARNING [CONTAINER]: Base image '%s' is outdated/vulnerable. Consider upgrading.",
        [base_image]
    )
}

# Advertir si hay muchas medium
warn[msg] {
    medium_count := count_by_severity("medium")
    medium_count > thresholds.medium

    msg := sprintf(
        "WARNING [CONTAINER]: Found %d MEDIUM vulnerabilities. Consider reducing technical debt.",
        [medium_count]
    )
}

# Advertir sobre vulnerabilidades sin fix
warn[msg] {
    issue := container_issues[_]
    lower(issue.details.severityCode) in ["critical", "high"]
    issue.details.fixAvailable == false

    cve := get_cve(issue)

    msg := sprintf(
        "WARNING [CONTAINER]: %s severity %s has no fix available. Monitor for updates.",
        [issue.details.severityCode, cve]
    )
}

# Advertir sobre vulnerabilidades en layers especificos
warn[msg] {
    issue := container_issues[_]
    lower(issue.details.severityCode) == "critical"
    issue.details.layerId != ""

    msg := sprintf(
        "WARNING [CONTAINER]: Critical vulnerability in layer %s. Consider multi-stage build.",
        [issue.details.layerId]
    )
}

# =============================================================================
# Helpers
# =============================================================================

get_cve(issue) = cve {
    refs := issue.details.referenceIdentifiers
    cves := [sprintf("CVE-%s", [r.id]) | r := refs[_]; r.type == "cve"]
    count(cves) > 0
    cve := cves[0]
} else = "N/A"

# Detectar si es un paquete del OS (no aplicacion)
is_os_package(issue) {
    pkg_type := lower(issue.details.packageType)
    pkg_type in ["deb", "apk", "rpm", "os"]
}
is_os_package(issue) {
    # Paquetes comunes de OS
    lib := lower(issue.details.libraryName)
    startswith(lib, "lib")
}

# =============================================================================
# Reportes
# =============================================================================

severity_counts := {
    "critical": count_by_severity("critical"),
    "high": count_by_severity("high"),
    "medium": count_by_severity("medium"),
    "low": count_by_severity("low"),
    "total": count(container_issues)
}

summary := {
    "counts": severity_counts,
    "thresholds": thresholds,
    "status": get_status,
    "fixable": count([i | i := container_issues[_]; i.details.fixAvailable == true])
}

get_status = "BLOCKED" {
    count_by_severity("critical") > thresholds.critical
}
get_status = "BLOCKED" {
    count_by_severity("high") > thresholds.high
}
get_status = "PASS" {
    count_by_severity("critical") <= thresholds.critical
    count_by_severity("high") <= thresholds.high
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Container Security Enforcement",
    "description": "Evaluates container image vulnerabilities with severity thresholds",
    "version": "1.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "sto", "container", "trivy", "docker"],
    "supported_scanners": ["AquaTrivy", "Grype", "Snyk Container", "Prisma Cloud"]
}
