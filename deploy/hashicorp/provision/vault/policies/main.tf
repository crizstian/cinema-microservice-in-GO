provider "vault" {
  ca_cert_file = "../../certs/ca.crt.pem"
}

provider "consul" {
  address    = "172.20.20.11:8500"
  datacenter = "dc1"
  scheme     = "http"
}

terraform {
  backend "consul" {
    address = "172.20.20.11:8500"
    path    = "terraform/vault/state"
  }
}