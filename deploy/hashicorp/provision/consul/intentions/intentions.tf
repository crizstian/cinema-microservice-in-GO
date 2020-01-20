provider "consul" {
  address    = "172.20.20.11:8500"
  datacenter = "dc1"
  scheme     = "http"
}

terraform {
  backend "consul" {
    address = "172.20.20.11:8500"
    path    = "terraform/dc1/consul/intentions/state"
  }
}
