package steps

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/cucumber/godog"
)

// Movie Step Definitions

func (tc *TestContext) solicitoLaListaDePeliculas() error {
	return tc.get("movie", "/movies")
}

func (tc *TestContext) solicitoLosEstrenosDePeliculas() error {
	return tc.get("movie", "/movies/premieres")
}

func (tc *TestContext) solicitoLaPeliculaConId(movieID string) error {
	return tc.get("movie", "/movies/"+movieID)
}

func (tc *TestContext) laRespuestaNoDeberiatenerMoviesNull() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	movies := result["movies"]
	if movies == nil {
		return fmt.Errorf("movies is null - this indicates seed data has wrong field names (year/month/day instead of releaseYear/releaseMonth/releaseDay)")
	}

	return nil
}

func (tc *TestContext) deberiaVerAlMenosNPeliculasEnEstrenos(minCount int) error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	movies, ok := result["movies"].([]interface{})
	if !ok {
		return fmt.Errorf("movies is not an array, got: %T", result["movies"])
	}

	if len(movies) < minCount {
		return fmt.Errorf("expected at least %d movies in premieres, got %d. Body: %s",
			minCount, len(movies), string(tc.lastBody))
	}

	return nil
}

func (tc *TestContext) todasLasPeliculasDeberianTenerReleaseYearAnioActual() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	movies, ok := result["movies"].([]interface{})
	if !ok {
		return fmt.Errorf("movies is not an array")
	}

	currentYear := time.Now().Year()
	for i, m := range movies {
		movie, ok := m.(map[string]interface{})
		if !ok {
			continue
		}

		// Check for releaseYear field (correct) or warn about year field (incorrect)
		if _, hasYear := movie["year"]; hasYear {
			return fmt.Errorf("movie %d has 'year' field instead of 'releaseYear' - seed data needs fixing", i)
		}

		releaseYear, ok := movie["releaseYear"].(float64)
		if !ok {
			// Try ReleaseYear (Go struct style)
			if ry, ok := movie["ReleaseYear"].(float64); ok {
				releaseYear = ry
			} else {
				return fmt.Errorf("movie %d missing releaseYear field", i)
			}
		}

		if int(releaseYear) != currentYear {
			return fmt.Errorf("movie %d has releaseYear=%d, expected %d", i, int(releaseYear), currentYear)
		}
	}

	return nil
}

func (tc *TestContext) todasLasPeliculasDeberianTenerReleaseMontMesActual() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	movies, ok := result["movies"].([]interface{})
	if !ok {
		return fmt.Errorf("movies is not an array")
	}

	currentMonth := int(time.Now().Month())
	for i, m := range movies {
		movie, ok := m.(map[string]interface{})
		if !ok {
			continue
		}

		// Check for releaseMonth field (correct) or warn about month field (incorrect)
		if _, hasMonth := movie["month"]; hasMonth {
			return fmt.Errorf("movie %d has 'month' field instead of 'releaseMonth' - seed data needs fixing", i)
		}

		releaseMonth, ok := movie["releaseMonth"].(float64)
		if !ok {
			// Try ReleaseMonth (Go struct style)
			if rm, ok := movie["ReleaseMonth"].(float64); ok {
				releaseMonth = rm
			} else {
				return fmt.Errorf("movie %d missing releaseMonth field", i)
			}
		}

		if int(releaseMonth) != currentMonth {
			return fmt.Errorf("movie %d has releaseMonth=%d, expected %d", i, int(releaseMonth), currentMonth)
		}
	}

	return nil
}

func (tc *TestContext) deberiaVerLaPelicula(title string) error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	// Check single movie response
	if movies, ok := result["movies"].(map[string]interface{}); ok {
		if t, ok := movies["Title"].(string); ok && t == title {
			return nil
		}
		if t, ok := movies["title"].(string); ok && t == title {
			return nil
		}
	}

	// Check array response
	if movies, ok := result["movies"].([]interface{}); ok {
		for _, m := range movies {
			if movie, ok := m.(map[string]interface{}); ok {
				if t, ok := movie["title"].(string); ok && t == title {
					return nil
				}
				if t, ok := movie["Title"].(string); ok && t == title {
					return nil
				}
			}
		}
	}

	return fmt.Errorf("movie '%s' not found in response: %s", title, string(tc.lastBody))
}

func (tc *TestContext) cadaPeliculaDeberiaTenerLosCampos(table *godog.Table) error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	movies, ok := result["movies"].([]interface{})
	if !ok {
		return fmt.Errorf("movies is not an array")
	}

	requiredFields := make([]string, 0)
	for _, row := range table.Rows[1:] { // Skip header
		requiredFields = append(requiredFields, row.Cells[0].Value)
	}

	for i, m := range movies {
		movie, ok := m.(map[string]interface{})
		if !ok {
			continue
		}

		for _, field := range requiredFields {
			if _, exists := movie[field]; !exists {
				return fmt.Errorf("movie %d missing required field '%s'", i, field)
			}
		}
	}

	return nil
}

func (tc *TestContext) deberiaRecibirUnMensajeDeError() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	// Check for error field
	if _, hasError := result["error"]; hasError {
		return nil
	}
	if _, hasMsg := result["message"]; hasMsg {
		return nil
	}

	return fmt.Errorf("no error message found in response: %s", string(tc.lastBody))
}

// Register movie steps
func RegisterMovieSteps(ctx *godog.ScenarioContext, tc *TestContext) {
	// List movies
	ctx.Step(`^solicito la lista de películas$`, tc.solicitoLaListaDePeliculas)
	ctx.Step(`^solicito los estrenos de películas$`, tc.solicitoLosEstrenosDePeliculas)
	ctx.Step(`^solicito la película con id "([^"]*)"$`, tc.solicitoLaPeliculaConId)

	// Premieres assertions
	ctx.Step(`^la respuesta NO debería tener movies = null$`, tc.laRespuestaNoDeberiatenerMoviesNull)
	ctx.Step(`^debería ver al menos (\d+) películas? en estrenos$`, tc.deberiaVerAlMenosNPeliculasEnEstrenos)
	ctx.Step(`^todas las películas deberían tener releaseYear = año actual$`, tc.todasLasPeliculasDeberianTenerReleaseYearAnioActual)
	ctx.Step(`^todas las películas deberían tener releaseMonth = mes actual$`, tc.todasLasPeliculasDeberianTenerReleaseMontMesActual)

	// Movie assertions
	ctx.Step(`^debería ver la película "([^"]*)"$`, tc.deberiaVerLaPelicula)
	ctx.Step(`^cada película debería tener los campos:$`, tc.cadaPeliculaDeberiaTenerLosCampos)
	ctx.Step(`^debería recibir un mensaje de error$`, tc.deberiaRecibirUnMensajeDeError)
}
