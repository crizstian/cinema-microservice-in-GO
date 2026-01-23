enable_script_checks       = true
enable_local_script_checks = true

checks = [
{
    id       = "token-expiration"
    name     = "agent-token-health-check"
    shell    = "/bin/bash"
    args     = ["/var/consul/config/agent-token.sh"]
    interval = "10s"
}
]