# Makefile para construcción de imágenes Docker
#
# Comandos principales:
#   make build SERVICE=booking-service VERSION=v1.0.0    - Construir una imagen
#   make build-all VERSION=v1.0.0                        - Construir todas las imágenes
#   make push SERVICE=booking-service VERSION=v1.0.0     - Build + push
#   make push-all VERSION=v1.0.0                         - Build + push todas las imágenes
#

# Configuración
SERVICES := booking movie payment notification
PLATFORM_SERVICES := mongodb webserver base
VERSION ?= v0.0.0-dev
REGISTRY ?= crizstian
ORGANIZATION ?= cinema

# Script de build
BUILD_SCRIPT := ./platform/scripts/build-image.sh
SERVICE_PATH := ./services

# ============================================================
# TARGETS PRINCIPALES
# ============================================================

.PHONY: help
help: ## Mostrar esta ayuda
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Makefile - Construcción de Imágenes Docker"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Uso:"
	@echo "  make build SERVICE=<servicio> VERSION=<version>    # Build single"
	@echo "  make build-all VERSION=<version>                   # Build all"
	@echo "  make push SERVICE=<servicio> VERSION=<version>     # Build + push"
	@echo "  make push-all VERSION=<version>                    # Build + push all"
	@echo ""
	@echo "Ejemplos:"
	@echo "  make build SERVICE=booking-service VERSION=v1.0.0"
	@echo "  make build-all VERSION=v1.0.0"
	@echo "  make push SERVICE=movie-service VERSION=v1.0.1"
	@echo ""
	@echo "Servicios disponibles:"
	@echo "  $(SERVICES)"
	@echo ""

.PHONY: build
build: ## Construir imagen de un servicio
ifndef SERVICE
	@echo "❌ ERROR: SERVICE es requerido"
	@echo "Uso: make build SERVICE=booking-service VERSION=v1.0.0"
	@exit 1
endif
	@SERVICE=$(SERVICE) VERSION=$(VERSION) REGISTRY=$(REGISTRY) ORGANIZATION=$(ORGANIZATION) $(BUILD_SCRIPT)

.PHONY: push
push: ## Construir y pushear imagen de un servicio
ifndef SERVICE
	@echo "❌ ERROR: SERVICE es requerido"
	@echo "Uso: make push SERVICE=booking-service VERSION=v1.0.0"
	@exit 1
endif
	@SERVICE=$(SERVICE) VERSION=$(VERSION) REGISTRY=$(REGISTRY) ORGANIZATION=$(ORGANIZATION) PUSH=true $(BUILD_SCRIPT)

.PHONY: build-all
build-all: ## Construir todas las imágenes
	@echo "🔨 Construyendo todas las imágenes (VERSION=$(VERSION))..."
	@for service in $(SERVICES); do \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "  $$service"; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		SERVICE=$$service VERSION=$(VERSION) REGISTRY=$(REGISTRY) ORGANIZATION=$(ORGANIZATION) $(BUILD_SCRIPT) || exit 1; \
	done
	@echo ""
	@echo "✅ Todas las imágenes construidas exitosamente"

.PHONY: push-all
push-all: ## Construir y pushear todas las imágenes
	@echo "🔨 Construyendo y pusheando todas las imágenes (VERSION=$(VERSION))..."
	@for service in $(SERVICES); do \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "  $$service"; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		SERVICE=$$service VERSION=$(VERSION) REGISTRY=$(REGISTRY) ORGANIZATION=$(ORGANIZATION) PUSH=true $(BUILD_SCRIPT) || exit 1; \
	done
	@echo ""
	@echo "✅ Todas las imágenes construidas y pusheadas exitosamente"

# ============================================================
# TARGETS DE DESARROLLO
# ============================================================

.PHONY: list
list: ## Listar servicios disponibles
	@echo "Servicios disponibles:"
	@for service in $(SERVICES); do echo "  - $$service"; done

.PHONY: test-build
test-build: ## Test build de un servicio (sin push)
ifndef SERVICE
	@echo "❌ ERROR: SERVICE es requerido"
	@exit 1
endif
	@SERVICE=$(SERVICE) VERSION=test-$(shell date +%Y%m%d-%H%M%S) REGISTRY=$(REGISTRY) ORGANIZATION=$(ORGANIZATION) $(BUILD_SCRIPT)

# ============================================================
# TARGETS DE VALIDACIÓN
# ============================================================

.PHONY: validate
validate: ## Validar monorepo completo (todas las etapas)
	@./platform/scripts/validate-monorepo.sh

.PHONY: validate-quick
validate-quick: ## Validación rápida (sin Docker: estructura, workspace, tests)
	@./platform/scripts/validate-monorepo.sh --quick

.PHONY: validate-docker
validate-docker: ## Validación solo de Docker (etapas 4,5,6,7)
	@./platform/scripts/validate-monorepo.sh --stages 4,5,6,7

.PHONY: validate-structure
validate-structure: ## Validar solo estructura de archivos
	@./platform/scripts/validation/01-validate-structure.sh

.PHONY: validate-workspace
validate-workspace: ## Validar solo Go workspace
	@./platform/scripts/validation/02-validate-workspace.sh

.PHONY: validate-tests
validate-tests: ## Validar solo tests unitarios
	@./platform/scripts/validation/03-validate-unit-tests.sh

.PHONY: validate-builds
validate-builds: ## Validar solo builds Docker
	@./platform/scripts/validation/04-validate-builds.sh

.PHONY: validate-mongodb
validate-mongodb: ## Validar solo MongoDB
	@./platform/scripts/validation/05-validate-mongodb.sh

.PHONY: validate-services
validate-services: ## Validar solo servicios
	@./platform/scripts/validation/06-validate-services.sh

.PHONY: validate-integration
validate-integration: ## Validar solo integración E2E
	@./platform/scripts/validation/07-validate-integration.sh
