package models

import (
	"testing"
)

func TestCreateCinemaRequest_Validate(t *testing.T) {
	tests := []struct {
		name    string
		req     CreateCinemaRequest
		wantErr error
	}{
		{
			name: "valid request",
			req: CreateCinemaRequest{
				Name:    "Cinepolis",
				Address: "Av. Insurgentes 123",
				City:    "CDMX",
				Country: "Mexico",
			},
			wantErr: nil,
		},
		{
			name: "missing name",
			req: CreateCinemaRequest{
				Address: "Av. Insurgentes 123",
				City:    "CDMX",
				Country: "Mexico",
			},
			wantErr: ErrNameRequired,
		},
		{
			name: "missing address",
			req: CreateCinemaRequest{
				Name:    "Cinepolis",
				City:    "CDMX",
				Country: "Mexico",
			},
			wantErr: ErrAddressRequired,
		},
		{
			name: "missing city",
			req: CreateCinemaRequest{
				Name:    "Cinepolis",
				Address: "Av. Insurgentes 123",
				Country: "Mexico",
			},
			wantErr: ErrCityRequired,
		},
		{
			name: "missing country",
			req: CreateCinemaRequest{
				Name:    "Cinepolis",
				Address: "Av. Insurgentes 123",
				City:    "CDMX",
			},
			wantErr: ErrCountryRequired,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.req.Validate()
			if err != tt.wantErr {
				t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestCreateRoomRequest_Validate(t *testing.T) {
	tests := []struct {
		name    string
		req     CreateRoomRequest
		wantErr error
	}{
		{
			name: "valid request",
			req: CreateRoomRequest{
				Name:       "Sala 1",
				RoomNumber: 1,
				Capacity:   150,
				Type:       RoomTypeStandard,
			},
			wantErr: nil,
		},
		{
			name: "missing name",
			req: CreateRoomRequest{
				RoomNumber: 1,
				Capacity:   150,
				Type:       RoomTypeStandard,
			},
			wantErr: ErrNameRequired,
		},
		{
			name: "invalid room number",
			req: CreateRoomRequest{
				Name:       "Sala 1",
				RoomNumber: 0,
				Capacity:   150,
				Type:       RoomTypeStandard,
			},
			wantErr: ErrRoomNumberInvalid,
		},
		{
			name: "invalid capacity",
			req: CreateRoomRequest{
				Name:       "Sala 1",
				RoomNumber: 1,
				Capacity:   0,
				Type:       RoomTypeStandard,
			},
			wantErr: ErrCapacityInvalid,
		},
		{
			name: "invalid room type",
			req: CreateRoomRequest{
				Name:       "Sala 1",
				RoomNumber: 1,
				Capacity:   150,
				Type:       "invalid",
			},
			wantErr: ErrRoomTypeInvalid,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.req.Validate()
			if err != tt.wantErr {
				t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestRoomType_IsValid(t *testing.T) {
	tests := []struct {
		rt   RoomType
		want bool
	}{
		{RoomTypeStandard, true},
		{RoomTypeVIP, true},
		{RoomTypeIMAX, true},
		{RoomType4DX, true},
		{RoomType("invalid"), false},
		{RoomType(""), false},
	}

	for _, tt := range tests {
		t.Run(string(tt.rt), func(t *testing.T) {
			if got := tt.rt.IsValid(); got != tt.want {
				t.Errorf("IsValid() = %v, want %v", got, tt.want)
			}
		})
	}
}
