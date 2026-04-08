package models

import "errors"

var (
	ErrNameRequired      = errors.New("name is required")
	ErrAddressRequired   = errors.New("address is required")
	ErrCityRequired      = errors.New("city is required")
	ErrCountryRequired   = errors.New("country is required")
	ErrRoomNumberInvalid = errors.New("room_number must be greater than 0")
	ErrCapacityInvalid   = errors.New("capacity must be greater than 0")
	ErrRoomTypeInvalid   = errors.New("invalid room type")
	ErrCinemaNotFound    = errors.New("cinema not found")
	ErrRoomNotFound      = errors.New("room not found")
)
