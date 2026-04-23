// Step 4: Seed test data
// Each service uses its own database (see platform/config/services.yaml)
print("Step 4: Seeding test data...");

// =======================================================================
// Movie service database: movie
// =======================================================================
db = db.getSiblingDB("movie");

db.movies.insertMany([
  {
    _id: ObjectId("507f1f77bcf86cd799439011"),
    id: "mov_shawshank",
    title: "The Shawshank Redemption",
    director: "Frank Darabont",
    duration: 142,
    genre: ["Drama"],
    rating: "R",
    synopsis: "Two imprisoned men bond over a number of years.",
    premiere_date: new Date("1994-09-23"),
    year: 2024,
    month: 4,
    day: 1
  },
  {
    _id: ObjectId("507f1f77bcf86cd799439012"),
    id: "mov_inception",
    title: "Inception",
    director: "Christopher Nolan",
    duration: 148,
    genre: ["Sci-Fi", "Thriller"],
    rating: "PG-13",
    synopsis: "A thief who steals corporate secrets through dream-sharing.",
    premiere_date: new Date("2010-07-16"),
    year: 2024,
    month: 4,
    day: 1
  }
]);

print("Seeded 'movie' database: 2 movies");

// =======================================================================
// Cinema service database: cinema
// =======================================================================
db = db.getSiblingDB("cinema");

db.cinemas.insertOne({
  _id: ObjectId("507f1f77bcf86cd799439022"),
  name: "Cinema Downtown",
  address: "123 Main Street",
  city: "Test City",
  country: "Testland"
});

db.rooms.insertMany([
  {
    _id: ObjectId("507f1f77bcf86cd799439031"),
    cinema_id: ObjectId("507f1f77bcf86cd799439022"),
    name: "Room 1",
    room_number: 1,
    capacity: 100,
    type: "standard"
  },
  {
    _id: ObjectId("507f1f77bcf86cd799439032"),
    cinema_id: ObjectId("507f1f77bcf86cd799439022"),
    name: "VIP Room",
    room_number: 2,
    capacity: 50,
    type: "vip"
  }
]);

print("Seeded 'cinema' database: 1 cinema, 2 rooms");

// =======================================================================
// Showtime service database: showtime
// =======================================================================
db = db.getSiblingDB("showtime");

var tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
tomorrow.setHours(19, 0, 0, 0);

var endTime = new Date(tomorrow);
endTime.setHours(21, 30, 0, 0);

db.showtimes.insertMany([
  {
    _id: "sht_001",
    showtime_id: "sht_001",
    movie_id: "mov_shawshank",
    cinema_id: "507f1f77bcf86cd799439022",
    room_id: "room_001",
    room_number: 1,
    start_time: tomorrow,
    end_time: endTime,
    price: { regular: 1200, vip: 2000, child: 800 },
    available_seats: 100,
    status: "scheduled",
    created_at: new Date(),
    updated_at: new Date()
  },
  {
    _id: "sht_002",
    showtime_id: "sht_002",
    movie_id: "mov_inception",
    cinema_id: "507f1f77bcf86cd799439022",
    room_id: "room_001",
    room_number: 1,
    start_time: new Date(tomorrow.getTime() + 3 * 60 * 60 * 1000),
    end_time: new Date(tomorrow.getTime() + 5.5 * 60 * 60 * 1000),
    price: { regular: 1500, vip: 2500, child: 1000 },
    available_seats: 100,
    status: "scheduled",
    created_at: new Date(),
    updated_at: new Date()
  }
]);

print("Seeded 'showtime' database: 2 showtimes");

// =======================================================================
// User service database: user
// =======================================================================
db = db.getSiblingDB("user");

// Note: No pre-seeded users - let users register fresh to avoid password hash issues
// bcrypt hashes cannot be reliably generated in mongosh

print("Seeded 'user' database: 0 users (register via API)");

// =======================================================================
// Seat service database: seat
// =======================================================================
db = db.getSiblingDB("seat");

db.reservations.drop();
print("Cleaned up previous reservations");

var room1Seats = [];
var rowLabels = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"];
for (var r = 0; r < 10; r++) {
  for (var s = 1; s <= 10; s++) {
    var seatType = "regular";
    var priceModifier = 1.0;

    if (r < 2) {
      seatType = "vip";
      priceModifier = 1.5;
    }
    if (r === 9 && s <= 2) {
      seatType = "wheelchair";
      priceModifier = 1.0;
    }

    room1Seats.push({
      id: rowLabels[r] + s,
      row: rowLabels[r],
      number: s,
      type: seatType,
      price_modifier: priceModifier
    });
  }
}

db.room_layouts.insertOne({
  room_id: "room_001",
  name: "Room 1",
  rows: 10,
  columns: 10,
  seats: room1Seats,
  created_at: new Date(),
  updated_at: new Date()
});

db.showtimes.insertMany([
  {
    showtime_id: "sht_001",
    room_id: "room_001"
  },
  {
    showtime_id: "sht_002",
    room_id: "room_001"
  }
]);

print("Seeded 'seat' database: 1 room layout (100 seats), 2 showtime mappings");

// =======================================================================
// Summary
// =======================================================================
print("");
print("=== Seed Summary ===");
print("movie:    2 movies");
print("cinema:   1 cinema, 2 rooms");
print("showtime: 2 showtimes");
print("user:     0 users (register via API)");
print("seat:     1 room layout, 2 showtime mappings");
