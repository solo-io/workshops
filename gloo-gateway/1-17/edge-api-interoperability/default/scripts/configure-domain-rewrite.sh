#!/usr/bin/env bash

set -x  # Debug mode to show commands
set -e  # Stop on error

hostname="$1"
new_hostname="$2"

## Install CoreDNS if not installed
if ! command -v coredns &> /dev/null; then
  wget https://github.com/coredns/coredns/releases/download/v1.8.3/coredns_1.8.3_linux_amd64.tgz
  tar xvf coredns_1.8.3_linux_amd64.tgz
  sudo mv coredns /usr/local/bin/
  sudo rm -rf coredns_1.8.3_linux_amd64.tgz
fi

name="$(echo {a..z} | tr -d ' ' | fold -w1 | shuf | head -n3 | tr -d '\n')"
tld=$(echo {a..z} | tr -d ' ' | fold -w1 | shuf | head -n2 | tr -d '\n')
random_domain="$name.$tld"
CONFIG_FILE=~/coredns.conf

## Update coredns.conf with a rewrite rule
if grep -q "rewrite name $hostname" $CONFIG_FILE; then
  sed -i "s/rewrite name $hostname.*/rewrite name $hostname $new_hostname/" $CONFIG_FILE
else
  if [ ! -f "$CONFIG_FILE" ]; then
    # Create a new config file if it doesn't exist
    cat <<EOF > $CONFIG_FILE
.:5300 {
    forward . 8.8.8.8 8.8.4.4
    log
}
EOF
  fi
  # Append a new rewrite rule
  sed -i "/log/i \    rewrite name $hostname $new_hostname" $CONFIG_FILE
fi

# Ensure the random domain rewrite rule is always present
if grep -q "rewrite name .* httpbin.org" $CONFIG_FILE; then
  sed -i "s/rewrite name .* httpbin.org/rewrite name $random_domain httpbin.org/" $CONFIG_FILE
else
  sed -i "/log/i \    rewrite name $random_domain httpbin.org" $CONFIG_FILE
fi

cat $CONFIG_FILE  # Display the config for debugging

## Check if CoreDNS is running and kill it
if pgrep coredns; then
  pkill coredns
  # wait for the process to be terminated
  sleep 10
fi

## Restart CoreDNS with the updated config
nohup coredns -conf $CONFIG_FILE &> /dev/null &

## Configure the system resolver
sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1:5300
FallbackDNS=
Domains=
DNSStubListener=yes
EOF

# Wait for coredns to be up and running
sleep 10

cat /etc/systemd/resolved.conf

sudo systemctl restart systemd-resolved

# Initialize a timeout counter (60 seconds)
timeout=60

while [ $timeout -gt 0 ]; do
    # Perform the DNS query and check for the expected rewrite
    response=$(curl -s http://$random_domain/get)
    if echo "$response" | grep -q "\"url\": \"http://$random_domain/get\""; then
        echo "DNS rewrite rule verification successful."
        exit 0
    else
        # Wait for 5 seconds before retrying
        sleep 5
        # Decrement the timeout counter
        ((timeout-=5))
    fi
done

# If the loop exits, it means the check failed consistently for 1 minute
echo "DNS rewrite rule verification failed."
exit 1
