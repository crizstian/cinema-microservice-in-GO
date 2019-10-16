#!/bin/sh
set -e

export CUSTOM_CMD="$@"

if [ -z $START_CMD ]; then
	echo "Setting custom command as the startup command"
	export START_CMD=${CUSTOM_CMD}
fi


echo "Setting secrets for $APP_NAME if exists"

if [ -n "$APP_NAME" ]; then

	#Get vault token if APP_NAME is specified by the application
	echo "Fetching role and secrets..."

	role_id=`curl -k -s -X GET http://$CONSUL_IP:8500/v1/kv/cluster/vault/$APP_NAME/role_id | jq  -r '.[].Value'| base64 -d -`
	secret_id=`curl -k -s -X GET http://$CONSUL_IP:8500/v1/kv/cluster/vault/$APP_NAME/secret_id | jq  -r '.[].Value'| base64 -d -`

	if [ -n "$role_id" ] && [ -n "$secret_id" ]; then
		echo "Exporting VAULT_TOKEN"

		export VAULT_TOKEN=`curl -k -s -X POST -d '{"role_id":"'$role_id'","secret_id":"'$secret_id'"}' http://vault.query.consul:8200/v1/auth/approle/login | jq -r .auth.client_token`
		if [ -z "$VAULT_TOKEN" ]; then
			echo "Unable to get a vault token, exiting..."
			exit 3
		fi

	# 	response=$(curl -ks -X GET --header "X-Vault-Token: ${VAULT_TOKEN}" http://vault.query.consul:8200/v1/secret/$APP_NAME | jq .data)
	# 	if [ "$response" = "null" ] ; then
	# 		echo "Secrets not available in path $APP_NAME, please store the secrets and try again"
	# 		exit 4
	# 	else
	# 		echo "Secrets detected in vault for the app, continuing..."
	# 	fi
	# else
	# 	echo "Application vault bootstrap appears to be incomplete. Please bootstrap the application and retry."
	# 	exit 2
	fi

  #Generating config file for envconsul
  echo "Generating secrets template file..."
  /usr/bin/consul-template -config /tmp/ct.hcl -once

  echo "Continuing with envconsul based startup..."
  exec /usr/bin/envconsul -consul-addr=$CONSUL_IP:8500  -config=/tmp/envconsul.hcl /tmp/start-process.sh $START_CMD
else
	echo "Application is not envconsul enabled; Continuing with standard startup..."
	exec $START_CMD
fi