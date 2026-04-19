# OPA Policies for Harness CD Pipeline

## Configuración en Harness

### 1. Crear Policy en Harness

1. Navegar a **Project Settings** → **Governance** → **Policies**
2. Click **+ New Policy**
3. Configurar:
   - **Name**: `configmap-validation`
   - **Rego**: Copiar contenido de `configmap-validation.rego`
4. Click **Save**

### 2. Crear Policy Set

1. Navegar a **Governance** → **Policy Sets**
2. Click **+ New Policy Set**
3. Configurar:
   - **Name**: `cinema-cd-validation`
   - **Entity Type**: `Pipeline`
   - **Event**: `On Run`
   - **Policies**: Seleccionar `configmap-validation`
   - **Action**: `Error and exit`
4. Click **Save**

### 3. Aplicar al Pipeline

El Policy Set se aplicará automáticamente a todos los pipelines del proyecto.

## Policies Incluidas

| Policy | Descripción |
|--------|-------------|
| `configmap-validation.rego` | Valida values antes del deploy (DB_REPLICA, etc.) |
| `deployment-validation.rego` | Valida manifests K8s renderizados |

## Testing Local

```bash
# Instalar OPA
brew install opa  # macOS
# o
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static && chmod +x opa

# Validar policy
opa eval -i values.json -d configmap-validation.rego "data.kubernetes.configmap.deny"

# Ejemplo con values de movie-service
cd platform/deploy/kubernetes
yq eval-all 'select(fi==0)*select(fi==1)*select(fi==2)' \
  values/base.yaml values/environments/dev.yaml values/services/movie.yaml \
  | yq -o=json > /tmp/values.json
opa eval -i /tmp/values.json -d policies/configmap-validation.rego "data.kubernetes.configmap.deny"
```

## Integración en Pipeline Harness

El pipeline debe incluir estos steps para validación completa:

```yaml
stages:
  - stage:
      name: DEV
      type: Deployment
      spec:
        execution:
          steps:
            - step:
                name: Validate Values
                identifier: validateValues
                type: ShellScript
                spec:
                  shell: Bash
                  source:
                    type: Inline
                    spec:
                      script: |
                        cd platform/deploy/kubernetes
                        ./scripts/validate-values.sh <+service.name> dev
            - step:
                name: Render Templates  
                identifier: renderTemplates
                type: ShellScript
                spec:
                  shell: Bash
                  source:
                    type: Inline
                    spec:
                      script: |
                        cd platform/deploy/kubernetes
                        ./scripts/render.sh <+service.name> dev <+artifact.tag>
            - step:
                name: Rollout Deployment
                identifier: rolloutDeployment
                type: K8sRollingDeploy
                timeout: 10m
                spec:
                  skipDryRun: false
            - step:
                name: Smoke Test - Liveness
                identifier: smokeTestLive
                type: Http
                timeout: 30s
                spec:
                  url: http://<+service.name>.cinema-dev.svc.cluster.local:<+serviceVariables.port>/health/live
                  method: GET
                  assertion: <+httpResponseCode> == 200
            - step:
                name: Smoke Test - Readiness
                identifier: smokeTestReady
                type: Http
                timeout: 30s
                spec:
                  url: http://<+service.name>.cinema-dev.svc.cluster.local:<+serviceVariables.port>/health/ready
                  method: GET
                  assertion: <+httpResponseCode> == 200
```
