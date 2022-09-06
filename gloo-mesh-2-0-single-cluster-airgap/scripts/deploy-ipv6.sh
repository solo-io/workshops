#!/usr/bin/env bash

number=$1
name=$2
region=$3
zone=$4
twodigits=$(printf "%02d\n" $number)
# https://www.site24x7.com/tools/ipv6-subnetcalculator.html
metalLBSubnet=(null 2001:db8::100/120 2001:db8::200/120 2001:db8::300/120)

if [ -z "$3" ]; then
  region=us-east-1
fi

if [ -z "$4" ]; then
  zone=us-east-1a
fi

if hostname -I; then
  myip=$(hostname -I | awk '{ print $1 }')
else
  myip=$(ipconfig getifaddr en0)
fi

reg_name='kind-registry'
reg_port='5000'
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

cache_name='kind-cache'
cache_port='5000'
running="$(docker inspect -f '{{.State.Running}}' "${cache_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  cat > config.yml <<EOF
version: 0.1
proxy:
  remoteurl: https://registry-1.docker.io
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF

  docker run \
    -d --restart=always -v `pwd`/config.yml:/etc/docker/registry/config.yml --name "${cache_name}" \
    registry:2
fi

cat << EOF > kind${number}.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 6443
    hostPort: 70${twodigits}
networking:
  ipFamily: ipv6
kubeadmConfigPatches:
- |
  kind: InitConfiguration
  nodeRegistration:
    kubeletExtraArgs:
      node-labels: "ingress-ready=true,topology.kubernetes.io/region=${region},topology.kubernetes.io/zone=${zone}"
EOF

kind create cluster --name kind${number} --config kind${number}.yaml

kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl --context=kind-kind${number} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

ipkind=$(docker inspect kind${number}-control-plane | jq -r '.[0].NetworkSettings.Networks[].GlobalIPv6Address')
networkkind=$(echo ${ipkind} | rev | cut -d: -f2- | rev):

cat << EOF > metallb${number}.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${networkkind}${number}1-${networkkind}${number}9
EOF

kubectl --context=kind-kind${number} apply -f metallb${number}.yaml

kubectl config rename-context kind-kind${number} ${name}