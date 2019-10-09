bind_addr = "172.20.20.31"
datacenter =  "dc2-ncv"
region =  "dc2-region"
data_dir = "/var/nomad/data"
log_level = "INFO"
leave_on_terminate = true
leave_on_interrupt = true
disable_update_check = true
client {
    enabled = true
}
addresses {
    rpc =  "172.20.20.31"
    http = "172.20.20.31"
    serf = "172.20.20.31"
}
advertise {
    http = "172.20.20.31:4646"
    rpc = "172.20.20.31:4647"
    serf = "172.20.20.31:4648"
}
consul {
    address = "172.20.20.31:8500"
    client_service_name = "nomad-dc2-client"
    server_service_name = "nomad-dc2-server"
    auto_advertise      = true
    server_auto_join    = true
    client_auto_join    = true
}

server {
    enabled = true
    bootstrap_expect = 1
}
