# ArgoCD - Cluster se-latam-test

Configuración específica de ArgoCD en el cluster GKE `se-latam-test`.

## Información del Cluster

| Campo | Valor |
|-------|-------|
| **Cluster Name** | se-latam-test |
| **Project** | sales-209522 |
| **Zone** | us-east1-b |
| **Kubernetes Version** | v1.35.3-gke.1522000 |
| **Installation Date** | 2026-04-27 |
| **Installation Method** | Helm |

## Acceso a ArgoCD

### URL y Credenciales

| Campo | Valor |
|-------|-------|
| **URL** | https://35.185.82.33 |
| **Service Type** | LoadBalancer |
| **Usuario** | admin |
| **Password** | Ver comando abajo |

```bash
# Obtener password actual
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Conectar al Cluster

```bash
# Obtener credenciales del cluster
gcloud container clusters get-credentials se-latam-test \
  --zone us-east1-b \
  --project sales-209522

# Verificar conexión
kubectl get nodes
```

## Componentes Instalados

```bash
# Ver pods de ArgoCD
kubectl get pods -n argocd
```

| Componente | Replicas | Propósito |
|------------|----------|-----------|
| argocd-server | 1 | API/UI |
| argocd-application-controller | 1 | Sincronización de apps |
| argocd-repo-server | 1 | Clonado de repos |
| argocd-redis | 1 | Cache |
| argocd-dex-server | 1 | SSO/OIDC |
| argocd-applicationset-controller | 1 | ApplicationSets |
| argocd-notifications-controller | 1 | Notificaciones |

## Servicios

```bash
kubectl get svc -n argocd
```

| Servicio | Tipo | Puerto | IP Externa |
|----------|------|--------|------------|
| argocd-server | LoadBalancer | 80, 443 | 35.185.82.33 |
| argocd-repo-server | ClusterIP | 8081 | - |
| argocd-redis | ClusterIP | 6379 | - |

## Node Pools

| Node Pool | Machine Type | Nodes | Propósito |
|-----------|--------------|-------|-----------|
| primary-nodepool | n1-standard-8 | 1-5 | Workloads generales |
| agent-nodepool | n1-standard-8 | 1-2 | Harness Delegate (tainted) |

## Operaciones Comunes

### Reiniciar ArgoCD

```bash
kubectl rollout restart deployment -n argocd
kubectl rollout restart statefulset -n argocd
```

### Ver Logs

```bash
# Server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Repo Server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -f
```

### Cambiar Password de Admin

```bash
# Via CLI
argocd login 35.185.82.33 --username admin --password <current-password> --insecure
argocd account update-password

# Via kubectl (reset to new random password)
kubectl -n argocd delete secret argocd-initial-admin-secret
kubectl rollout restart deployment argocd-server -n argocd
# Wait and get new password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Backup/Restore

```bash
# Export all apps
argocd app list -o yaml > argocd-apps-backup.yaml

# Export all projects
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Export all repos
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository -o yaml > argocd-repos-backup.yaml
```

## Helm Release Info

```bash
# Ver release actual
export HELM_CONFIG_HOME=/tmp/helm-config
export HELM_CACHE_HOME=/tmp/helm-cache
export HELM_DATA_HOME=/tmp/helm-data
helm list -n argocd

# Ver valores usados
helm get values argocd -n argocd

# Upgrade
helm repo update
helm upgrade argocd argo/argo-cd -n argocd --reuse-values
```

## Troubleshooting

### ArgoCD Server no responde

```bash
# Verificar pod
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server

# Verificar servicio
kubectl get svc argocd-server -n argocd
kubectl describe svc argocd-server -n argocd
```

### Problemas de Sincronización

```bash
# Ver estado de apps
argocd app list

# Forzar refresh
argocd app get <app-name> --refresh

# Forzar sync
argocd app sync <app-name> --force
```

### Problemas con Repositorios

```bash
# Listar repos
argocd repo list

# Test conexión
argocd repo get <repo-url>

# Ver logs de repo-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100
```

## Seguridad

### Certificado TLS

El servicio usa certificado self-signed por defecto. Para producción:

1. Configurar cert-manager con Let's Encrypt
2. O usar Ingress con TLS termination

### Firewall Rules

Asegurar que solo IPs autorizadas puedan acceder al LoadBalancer:

```bash
# Crear firewall rule restrictiva (ejemplo)
gcloud compute firewall-rules create allow-argocd-admin \
  --allow tcp:443 \
  --source-ranges="YOUR_IP/32" \
  --target-tags=gke-se-latam-test-primary-nodepool
```

## Costos Estimados

| Recurso | Costo Mensual |
|---------|---------------|
| GKE Cluster (management) | $73 |
| primary-nodepool (n1-standard-8) | ~$198 |
| agent-nodepool (n1-standard-8) | ~$198 |
| LoadBalancer | ~$18 |
| **Total** | ~$487/mes |

## Referencias

- [Installation Guide](installation-guide.md)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Helm Chart Values](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
