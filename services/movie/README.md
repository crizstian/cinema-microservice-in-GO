# Movie Service

Servicio de gestión de películas y carteleras.

## Descripción

Servicio responsable de la gestión del catálogo de películas, horarios y disponibilidad.

## Estructura

```
movie/
├── cmd/
│   └── movie/
│       └── main.go
├── internal/
│   ├── api/
│   ├── models/
│   ├── db/
│   ├── routes/
│   ├── server/
│   └── errors/
├── go.mod
└── README.md
```

## Build & Run

```bash
cd services/movie
go build -o movie ./cmd/movie
./movie
```

## API Endpoints

- `GET /` - Health check
- `GET /api/movies` - Listar películas
- `GET /api/movies/:id` - Obtener película por ID
- `POST /api/movies` - Crear película
- `PUT /api/movies/:id` - Actualizar película
- `DELETE /api/movies/:id` - Eliminar película


de,mpo
