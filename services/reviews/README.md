# Reviews Service

Cinema reviews and ratings microservice built with **Micronaut 4.x**.

## Overview

Provides movie review and rating capabilities:
- Create, update, delete reviews
- Get reviews by movie or user
- Rating statistics per movie
- Mark reviews as helpful

## Tech Stack

- **Framework:** Micronaut 4.3
- **Build:** Gradle
- **Java:** 21
- **Port:** 8012

## Project Structure

```
reviews/
├── build.gradle
├── settings.gradle
├── gradle.properties
├── api/
│   └── openapi.yaml
└── src/
    ├── main/
    │   ├── java/dev/cinema/latam/reviews/
    │   │   ├── Application.java
    │   │   ├── controller/
    │   │   │   ├── HealthController.java
    │   │   │   └── ReviewsController.java
    │   │   ├── model/
    │   │   │   ├── Review.java
    │   │   │   ├── ReviewRequest.java
    │   │   │   └── ReviewStats.java
    │   │   └── service/
    │   │       └── ReviewService.java
    │   └── resources/
    │       └── application.yml
    └── test/java/dev/cinema/latam/reviews/
        └── ReviewsControllerTest.java
```

## Running Locally

```bash
# From service directory
cd services/reviews
./gradlew run

# Or using Task
task java:run SERVICE=reviews
```

## Build

```bash
# Gradle build
./gradlew build

# Docker build
task java:build SERVICE=reviews
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/ping` | Ping/pong |
| GET | `/api/reviews` | List all reviews |
| GET | `/api/reviews/{id}` | Get review by ID |
| POST | `/api/reviews` | Create review |
| PUT | `/api/reviews/{id}` | Update review |
| DELETE | `/api/reviews/{id}` | Delete review |
| POST | `/api/reviews/{id}/helpful` | Mark as helpful |
| GET | `/api/reviews/movie/{movieId}` | Reviews by movie |
| GET | `/api/reviews/movie/{movieId}/stats` | Movie statistics |
| GET | `/api/reviews/user/{userId}` | Reviews by user |

## Micronaut Endpoints

- `/health` - Health checks
- `/prometheus` - Prometheus metrics

## Testing

```bash
./gradlew test
# Or
task java:test SERVICE=reviews
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MICRONAUT_SERVER_PORT` | 8012 | HTTP server port |
