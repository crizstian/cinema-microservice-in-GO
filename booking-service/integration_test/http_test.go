package integration_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

var u = `{
	"name": "Cristian",
	"lastName": "Ramirez",
	"email": "cristiano.rosetti@gmail.com",
	"creditCard": {
		"number": "4242424242424242",
		"cvc": "123",
		"exp_month": "12",
		"exp_year": "2020"
	},
	"membership": "7777888899990000"
}`

var b = `{
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

var brJSON = fmt.Sprintf(`{"user": %s, "booking": %s}`, u, b)

var url = "http://172.20.20.11:3002/booking/"

func TestBookingEndpoint(t *testing.T) {

	fmt.Println("Booking Endpoint URL:>", url)

	var jsonStr = []byte(brJSON)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonStr))
	assert.NoError(t, err)

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	assert.NoError(t, err)

	defer resp.Body.Close()

	fmt.Println("response Status:", resp.Status)
	fmt.Println("response Headers:", resp.Header)
	body, _ := ioutil.ReadAll(resp.Body)

	var prettyJSON bytes.Buffer
	errr := json.Indent(&prettyJSON, body, "", "\t")
	assert.NoError(t, errr)

	b := string(prettyJSON.Bytes())
	log.Println("response Body:", b)

	assert.NotContains(t, "An error ocurred", b)
}
