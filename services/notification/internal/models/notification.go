package models

// Movie ...
type Movie struct {
	Title   string `json:"title"`
	Formtat string `json:"format"`
}

// Booking ...
type Booking struct {
	UserType    string   `json:"userType"`
	City        string   `json:"city"`
	Cinema      string   `json:"cinema"`
	Schedule    string   `json:"schedule"`
	Movie       Movie    `json:"movie"`
	CinemaRoom  int      `json:"cinemaRoom"`
	Seats       []string `json:"seats"`
	TotalAmount int      `json:"totalAmount"`
}

// Ticket ...
type Ticket struct {
	Booking     Booking `json:"booking"`
	OrderID     string  `json:"orderId"`
	Description string  `json:"description"`
	ReceiptURL  string  `json:"receipt_url"`
	UserName    string  `json:"userName"`
	Email       string  `json:"email"`
}
