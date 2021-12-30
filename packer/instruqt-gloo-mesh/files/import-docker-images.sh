#!/bin/bash
mkdir -p /var/lib/rancher/k3s/server/manifests
touch /var/lib/rancher/k3s/server/manifests/traefik.yaml.skip
touch /var/lib/rancher/k3s/server/manifests/servicelb.yaml.skip
export K3S_NODE_NAME=kubernetes
systemctl daemon-reload
systemctl start k3s

while ! nc -z kubernetes 6443 -v; do sleep 1; done

# /usr/local/bin/k3s ctr i ls -q

wget -q https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise/gloo-mesh-enterprise-${GLOO_VERSION}.tgz
gloo_images=$(helm template gloo-mesh-enterprise ./gloo-mesh-enterprise-${GLOO_VERSION}.tgz --namespace gloo-mesh --version=${GLOO_VERSION} --set rbac-webhook.enabled=true --create-namespace --set-string licenseKey=dummy|grep image:|sed 's/- //g'|awk '{print $2}'|sed 's/"//g'|sed 's/docker.io/docker.io\/library/g'|sed 's/jimmidyson\//docker.io\/jimmidyson\//g'|sed 's/prom\//docker.io\/prom\//g')
for i in $gloo_images
do
  /usr/local/bin/k3s ctr i pull $i
done
rm ./gloo-mesh-enterprise-${GLOO_VERSION}.tgz

wget -q https://storage.googleapis.com/gloo-mesh-enterprise/enterprise-agent/enterprise-agent-${GLOO_VERSION}.tgz
gloo_images=$(helm template gloo-mesh-enterprise ./enterprise-agent-${GLOO_VERSION}.tgz --namespace gloo-mesh --version=${GLOO_VERSION} --set rate-limiter.enabled=true --set ext-auth-service.enabled=true --create-namespace --set-string licenseKey=dummy|grep image:|sed 's/- //g'|awk '{print $2}'|sed 's/"//g'|sed 's/docker.io/docker.io\/library/g')
for i in $gloo_images
do
  /usr/local/bin/k3s ctr i pull $i
done
rm ./enterprise-agent-${GLOO_VERSION}.tgz

for i in pilot proxyv2 operator
do
  /usr/local/bin/k3s ctr i pull docker.io/istio/$i:$ISTIO_VERSION
done

for url in https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml
do
  for image in $(curl -sfL ${url}|grep image:|awk '{print $2}')
  do
    /usr/local/bin/k3s ctr i pull $image
  done
done

/usr/local/bin/k3s ctr i pull quay.io/keycloak/keycloak:12.0.4
