# =============================================================================
# OPA Policy: Pipeline Security Enforcement
# Valida que el pipeline tenga los controles de seguridad requeridos
# =============================================================================
#
# Esta policy se aplica a NIVEL PIPELINE (policySetRef en stage)
# Evalúa la DEFINICIÓN del pipeline, NO los resultados de scan
#
# Casos de uso:
# - Asegurar que ciertos scanners estén presentes
# - Validar configuración de steps de seguridad
# - Controlar quién puede ejecutar pipelines de producción
# =============================================================================

package pipeline.security.enforcement

import future.keywords.in
import future.keywords.if

# =============================================================================
# Configuración
# =============================================================================

# Scanners requeridos para pipelines de seguridad
required_scanner_types := ["HarnessSCA","HarnessSAST", "Snyk", "AquaTrivy", "Gitleaks"]

# Mínimo de scanners requeridos
min_scanners_required := 2

# =============================================================================
# Helpers
# =============================================================================

# Obtener todos los steps del pipeline
all_steps := steps {
    steps := [step |
        stage := input.pipeline.stages[_].stage
        step := stage.spec.execution.steps[_].step
    ]
}

# Obtener steps de grupos
grouped_steps := steps {
    steps := [step |
        stage := input.pipeline.stages[_].stage
        stepGroup := stage.spec.execution.steps[_].stepGroup
        parallel := stepGroup.steps[_].parallel
        step := parallel[_].step
    ]
}

# Todos los tipos de step
all_step_types := types {
    direct := {step.type | step := all_steps[_]}
    grouped := {step.type | step := grouped_steps[_]}
    types := direct | grouped
}

# Contar scanners de seguridad presentes
security_scanners := [t |
    t := all_step_types[_]
    t in required_scanner_types
]

# =============================================================================
# Reglas de validación de estructura
# =============================================================================

# Denegar si no hay suficientes scanners de seguridad
deny[msg] {
    count(security_scanners) < min_scanners_required

    msg := sprintf(
        "BLOCKED: Pipeline must have at least %d security scanners. Found: %d (%v)",
        [min_scanners_required, count(security_scanners), security_scanners]
    )
}

# Denegar si no hay SAST scanner
deny[msg] {
    not "HarnessSAST" in all_step_types
    not "Semgrep" in all_step_types
    not "Checkmarx" in all_step_types

    msg := "BLOCKED: Pipeline must include a SAST scanner (HarnessSAST, Semgrep, or Checkmarx)"
}

# Denegar si no hay detección de secretos
deny[msg] {
    not "Gitleaks" in all_step_types
    not "TruffleHog" in all_step_types

    msg := "BLOCKED: Pipeline must include secret detection (Gitleaks or TruffleHog)"
}

# =============================================================================
# Reglas de acceso y control
# =============================================================================

# Denegar si usuario no autorizado ejecuta en producción
deny[msg] {
    # Si es un tag de producción
    input.pipeline.tags.environment == "production"

    # Verificar si el usuario está en el grupo autorizado
    user_groups := {g.identifier | g := input.metadata.userGroups[_]}
    not "ProductionDeployers" in user_groups
    not "SalesEngineers" in user_groups

    msg := sprintf(
        "BLOCKED: User '%s' is not authorized to run production pipelines",
        [input.metadata.user.email]
    )
}

# =============================================================================
# Warnings
# =============================================================================

# Advertir si no hay policy enforcement en steps de scan
warn[msg] {
    step := all_steps[_]
    step.type in required_scanner_types
    not step.enforce

    msg := sprintf(
        "WARNING: Scanner step '%s' does not have policy enforcement configured",
        [step.identifier]
    )
}

# Advertir si hay failure strategies que ignoran errores de seguridad
warn[msg] {
    step := all_steps[_]
    step.type in required_scanner_types

    strategy := step.failureStrategies[_]
    strategy.onFailure.action.type == "MarkAsSuccess"

    msg := sprintf(
        "WARNING: Scanner '%s' has MarkAsSuccess on failure - security issues may be ignored",
        [step.identifier]
    )
}

# =============================================================================
# Información del pipeline
# =============================================================================

pipeline_info := {
    "name": input.pipeline.name,
    "identifier": input.pipeline.identifier,
    "stages": count(input.pipeline.stages),
    "security_scanners": security_scanners,
    "has_sast": "HarnessSAST" in all_step_types,
    "has_sca": "Snyk" in all_step_types,
    "has_secrets": "Gitleaks" in all_step_types,
    "has_container": "AquaTrivy" in all_step_types,
    "executed_by": input.metadata.user.email
}

# =============================================================================
# Metadata
# =============================================================================

metadata := {
    "name": "Pipeline Security Enforcement",
    "description": "Validates pipeline structure has required security controls",
    "version": "1.0.0",
    "level": "pipeline",
    "author": "Harness SE Team"
}
