#!/bin/bash
# Let the script fail in every command failure. Not worth having if conditions around every bad certificate
set -e

echo "Pre-Start started"

# main() {
#     export CERT_ROOT=/usr/local/nginx/certs
#     #Ensure that the certificate folders exist
#     mkdir -p $CERT_ROOT
#     chmod 0755 $CERT_ROOT

#     #Replace the - in the APP_UUID just before generating the envconsul template
#     export APP_ID=$(echo $APP_UUID | sed -e 's/-//g')

#     # The _key and md5 entries are filtered out here (Reason: writeCertAndKey fetches it automatically)
#     for secret in `curl -ks -X LIST --header "X-Vault-Token: ${VAULT_TOKEN}" https://active.vault.service:8200/v1/secret/${APP_ID}/certs | jq -r '.data.keys[]' | grep "_crt$"`
#     do
#         writeCertAndKey $secret
#     done
# }

# # Method that does the following:
# # 1. Downloads the certificate and key
# # 2. Generates an nginx configuration file per domain
# writeCertAndKey() {
#     certPath=$1 #E.g. devfarm_mu_mo_sap_corp_crt
#     domain=$(echo $certPath|sed -e 's/_/\./g') #E.g. devfarm.mu.mo.sap.corp.crt
#     fqdn="${domain%.*}" #E.g. devfarm.mu.mo.sap.corp
#     info "Adding [$certPath] [$domain] [$fqdn]"

#     certFilePath="$CERT_ROOT/$fqdn.crt"
#     downloadAndValdidate $certPath $certFilePath

#     domainPath=$(echo $fqdn|sed -e 's/\./_/g') #E.g. devfarm_mu_mo_sap_corp
#     keyPath="${domainPath}_key" #E.g. devfarm_mu_mo_sap_corp_key
#     keyFilePath="$CERT_ROOT/$fqdn.key"
#     downloadAndValdidate $keyPath $keyFilePath

#     #Now since we have both cert and key, let's generate server config
#     export DOMAIN_NAME=$fqdn
#     export CERT_PATH=$certFilePath
#     export KEY_PATH=$keyFilePath
#     filePath="/var/tmp/domain.ctmpl"

#     #Fetch if there is a default pod administered for this. There are two cases
#     #1. Existing running data centers which will not have the default pod stored in vault
#     #2. New data centers with the default pod stored. Here again, there are two variations
#         #2a. Those certificates which are stored with "none" as the default pod
#         #2b. Those certificates which are stored with actual default pod name, for e.g. seller-portal
#     export QUERY_NAME=`curl -ks --header "X-Vault-Token: $VAULT_TOKEN" https://active.vault.service:8200/v1/secret/${APP_ID}/certs/${domainPath}_query_name | jq -r .data.value`
#     if [[ $QUERY_NAME = "null" ]]; then
#         info "No default pod detected. This is an old StoreCertificate path."
#     elif [[ $QUERY_NAME = "none" ]]; then
#         info "No default pod detected. This is a new StoreCertificate path without any default pod"
#     else
#         filePath="/var/tmp/domain-app.ctmpl"
#         if [ -e "/var/tmp/${QUERY_NAME}-domain-app.ctmpl" ]; then
#             filePath="/var/tmp/${QUERY_NAME}-domain-app.ctmpl"
#         fi
#     fi
#     info "Generating domain configuration for [${fqdn}]"

#     consul-template -log-level err -once -vault-addr "https://active.vault.service:8200" -consul-addr $NOMAD_IP_cobalt:8500 -template "${filePath}:/usr/local/nginx/conf/domain.${fqdn}.conf"

#     info "Generation complete for [${fqdn}], testing nginx"
#     nginx -t
# }



#  # Method to do the following
#  # 1. Download the secretpath as a file
#  # 2. Download the md5 and validate the downloaded file
#  # The function returns an non-zero value and this causes the script to exit if there is mismatch
# downloadAndValdidate() {
#     secretPath=$1
#     destinationFile=$2
#     tmpFile=`mktemp /tmp/gwnginxfile.XXXXXX`
#     info "Downloading [$secretPath] [$destinationFile] [$tmpFile]"

#     curl -ks --header "X-Vault-Token: $VAULT_TOKEN" https://active.vault.service:8200/v1/secret/${APP_ID}/certs/$secretPath | jq -r .data.value | sed 's/\\n/\n/g' | sed '/^$/d' > $tmpFile #Download the file
#     md5value=`md5sum $tmpFile | awk '{print $1}'`

#     #Check if an entry with checksum exists in vault
#     md5path="${secretPath}_md5_${md5value}"
#     info "Checking [$md5path]"
#     md5Stored=`curl -ks --header "X-Vault-Token: $VAULT_TOKEN" https://active.vault.service:8200/v1/secret/${APP_ID}/certs/$md5path | jq -r '.data.value'`
#     if [ "$md5Stored" == "$md5value" ]; then
#         info "Validated md5 [$md5value] of [$secretPath]"
#     else
#         warn "Md5 [$md5Stored] of file [$secretPath] does not match what is expected [$md5value]"
#         # This is considered warning as we want to go ahead with the container startup
#     fi
#     mv $tmpFile $destinationFile
#     chmod 0600 $destinationFile
#     info "Certificate md5 validated for [$secretPath]"
#     return 0 # 0 = success
# }
# info() {
#     echo "[INFO] $1"
# }
# warn() {
#     echo "[WARN] $1"
# }
# error() {
#     echo "[ERROR] $1"
# }
# main

echo "Pre-Start done"
exit 0