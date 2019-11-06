data_dir = "/var/consul/config/"
log_level = "DEBUG"

datacenter = "dc1"
primary_datacenter = "dc1"

server = true

bootstrap_expect = 1
ui = true

bind_addr = "0.0.0.0"

addresses = {
  https = "0.0.0.0"
}

ports {
  grpc = 8502
  https = 8501
  http = -1
}

connect {
  enabled = true
}

advertise_addr = "172.20.20.11"
advertise_addr_wan = "172.20.20.11"

enable_central_service_config = true

acl = {
  enabled = true
  default_policy = "allow"
  down_policy = "extend-cache"
}

telemetry = {
  dogstatsd_addr = "10.0.2.15:8125"
  disable_hostname = true
}

key_file = "/var/vault/config/server.key.pem"
cert_file = "/var/vault/config/server.crt.pem"
ca_file = "/var/vault/config/ca.crt.pem"

verify_incoming = true
verify_outgoing = true
verify_server_hostname = true