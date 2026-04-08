// Step 3: Create indexes
print("Step 3: Creating indexes...");

db = db.getSiblingDB("cinema");

// Movies
db.movies.createIndex({ title: 1 });
db.movies.createIndex({ premiere_date: 1 });

// Users
db.users.createIndex({ email: 1 }, { unique: true });

// Bookings
db.bookings.createIndex({ order_id: 1 }, { unique: true });
db.bookings.createIndex({ user_id: 1 });

// Showtimes
db.showtimes.createIndex({ movie_id: 1, date: 1 });
db.showtimes.createIndex({ cinema_id: 1, date: 1 });

// Reservations
db.reservations.createIndex({ showtime_id: 1, seat_id: 1 }, { unique: true });

// Payments
db.payments.createIndex({ payment_id: 1 }, { unique: true });

print("Indexes created");
