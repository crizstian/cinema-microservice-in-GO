package api

import (
	"fmt"
)

var user = `{
	"name": "Cristian",
	"lastName": "Ramirez",
	"email": "cristiano.rosetti@gmail.com",
	"creditCard": {
		"number": "4242424242424242",
		"cvc": "123",
		"exp_month": "12",
		"exp_year": "2019"
	},
	"membership": "7777888899990000"
}`

var booking = `{
	"city": "Morelia",
	"cinema": "Plaza Morelia",
	"movie": {
		"title": "Assasins Creed",
		"format": "IMAX"
	},
	"schedule": "1569600200785",
	"cinemaRoom": 7,
	"seats": ["45"],
	"totalAmount": 71
}`

var br = fmt.Sprintf(`{"user": %s, "booking": %s}`, user, booking)

// func TestRoot(t *testing.T) {

// 	// Setup
// 	e := echo.New()
// 	req := httptest.NewRequest(http.MethodPost, "/booking/", strings.NewReader(br))
// 	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
// 	rec := httptest.NewRecorder()
// 	c := e.NewContext(req, rec)
// 	a := new(API)

// 	// Assertions
// 	if assert.NoError(t, a.MakeBooking(c)) {
// 		assert.Equal(t, http.StatusCreated, rec.Code)
// 		// assert.Equal(t, userJSON, rec.Body.String())
// 	}
// }
