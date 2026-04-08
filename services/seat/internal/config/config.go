package config

import (
	"os"
)

// Config holds the service configuration
type Config struct {
	Port         string
	MongoURI     string
	MongoDB      string
	RedisAddr    string
	RedisPass    string
	RedisDB      int
}

// Load loads configuration from environment variables
func Load() *Config {
	return &Config{
		Port:      getEnv("PORT", "3004"),
		MongoURI:  getEnv("MONGO_URI", "mongodb://localhost:27017"),
		MongoDB:   getEnv("MONGO_DB", "cinema_seats"),
		RedisAddr: getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPass: getEnv("REDIS_PASS", ""),
		RedisDB:   0,
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
