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

// CreditCard ...
type CreditCard struct {
	Number   string `json:"number"`
	Cvc      string `json:"cvc"`
	ExpMonth string `json:"exp_month"`
	ExpYear  string `json:"exp_year"`
}

// UserMember ...
type UserMember struct {
	Name        string     `json:"name"`
	LastName    string     `json:"lastName"`
	Email       string     `json:"email"`
	PhoneNumber string     `json:"phoneNumber"`
	CreditCard  CreditCard `json:"creditCard"`
	Membership  string     `json:"membership"`
}

// BookingRequest ...
type BookingRequest struct {
	User    UserMember `json:"user"`
	Booking Booking    `json:"booking"`
}

// Payment ...
type Payment struct {
	UserName    string `json:"userName"`
	Currency    string `json:"currency"`
	Number      string `json:"number"`
	Cvc         string `json:"cvc"`
	ExpMonth    string `json:"exp_month"`
	ExpYear     string `json:"exp_year"`
	Amount      int    `json:"amount"`
	Description string `json:"description"`
}
