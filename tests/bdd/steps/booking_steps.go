package steps

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/cucumber/godog"
)

// Booking Step Definitions

func (tc *TestContext) navegoElCatalogoDePeliculas() error {
	if err := tc.get("movie", "/movies"); err != nil {
		return err
	}

	if tc.lastResponse.StatusCode != 200 {
		return fmt.Errorf("failed to get movies: %d", tc.lastResponse.StatusCode)
	}

	// Extract first movie ID
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	if movies, ok := result["movies"].([]interface{}); ok && len(movies) > 0 {
		if movie, ok := movies[0].(map[string]interface{}); ok {
			tc.movieID = movie["id"].(string)
		}
	}

	if tc.movieID == "" {
		tc.movieID = "mov_shawshank" // fallback
	}

	return nil
}

func (tc *TestContext) seleccionoLaFuncion(showtimeID string) error {
	tc.showtimeID = showtimeID
	return nil
}

func (tc *TestContext) veoElMapaDeAsientos() error {
	path := fmt.Sprintf("/seats/availability?showtime_id=%s", tc.showtimeID)
	return tc.get("seat", path)
}

func (tc *TestContext) deberiaVerAsientosDisponibles() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	seats, ok := result["seats"].([]interface{})
	if !ok || len(seats) == 0 {
		return fmt.Errorf("no seats found in response")
	}

	availableCount := 0
	for _, seat := range seats {
		if seatMap, ok := seat.(map[string]interface{}); ok {
			if status, ok := seatMap["status"].(string); ok && status == "available" {
				availableCount++
			}
		}
	}

	if availableCount == 0 {
		return fmt.Errorf("no available seats found")
	}

	return nil
}

func (tc *TestContext) reservoTemporalmenteLosAsientosConSesion(seats, sessionID string) error {
	tc.seats = strings.Split(seats, ",")
	tc.sessionID = sessionID

	payload := map[string]interface{}{
		"showtime_id": tc.showtimeID,
		"seat_ids":    tc.seats,
		"session_id":  sessionID,
	}

	return tc.post("seat", "/seats/hold", payload)
}

func (tc *TestContext) deberiaRecibirUnaConfirmacionDeHoldConTTL() error {
	if tc.lastResponse.StatusCode != 201 {
		return fmt.Errorf("expected 201, got %d: %s", tc.lastResponse.StatusCode, string(tc.lastBody))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	holdID, ok := result["hold_id"].(string)
	if !ok || holdID == "" {
		return fmt.Errorf("no hold_id in response")
	}
	tc.holdID = holdID

	if _, ok := result["expires_at"]; !ok {
		return fmt.Errorf("no expires_at in response")
	}

	return nil
}

func (tc *TestContext) creoUnaReservaConLosSiguientesDatos(table *godog.Table) error {
	// Parse table into nested structure
	user := map[string]interface{}{
		"creditCard": map[string]interface{}{},
	}
	booking := map[string]interface{}{
		"showtime_id": tc.showtimeID,
		"hold_id":     tc.holdID,
		"session_id":  tc.sessionID,
		"seats":       tc.seats,
	}

	for _, row := range table.Rows[1:] { // Skip header
		field := row.Cells[0].Value
		value := row.Cells[1].Value

		switch {
		case strings.HasPrefix(field, "user.creditCard."):
			key := strings.TrimPrefix(field, "user.creditCard.")
			user["creditCard"].(map[string]interface{})[key] = value
		case strings.HasPrefix(field, "user."):
			key := strings.TrimPrefix(field, "user.")
			user[key] = value
		case strings.HasPrefix(field, "booking."):
			key := strings.TrimPrefix(field, "booking.")
			if key == "totalAmount" {
				// Parse as number
				var amount float64
				fmt.Sscanf(value, "%f", &amount)
				booking[key] = amount
			} else if key == "seats" {
				booking[key] = strings.Split(value, ",")
			} else {
				booking[key] = value
			}
		}
	}

	payload := map[string]interface{}{
		"user":    user,
		"booking": booking,
	}

	return tc.post("booking", "/booking", payload)
}

func (tc *TestContext) laReservaDeberiaSerConfirmadaConCodigo(expectedCode int) error {
	return tc.deberiaRecibirCodigo(expectedCode)
}

func (tc *TestContext) deberiaRecibirUnTicketConOrderId() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	ticket, ok := result["ticket"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("no ticket in response: %s", string(tc.lastBody))
	}

	orderID, ok := ticket["order_id"].(string)
	if !ok || orderID == "" {
		return fmt.Errorf("no order_id in ticket")
	}
	tc.orderID = orderID

	return nil
}

func (tc *TestContext) deberiaRecibirUnTicketConBookingId() error {
	var result map[string]interface{}
	if err := json.Unmarshal(tc.lastBody, &result); err != nil {
		return err
	}

	ticket, ok := result["ticket"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("no ticket in response")
	}

	bookingID, ok := ticket["booking_id"].(string)
	if !ok || bookingID == "" {
		return fmt.Errorf("no booking_id in ticket")
	}
	tc.bookingID = bookingID

	return nil
}

// Register booking steps
func RegisterBookingSteps(ctx *godog.ScenarioContext, tc *TestContext) {
	// Navigation
	ctx.Step(`^navego el catálogo de películas$`, tc.navegoElCatalogoDePeliculas)
	ctx.Step(`^selecciono la función "([^"]*)"$`, tc.seleccionoLaFuncion)
	ctx.Step(`^veo el mapa de asientos$`, tc.veoElMapaDeAsientos)

	// Assertions
	ctx.Step(`^debería ver asientos disponibles$`, tc.deberiaVerAsientosDisponibles)

	// Hold seats
	ctx.Step(`^reservo temporalmente los asientos "([^"]*)" con sesión "([^"]*)"$`, tc.reservoTemporalmenteLosAsientosConSesion)
	ctx.Step(`^debería recibir una confirmación de hold con TTL$`, tc.deberiaRecibirUnaConfirmacionDeHoldConTTL)

	// Create booking
	ctx.Step(`^creo una reserva con los siguientes datos:$`, tc.creoUnaReservaConLosSiguientesDatos)
	ctx.Step(`^la reserva debería ser confirmada con código (\d+)$`, tc.laReservaDeberiaSerConfirmadaConCodigo)
	ctx.Step(`^debería recibir un ticket con order_id$`, tc.deberiaRecibirUnTicketConOrderId)
	ctx.Step(`^debería recibir un ticket con booking_id$`, tc.deberiaRecibirUnTicketConBookingId)
}
