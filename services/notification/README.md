# Notification Service

Servicio de envío de notificaciones por email.

## Descripción

Servicio responsable de enviar notificaciones por correo electrónico a usuarios.

## Estructura

```
notification/
├── cmd/
│   └── notification/
│       └── main.go
├── internal/
│   ├── api/
│   ├── models/
│   ├── smtp/               # Cliente Gmail
│   ├── config/
│   ├── routes/
│   ├── server/
│   └── errors/
├── go.mod
└── README.md
```

## Build & Run

```bash
cd services/notification
go build -o notification ./cmd/notification
./notification
```

## Configuration

```bash
export SERVICE_PORT=8000
export EMAIL=your-email@gmail.com
export EMAIL_PASS=your-app-password
```

## API Endpoints

- `GET /` - Health check
- `POST /api/notifications` - Enviar notificación
