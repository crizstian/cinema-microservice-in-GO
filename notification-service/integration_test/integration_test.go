package integration_test

import (
	"cinemas-microservices/notification-service/src/api"
	"cinemas-microservices/notification-service/src/config"
	"cinemas-microservices/notification-service/src/smtp"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo"

	"github.com/stretchr/testify/assert"
)

// NotificationServiceSuit struct for Movie Service Suite
type NotificationServiceSuit struct {
	s *smtp.Config
	r api.Repository
}

var m = &NotificationServiceSuit{
	s: nil,
	r: nil,
}

var notificationJSON = `
{
	"city": "Morelia",
	"userType": "loyal",
	"totalAmount": 71,
	"cinema": {
		"name": "Plaza Morelia",
		"room": "1",
		"seats": "53, 54"
	},
	"movie": {
		"title": "Assasins Creed",
		"format": "IMAX",
		"schedule": "2019-09-24T16:56:38.775Z"
	},
	"orderId": "1aa90cx",
	"description": "some description",
	"user": {
		"name": "Cristian Ramirez",
		"email": "cristiano.rosetti@gmail.com"
	}
}
`

// SetupSuite setup at the beginning of test
func TestSetupSuite(t *testing.T) {

	c := config.GetServiceConfig()

	assert.NotEmpty(t, c)

	di := make(chan *config.DI)
	go config.InitDI(di)

	d := <-di

	m.s = d.SMTP
	assert.NotNil(t, m.s)
}

// SetupServer ...
func TestSetupServer(t *testing.T) {
	r, err := api.Connect(m.s)
	assert.NoError(t, err)
	m.r = r
}

// SetupAPI ...
func TestSetupAPI(t *testing.T) {
	// Setup
	e := echo.New()
	req := httptest.NewRequest(http.MethodPost, "/notification/sendEmail", strings.NewReader(notificationJSON))
	req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	// Assertions
	if assert.NoError(t, m.r.SendEmail(c)) {
		assert.Equal(t, http.StatusCreated, rec.Code)
		// assert.Equal(t, userJSON, rec.Body.String())
	}
}

// TearDownSuite teardown at the end of test
func TestTearDownSuite(t *testing.T) {
	fmt.Println("End of test")
}
