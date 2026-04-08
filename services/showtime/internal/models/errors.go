package models

import "errors"

var (
	ErrInvalidMovieID    = errors.New("invalid movie_id")
	ErrInvalidCinemaID   = errors.New("invalid cinema_id")
	ErrInvalidRoomNumber = errors.New("room_number must be >= 1")
	ErrInvalidStartTime  = errors.New("invalid start_time")
	ErrInvalidEndTime    = errors.New("end_time must be after start_time")
	ErrInvalidPrice      = errors.New("regular price must be > 0")
	ErrInvalidSeats      = errors.New("available_seats must be >= 1")
	ErrShowtimeNotFound  = errors.New("showtime not found")
	ErrMovieNotFound     = errors.New("movie not found in movie-service")
	ErrRoomConflict      = errors.New("room is occupied at the specified time")
	ErrCannotModify      = errors.New("cannot modify completed or cancelled showtime")
)
