# Loyalty Service

Cinema loyalty and rewards microservice built with **Quarkus 3.x**.

## Overview

Provides a points-based loyalty program for cinema customers:
- Create loyalty accounts
- Earn points on ticket purchases
- Redeem points for rewards
- Tier-based multipliers

## Tech Stack

- **Framework:** Quarkus 3.8
- **Build:** Maven
- **Java:** 21
- **Port:** 8011

## Loyalty Tiers

| Tier | Min Points | Multiplier |
|------|------------|------------|
| Bronze | 0 | 1.0x |
| Silver | 1,000 | 1.25x |
| Gold | 5,000 | 1.5x |
| Platinum | 15,000 | 2.0x |

## Project Structure

```
loyalty/
├── pom.xml
├── api/
│   └── openapi.yaml
└── src/
    ├── main/
    │   ├── java/dev/cinema/latam/loyalty/
    │   │   ├── resource/
    │   │   │   ├── HealthResource.java
    │   │   │   └── PointsResource.java
    │   │   ├── model/
    │   │   │   ├── LoyaltyAccount.java
    │   │   │   ├── LoyaltyTier.java
    │   │   │   ├── PointsTransaction.java
    │   │   │   └── TransactionType.java
    │   │   └── service/
    │   │       └── PointsService.java
    │   └── resources/
    │       └── application.properties
    └── test/java/dev/cinema/latam/loyalty/
        └── PointsResourceTest.java
```

## Running Locally

```bash
# From service directory
cd services/loyalty
mvn quarkus:dev

# Or using Task
task java:run SERVICE=loyalty
```

## Build

```bash
# Maven build
mvn clean package

# Docker build
task java:build SERVICE=loyalty
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/ping` | Ping/pong |
| GET | `/api/loyalty/accounts` | List all accounts |
| GET | `/api/loyalty/accounts/{userId}` | Get account |
| POST | `/api/loyalty/accounts/{userId}` | Create account |
| POST | `/api/loyalty/accounts/{userId}/earn` | Earn points |
| POST | `/api/loyalty/accounts/{userId}/redeem` | Redeem points |
| GET | `/api/loyalty/accounts/{userId}/transactions` | Transaction history |
| GET | `/api/loyalty/accounts/{userId}/tier` | Get tier status |

## Quarkus Endpoints

- `/q/health` - Quarkus health checks
- `/q/metrics` - Prometheus metrics

## Testing

```bash
mvn test
# Or
task java:test SERVICE=loyalty
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `QUARKUS_HTTP_PORT` | 8011 | HTTP server port |
