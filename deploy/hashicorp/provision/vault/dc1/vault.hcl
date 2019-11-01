cluster_name = "dc1"
ui = true
api_addr = "http://172.20.20.11:8200"

storage "consul" {
  address = "172.20.20.11:8500"
  path    = "vault/"
	service = "vault"
}

listener "tcp" {
    address = "172.20.20.11:8200"
    #tls_cert_file = "/var/vault/config/vault.crt"
    #tls_key_file = "/var/vault/config/vault.key"
    #tls_min_version = "tls12"
    tls_disable = true
}

telemetry = {
  dogstatsd_addr = "10.0.2.15:8125"
  disable_hostname = true
}