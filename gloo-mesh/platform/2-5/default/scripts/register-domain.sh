#!/usr/bin/env bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <hostname> <new_ip_or_domain>"
    exit 1
fi

# Variables
hostname="$1"
new_ip_or_domain="$2"
hosts_file="/etc/hosts"

# Function to check if the input is a valid IP address
is_ip() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0 # 0 = true
    else
        return 1 # 1 = false
    fi
}

# Function to resolve domain to the first IPv4 address using dig
resolve_domain() {
    # Using dig to query A records, and awk to parse the first IPv4 address
    dig +short A "$1" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print; exit}'
}

# Validate new_ip_or_domain or resolve domain to IP
if is_ip "$new_ip_or_domain"; then
    new_ip="$new_ip_or_domain"
else
    new_ip=$(resolve_domain "$new_ip_or_domain")
    if [ -z "$new_ip" ]; then
        echo "Failed to resolve domain to an IPv4 address."
        exit 1
    fi
fi

# Check if the entry already exists
if grep -q "$hostname" "$hosts_file"; then
    # Update the existing entry with the new IP
    tempfile=$(mktemp)
    sed "s/^.*$hostname/$new_ip $hostname/" "$hosts_file" > "$tempfile"
    sudo mv "$tempfile" "$hosts_file"
    echo "Updated $hostname in $hosts_file with new IP: $new_ip"
else
    # Add a new entry if it doesn't exist
    echo "$new_ip $hostname" | sudo tee -a "$hosts_file" > /dev/null
    echo "Added $hostname to $hosts_file with IP: $new_ip"
fi