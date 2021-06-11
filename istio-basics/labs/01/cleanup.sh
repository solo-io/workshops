#!/usr/bin/env bash -le

istioctl x uninstall --purge -y
kubectl delete ns istio-system