# docker run -p 27017:27017 \
# -e "DB_ADMIN_USER=cristian" \
# -e "DB_ADMIN_PASS=cristianPassword2017" \
# -e "DB_REPLICA_ADMIN=replicaAdmin" \
# -e "DB_REPLICA_ADMIN_PASS=replicaAdminPassword2017" \
# -e "DB_REPLSET_NAME=rs1" \
# -e "DB_PORT=27017" \
# -d cinemas-db:v0.1

IS_PRIMARY="true"

if [ $IS_PRIMARY == "true" ]; then
  echo "is primary"
else 
  echo "no primary"
fi