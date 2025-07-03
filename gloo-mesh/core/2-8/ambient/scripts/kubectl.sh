#!/bin/bash

echo "kubectl apply -f-<<EOF"
while IFS= read -r line || [[ -n "$line" ]]
do
  printf "%s\n" "$line"
done < "${1:-/dev/stdin}"
echo "EOF"