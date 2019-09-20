package integration_test

import (
	"cinemas-microservices/payment-service/src/api"
	"testing"

	"gopkg.in/mgo.v2"
)

// PaymentServiceSuit struct for Movie Service Suite
type PaymentServiceSuit struct {
	s  *mgo.Session
	db *mgo.Database
	r  api.Repository
}

var m = &PaymentServiceSuit{
	s:  nil,
	db: nil,
	r:  nil,
}

// SetupSuite setup at the beginning of test
func TestSetupSuite(t *testing.T) {

	// conn := make(chan *db.MongoConnection)

	// go db.MongoDB(conn)

	// session := <-conn

	// assert.NoError(t, session.Err)

	// result := struct{ Ok int }{}
	// err := session.Session.Run("ping", &result)

	// assert.NoError(t, err)
	// assert.Equal(t, result.Ok, 1)

	// m.db = session.DB
	// m.s = session.Session
}

// SetupServer ...
func TestSetupServer(t *testing.T) {
	// r, err := api.Connect(m.db)
	// assert.NoError(t, err)

	// serverError := make(chan error)

	// server.Start(map[string]interface{}{
	// 	"port": 8500,
	// 	"repo": r,
	// }, serverError)

	// err = <-serverError
	// assert.NoError(t, err)
	// m.r = r
}

// SetupAPI ...
func TestSetupAPI(t *testing.T) {
	// Setup
	// e := echo.New()
	// req := httptest.NewRequest(http.MethodGet, "/", nil)
	// rec := httptest.NewRecorder()
	// c := e.NewContext(req, rec)
	// c.SetPath("/movies/:id")
	// c.SetParamNames("id")
	// c.SetParamValues("10")

	// // Assertions
	// if assert.NoError(t, m.r.GetMovieByID(c)) {
	// 	assert.Equal(t, http.StatusOK, rec.Code)
	// 	assert.Equal(t, movieJSON, strings.TrimSpace(rec.Body.String()))
	// }
}

// TearDownSuite teardown at the end of test
func TestTearDownSuite(t *testing.T) {
	m.s.Close()
}
