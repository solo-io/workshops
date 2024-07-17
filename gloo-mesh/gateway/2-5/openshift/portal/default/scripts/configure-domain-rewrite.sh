#!/usr/bin/env bash

hostname="$1"
new_hostname="$2"

## Install CoreDNS
wget https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz
tar xvf coredns_1.8.3_linux_amd64.tgz
coredns
sudo mv coredns /usr/local/bin/
sudo rm -rf coredns_1.8.3_linux_amd64.tgz

cat <<EOF > ~/coredns.conf
.:5300 {
    forward . 8.8.8.8 8.8.4.4
    rewrite name $hostname $new_hostname
    log
}
EOF

## Run coredns in the background
coredns -conf ~/coredns.conf &> /dev/null &

sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOF

DNS=127.0.0.1:5300
DNSStubListener=yes
EOF

sudo systemctl restart systemd-resolved
