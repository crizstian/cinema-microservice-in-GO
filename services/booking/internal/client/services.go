package client

import (
	"context"
	"net/http"
	"time"
)

var basePaymentURL string
var baseNotificationURL string

// Operations ...
type Operations struct {
	Client *Client
}

// Services ...
type Services interface {
	PaymentWall(createRequest interface{}) (interface{}, error)
	NotificationWall(createRequest interface{}) (interface{}, error)
	SetBasePaymentURL(url string)
	SetNotificationURL(url string)
	GetBasePaymentURL() string
	GetNotificationURL() string
}

// PaymentWall ...
func (o Operations) PaymentWall(createRequest interface{}) (interface{}, error) {
	// Timeout de 5 segundos para evitar bloqueos en payment service
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	url := basePaymentURL + "/payment/makePurchase"

	req, err := o.Client.NewRequest(ctx, http.MethodPost, url, createRequest)
	paymentResponse := new(map[string]interface{})

	if err != nil {
		return nil, err
	}

	return paymentResponse, o.Client.Do(ctx, req, paymentResponse)
}

// NotificationWall ...
func (o Operations) NotificationWall(createRequest interface{}) (interface{}, error) {
	// Timeout de 3 segundos para notificaciones (pueden ser asíncronas)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	url := baseNotificationURL + "/notification/sendEmail"

	req, err := o.Client.NewRequest(ctx, http.MethodPost, url, createRequest)
	nr := new(map[string]interface{})

	if err != nil {
		return nil, err
	}

	return nr, o.Client.Do(ctx, req, nr)
}

// SetBasePaymentURL ...
func (o Operations) SetBasePaymentURL(url string) {
	basePaymentURL = url
}

// SetNotificationURL ...
func (o Operations) SetNotificationURL(url string) {
	baseNotificationURL = url
}

// GetBasePaymentURL ...
func (o Operations) GetBasePaymentURL() string {
	return basePaymentURL
}

// GetNotificationURL ...
func (o Operations) GetNotificationURL() string {
	return baseNotificationURL
}
