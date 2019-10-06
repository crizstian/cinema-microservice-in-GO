bind_addr = "172.20.20.11"
datacenter =  "dc1-ncv"
region =  "dc1-region"
data_dir = "/var/nomad/data"
log_level = "INFO"
leave_on_terminate = true
leave_on_interrupt = true
disable_update_check = true
client {
    enabled = true
}
addresses {
    rpc =  "172.20.20.11"
    http = "0.0.0.0"
}
advertise {
    rpc = "172.20.20.11:4647"
}
consul {
    address = "172.20.20.11:8500"
    client_service_name = "nomad-dc1-client"
    server_service_name = "nomad-dc1-server"
    auto_advertise      = true
    server_auto_join    = true
    client_auto_join    = true
}

server {
    enabled = true
    bootstrap_expect = 1
}
