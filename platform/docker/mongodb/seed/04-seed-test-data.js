// Step 4: Seed test data
print("Step 4: Seeding test data...");

db = db.getSiblingDB("cinema");

// Movies - with 'id' field for movie service queries
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

// Cinema
db.cinemas.insertOne({
  _id: ObjectId("507f1f77bcf86cd799439022"),
  name: "Cinema Downtown",
  address: "123 Main Street",
  city: "Test City",
  country: "Testland"
});

// Rooms (for cinema service)
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

// Showtime (tomorrow) - with string ID for showtime service
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
    start_time: new Date(tomorrow.getTime() + 3 * 60 * 60 * 1000), // +3 hours
    end_time: new Date(tomorrow.getTime() + 5.5 * 60 * 60 * 1000),
    price: { regular: 1500, vip: 2500, child: 1000 },
    available_seats: 100,
    status: "scheduled",
    created_at: new Date(),
    updated_at: new Date()
  }
]);

// Test user
db.users.insertOne({
  _id: ObjectId("507f1f77bcf86cd799439041"),
  email: "test@example.com",
  password_hash: "$2a$10$testhashedpassword",
  name: "Test User",
  membership_type: "regular",
  created_at: new Date()
});

print("Test data seeded in 'cinema' database: 2 movies, 1 cinema, 2 rooms, 2 showtimes, 1 user");

// =======================================================================
// Seat service uses a separate database: cinema_seats
// =======================================================================
db = db.getSiblingDB("cinema_seats");

// IMPORTANT: Clean up previous test data to ensure idempotent test runs
// Drop reservations from previous runs (these cause stale seat status)
db.reservations.drop();
print("Cleaned up previous reservations");

// Room layouts for seat service
// Generate seats for Room 1 (10 rows x 10 seats = 100 seats)
var room1Seats = [];
var rowLabels = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"];
for (var r = 0; r < 10; r++) {
  for (var s = 1; s <= 10; s++) {
    var seatType = "regular";
    var priceModifier = 1.0;

    // VIP seats in rows A-B
    if (r < 2) {
      seatType = "vip";
      priceModifier = 1.5;
    }
    // Wheelchair accessible in row J, seats 1-2
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

// Also need showtime -> room mapping in cinema_seats database
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

print("Test data seeded in 'cinema_seats' database: 1 room layout (100 seats), 2 showtime mappings");
