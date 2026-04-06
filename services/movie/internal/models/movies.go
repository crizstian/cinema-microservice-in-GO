package models

// Movie ...
type Movie struct {
	ID           string `bson:"_id"`
	Title        string
	Runtime      string
	Format       string
	Plot         string
	ReleaseYear  int `bson:"year"`
	ReleaseMonth int `bson:"month"`
	ReleaseDay   int `bson:"day"`
	Director     string
	Genres       []string
}
