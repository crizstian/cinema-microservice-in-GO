package errs

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/labstack/echo"
	log "github.com/sirupsen/logrus"
)

// ERRORS CONST
const (
	ErrUsr = "user"
	ErrExt = "external"
	ErrInt = "internal"
)

// Send ...
func Send(status string, msg string, err error) *echo.HTTPError {
	m := msg
	var c int

	// Case-insensitive comparison
	switch strings.ToLower(status) {
	case "user":
		c = http.StatusBadRequest
		m += ", verify your data."
		log.Warn("An External error occured." + msg)
	case "external":
		c = http.StatusInternalServerError
		m += " Something went wrong, please contact you're administrator."
		log.Warn("An External error occured." + msg)
	case "internal":
		c = http.StatusNotAcceptable
		log.Warn("An Internal error occured." + msg)
	}

	// Include original error in message for debugging
	if err != nil {
		m = fmt.Sprintf("%s: %s", m, err.Error())
	}

	fmt.Println("-------------------------------------")
	fmt.Println("ERROR => ")
	log.Error(err)
	fmt.Println("-------------------------------------")
	fmt.Println("Sending Echo Error: " + m)
	fmt.Println("-------------------------------------")

	return echo.NewHTTPError(c, m)
}
