exec consul connect envoy \
-mesh-gateway \
-register \
-http-addr "172.20.20.31:8500" \
-grpc-addr "172.20.20.31:8502" \
-wan-address "172.20.20.31:8443" \
-address "127.0.0.1:8443" \
-admin-bind="172.20.20.31:18443"
-bind-address "default=172.20.20.31:8443" >>/var/log/mesh.log 2>&1