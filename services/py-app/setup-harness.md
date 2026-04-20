# Setup de Harness para Demo Yalo

## Pre-requisitos

- [ ] Cuenta de Harness con STO habilitado
- [ ] Cuenta de Snyk con API token
- [ ] Repositorio en GitHub
- [ ] Docker Registry (DockerHub, GCR, etc.)

---

## Paso 1: Crear Proyecto en Harness

```
Organization: default (o crear nueva)
Project Name: yalo-demo
Project ID: yalo_demo
```

---

## Paso 2: Configurar Connectors

### 2.1 GitHub Connector

```yaml
connector:
  name: github-yalo
  identifier: github_yalo
  type: Github
  spec:
    url: https://github.com/<org>/yalo-demo-app
    authentication:
      type: Http
      spec:
        type: UsernameToken
        spec:
          username: <github-username>
          tokenRef: account.github_token
    apiAccess:
      type: Token
      spec:
        tokenRef: account.github_token
```

### 2.2 Docker Registry Connector

```yaml
connector:
  name: dockerhub
  identifier: dockerhub
  type: DockerRegistry
  spec:
    dockerRegistryUrl: https://index.docker.io/v2/
    providerType: DockerHub
    auth:
      type: UsernamePassword
      spec:
        username: <dockerhub-username>
        passwordRef: account.dockerhub_password
```

### 2.3 Snyk Connector (implícito en step)

Crear secret para Snyk API token:
```
Secret Name: snyk_api_token
Secret Value: <tu-snyk-api-token>
```

---

## Paso 3: Crear Secrets

| Secret Name | Descripción | Scope |
|-------------|-------------|-------|
| `github_token` | GitHub Personal Access Token | Account |
| `dockerhub_password` | DockerHub password o token | Account |
| `snyk_api_token` | Snyk API token | Project |
| `slack_webhook` | Slack webhook URL (opcional) | Project |

---

## Paso 4: Importar Pipeline

### Opción A: Via UI

1. Ir a Pipelines → Create Pipeline
2. Seleccionar "Import from Git"
3. Seleccionar connector de GitHub
4. Path: `.harness/pipeline-security-scan.yaml`

### Opción B: Via CLI

```bash
harness pipeline create \
  --org default \
  --project yalo_demo \
  --file .harness/pipeline-security-scan.yaml
```

### Opción C: Via API

```bash
curl -X POST \
  'https://app.harness.io/pipeline/api/pipelines/v2?accountIdentifier=<ACCOUNT_ID>&orgIdentifier=default&projectIdentifier=yalo_demo' \
  -H 'Content-Type: application/yaml' \
  -H 'x-api-key: <API_KEY>' \
  -d @.harness/pipeline-security-scan.yaml
```

---

## Paso 5: Crear OPA Policies

### 5.1 Crear Policy via UI

1. Ir a Project Settings → Policies
2. Click "New Policy"
3. Copiar contenido de `policies/security_critical_epss.rego`
4. Guardar como "Security Critical EPSS"

### 5.2 Crear Policy Set

1. Ir a Project Settings → Policy Sets
2. Click "New Policy Set"
3. Nombre: "Security STO Policies"
4. Agregar policies:
   - security_critical_epss
   - security_high_severity
5. Entity Type: Pipeline
6. Event: On Run
7. Action: Error and Exit

---

## Paso 6: Configurar Branch Protection (GitHub)

```yaml
# En GitHub repo settings → Branches → Branch protection rules

Branch name pattern: main

Rules:
  - Require status checks to pass before merging: ✓
    - Required checks:
      - yalo-security-scan
  - Require branches to be up to date before merging: ✓
```

---

## Paso 7: Verificar Setup

### Checklist de verificación

```bash
# 1. Verificar connectors
harness connector list --org default --project yalo_demo

# 2. Verificar secrets
harness secret list --org default --project yalo_demo

# 3. Verificar pipeline
harness pipeline get \
  --org default \
  --project yalo_demo \
  --pipeline yalo_security_scan

# 4. Verificar policies
harness policy list --org default --project yalo_demo
```

### Test de pipeline

1. Hacer un commit al repo
2. Verificar que el pipeline se ejecuta
3. Verificar que Snyk detecta vulnerabilidades
4. Verificar que las policies evalúan correctamente

---

## Troubleshooting

### Pipeline no ejecuta

```
Causa: Connector de GitHub sin permisos
Fix: Verificar PAT tiene scope: repo, workflow
```

### Snyk no detecta vulnerabilidades

```
Causa: API token inválido o expirado
Fix: Regenerar token en Snyk y actualizar secret
```

### Policy no bloquea

```
Causa: Policy Set no asociado al pipeline
Fix: Verificar entitySelector incluye el pipeline
```

### Error en Docker push

```
Causa: Credenciales incorrectas
Fix: Verificar username/password en connector
```

---

## Variables de Ambiente para Demo

```bash
export HARNESS_ACCOUNT_ID="<tu-account-id>"
export HARNESS_API_KEY="<tu-api-key>"
export HARNESS_ORG_ID="default"
export HARNESS_PROJECT_ID="yalo_demo"
export SNYK_TOKEN="<snyk-api-token>"
export GITHUB_TOKEN="<github-pat>"
```

---

## Comandos Útiles

```bash
# Ejecutar pipeline manualmente
harness pipeline run \
  --org default \
  --project yalo_demo \
  --pipeline yalo_security_scan \
  --branch main

# Ver ejecución
harness pipeline execution get \
  --org default \
  --project yalo_demo \
  --execution <execution-id>

# Ver issues de STO
harness sto issues list \
  --org default \
  --project yalo_demo \
  --pipeline yalo_security_scan

# Evaluar policy manualmente
harness policy evaluate \
  --org default \
  --project yalo_demo \
  --policy security_critical_epss \
  --input test-input.json
```
