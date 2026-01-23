#!/bin/sh
set -e

mongod \
  --keyFile /data/keyfile/mongo-keyfile \
  --replSet $DB_REPLSET_NAME \
  --storageEngine wiredTiger \
  --port $DB_PORT \
  --bind_ip 0.0.0.0