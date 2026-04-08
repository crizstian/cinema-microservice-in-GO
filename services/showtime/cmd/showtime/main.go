package main

import (
	"os"

	"cinemas/services/showtime/internal/api"
	"cinemas/services/showtime/internal/clients"
	"cinemas/services/showtime/internal/db"
	"cinemas/services/showtime/internal/routes"
	"cinemas/services/showtime/internal/server"

	"github.com/sirupsen/logrus"
)

func main() {
	if err := run(); err != nil {
		logrus.Fatal(err)
	}
}

func run() error {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3003"
	}

	// Get MongoDB configuration
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}
	mongoDB := os.Getenv("MONGO_DB")
	if mongoDB == "" {
		mongoDB = "cinema"
	}

	// Get Movie Service URL
	movieServiceURL := os.Getenv("MOVIE_SERVICE_URL")
	if movieServiceURL == "" {
		movieServiceURL = "http://localhost:8000"
	}

	srv := server.New(server.Config{Port: port})

	// Register health routes
	routes.HealthyAPI(srv.Echo)

	// Connect to MongoDB
	database, err := db.ConnectMongo(mongoURI, mongoDB)
	if err != nil {
		logrus.Warnf("Could not connect to MongoDB: %v (starting anyway)", err)
	}

	if database != nil {
		// Initialize store
		store := db.NewMongoStore(database)

		// Initialize movie client
		movieClient := clients.NewMovieClient(movieServiceURL)

		// Initialize webhook sender (no-op for now)
		webhookSender := clients.NewNoOpWebhookSender()

		// Connect API
		showtimeAPI := api.Connect(store, movieClient, webhookSender)

		// Register showtime routes
		routes.ShowtimeAPI(srv.Echo.Group("/showtimes"), showtimeAPI)

		srv.Logger.Info("Showtime API routes registered")
	} else {
		srv.Logger.Warn("Showtime API routes NOT registered (no database connection)")
	}

	srv.Logger.Info("Showtime service starting...")
	srv.Logger.Infof("Port: %s, MongoDB: %s/%s", port, mongoURI, mongoDB)

	return srv.Start()
}
