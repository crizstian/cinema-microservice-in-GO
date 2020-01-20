provider "vault" {
  ca_cert_file = "../../certs/ca.crt.pem"
}

provider "consul" {
  address    = "dc1-consul-server:8500"
  datacenter = "dc1"
  scheme     = "http"
}

terraform {
  backend "consul" {
    address = "dc1-consul-server:8500"
    path    = "terraform/dc1/vault/policies/state"
  }
}