cluster_name = "dc2"
ui = true

# Advertise the non-loopback interface
api_addr = "https://172.20.20.31:8200"
cluster_addr = "https://172.20.20.31:8201"

# Storage config
storage "consul" {
  address = "172.20.20.31:8500"
  path    = "vault/"
	service = "vault"
}

# Listeners config
listener "tcp" {
    address = "172.20.20.31:8200"
    tls_cert_file = "/var/vault/config/server.crt.pem"
    tls_key_file = "/var/vault/config/server.key.pem"
}

# Telemetry
# telemetry = {
#   statsite_address = "10.0.2.15:8125"
#   disable_hostname = true
# }