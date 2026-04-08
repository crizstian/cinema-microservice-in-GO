package models

// Movie ...
type Movie struct {
	ID           string   `json:"id" bson:"id"`
	Title        string   `json:"title" bson:"title"`
	Runtime      string   `json:"runtime,omitempty" bson:"runtime,omitempty"`
	Format       string   `json:"format,omitempty" bson:"format,omitempty"`
	Plot         string   `json:"plot,omitempty" bson:"plot,omitempty"`
	ReleaseYear  int      `json:"release_year,omitempty" bson:"year,omitempty"`
	ReleaseMonth int      `json:"release_month,omitempty" bson:"month,omitempty"`
	ReleaseDay   int      `json:"release_day,omitempty" bson:"day,omitempty"`
	Director     string   `json:"director,omitempty" bson:"director,omitempty"`
	Genres       []string `json:"genres,omitempty" bson:"genre,omitempty"`
	Duration     int      `json:"duration,omitempty" bson:"duration,omitempty"`
	Rating       string   `json:"rating,omitempty" bson:"rating,omitempty"`
	Synopsis     string   `json:"synopsis,omitempty" bson:"synopsis,omitempty"`
}
