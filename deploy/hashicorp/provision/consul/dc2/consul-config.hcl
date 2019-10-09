data_dir = "/var/consul/config/"
log_level = "DEBUG"

datacenter = "dc2"
primary_datacenter = "dc1"

server = true

bootstrap_expect = 1

bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"

ports {
  grpc = 8502
}

connect {
  enabled = true
}

ui = true
enable_central_service_config = true

advertise_addr = "172.20.20.31"
advertise_addr_wan = "172.20.20.31"
retry_join_wan = ["172.20.20.11"]
