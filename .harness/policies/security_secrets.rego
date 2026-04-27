# =============================================================================
# OPA Policy: Secret Detection Enforcement
# Evalua findings de secret detection (Gitleaks, TruffleHog, etc.)
# =============================================================================
#
# Input Structure (Harness STO):
# - input[_].name == "securityTestData" -> outcome.issues[]
# - issueType == "SECRET"
# =============================================================================

package security.sto.secrets

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuracion
# =============================================================================

# Zero tolerance para secrets - cualquier secret detectado bloquea
max_secrets_allowed := 0

# Tipos de secrets de alto riesgo (bloqueo inmediato)
high_risk_secret_types := [
    "aws-access-key",
    "aws-secret-key",
    "gcp-api-key",
    "azure-storage-key",
    "private-key",
    "github-token",
    "gitlab-token",
    "slack-token",
    "stripe-api-key",
    "twilio-api-key",
    "sendgrid-api-key",
    "database-password",
    "jwt-secret"
]

# =============================================================================
# Helpers
# =============================================================================

security_test_data := data_obj {
    some i
    input[i].name == "securityTestData"
    data_obj := input[i]
}

issues := security_test_data.outcome.issues

# Filtrar solo issues de tipo SECRET
secret_issues := [issue |
    issue := issues[_]
    issue.issueType == "SECRET"
]

# =============================================================================
# Reglas DENY
# =============================================================================

# Denegar si hay cualquier secret detectado
deny[msg] {
    count(secret_issues) > max_secrets_allowed

    msg := sprintf(
        "BLOCKED [SECRETS]: Found %d exposed secrets. Secrets in code are never allowed.",
        [count(secret_issues)]
    )
}

# Denegar secrets de alto riesgo con detalles
deny[msg] {
    issue := secret_issues[_]
    secret_type := lower(issue.details.secretType)

    # Verificar si es un tipo de alto riesgo
    some high_risk in high_risk_secret_types
    contains(secret_type, high_risk)

    loc := get_location(issue)

    msg := sprintf(
        "BLOCKED [SECRETS]: High-risk secret '%s' found at %s. Type: %s",
        [issue.details.title, loc, issue.details.secretType]
    )
}

# Denegar secrets en archivos criticos
deny[msg] {
    issue := secret_issues[_]
    occ := issue.occurrences[0]
    file := occ.fileName

    # Archivos que nunca deben tener secrets
    is_critical_file(file)

    msg := sprintf(
        "BLOCKED [SECRETS]: Secret found in critical file '%s'. This file should never contain secrets.",
        [file]
    )
}

# =============================================================================
# Reglas WARN
# =============================================================================

# Advertir sobre secrets en commits recientes
warn[msg] {
    issue := secret_issues[_]
    occ := issue.occurrences[0]

    # Si el commit es reciente (tiene hash)
    occ.commit != ""

    msg := sprintf(
        "WARNING [SECRETS]: Secret '%s' found in commit %s. Consider rotating this credential.",
        [issue.details.title, occ.commit]
    )
}

# =============================================================================
# Helpers
# =============================================================================

get_location(issue) = loc {
    occ := issue.occurrences[0]
    loc := sprintf("%s:%d", [occ.fileName, occ.lineNumber])
} else = "unknown"

# Archivos criticos que nunca deben tener secrets
is_critical_file(file) {
    endswith(file, ".env")
}
is_critical_file(file) {
    endswith(file, ".env.local")
}
is_critical_file(file) {
    endswith(file, ".env.production")
}
is_critical_file(file) {
    contains(file, "docker-compose")
}
is_critical_file(file) {
    endswith(file, "Dockerfile")
}
is_critical_file(file) {
    endswith(file, ".yml")
    contains(file, "pipeline")
}

# =============================================================================
# Reportes
# =============================================================================

summary := {
    "total_secrets": count(secret_issues),
    "status": get_status,
    "locations": [get_location(i) | i := secret_issues[_]]
}

get_status = "BLOCKED" {
    count(secret_issues) > 0
}
get_status = "PASS" {
    count(secret_issues) == 0
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Secret Detection Enforcement",
    "description": "Zero tolerance policy for exposed secrets in code",
    "version": "1.0.0",
    "author": "Harness SE Team",
    "tags": ["security", "sto", "secrets", "gitleaks"],
    "supported_scanners": ["Gitleaks", "TruffleHog", "GitGuardian"]
}
