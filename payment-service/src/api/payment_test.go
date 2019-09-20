package api

var userJSON = `
{
	"userName": "Cristian Ramirez",
	"currency": "mxn",
	"number": "4242424242424242",
	"cvc": "123",
	"exp_month": "12",
	"exp_year": "2019",
	"amount": 71,
	"description": "Tickect(s) for movie 'Assasins Creed', with seat(s) 47, 48 at time 8 / feb / 17"
}
`

// func TestRoot(t *testing.T) {
// 	// Setup
// 	e := echo.New()
// 	req := httptest.NewRequest(http.MethodPost, "/payment/root", strings.NewReader(userJSON))
// 	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
// 	rec := httptest.NewRecorder()
// 	c := e.NewContext(req, rec)

// 	// Assertions
// 	if assert.NoError(t, Root(c)) {
// 		assert.Equal(t, http.StatusCreated, rec.Code)
// 		// assert.Equal(t, userJSON, rec.Body.String())
// 	}
// }
