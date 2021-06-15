#!/usr/bin/env bash -l
set +e

kubectl delete ns bookinfo
kubectl delete vs/demo -n gloo-system