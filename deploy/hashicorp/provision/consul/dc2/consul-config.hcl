data_dir = "/var/consul/config/"
log_level = "DEBUG"

datacenter         = "dc2"
primary_datacenter = "dc1"

ui     = true
server = true
bootstrap_expect = 1

bind_addr   = "0.0.0.0"
client_addr = "0.0.0.0"

ports {
  grpc  = 8502
  https = 8501
  http  = 8500
}

advertise_addr     = "172.20.20.31"
advertise_addr_wan = "172.20.20.31"
retry_join_wan     = ["172.20.20.11"]

enable_central_service_config = true

connect {
  enabled = true
}

// acl = {
//   enabled        = true
//   default_policy = "allow"
//   down_policy    = "extend-cache"
// }

# verify_incoming        = false
# verify_incoming_rpc    = true
# verify_outgoing        = true
# verify_server_hostname = true

# auto_encrypt = {
#   allow_tls = true
# }

# ca_file    = "/var/vault/config/ca.crt.pem"
# cert_file  = "/var/vault/config/server.crt.pem"
# key_file   = "/var/vault/config/server.key.pem"

encrypt = "apEfb4TxRk3zGtrxxAjIkwUOgnVkaD88uFyMGHqKjIw="
# encrypt_verify_incoming = true
# encrypt_verify_outgoing = true

telemetry = {
  dogstatsd_addr   = "10.0.2.15:8125"
  disable_hostname = true
}