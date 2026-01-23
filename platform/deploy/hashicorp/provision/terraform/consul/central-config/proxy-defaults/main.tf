variable "proxy_defaults" {
  default = ""
}
variable "enable_proxy_defaults" {
  default = false
}

resource "consul_config_entry" "proxy_defaults" {
  count = var.enable_proxy_defaults ? 1 : 0

  kind = "proxy-defaults"
  # Note that only "global" is currently supported for proxy-defaults and that
  # Consul will override this attribute if you set it to anything else.
  name = "global"

  config_json = jsonencode(var.proxy_defaults)
}