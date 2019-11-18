#!/bin/bash

. /etc/environment

# Enable KV Secrets Engine
vault secrets enable -path=secret kv

echo "Writing Secrets for apps"
echo "root token: $VAULT_TOKEN"
echo "vault address: $VAULT_ADDR"

# Mongodb Secrets
vault write secret/mongodb DB_ADMIN_USER=cristian DB_ADMIN_PASS=cristianPassword2017 DB_REPLICA_ADMIN=replicaAdmin DB_REPLICA_ADMIN_PASS=replicaAdminPassword2017 DB_REPLSET_NAME=rs1

# Booking Service Secrets
vault write secret/booking-service DB_USER=cristian DB_PASS=cristianPassword2017 DB_NAME=booking DB_REPLICA=rs1

# Payment Service Secrets
vault write secret/payment-service DB_USER=cristian DB_PASS=cristianPassword2017 DB_NAME=payment DB_REPLICA=rs1 STRIPE_SECRET=sk_test_lPPoJjmmbSjymtgo4r0O3z89 STRIPE_PUBLIC=pk_test_l10342hIODZmOJsBpY6GVPHj

# Notification Service Secrets
vault write secret/notification-service EMAIL=crr.developer.9@gmail.com EMAIL_PASS=Cris123#

# Movie Service Secrets
vault write secret/movie-service DB_ADMIN_USER=cristian DB_ADMIN_PASS=cristianPassword2017 DB_REPLSET_NAME=rs1 DB_NAME=movies

# Enable Consul Secrets Engine
vault secrets enable consul

# Enable Consul Role Engine
vault write consul/config/access scheme=http address=$HOST_IP:8500 token=$CONSUL_HTTP_TOKEN