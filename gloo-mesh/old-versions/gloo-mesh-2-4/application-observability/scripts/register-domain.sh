#!/usr/bin/env bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <hostname> <new_ip>"
    exit 1
fi

# Variables
hostname="$1"
new_ip="$2"
hosts_file="/etc/hosts"

# Check if the entry already exists
if grep -q "$hostname" "$hosts_file"; then
    # Update the existing entry with the new IP
    sudo sed -i '' "s/^.*$hostname/$new_ip $hostname/" "$hosts_file"
    echo "Updated $hostname in $hosts_file with new IP: $new_ip"
else
    # Add a new entry if it doesn't exist
    echo "$new_ip $hostname" | sudo tee -a "$hosts_file" > /dev/null
    echo "Added $hostname to $hosts_file with IP: $new_ip"
fi
