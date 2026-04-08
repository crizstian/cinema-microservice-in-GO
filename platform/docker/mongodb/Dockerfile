# ============================================================
# MongoDB Initialization Container
# ============================================================
# Single Dockerfile for both dev (auth) and test (no-auth) modes
#
# Environment Variables:
#   MONGO_HOST      - Primary MongoDB host (default: mongo)
#   REPLICA_SET     - Replica set name (default: rs0)
#   REPLICA_MEMBERS - Comma-separated members (default: single node)
#   AUTH_ENABLED    - Enable authentication (default: false)
#   MONGO_ADMIN_USER/PASS - Admin credentials (when AUTH_ENABLED=true)
#   MONGO_APP_USER/PASS   - App credentials (when AUTH_ENABLED=true)
#
# Usage:
#   # Test mode (no auth, single node)
#   docker build -t mongo-init .
#
#   # Dev mode (auth, 3 nodes)
#   docker run -e AUTH_ENABLED=true -e REPLICA_MEMBERS=mongo1,mongo2,mongo3 ...
# ============================================================

FROM mongo:8.0

COPY seed/*.js /scripts/

ENV MONGO_HOST=mongo
ENV REPLICA_SET=rs0
ENV REPLICA_MEMBERS=""
ENV AUTH_ENABLED=false

COPY <<'EOF' /init.sh
#!/bin/bash
set -e

echo "=== MongoDB Initialization ==="
echo "Host: ${MONGO_HOST}, ReplicaSet: ${REPLICA_SET}"
echo "Auth: ${AUTH_ENABLED}, Members: ${REPLICA_MEMBERS:-single-node}"

# Build auth options
AUTH_OPTS=""
if [ "$AUTH_ENABLED" = "true" ]; then
  AUTH_OPTS="-u ${MONGO_ADMIN_USER} -p ${MONGO_ADMIN_PASS} --authenticationDatabase admin"
  echo "Authentication: enabled"
fi

# Build replica set members
if [ -n "$REPLICA_MEMBERS" ]; then
  IFS=',' read -ra HOSTS <<< "$REPLICA_MEMBERS"
  MEMBERS="["
  for i in "${!HOSTS[@]}"; do
    [ $i -gt 0 ] && MEMBERS+=","
    PRIORITY=$((3-i))
    MEMBERS+="{_id:$i,host:'${HOSTS[$i]}:27017',priority:$PRIORITY}"
  done
  MEMBERS+="]"
else
  MEMBERS="[{_id:0,host:'${MONGO_HOST}:27017'}]"
fi

echo ""
echo ">>> Step 1: Initialize replica set..."
mongosh --host ${MONGO_HOST}:27017 $AUTH_OPTS --eval "
  try {
    rs.initiate({_id:'${REPLICA_SET}',members:${MEMBERS}});
    print('Replica set initiated');
  } catch(e) {
    if (e.codeName === 'AlreadyInitialized') print('Already initialized');
    else throw e;
  }
" || true

echo ""
echo ">>> Step 2: Waiting for PRIMARY election..."
for i in $(seq 1 30); do
  PRIMARY=$(mongosh --host ${MONGO_HOST}:27017 $AUTH_OPTS --quiet --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY')?.name" 2>/dev/null || echo "")
  if [ -n "$PRIMARY" ] && [ "$PRIMARY" != "null" ]; then
    echo "  PRIMARY elected: $PRIMARY"
    MONGO_HOST=$(echo $PRIMARY | cut -d: -f1)
    break
  fi
  echo "  Waiting... ($i/30)"
  sleep 2
done

if [ "$AUTH_ENABLED" = "true" ] && [ -n "$MONGO_APP_USER" ]; then
  echo ""
  echo ">>> Step 3: Creating application user..."
  mongosh --host ${MONGO_HOST}:27017 $AUTH_OPTS --eval "
    db = db.getSiblingDB('admin');
    try {
      db.createUser({
        user: '${MONGO_APP_USER}',
        pwd: '${MONGO_APP_PASS}',
        roles: [
          {role:'readWrite',db:'cinema'},
          {role:'readWrite',db:'cinema_seats'},
          {role:'readWrite',db:'cinema_payments'}
        ]
      });
      print('App user created');
    } catch(e) {
      print('User exists: ' + e.codeName);
    }
  "
  AUTH_OPTS="-u ${MONGO_APP_USER} -p ${MONGO_APP_PASS} --authenticationDatabase admin"
fi

echo ""
echo ">>> Step 4: Running seed scripts..."
for script in /scripts/*.js; do
  [ -f "$script" ] || continue
  echo "  $(basename $script)"
  mongosh --host ${MONGO_HOST}:27017 $AUTH_OPTS < "$script" || true
done

echo ""
echo ">>> Step 5: Verification..."
mongosh --host ${MONGO_HOST}:27017 $AUTH_OPTS --eval "
  print('Replica: ' + rs.status().set);
  rs.status().members.forEach(m => print('  ' + m.name + ' -> ' + m.stateStr));
  db = db.getSiblingDB('cinema');
  print('Data: ' + db.movies.countDocuments() + ' movies, ' + db.showtimes.countDocuments() + ' showtimes');
"

echo "=== Complete ==="
EOF

RUN chmod +x /init.sh

ENTRYPOINT ["/init.sh"]
