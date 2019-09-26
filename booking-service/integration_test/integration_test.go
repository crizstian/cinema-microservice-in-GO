package integration_test

import (
	"cinemas-microservices/booking-service/src/api"
	"cinemas-microservices/booking-service/src/config"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo"
	"github.com/stretchr/testify/assert"

	"gopkg.in/mgo.v2"
)

// BookingServiceSuit struct for Movie Service Suite
type BookingServiceSuit struct {
	s         *mgo.Session
	db        *mgo.Database
	r         api.Repository
	APIClient *config.Client
}

var m = &BookingServiceSuit{
	s:         nil,
	db:        nil,
	r:         nil,
	APIClient: nil,
}

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

var bookingRequestJSON = fmt.Sprintf(`{"user": %s, "booking": %s}`, user, booking)

// SetupSuite setup at the beginning of test
func TestSetupSuite(t *testing.T) {

	c := config.GetServiceConfig()

	assert.NotEmpty(t, c)

	di := make(chan *config.DI)
	go config.InitDI(di)

	d := <-di

	m.db = d.Database.DB
	assert.NotNil(t, m.db)

	m.s = d.Database.Session
	assert.NotNil(t, m.s)

	result := struct{ Ok int }{}
	err := m.s.Run("ping", &result)

	assert.NoError(t, err)
	assert.Equal(t, result.Ok, 1)

	m.APIClient = d.APIClient
}

// SetupServer ...
func TestSetupServer(t *testing.T) {
	r, err := api.Connect(m.db, m.APIClient)
	assert.NoError(t, err)
	m.r = r
}

// SetupAPI ...
func TestSetupAPI(t *testing.T) {
	// Setup
	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/booking/", strings.NewReader(bookingRequestJSON))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	// Assertions
	if assert.NoError(t, m.r.MakeBooking(c)) {
		assert.Equal(t, http.StatusCreated, rec.Code)
		// assert.Equal(t, userJSON, rec.Body.String())
	}

	fmt.Printf("RESPONSE \n %s", rec.Body.String())
}

// TearDownSuite teardown at the end of test
func TestTearDownSuite(t *testing.T) {
	m.s.Close()
}
