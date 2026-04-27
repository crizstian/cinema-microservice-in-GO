# BDD Tests con Gherkin (godog)

## Fuente de Verdad

Los archivos `.feature` en `features/` son la **fuente de verdad** para los flujos de negocio del sistema Cinema Microservices.

```
features/
├── booking.feature   # Flujo completo de reserva
├── movies.feature    # Catálogo y estrenos
└── seats.feature     # Gestión de asientos
```

## Ejecutar Tests

### Todos los tests
```bash
task test:bdd
# o
cd tests/bdd && go test -v ./...
```

### Por tags
```bash
# Solo smoke tests
GODOG_TAGS="@smoke" task test:bdd

# Solo tests de booking
GODOG_TAGS="@booking" task test:bdd

# Tests críticos
GODOG_TAGS="@critical" task test:bdd

# Excluir tests lentos
GODOG_TAGS="~@slow" task test:bdd
```

### Formato de output
```bash
# Pretty (default)
GODOG_FORMAT=pretty task test:bdd

# JUnit XML (para CI)
GODOG_FORMAT=junit task test:bdd

# Cucumber JSON
GODOG_FORMAT=cucumber task test:bdd
```

## Tags Disponibles

| Tag | Descripción |
|-----|-------------|
| `@smoke` | Tests básicos de funcionamiento |
| `@critical` | Tests de funcionalidad crítica |
| `@booking` | Tests de reservas |
| `@movies` | Tests de películas |
| `@premieres` | Tests de estrenos |
| `@seats` | Tests de asientos |
| `@payment` | Tests de pagos |
| `@expiration` | Tests de expiración TTL |
| `@concurrent` | Tests de concurrencia |

## Estructura de Escenarios

### Ejemplo: Booking completo
```gherkin
Escenario: Reserva completa con pago exitoso
  Dado que soy un usuario registrado con email "test@cinema.local"
  
  Cuando navego el catálogo de películas
  Entonces debería ver al menos 1 película
  
  Cuando selecciono la función "sht_001"
  Y veo el mapa de asientos
  Entonces debería ver asientos disponibles
  
  Cuando reservo temporalmente los asientos "A5,A6" con sesión "sess_001"
  Entonces debería recibir una confirmación de hold con TTL
  
  Cuando creo una reserva con los siguientes datos:
    | campo                  | valor            |
    | user.name              | Test User        |
    | user.creditCard.number | 4242424242424242 |
    | booking.totalAmount    | 240              |
  Entonces la reserva debería ser confirmada con código 201
```

## Agregar Nuevos Steps

1. Agregar el step en el archivo `.feature`
2. Ejecutar tests - godog mostrará el step pendiente
3. Implementar en `steps/<domain>_steps.go`
4. Registrar en la función `Register<Domain>Steps`

### Ejemplo
```go
// steps/my_steps.go
func (tc *TestContext) miNuevoStep(param string) error {
    // Implementación
    return nil
}

func RegisterMySteps(ctx *godog.ScenarioContext, tc *TestContext) {
    ctx.Step(`^mi nuevo step con "([^"]*)"$`, tc.miNuevoStep)
}
```

## CI/CD

Los BDD tests se ejecutan como parte del pipeline:

```yaml
# En CI-Unified-v3
- step:
    name: BDD Tests
    spec:
      command: |
        cd tests/bdd
        go test -v ./... 2>&1 | tee bdd-results.txt
```

## Beneficios de Gherkin como Source of Truth

1. **Legible por negocio**: Stakeholders pueden validar escenarios
2. **Sincronizado**: Tests y documentación son lo mismo
3. **Ejecutable**: No hay drift entre docs y realidad
4. **Ejemplos válidos**: Los datos en features son datos de prueba reales
