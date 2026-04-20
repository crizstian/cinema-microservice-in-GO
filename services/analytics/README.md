# Analytics Service

Cinema analytics and reporting microservice built with **Spring Boot 3.2**.

## Overview

Provides business intelligence capabilities for the cinema platform:
- Sales reports (daily, weekly, monthly)
- Top movies analytics
- Occupancy rate metrics
- Revenue by cinema location

## Tech Stack

- **Framework:** Spring Boot 3.2
- **Build:** Maven
- **Java:** 21
- **Port:** 8010

## Project Structure

```
analytics/
├── pom.xml
├── api/
│   └── openapi.yaml
└── src/
    ├── main/
    │   ├── java/dev/cinema/latam/analytics/
    │   │   ├── AnalyticsApplication.java
    │   │   ├── controller/
    │   │   │   ├── HealthController.java
    │   │   │   └── ReportsController.java
    │   │   ├── model/
    │   │   │   ├── Report.java
    │   │   │   └── ReportType.java
    │   │   └── service/
    │   │       └── ReportService.java
    │   └── resources/
    │       └── application.yml
    └── test/java/dev/cinema/latam/analytics/
        └── AnalyticsApplicationTests.java
```

## Running Locally

```bash
# From service directory
cd services/analytics
mvn spring-boot:run

# Or using Task
task java:run SERVICE=analytics
```

## Build

```bash
# Maven build
mvn clean package

# Docker build
task java:build SERVICE=analytics
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/ping` | Ping/pong |
| GET | `/api/reports` | List all reports |
| GET | `/api/reports/{id}` | Get report by ID |
| GET | `/api/reports/type/{type}` | Get reports by type |
| POST | `/api/reports/generate?type=X` | Generate new report |

### Report Types

- `DAILY_SALES` - Daily sales summary
- `WEEKLY_SALES` - Weekly sales with growth rate
- `MONTHLY_SALES` - Monthly sales overview
- `TOP_MOVIES` - Top performing movies
- `OCCUPANCY_RATE` - Theater occupancy metrics
- `REVENUE_BY_CINEMA` - Revenue breakdown by location

## Testing

```bash
mvn test
# Or
task java:test SERVICE=analytics
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | 8010 | HTTP server port |
