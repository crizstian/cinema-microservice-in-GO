# language: es
Característica: Gestión de Asientos
  Como cliente del cine
  Quiero ver y reservar asientos
  Para asegurar los mejores lugares

  Antecedentes:
    Dado que el sistema de cine está funcionando
    Y existe la función "sht_001" con los siguientes asientos:
      | seat_id | row | number | status    | price |
      | A1      | A   | 1      | available | 120   |
      | A2      | A   | 2      | available | 120   |
      | A3      | A   | 3      | available | 120   |
      | A4      | A   | 4      | reserved  | 120   |
      | A5      | A   | 5      | available | 120   |

  @smoke @seats
  Escenario: Ver disponibilidad de asientos
    Cuando solicito la disponibilidad de asientos para función "sht_001"
    Entonces debería recibir código 200
    Y debería ver al menos 4 asientos disponibles
    Y el asiento "A4" debería estar reservado

  @seats @hold
  Escenario: Reservar asientos temporalmente (hold)
    Cuando reservo temporalmente los asientos "A1,A2" con sesión "sess_test_001"
    Entonces debería recibir código 201
    Y debería recibir un hold_id
    Y debería recibir expires_at con TTL válido

    Cuando solicito la disponibilidad de asientos para función "sht_001"
    Entonces el asiento "A1" debería estar en hold
    Y el asiento "A2" debería estar en hold

  @seats @hold @conflict
  Escenario: Conflicto al reservar asientos ya en hold
    Dado que la sesión "sess_other" tiene hold en asientos "A3"

    Cuando reservo temporalmente los asientos "A3" con sesión "sess_test_002"
    Entonces debería recibir código 409
    Y el mensaje debería indicar conflicto de asientos

  @seats @hold @release
  Escenario: Liberar hold manualmente
    Dado que tengo un hold con id "hold_123" para asientos "A5"

    Cuando libero el hold "hold_123"
    Entonces debería recibir código 200
    Y el asiento "A5" debería estar disponible

  @seats @hold @expiration
  Escenario: Hold expira automáticamente por TTL (Redis)
    Dado que el TTL de hold está configurado a 5 segundos
    Y he reservado temporalmente los asientos "A1" con sesión "sess_ttl_test"

    Cuando espero 6 segundos
    Entonces el asiento "A1" debería estar disponible
    Y la key de Redis "seat:hold:sht_001:A1" no debería existir

  @seats @concurrent
  Escenario: Prevención de race condition en holds concurrentes
    Cuando 2 usuarios intentan reservar el asiento "A5" simultáneamente
    Entonces solo 1 debería obtener el hold
    Y el otro debería recibir código 409

  @seats @validation
  Escenario: Validar asientos antes de confirmar
    Dado que tengo un hold en asientos "A1,A2" con hold_id "hold_456"

    Cuando confirmo los asientos con hold_id "hold_456"
    Entonces los asientos "A1,A2" deberían cambiar a estado "reserved"
    Y el hold debería ser eliminado de Redis
