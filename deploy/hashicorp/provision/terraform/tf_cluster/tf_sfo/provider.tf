provider "consul" {
  address    = var.consul_address
  datacenter = var.consul_datacenter
  scheme     = var.consul_scheme
}

provider "vault" {}

terraform {
  backend "consul" {}
}
