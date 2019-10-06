#!/bin/sh
set -e

#This is done to access the startup passed by derived containers in containerpilot job definition
# export CUSTOM_CMD="$@"

# if [ ! -n "$ACTIVE_ACTIVE" ] ||  [ `echo  $ACTIVE_ACTIVE |  tr [:upper:] [:lower:]` = "false" ]; then
# 	echo "Setting ENABLE_DR to true"
# 	ENABLE_DR=true
# fi

# if [ -n "$ENABLE_DR" ] ; then
# 	echo "Adding DR related paths for envconsul monitoring"
# 	cat /var/tmp/hashi/envconsul.consul.dr.hcl >> /tmp/envconsul.hcl.tmpl
# fi

# if [ ! -n "$NOMAD_MEMORY_LIMIT" ] ; then
# 	echo "Exporting NOMAD_MEMORY_LIMIT with default value of 512MB"
# 	export NOMAD_MEMORY_LIMIT=512
# fi

# if [ -n "$APP_NAME" ]; then
# 	echo "Adding application specific paths to envconsul monitoring"
# 	cat /var/tmp/hashi/envconsul.consul.hcl.tmpl >> /tmp/envconsul.hcl.tmpl
# fi

# if [ "$ENABLE_CONTAINER_PILOT" = "true" ]; then
# 	echo "Setting up containerpilot as the startup command"
# 	START_CMD="/usr/local/bin/containerpilot -config /opt/containerpilot/app.json5"
# else
# 	echo "Setting custom command as the startup command"
# 	START_CMD=${CUSTOM_CMD}
# fi

# echo "START_CMD=[${START_CMD}]"

# log_level=$(get_log_level)

# #If either consul config or vault secret is asked by application
# #convert ACTIVE_ACTIVE to lowercase and comparing so that we dont worry about its case
# if [ -n "$APP_UUID" ] || [ -n "$ENABLE_DR" ] || [ -n "$APP_NAME" ]; then

# 		#Generating config file for envconsul
# 		cat /tmp/envconsul.hcl.tmpl
# 		consul-template -config /var/tmp/hashi/ct.hcl -once
# 		cat /tmp/envconsul.hcl

# 		echo "Continuing with envconsul based startup..."
# else
# 	echo "Application is not envconsul enabled; Continuing with standard startup..."
# 	exec $START_CMD
# fi

mongod \
  --keyFile /data/keyfile/mongo-keyfile \
  --replSet $DB_REPLSET_NAME \
  --storageEngine wiredTiger \
  --port $DB_PORT \
  --bind_ip 0.0.0.0