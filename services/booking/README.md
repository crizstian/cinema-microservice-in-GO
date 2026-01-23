# Booking Service

Servicio de gestión de reservas para el sistema de cinemas.

## Descripción

El servicio de reservas orquesta el proceso completo de booking:
1. Validación de datos de reserva
2. Procesamiento de pago (integración con payment-service)
3. Creación del ticket
4. Envío de notificación (integración con notification-service)

## Estructura

```
booking/
├── cmd/
│   └── booking/
│       └── main.go          # Punto de entrada
├── internal/
│   ├── api/                 # HTTP handlers
│   ├── service/             # Lógica de negocio
│   ├── models/              # Estructuras de datos
│   ├── db/                  # Acceso a MongoDB
│   ├── client/              # Clientes HTTP (payment, notification)
│   ├── config/              # Configuración y DI
│   ├── routes/              # Definición de rutas
│   ├── server/              # Setup de Echo
│   ├── tracing/             # Jaeger tracing
│   └── errors/              # Errores personalizados
├── go.mod
├── Dockerfile
└── README.md
```

## Build

```bash
# Desde la raíz del monorepo
cd services/booking
go build -o booking ./cmd/booking

# O usar Make desde la raíz
make build SERVICE=booking VERSION=v1.0.0
```

## Run

```bash
# Configurar variables de entorno
export DB_USER=cristian
export DB_PASS=cristianPassword2017
export DB_SERVERS=10.7.0.3:27017,10.7.0.4:27017,10.7.0.5:27017
export DB_NAME=booking
export DB_REPLICA=rs1
export SERVICE_PORT=8000
export PAYMENT_URL=http://10.7.0.7:8000
export NOTIFICATION_URL=http://10.7.0.8:8000

# Ejecutar
./booking
```

## Tests

```bash
# Unit tests
go test ./internal/...

# Integration tests
go test -tags=integration ./...
```

## API Endpoints

- `GET /` - Health check
- `POST /api/bookings` - Crear nueva reserva
- `GET /api/bookings/:id` - Obtener reserva por ID

## Dependencies

- MongoDB (replica set)
- Payment Service
- Notification Service
- Echo framework (HTTP)
- Jaeger (tracing, opcional)








demoiasda
