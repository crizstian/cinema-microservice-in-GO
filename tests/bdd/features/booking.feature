# language: es
Característica: Flujo Completo de Reserva de Cine
  Como cliente del cine
  Quiero reservar asientos para una función
  Para asegurar mi lugar en la película que deseo ver

  Antecedentes:
    Dado que el sistema de cine está funcionando
    Y existen las siguientes películas:
      | id            | title                    | releaseYear | releaseMonth | releaseDay |
      | mov_shawshank | The Shawshank Redemption | 2026        | 4            | 26         |
      | mov_inception | Inception                | 2026        | 4            | 25         |
    Y existen las siguientes funciones:
      | id      | movie_id      | cinema_id | room  | start_time          | price |
      | sht_001 | mov_shawshank | cin_001   | Sala1 | 2026-04-26T19:00:00 | 120   |
      | sht_002 | mov_inception | cin_001   | Sala2 | 2026-04-26T21:00:00 | 120   |

  @smoke @booking
  Escenario: Reserva completa con pago exitoso
    Dado que soy un usuario registrado con email "e2e_test@cinema.local"

    Cuando navego el catálogo de películas
    Entonces debería ver al menos 1 película

    Cuando selecciono la función "sht_001"
    Y veo el mapa de asientos
    Entonces debería ver asientos disponibles

    Cuando reservo temporalmente los asientos "A5,A6" con sesión "sess_e2e_001"
    Entonces debería recibir una confirmación de hold con TTL

    Cuando creo una reserva con los siguientes datos:
      | campo                  | valor             |
      | user.name              | E2E Test User     |
      | user.lastName          | Automation        |
      | user.email             | e2e_test@cinema.local |
      | user.phoneNumber       | +52 55 1234 5678  |
      | user.creditCard.number | 4242424242424242  |
      | user.creditCard.cvc    | 123               |
      | user.creditCard.exp_month | 12             |
      | user.creditCard.exp_year  | 2027           |
      | booking.totalAmount    | 240               |
      | booking.seats          | A5,A6             |
    Entonces la reserva debería ser confirmada con código 201
    Y debería recibir un ticket con order_id
    Y debería recibir un ticket con booking_id

  @booking @payment
  Escenario: Pago rechazado por tarjeta inválida
    Dado que soy un usuario registrado con email "e2e_test@cinema.local"
    Y he reservado temporalmente los asientos "B1,B2" para la función "sht_001"

    Cuando creo una reserva con tarjeta inválida "4000000000000002"
    Entonces debería recibir un error de pago
    Y los asientos "B1,B2" deberían seguir en hold

  @booking @seats
  Escenario: Conflicto al intentar reservar asientos ocupados
    Dado que el usuario "user_a@test.com" tiene un hold en asientos "C1,C2" para función "sht_001"

    Cuando el usuario "user_b@test.com" intenta reservar los asientos "C1,C2"
    Entonces debería recibir un error 409 de conflicto
    Y el mensaje debería indicar que los asientos no están disponibles

  @booking @expiration
  Escenario: Hold expira después del TTL
    Dado que el TTL de hold está configurado a 5 segundos
    Y he reservado temporalmente los asientos "D1,D2" para la función "sht_001"

    Cuando espero 6 segundos
    Y verifico la disponibilidad de asientos
    Entonces los asientos "D1,D2" deberían estar disponibles nuevamente

  @booking @verification
  Escenario: Verificar reserva existente
    Dado que tengo una reserva confirmada con order_id "ord_12345"

    Cuando consulto mi reserva
    Entonces debería ver los detalles del ticket
    Y debería ver el estado "confirmed"
