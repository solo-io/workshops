port=$(docker inspect $1-control-plane | jq -r '.[0].NetworkSettings.Ports."6443/tcp" | .[] | select(.HostIp=="127.0.0.1") | .HostPort')
vagrant ssh -- -o ControlPersist=yes -fNT -L $port:localhost:$port
