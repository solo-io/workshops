#!/bin/bash
mkdir -p /var/lib/rancher/k3s/server/manifests
touch /var/lib/rancher/k3s/server/manifests/traefik.yaml.skip
export K3S_NODE_NAME=kubernetes
systemctl daemon-reload
systemctl start k3s

while ! nc -z kubernetes 6443 -v; do sleep 1; done

for i in gloo-ee gloo-ee-envoy-wrapper gloo-fed-apiserver-envoy gloo-fed-apiserver gloo-fed gloo-federation-console extauth-ee observability-ee rate-limit-ee
do
  /usr/local/bin/k3s ctr i pull quay.io/solo-io/$i:$GLOOEE_VERSION
done

for i in certgen discovery gateway
do
  /usr/local/bin/k3s ctr i pull quay.io/solo-io/$i:$GLOO_VERSION
done

for i in examples-bookinfo-details-v1 examples-bookinfo-productpage-v1 examples-bookinfo-ratings-v1 examples-bookinfo-reviews-v2 examples-bookinfo-reviews-v3
do
  /usr/local/bin/k3s ctr i pull docker.io/istio/$i:1.16.2
done

/usr/local/bin/k3s ctr i pull docker.io/grafana/grafana:6.6.2
/usr/local/bin/k3s ctr i pull docker.io/library/redis:5
/usr/local/bin/k3s ctr i pull docker.io/kennethreitz/httpbin:latest
/usr/local/bin/k3s ctr i pull quay.io/keycloak/keycloak:12.0.4

echo "the end"

systemctl stop k3s