#!/usr/bin/env bash -le

kubectl label namespace istioinaction istio-injection-
kubectl rollout restart deployment web-api -n istioinaction
kubectl rollout restart deployment purchase-history-v1 -n istioinaction
kubectl rollout restart deployment recommendation -n istioinaction
kubectl rollout restart deployment sleep -n istioinaction