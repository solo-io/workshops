#!/usr/bin/env bash

printf "Waiting for all the kube-system pods to become ready in context $1"
until [ $(kubectl --context $1 -n kube-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"

printf "Waiting for all the metallb-system pods to become ready in context $1"
until [ $(kubectl --context $1 -n metallb-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"