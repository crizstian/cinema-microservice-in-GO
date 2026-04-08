package models

import (
	"errors"
	"time"
)

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

// RefundReason represents valid refund reasons for Stripe
type RefundReason string

const (
	RefundReasonDuplicate           RefundReason = "duplicate"
	RefundReasonFraudulent          RefundReason = "fraudulent"
	RefundReasonRequestedByCustomer RefundReason = "requested_by_customer"
)

// RefundRequest represents a refund request
type RefundRequest struct {
	Reason string `json:"reason"`
	Amount *int64 `json:"amount,omitempty"`
}

// RefundStatus represents the status of a refund
type RefundStatus string

const (
	RefundStatusPending   RefundStatus = "pending"
	RefundStatusSucceeded RefundStatus = "succeeded"
	RefundStatusFailed    RefundStatus = "failed"
	RefundStatusCanceled  RefundStatus = "canceled"
)

// RefundResponse represents a refund response
type RefundResponse struct {
	RefundID       string       `json:"refund_id"`
	Status         RefundStatus `json:"status"`
	AmountRefunded int64        `json:"amount_refunded"`
	ChargeID       string       `json:"charge_id"`
	Reason         string       `json:"reason"`
	CreatedAt      time.Time    `json:"created_at"`
}

// Validate validates a RefundRequest
func (r *RefundRequest) Validate() error {
	if r.Reason == "" {
		return errors.New("reason is required")
	}

	validReasons := map[string]bool{
		string(RefundReasonDuplicate):           true,
		string(RefundReasonFraudulent):          true,
		string(RefundReasonRequestedByCustomer): true,
	}

	if !validReasons[r.Reason] {
		return errors.New("invalid refund reason")
	}

	if r.Amount != nil && *r.Amount <= 0 {
		return errors.New("amount must be greater than 0")
	}

	return nil
}

// IsValidRefundReason checks if a reason is valid
func IsValidRefundReason(reason string) bool {
	switch RefundReason(reason) {
	case RefundReasonDuplicate, RefundReasonFraudulent, RefundReasonRequestedByCustomer:
		return true
	}
	return false
}
