kind     = "service-resolver"
name     = "notification"

failover = {
  "*" = {
    datacenters = ["dc2"]
  }
}
