# language: es
Característica: Catálogo de Películas
  Como cliente del cine
  Quiero ver las películas disponibles y estrenos
  Para decidir qué película ver

  Antecedentes:
    Dado que el sistema de cine está funcionando
    Y existen las siguientes películas:
      | id            | title                    | releaseYear | releaseMonth | releaseDay | genre   |
      | mov_shawshank | The Shawshank Redemption | 2026        | 4            | 26         | Drama   |
      | mov_inception | Inception                | 2026        | 4            | 25         | Sci-Fi  |
      | mov_old       | Classic Movie            | 2020        | 1            | 1          | Classic |

  @smoke @movies
  Escenario: Listar todas las películas
    Cuando solicito la lista de películas
    Entonces debería recibir código 200
    Y debería ver al menos 3 películas
    Y cada película debería tener los campos:
      | campo  |
      | id     |
      | title  |

  @movies @premieres @critical
  Escenario: Listar estrenos del mes actual
    # Este escenario valida que el seed data tenga los campos correctos:
    # releaseYear, releaseMonth, releaseDay (NO year, month, day)

    Cuando solicito los estrenos de películas
    Entonces debería recibir código 200
    Y la respuesta NO debería tener movies = null
    Y debería ver al menos 1 película en estrenos
    Y todas las películas deberían tener releaseYear = año actual
    Y todas las películas deberían tener releaseMonth = mes actual

  @movies @premieres
  Escenario: Estrenos vacíos cuando no hay películas recientes
    Dado que solo existen películas con fechas antiguas

    Cuando solicito los estrenos de películas
    Entonces debería recibir código 200
    Y debería ver 0 películas en estrenos

  @movies
  Escenario: Obtener película por ID
    Cuando solicito la película con id "mov_shawshank"
    Entonces debería recibir código 200
    Y debería ver la película "The Shawshank Redemption"

  @movies @error
  Escenario: Película no encontrada
    Cuando solicito la película con id "mov_nonexistent"
    Entonces debería recibir código 404
    Y debería recibir un mensaje de error

  @movies @search
  Escenario: Buscar películas por género
    Cuando busco películas con género "Drama"
    Entonces debería ver la película "The Shawshank Redemption"
    Y no debería ver la película "Inception"
