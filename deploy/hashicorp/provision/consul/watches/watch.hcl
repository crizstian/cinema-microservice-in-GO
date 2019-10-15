watches = [
#   {
#   type    = "service"
#   service = "mongodb1"
#   args    = ["/var/consul/config/remove-mongo-key.sh", "cluster/cinemas-db/mongo-cluster/", "mongodb1"]
# },{
#   type    = "service"
#   service = "mongodb2"
#   args    = ["/var/consul/config/remove-mongo-key.sh", "cluster/cinemas-db/mongo-cluster/", "mongodb2"]
# },
{
  type    = "services"
  # service = "mongodb3"
  args    = ["/var/consul/config/remove-mongo-key.sh", "cluster/cinemas-db/mongo-cluster/", "mongodb3"]
},{
  type    = "keyprefix"
  prefix = "cluster/cinemas-db/mongo-cluster/"
  args = ["/var/consul/config/mongoStatus.sh", "/cluster/cinemas-db/mongo-cluster/", "initMongo"]
}]