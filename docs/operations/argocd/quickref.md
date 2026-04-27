# ArgoCD Quick Reference

Referencia rápida para operaciones comunes de ArgoCD.

## Clusters Disponibles

| Cluster | URL | Proyecto GCP |
|---------|-----|--------------|
| se-latam-test | https://35.185.82.33 | sales-209522 |

## Conectar

```bash
# GKE credentials
gcloud container clusters get-credentials se-latam-test --zone us-east1-b --project sales-209522

# ArgoCD CLI login
argocd login 35.185.82.33 --username admin --insecure

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Aplicaciones

```bash
argocd app list                      # Listar apps
argocd app get <name>                # Detalle de app
argocd app sync <name>               # Sincronizar
argocd app sync <name> --force       # Forzar sync
argocd app diff <name>               # Ver diferencias
argocd app history <name>            # Historial
argocd app rollback <name> <rev>     # Rollback
argocd app delete <name>             # Eliminar
```

## Repositorios

```bash
argocd repo list                     # Listar repos
argocd repo add <url> --username git --password <token>
argocd repo rm <url>                 # Eliminar repo
```

## Clusters

```bash
argocd cluster list                  # Listar clusters
argocd cluster add <context>         # Agregar cluster
argocd cluster rm <server>           # Eliminar cluster
```

## Proyectos

```bash
argocd proj list                     # Listar proyectos
argocd proj get <name>               # Detalle
argocd proj create <name>            # Crear
```

## Kubectl Shortcuts

```bash
# Pods
kubectl get pods -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# Restart
kubectl rollout restart deployment -n argocd

# Port forward (si no hay LoadBalancer)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## ApplicationSet (crear múltiples apps)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cinema-services
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - service: booking-service
          - service: movie-service
          - service: user-service
  template:
    metadata:
      name: '{{service}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        targetRevision: HEAD
        path: 'services/{{service}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: cinema
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Sync Policies

```yaml
syncPolicy:
  automated:
    prune: true          # Eliminar recursos huérfanos
    selfHeal: true       # Auto-corregir drift
    allowEmpty: false    # No permitir sync vacío
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

## Aliases Recomendados

```bash
# Agregar a ~/.bashrc o ~/.zshrc
alias acd='argocd'
alias acda='argocd app'
alias acdal='argocd app list'
alias acdas='argocd app sync'
alias acdag='argocd app get'
alias kga='kubectl get applications -n argocd'
```
