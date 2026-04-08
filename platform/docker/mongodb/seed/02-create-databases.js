// Step 2: Create databases and collections
print("Step 2: Creating databases and collections...");

db = db.getSiblingDB("cinema");

const collections = [
  "movies", "cinemas", "rooms", "showtimes",
  "users", "bookings", "tickets", "payments", "reservations"
];

collections.forEach(function(coll) {
  if (!db.getCollectionNames().includes(coll)) {
    db.createCollection(coll);
    print("Created cinema." + coll);
  }
});

print("Databases and collections ready");
