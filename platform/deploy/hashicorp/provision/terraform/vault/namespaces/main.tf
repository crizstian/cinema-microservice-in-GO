variable "enable_namespaces" {}
variable "namespaces" {}

resource "vault_namespace" "ns" {
  count = var.enable_namespaces && length(var.namespaces) > 0 ? length(var.namespaces) : 0
  
  path = var.namespaces[count.index]
}