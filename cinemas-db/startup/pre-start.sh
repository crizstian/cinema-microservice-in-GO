#!/bin/bash
set -e

env | grep CONSUL

export CUSTOM_CMD="$@"

echo "is CONSUL_HTTP_SSL = $CONSUL_HTTP_SSL"

if [ "$CONSUL_HTTP_SSL" == "true" ]; then
	echo "SSL IS ENABLED"
  curl_ssl="--cacert ${CA_CERT_FILE}"
fi

if [ -z $START_CMD ]; then
	echo "Setting custom command as the startup command"
	export START_CMD=${CUSTOM_CMD}
fi

echo "Setting secrets for $APP_NAME if exists"

if [ -n "$APP_NAME" ]; then

	#Get vault token if APP_NAME is specified by the application
	echo "Fetching role and secrets..."

	echo "consul request: curl $curl_ssl -s -X GET ${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}/v1/kv/cluster/apps/${APP_NAME}/auth/"

	role_id=`curl $curl_ssl -s -X GET ${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}/v1/kv/cluster/apps/${APP_NAME}/auth/role_id | jq  -r '.[].Value'| base64 -d -`
	secret_id=`curl $curl_ssl -s -X GET ${CONSUL_SCHEME}://${CONSUL_IP}:${CONSUL_PORT}/v1/kv/cluster/apps/${APP_NAME}/auth/secret_id | jq  -r '.[].Value'| base64 -d -`

	echo "role_id = $role_id"
	echo "secret_id = $secret_id"

	if [ -n "$role_id" ] && [ -n "$secret_id" ]; then
		echo "Exporting VAULT_TOKEN"

		export VAULT_TOKEN=`curl --cacert ${CA_CERT_FILE} -s -X POST -d '{"role_id":"'$role_id'","secret_id":"'$secret_id'"}' https://vault.service.consul:8200/v1/auth/approle/login | jq -r .auth.client_token`
		if [ -z "$VAULT_TOKEN" ]; then
			echo "Unable to get a vault token, exiting..."
			exit 3
		fi

		#response=$(curl $curl_ssl -s -X GET --header "X-Vault-Token: ${VAULT_TOKEN}" https://vault.service.consul:8200/v1/secret/$APP_NAME | jq .data)
	fi
	
  #Generating config file for envconsul
  echo "Generating secrets template file..."
  /usr/bin/consul-template -config /tmp/ct.hcl -once

	cat /tmp/envconsul.hcl

  echo "Continuing with envconsul based startup..."
  exec /usr/bin/envconsul -config=/tmp/envconsul.hcl /tmp/startProcess.sh $START_CMD
else
	echo "Application is not envconsul enabled; Continuing with standard startup..."
	exec $START_CMD
fi
