# ADR-008: Gherkin como Fuente de Verdad para Flujos de Negocio

**Estado**: Propuesto  
**Fecha**: 2026-04-26  
**Autores**: Platform Team

## Contexto

### Problema Identificado

Durante las pruebas del sistema se detectó una desincronización crítica entre:

1. **Unit Tests (Go)**: Usaban datos de seed aislados con campos correctos (`ReleaseYear`, `ReleaseMonth`, `ReleaseDay`)
2. **E2E Tests (Go)**: No cubrían todos los endpoints de negocio (faltaba `/movies/premieres`)
3. **Seed Data (MongoDB)**: Tenía campos incorrectos (`year`, `month`, `day`)
4. **Documentación (Markdown)**: Mostraba formatos de request incorrectos (`booking.payment` vs `user.creditCard`)

**Resultado**: Los tests automatizados pasaban pero las pruebas manuales fallaban.

### Raíz del Problema

No existe una **fuente de verdad única** que defina:
- Los flujos de negocio esperados
- Los formatos de request/response correctos
- Los datos de prueba válidos
- Los criterios de aceptación

## Decisión

Adoptar **Gherkin** como fuente de verdad para los flujos de negocio del sistema, implementado con **godog** (Cucumber para Go).

### Arquitectura Propuesta

```
┌─────────────────────────────────────────────────────────────────┐
│                    GHERKIN FEATURE FILES                        │
│                    (FUENTE DE VERDAD)                           │
│                                                                 │
│  tests/features/                                                │
│  ├── booking.feature      # Flujo completo de reserva          │
│  ├── movies.feature       # Catálogo y estrenos                 │
│  ├── seats.feature        # Hold, release, TTL                  │
│  └── payment.feature      # Procesamiento de pagos              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
┌───────────────┐  ┌────────────────┐  ┌────────────────┐
│  Step Defs    │  │  API Docs      │  │  Seed Data     │
│  (Go/godog)   │  │  (generated)   │  │  (validated)   │
│               │  │                │  │                │
│  Ejecutan los │  │  Swagger/OAS   │  │  Fixtures JSON │
│  tests reales │  │  from features │  │  from examples │
└───────────────┘  └────────────────┘  └────────────────┘
```

### Beneficios

| Aspecto | Antes | Después |
|---------|-------|---------|
| Documentación | Markdown manual, desactualizado | Generado desde features |
| Tests E2E | Código Go difícil de leer | Gherkin legible por negocio |
| Seed Data | Duplicado, inconsistente | Derivado de ejemplos Gherkin |
| Onboarding | Leer código para entender flujos | Leer features en lenguaje natural |
| Validación | Tests pasan, manual falla | Misma fuente para ambos |

### Estructura de Features

```gherkin
# tests/features/booking.feature
Feature: Cinema Booking Flow
  Como cliente del cine
  Quiero reservar asientos para una función
  Para asegurar mi lugar en la película

  Background:
    Given the cinema system is running
    And the following movies exist:
      | id            | title                    | releaseYear | releaseMonth | releaseDay |
      | mov_shawshank | The Shawshank Redemption | 2026        | 4            | 26         |
    And the following showtimes exist:
      | id      | movie_id      | cinema_id | start_time          |
      | sht_001 | mov_shawshank | cin_001   | 2026-04-26T19:00:00 |

  Scenario: Complete booking with payment
    Given I am a registered user with email "test@cinema.local"
    When I browse movies in the catalog
    Then I should see at least 1 movie

    When I select showtime "sht_001"
    And I view the seat map
    Then I should see available seats

    When I hold seats "A5,A6" for session "sess_123"
    Then I should receive a hold confirmation with TTL

    When I create a booking with:
      | field                  | value            |
      | user.name              | Test User        |
      | user.email             | test@cinema.local|
      | user.creditCard.number | 4242424242424242 |
      | booking.totalAmount    | 240              |
      | booking.seats          | A5,A6            |
    Then the booking should be confirmed
    And I should receive a ticket with order_id

  Scenario: Premieres show current month movies
    When I request movie premieres
    Then I should see movies with releaseYear = current year
    And I should see movies with releaseMonth = current month
```

## Implementación

### Fase 1: Setup (Sprint actual)
- [ ] Agregar godog como dependencia
- [ ] Crear estructura `tests/features/`
- [ ] Implementar feature `booking.feature`
- [ ] Step definitions básicos

### Fase 2: Migración (Siguiente sprint)
- [ ] Migrar E2E tests existentes a Gherkin
- [ ] Validar seed data contra ejemplos de features
- [ ] Generar documentación desde features

### Fase 3: CI/CD Integration
- [ ] Ejecutar features en pipeline
- [ ] Generar reportes HTML
- [ ] Fallar build si features fallan

## Alternativas Consideradas

### 1. OpenAPI como Source of Truth
- **Pros**: Estándar, genera clientes
- **Contras**: No describe flujos de negocio, solo endpoints

### 2. Mantener status quo con mejor documentación
- **Pros**: Sin cambios de tooling
- **Contras**: La documentación siempre se desactualiza

### 3. Contract Testing (Pact)
- **Pros**: Verifica contratos entre servicios
- **Contras**: No cubre flujos E2E completos

## Consecuencias

### Positivas
- Features legibles por stakeholders no técnicos
- Tests y documentación siempre sincronizados
- Ejemplos de features = datos de prueba válidos
- Onboarding más rápido para nuevos devs

### Negativas
- Curva de aprendizaje de Gherkin/godog
- Overhead de mantener step definitions
- Posible duplicación inicial durante migración

### Riesgos
- Step definitions pueden volverse frágiles si no se diseñan bien
- Gherkin verbose para escenarios muy técnicos

## Referencias

- [Cucumber/Gherkin Documentation](https://cucumber.io/docs/gherkin/)
- [godog - Cucumber for Go](https://github.com/cucumber/godog)
- [BDD Best Practices](https://cucumber.io/docs/bdd/)
- [Living Documentation](https://www.infoq.com/articles/living-documentation-bdd/)
