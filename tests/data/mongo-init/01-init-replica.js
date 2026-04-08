// Step 1: Initialize replica set
print("Step 1: Initializing replica set...");

try {
  const status = rs.status();
  print("Replica set already initialized: " + status.set);
} catch (e) {
  print("Initializing new replica set...");
  rs.initiate({
    _id: "rs0",
    members: [{ _id: 0, host: "mongo:27017" }]
  });
  print("Replica set initialized successfully");
}
