package server

import (
	"cinemas/services/cinema/internal/api"
	"cinemas/services/cinema/internal/routes"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"go.mongodb.org/mongo-driver/mongo"
)

// New creates and configures a new Echo server.
func New(db *mongo.Database) *echo.Echo {
	e := echo.New()
	e.HideBanner = true

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	handler := api.NewHandler(db)
	routes.Setup(e, handler)

	return e
}
