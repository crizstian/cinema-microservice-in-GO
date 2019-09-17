package server

import (
	"os"
	"strconv"
	"cinemas-microservices/movie-service/src/api"
	"cinemas-microservices/movie-service/src/routes"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
	log "github.com/sirupsen/logrus"
)

func init() {
	// Log as JSON instead of the default ASCII formatter.
	// log.SetFormatter(&log.JSONFormatter{})

	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)

	// Only log the warning severity or above.
	log.SetLevel(log.InfoLevel)
}

// Start ...
func Start(r map[string]interface{}) {

	e := echo.New()

	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: "method=${method}, uri=${uri}, status=${status}\n",
	}))
	e.Use(middleware.Recover())

	app := e.Group("/movies")

	routes.API(app, r["repo"].(api.Repository))
	routes.HealthyAPI(e)

	// start server
	e.Logger.Fatal(e.Start(":" + strconv.Itoa(r["port"].(int))))
}
