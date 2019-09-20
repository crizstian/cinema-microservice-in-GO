#!/bin/bash
set -e

echo "Proceeding with startup..."
echo "IS_PRIMARY = " $IS_PRIMARY

if [ $IS_PRIMARY == "true" ]; then
  /var/tmp/start/startWithConfig.sh & 
  /var/tmp/start/initMongo.sh &
  wait
else 
  /var/tmp/start/startWithConfig.sh
fi
