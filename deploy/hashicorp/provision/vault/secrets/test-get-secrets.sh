#!/bin/sh
set -e

#This is done to access the startup passed by derived containers in containerpilot job definition
# export CUSTOM_CMD="$@"

export APP_NAME=booking-service

if [ -n "$APP_NAME" ]; then

	#Get vault token if APP_NAME is specified by the application
	echo "Fetching role and secrets..."

	role_id=`curl -k -s -X GET http://172.20.20.11:8500/v1/kv/cluster/vault/$APP_NAME/role_id | jq  -r '.[].Value'| base64 -d -`
	secret_id=`curl -k -s -X GET http://172.20.20.11:8500/v1/kv/cluster/vault/$APP_NAME/secret_id | jq  -r '.[].Value'| base64 -d -`

	if [ -n "$role_id" ] && [ -n "$secret_id" ]; then
		echo "Exporting VAULT_TOKEN"

		export VAULT_TOKEN=`curl -k -s -X POST -d '{"role_id":"'$role_id'","secret_id":"'$secret_id'"}' http://vault.service.consul:8200/v1/auth/approle/login | jq -r .auth.client_token`
		if [ -z "$VAULT_TOKEN" ]; then
			echo "Unable to get a vault token, exiting..."
			exit 3
		fi

		response=$(curl -ks -X GET --header "X-Vault-Token: ${VAULT_TOKEN}" http://vault.service.consul:8200/v1/secret/$APP_NAME | jq .data)
		if [ "$response" = "null" ] ; then
			echo "Secrets not available in path $APP_NAME, please store the secrets and try again"
			exit 4
		else
			echo "Secrets detected in vault for the app, continuing..."
		fi
	else
		echo "Application vault bootstrap appears to be incomplete. Please bootstrap the application and retry."
		exit 2
	fi

  #Generating config file for envconsul
  consul-template -config /vagrant/provision/vault/secrets/ct.hcl -once

	chmod +x /vagrant/provision/vault/secrets/test-script.sh 

  echo "Continuing with envconsul based startup..."
  exec envconsul -consul-addr=172.20.20.11:8500  -config=/vagrant/provision/vault/secrets/envconsul.hcl /vagrant/provision/vault/secrets/test-script.sh 
else
	echo "Application is not envconsul enabled; Continuing with standard startup..."
	exec $START_CMD
fi
