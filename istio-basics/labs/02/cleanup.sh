#!/usr/bin/env bash -le

kubectl delete ns istioinaction
kubectl delete secret/istioinaction-cert -n istio-system