package main

import (
	"log"
	"os"

	"cinemas/services/cinema/internal/db"
	"cinemas/services/cinema/internal/server"
)

func main() {
	database, err := db.Connect()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8085"
	}

	e := server.New(database)
	log.Printf("Cinema service starting on port %s", port)
	if err := e.Start(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
