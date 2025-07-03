#!/bin/bash

# Read input line by line and prepend a timestamp
while IFS= read -r line; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') $line"
done
