package models

// Cinema ...
type Cinema struct {
	Name  string `json:"name"`
	Room  string `json:"room"`
	Seats string `json:"seats"`
}

// Movie ...
type Movie struct {
	Title    string `json:"title"`
	Format   string `json:"format"`
	Schedule string `json:"schedule"`
}

// User ...
type User struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

// Notification ...
type Notification struct {
	City        string `json:"city"`
	UserType    string `json:"userType"`
	TotalAmount int    `json:"totalAmount"`
	Cinema      Cinema `json:"cinema"`
	Movie       Movie  `json:"movie"`
	OrderID     string `json:"orderId"`
	Description string `json:"description"`
	User        User   `json:"user"`
}
