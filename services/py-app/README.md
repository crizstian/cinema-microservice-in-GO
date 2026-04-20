# Yalo Demo App - Harness STO Demo

Aplicación de demostración para Harness Security Testing Orchestration (STO).

## Propósito

Esta aplicación contiene **vulnerabilidades intencionales** para demostrar las capacidades de:
- Detección de vulnerabilidades (SAST, SCA, Container)
- Auto-remediation con Harness AI
- Error Analysis Agent
- OPA Policies con EPSS

## Estructura del Proyecto

```
yalo-demo-app/
├── src/
│   └── app.py                 # Aplicación Flask con vulnerabilidades
├── tests/
│   └── test_app.py            # Tests unitarios (algunos fallarán con fixes)
├── policies/
│   ├── security_critical_epss.rego    # Policy: Critical + EPSS alto
│   ├── security_high_severity.rego    # Policy: Threshold por severidad
│   └── security_risk_based.rego       # Policy: Risk-based (multi-factor)
├── .harness/
│   ├── pipeline-security-scan.yaml    # Pipeline CI + STO
│   └── policy-set.yaml                # Configuración de Policy Sets
├── requirements.txt           # Dependencias (con versiones vulnerables)
├── Dockerfile                 # Container image
├── pytest.ini                 # Configuración de pytest
└── README.md                  # Este archivo
```

## Vulnerabilidades Incluidas

### SAST (Código)

| Tipo | CWE | Severidad | Ubicación |
|------|-----|-----------|-----------|
| Hardcoded Secrets | CWE-798 | High | `app.py:17-19` |
| SQL Injection | CWE-89 | Critical | `app.py:38` |
| Command Injection | CWE-78 | Critical | `app.py:58` |
| Insecure Deserialization | CWE-502 | High | `app.py:75` |
| XSS | CWE-79 | Medium | `app.py:90` |
| Weak Cryptography (MD5) | CWE-328 | Medium | `app.py:105` |
| Path Traversal | CWE-22 | High | `app.py:120` |

### SCA (Dependencias)

| Paquete | Versión | CVE | Severidad |
|---------|---------|-----|-----------|
| Flask | 2.0.1 | CVE-2023-30861 | High |
| PyYAML | 5.3.1 | CVE-2020-14343 | Critical |
| requests | 2.25.1 | CVE-2023-32681 | Medium |
| Pillow | 8.1.0 | CVE-2021-25287 | Critical |
| SQLAlchemy | 1.3.23 | CVE-2021-3655 | High |

## Uso para Demo

### 1. Preparar ambiente

```bash
# Clonar repo
git clone <repo-url>
cd yalo-demo-app

# Crear virtualenv
python -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt
```

### 2. Ejecutar tests

```bash
# Todos los tests
pytest tests/ -v

# Con coverage
pytest tests/ --cov=src --cov-report=html
```

### 3. Ejecutar aplicación

```bash
# Desarrollo
flask run --host=0.0.0.0 --port=5000

# O con Docker
docker build -t yalo-demo-app .
docker run -p 5000:5000 yalo-demo-app
```

### 4. Configurar Harness

1. Crear proyecto en Harness
2. Configurar connectors:
   - GitHub (para clonar repo)
   - Docker Registry (para push de imagen)
   - Snyk (API token)
3. Importar pipeline desde `.harness/pipeline-security-scan.yaml`
4. Crear Policy Set desde `.harness/policy-set.yaml`
5. Ejecutar pipeline

## Tests que Fallarán con Fixes

Algunos tests están diseñados para fallar cuando se aplican fixes de seguridad:

| Test | Fallará si... |
|------|---------------|
| `test_hash_password_function` | Se cambia MD5 a SHA256/bcrypt |
| `test_database_password_exists` | Se mueve secret a env var |
| `test_api_key_format` | Se mueve API key a env var |

Esto es intencional para demostrar el Error Analysis Agent.

## OPA Policies

### security_critical_epss.rego
- Bloquea si hay Critical con EPSS > 0.5
- Bloquea si hay High con EPSS > 0.7
- Warning para High con EPSS moderado

### security_high_severity.rego
- Zero tolerance para Critical
- Máximo 5 High
- Máximo 20 Medium

### security_risk_based.rego
- Calcula risk score combinando:
  - Severidad (30%)
  - EPSS (25%)
  - Reachability (20%)
  - Fix disponible (15%)
  - Edad del CVE (10%)
- Bloquea si risk score >= 8.0

## Notas Importantes

1. **NO usar en producción** - Este código es intencionalmente vulnerable
2. **Solo para demos** - Las vulnerabilidades son features, no bugs
3. **Actualizar Snyk token** - Usar token válido en secrets de Harness
4. **Branch protection** - Configurar en GitHub para bloquear merges fallidos

## Flujo de Demo Sugerido

1. Mostrar código con vulnerabilidades
2. Ejecutar pipeline - ver detección
3. Mostrar Raw Scanner Severity (Snyk)
4. Click en "Generate Fix" para SQL Injection
5. Ver PR generado
6. Ver test que falla (hash_password)
7. Mostrar Error Agent analizando
8. Ver fix iterado
9. Tests pasan
10. Mostrar policy bloqueando (si hay críticos pendientes)

## Contacto

Harness SE Team - demo@harness.io
