#!/usr/bin/env bash

function init_replica_set {
  bash -c 'mongo < /data/admin/replica.js'
  sleep 2
  bash -c 'mongo < /data/admin/admin.js'
  sleep 2
  bash -c 'mongo -u '$DB_REPLICA_ADMIN' -p '$DB_REPLICA_ADMIN_PASS' --eval "rs.status()" --authenticationDatabase "admin"'
}

# @params server primary-mongo-container
function add_replicas {
  echo '·· adding replicas >>>> ··'

  # Wait for all nodes to be ready first
  wait_for_databases $DB1 $DB2 $DB3

  # add nuppdb replicas
  for server in $DB1 $DB2 $DB3
  do
    rs="rs.add('$server')"
    add='mongo --eval "'$rs'" -u '$DB_REPLICA_ADMIN' -p '$DB_REPLICA_ADMIN_PASS' --authenticationDatabase="admin"'
    echo ">>>>>>>>>>> adding mongodb server $server to replica set"
    bash -c "$add"
    sleep 2
  done
}

function wait_for {
  echo ">>>>>>>>>>> waiting for mongodb at $1:$2"
  start_ts=$(date +%s)
  while :
  do
    (echo > /dev/tcp/$1/$2) >/dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
        end_ts=$(date +%s)
        echo "<<<<< $1:$2 is available after $((end_ts - start_ts)) seconds"
        sleep 3
        break
    fi
    sleep 2
  done
}

function wait_for_databases {
  # Wait for all provided MongoDB instances
  for ip in "$@"; do
    # Extract IP without port
    server_ip=$(echo $ip | cut -d':' -f1)
    echo "Waiting for MongoDB at $server_ip:$DB_PORT"
    wait_for "$server_ip" "$DB_PORT"
  done
  echo "All MongoDB instances are ready"
}

function setupDefaultCinemasData {
  bash -c 'mongo -u '$DB_ADMIN_USER' -p '$DB_ADMIN_PASS' --authenticationDatabase "admin" < /data/admin/movies.js'
  # mongoimport --db cinemas --collection cinemas --file /data/admin/cinemas.json -u $CINEMA_DBUSER -p $CINEMA_DBPASS --authenticationDatabase=admin --jsonArray
  # mongoimport --db cinemas --collection cities --file /data/admin/cities.json -u $CINEMA_DBUSER -p $CINEMA_DBPASS --authenticationDatabase=admin --jsonArray
  # mongoimport --db cinemas --collection countries --file /data/admin/countries.json -u $CINEMA_DBUSER -p $CINEMA_DBPASS --authenticationDatabase=admin --jsonArray
  # mongoimport --db cinemas --collection states --file /data/admin/states.json -u $CINEMA_DBUSER -p $CINEMA_DBPASS --authenticationDatabase=admin --jsonArray
}

function createDBUsers {
  bash -c 'mongo -u '$DB_ADMIN_USER' -p '$DB_ADMIN_PASS' --authenticationDatabase "admin" < /data/admin/grantRole.js'
  # mongo admin -u $DB_ADMIN_USER -p $DB_ADMIN_PASS --eval "db.createUser({ user: '$BOOKSTORE_DBUSER', pwd: '$BOOKSTORE_DBPASS', roles: [ { role: 'dbOwner', db: 'bookstore' } ] })"
  # mongo admin -u $DB_ADMIN_USER -p $DB_ADMIN_PASS --eval "db.createUser({ user: '$CINEMA_DBUSER', pwd: '$CINEMA_DBPASS', roles: [ { role: 'dbOwner', db: 'cinemas' } ] })"
}

function check_status {
  bash -c 'mongo -u '$DB_REPLICA_ADMIN' -p '$DB_REPLICA_ADMIN_PASS' --eval "rs.status()" --authenticationDatabase "admin"'
}

function init {
  init_replica_set
  echo ">>>>>>>>>>> waiting for mongodb to init"
  sleep 5
  add_replicas
  sleep 5
  check_status
  createDBUsers
  sleep 3
  setupDefaultCinemasData
  echo ">>>>>>>>>>> mongodb cluster setup complete"
}

echo ">>>>>>>>>>> MongoInit.sh Loaded"

sleep 10
echo ">>>>>>>>>>> STARTING MONGODB REPLICA TO INIT"
init

# mongo -u $DB_REPLICA_ADMIN -p $DB_REPLICA_ADMIN_PASS --eval "rs.status()" --authenticationDatabase "admin"