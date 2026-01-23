package models

// Payment ...
type Payment struct {
	UserName    string `json:"userName"`
	Currency    string `json:"currency"`
	Number      string `json:"number"`
	Cvc         string `json:"cvc"`
	ExpMonth    string `json:"exp_month"`
	ExpYear     string `json:"exp_year"`
	Amount      int64  `json:"amount"`
	Description string `json:"description"`
}
