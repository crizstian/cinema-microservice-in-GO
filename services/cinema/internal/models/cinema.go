package models

// Location represents geographic coordinates.
type Location struct {
	Lat float64 `json:"lat" bson:"lat"`
	Lng float64 `json:"lng" bson:"lng"`
}

// Amenity represents available amenities at a cinema.
type Amenity string

const (
	AmenityParking          Amenity = "parking"
	AmenityFoodCourt        Amenity = "food_court"
	Amenity3D               Amenity = "3d"
	AmenityIMAX             Amenity = "imax"
	Amenity4DX              Amenity = "4dx"
	AmenityVIPLounge        Amenity = "vip_lounge"
	AmenityWheelchairAccess Amenity = "wheelchair_access"
	AmenityDolbyAtmos       Amenity = "dolby_atmos"
)

// RoomType represents the type of cinema room.
type RoomType string

const (
	RoomTypeStandard RoomType = "standard"
	RoomTypeVIP      RoomType = "vip"
	RoomTypeIMAX     RoomType = "imax"
	RoomType4DX      RoomType = "4dx"
)

// Cinema represents a cinema location.
type Cinema struct {
	ID        string    `json:"id" bson:"_id,omitempty"`
	Name      string    `json:"name" bson:"name"`
	Address   string    `json:"address" bson:"address"`
	City      string    `json:"city" bson:"city"`
	Country   string    `json:"country" bson:"country"`
	Location  *Location `json:"location,omitempty" bson:"location,omitempty"`
	Amenities []Amenity `json:"amenities,omitempty" bson:"amenities,omitempty"`
}

// CinemaWithRooms includes the cinema details with its rooms.
type CinemaWithRooms struct {
	Cinema `bson:",inline"`
	Rooms  []Room `json:"rooms,omitempty" bson:"rooms,omitempty"`
}

// Room represents a cinema room/screen.
type Room struct {
	ID           string   `json:"id" bson:"_id,omitempty"`
	CinemaID     string   `json:"cinema_id" bson:"cinema_id"`
	Name         string   `json:"name" bson:"name"`
	RoomNumber   int      `json:"room_number" bson:"room_number"`
	Capacity     int      `json:"capacity" bson:"capacity"`
	Type         RoomType `json:"type" bson:"type"`
	SeatLayoutID string   `json:"seat_layout_id,omitempty" bson:"seat_layout_id,omitempty"`
}

// CreateCinemaRequest is the request body for creating a cinema.
type CreateCinemaRequest struct {
	Name      string    `json:"name"`
	Address   string    `json:"address"`
	City      string    `json:"city"`
	Country   string    `json:"country"`
	Location  *Location `json:"location,omitempty"`
	Amenities []Amenity `json:"amenities,omitempty"`
}

// CreateRoomRequest is the request body for creating a room.
type CreateRoomRequest struct {
	Name         string   `json:"name"`
	RoomNumber   int      `json:"room_number"`
	Capacity     int      `json:"capacity"`
	Type         RoomType `json:"type"`
	SeatLayoutID string   `json:"seat_layout_id,omitempty"`
}

// CinemaListResponse is the response for listing cinemas.
type CinemaListResponse struct {
	Cinemas []Cinema `json:"cinemas"`
	Total   int      `json:"total"`
}

// RoomListResponse is the response for listing rooms.
type RoomListResponse struct {
	Rooms []Room `json:"rooms"`
	Total int    `json:"total"`
}

// ErrorResponse is the standard error response.
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// Validate validates CreateCinemaRequest fields.
func (r *CreateCinemaRequest) Validate() error {
	if r.Name == "" {
		return ErrNameRequired
	}
	if r.Address == "" {
		return ErrAddressRequired
	}
	if r.City == "" {
		return ErrCityRequired
	}
	if r.Country == "" {
		return ErrCountryRequired
	}
	return nil
}

// Validate validates CreateRoomRequest fields.
func (r *CreateRoomRequest) Validate() error {
	if r.Name == "" {
		return ErrNameRequired
	}
	if r.RoomNumber < 1 {
		return ErrRoomNumberInvalid
	}
	if r.Capacity < 1 {
		return ErrCapacityInvalid
	}
	if !r.Type.IsValid() {
		return ErrRoomTypeInvalid
	}
	return nil
}

// IsValid checks if the room type is valid.
func (rt RoomType) IsValid() bool {
	switch rt {
	case RoomTypeStandard, RoomTypeVIP, RoomTypeIMAX, RoomType4DX:
		return true
	}
	return false
}
