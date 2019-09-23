package integration_test

import (
	"cinemas-microservices/payment-service/src/api"
	"cinemas-microservices/payment-service/src/config"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo"
	"github.com/stripe/stripe-go/client"

	"github.com/stretchr/testify/assert"

	"gopkg.in/mgo.v2"
)

// PaymentServiceSuit struct for Movie Service Suite
type PaymentServiceSuit struct {
	s      *mgo.Session
	db     *mgo.Database
	r      api.Repository
	stripe *client.API
}

var m = &PaymentServiceSuit{
	s:      nil,
	db:     nil,
	r:      nil,
	stripe: nil,
}

var paymentJSON = `
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

	m.stripe = d.Stripe
	assert.NotNil(t, m.stripe)
}

// SetupServer ...
func TestSetupServer(t *testing.T) {
	r, err := api.Connect(m.db, m.stripe)
	assert.NoError(t, err)
	m.r = r
}

// SetupAPI ...
func TestSetupAPI(t *testing.T) {
	// Setup
	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/payment/makePurchase", strings.NewReader(paymentJSON))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	// Assertions
	if assert.NoError(t, m.r.RegisterPurchase(c)) {
		assert.Equal(t, http.StatusCreated, rec.Code)
		// assert.Equal(t, userJSON, rec.Body.String())
	}
}

// TearDownSuite teardown at the end of test
func TestTearDownSuite(t *testing.T) {
	m.s.Close()
}
