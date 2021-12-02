#!/bin/bash
mkdir -p /var/lib/rancher/k3s/server/manifests
touch /var/lib/rancher/k3s/server/manifests/traefik.yaml.skip
export K3S_NODE_NAME=kubernetes
systemctl daemon-reload
systemctl start k3s

while ! nc -z kubernetes 6443 -v; do sleep 1; done

wget -q https://storage.googleapis.com/gloo-ee-helm/charts/gloo-ee-${GLOOEE_VERSION}.tgz
gloo_images=$(helm template gloo ./gloo-ee-${GLOOEE_VERSION}.tgz --namespace gloo-system --version=${GLOOEE_VERSION} --create-namespace --set-string license_key=dummy|grep image:|sed 's/- //g'|awk '{print $2}'|sed 's/"//g'|sed 's/docker.io/docker.io\/library/g')
for i in $gloo_images
do
  /usr/local/bin/k3s ctr i pull $i
done
rm gloo-ee-${GLOOEE_VERSION}.tgz

for url in https://raw.githubusercontent.com/istio/istio/1.7.3/samples/bookinfo/platform/kube/bookinfo.yaml https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/12.0.4/kubernetes-examples/keycloak.yaml
do
  for image in $(curl -sfL ${url}|grep image:|awk '{print $2}')
  do
    /usr/local/bin/k3s ctr i pull $image
  done
done

systemctl stop k3s