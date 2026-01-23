# Payment Service

Servicio de procesamiento de pagos.

## Descripción

Servicio responsable de procesar pagos a través de Stripe.

## Estructura

```
payment/
├── cmd/
│   └── payment/
│       └── main.go
├── internal/
│   ├── api/
│   ├── models/
│   ├── db/
│   ├── config/
│   ├── routes/
│   ├── server/
│   └── errors/
├── go.mod
└── README.md
```

## Build & Run

```bash
cd services/payment
go build -o payment ./cmd/payment
./payment
```

## API Endpoints

- `GET /` - Health check
- `POST /api/payments` - Procesar pago
- `GET /api/payments/:id` - Obtener estado de pago
