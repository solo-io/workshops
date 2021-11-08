#!/bin/bash
mkdir -p /var/lib/rancher/k3s/server/manifests
touch /var/lib/rancher/k3s/server/manifests/traefik.yaml.skip
touch /var/lib/rancher/k3s/server/manifests/servicelb.yaml.skip
export K3S_NODE_NAME=kubernetes
systemctl daemon-reload
systemctl start k3s

while ! nc -z kubernetes 6443 -v; do sleep 1; done

# /usr/local/bin/k3s ctr i ls -q

for i in enterprise-networking gloo-mesh-apiserver gloo-mesh-envoy gloo-mesh-ui rbac-webhook enterprise-agent
do
  /usr/local/bin/k3s ctr i pull gcr.io/gloo-mesh/$i:$GLOO_VERSION
done

for i in pilot proxyv2
do
  /usr/local/bin/k3s ctr i pull docker.io/istio/$i:$ISTIO_VERSION
done

for i in examples-bookinfo-details-v1 examples-bookinfo-productpage-v1 examples-bookinfo-ratings-v1 examples-bookinfo-reviews-v1 examples-bookinfo-reviews-v2 examples-bookinfo-reviews-v3
do
  /usr/local/bin/k3s ctr i pull docker.io/istio/$i:1.16.2
done

/usr/local/bin/k3s ctr i pull quay.io/prometheus/prometheus:v2.26.0
/usr/local/bin/k3s ctr i pull docker.io/library/redis:6.2.6
/usr/local/bin/k3s ctr i pull docker.io/jimmidyson/configmap-reload:v0.5.0
/usr/local/bin/k3s ctr i pull gcr.io/gloo-mesh/rate-limiter:0.5.4
/usr/local/bin/k3s ctr i pull gcr.io/gloo-mesh/ext-auth-service:0.19.7
/usr/local/bin/k3s ctr i pull quay.io/keycloak/keycloak:12.0.4

systemctl stop k3s