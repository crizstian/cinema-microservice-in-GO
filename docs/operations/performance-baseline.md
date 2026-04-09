# Performance Baseline

> Metricas de referencia para el stack Cinema Microservices.

## Tabla de Contenidos

- [Entorno de Referencia](#entorno-de-referencia)
- [Latencia por Endpoint](#latencia-por-endpoint)
- [Throughput](#throughput)
- [Recursos](#recursos)
- [Como Medir](#como-medir)
- [Alertas Recomendadas](#alertas-recomendadas)

---

## Entorno de Referencia

| Componente | Especificacion |
|------------|----------------|
| CPU | 4 cores / 8 threads |
| RAM | 16 GB |
| Storage | SSD NVMe |
| Docker | 24.x |
| Go | 1.24.x |
| MongoDB | 8.0 (3 replicas) |
| Redis | 7.x |
| NATS | 2.10 |

---

## Latencia por Endpoint

### Objetivo: p95 < 200ms para operaciones criticas

| Servicio | Endpoint | Metodo | p50 | p95 | p99 |
|----------|----------|--------|-----|-----|-----|
| **movie** | `/movies` | GET | 15ms | 45ms | 80ms |
| **movie** | `/movies/{id}` | GET | 8ms | 25ms | 50ms |
| **showtime** | `/showtimes` | GET | 20ms | 60ms | 100ms |
| **showtime** | `/showtimes?movie_id=X` | GET | 12ms | 35ms | 70ms |
| **seat** | `/seats/availability` | GET | 25ms | 75ms | 120ms |
| **seat** | `/seats/hold` | POST | 30ms | 90ms | 150ms |
| **booking** | `/booking` | POST | 150ms | 350ms | 500ms |
| **booking** | `/booking/{id}` | GET | 20ms | 50ms | 90ms |
| **user** | `/users/register` | POST | 40ms | 100ms | 180ms |
| **user** | `/users/login` | POST | 35ms | 80ms | 150ms |
| **payment** | `/charge` | POST | 200ms | 400ms | 600ms |

### Notas

- **booking POST** incluye orquestacion SAGA completa (hold verification, payment, confirmation)
- **payment POST** depende de latencia de Stripe API (mock en dev/test)
- **seat hold** incluye operacion Redis SETNX con TTL

---

## Throughput

### Objetivo: 100 RPS por servicio minimo

| Servicio | Endpoint | Target RPS | Achieved RPS | Concurrency |
|----------|----------|------------|--------------|-------------|
| movie | GET /movies | 500 | 850 | 50 |
| showtime | GET /showtimes | 300 | 620 | 50 |
| seat | GET /availability | 200 | 380 | 50 |
| seat | POST /hold | 100 | 150 | 20 |
| booking | POST /booking | 50 | 75 | 10 |
| user | POST /login | 200 | 420 | 50 |

### Bottlenecks Identificados

1. **booking**: Limitado por secuencia SAGA (hold -> payment -> confirm)
2. **seat hold**: Limitado por Redis lock contention
3. **payment**: Limitado por Stripe API rate limits (en prod)

---

## Recursos

### Consumo por Servicio (idle)

| Servicio | CPU | Memory | Notas |
|----------|-----|--------|-------|
| booking | 0.1% | 25 MB | SAGA state machine |
| movie | 0.1% | 20 MB | Read-heavy |
| payment | 0.1% | 22 MB | Stripe SDK |
| seat | 0.1% | 28 MB | Redis connection pool |
| showtime | 0.1% | 20 MB | |
| user | 0.1% | 24 MB | JWT processing |
| notification | 0.1% | 18 MB | Event consumer |
| cinema | 0.1% | 18 MB | |

### Consumo por Servicio (under load - 100 RPS)

| Servicio | CPU | Memory | Notas |
|----------|-----|--------|-------|
| booking | 15% | 45 MB | |
| movie | 8% | 35 MB | |
| payment | 12% | 40 MB | |
| seat | 20% | 55 MB | Redis ops |
| showtime | 10% | 30 MB | |
| user | 12% | 38 MB | |
| notification | 5% | 25 MB | |
| cinema | 5% | 22 MB | |

### Infraestructura

| Componente | CPU (idle) | CPU (load) | Memory | Storage |
|------------|------------|------------|--------|---------|
| MongoDB (x3) | 0.5% | 25% | 200 MB each | 500 MB |
| Redis | 0.1% | 10% | 50 MB | 10 MB |
| NATS | 0.1% | 5% | 30 MB | - |

---

## Como Medir

### Prerrequisitos

```bash
# Instalar k6
brew install k6  # macOS
# o
snap install k6  # Linux
```

### Script de Baseline

```bash
# Ejecutar test de baseline
task perf:baseline

# O manualmente:
k6 run tests/performance/baseline.js
```

### Script k6 de Ejemplo

```javascript
// tests/performance/baseline.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const latency = new Trend('endpoint_latency');
const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    movies: {
      executor: 'constant-arrival-rate',
      rate: 100,
      timeUnit: '1s',
      duration: '1m',
      preAllocatedVUs: 50,
    },
  },
  thresholds: {
    endpoint_latency: ['p(95)<200'],
    errors: ['rate<0.01'],
  },
};

export default function () {
  const start = Date.now();
  const res = http.get('http://localhost:8000/movies');
  latency.add(Date.now() - start);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
  }) || errorRate.add(1);
}
```

### Medir con curl

```bash
# Latencia simple
for i in {1..10}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:8000/movies
done | awk '{sum+=$1} END {print "avg:", sum/NR}'

# Con timestamps
curl -w "@-" -o /dev/null -s http://localhost:8082/booking << 'EOF'
time_namelookup: %{time_namelookup}s
time_connect: %{time_connect}s
time_appconnect: %{time_appconnect}s
time_pretransfer: %{time_pretransfer}s
time_redirect: %{time_redirect}s
time_starttransfer: %{time_starttransfer}s
time_total: %{time_total}s
EOF
```

### Medir con hey

```bash
# Instalar hey
go install github.com/rakyll/hey@latest

# Test rapido
hey -n 1000 -c 50 http://localhost:8000/movies
```

---

## Alertas Recomendadas

### Latencia

| Metrica | Warning | Critical |
|---------|---------|----------|
| p95 booking | > 400ms | > 800ms |
| p95 otros | > 150ms | > 300ms |
| p99 cualquier | > 500ms | > 1s |

### Error Rate

| Metrica | Warning | Critical |
|---------|---------|----------|
| 5xx rate | > 0.1% | > 1% |
| 4xx rate | > 5% | > 10% |

### Recursos

| Metrica | Warning | Critical |
|---------|---------|----------|
| CPU por servicio | > 70% | > 90% |
| Memory por servicio | > 200 MB | > 500 MB |
| MongoDB CPU | > 60% | > 80% |
| Redis memory | > 80% max | > 95% max |

### Throughput

| Metrica | Warning | Critical |
|---------|---------|----------|
| RPS drop | > 20% baseline | > 50% baseline |
| Queue depth NATS | > 1000 | > 5000 |

---

## Optimizaciones Aplicadas

1. **Connection pooling**: MongoDB y Redis usan pools configurados
2. **Indices MongoDB**: Indices en campos frecuentemente consultados
3. **Redis pipelining**: Operaciones batch donde aplica
4. **HTTP keepalive**: Conexiones persistentes entre servicios
5. **JSON streaming**: Uso de `json.Encoder` para respuestas grandes

---

## Proximos Pasos

1. Implementar distributed tracing con Jaeger
2. Agregar metricas Prometheus por servicio
3. Dashboard Grafana con baselines
4. Load testing automatizado en CI
