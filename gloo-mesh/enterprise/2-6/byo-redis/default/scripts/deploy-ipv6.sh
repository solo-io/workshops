#!/usr/bin/env bash

number=$1
name=$2
region=$3
zone=$4
kindest_node=${KINDEST_NODE:-kindest\/node:v1.28.0@sha256:b7a4cad12c197af3ba43202d3efe03246b3f0793f162afb40a33c923952d5b31}
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
docker start "${reg_name}" 2>/dev/null || \
docker run -d --restart=always -p "0.0.0.0:${reg_port}:5000" --name "${reg_name}" registry:2

cache_port='5000'
cat > registries <<EOF
docker https://registry-1.docker.io
us-docker https://us-docker.pkg.dev
us-central1-docker https://us-central1-docker.pkg.dev
quay https://quay.io
gcr https://gcr.io
EOF

cat registries | while read cache_name cache_url; do
cat > ${HOME}/.${cache_name}-config.yml <<EOF
version: 0.1
proxy:
  remoteurl: ${cache_url}
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

docker start "${cache_name}" 2>/dev/null || \
docker run -d --restart=always ${DEPLOY_EXTRA_PARAMS} -v ${HOME}/.${cache_name}-config.yml:/etc/docker/registry/config.yml --name "${cache_name}" registry:2
done

cat << EOF > kind${number}.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: ${kindest_node}
  extraPortMappings:
  - containerPort: 6443
    hostPort: 70${twodigits}
  labels:
    ingress-ready: true
    topology.kubernetes.io/region: ${region}
    topology.kubernetes.io/zone: ${zone}
networking:
  ipFamily: ipv6
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["http://docker:${cache_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."us-docker.pkg.dev"]
    endpoint = ["http://us-docker:${cache_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."us-central1-docker.pkg.dev"]
    endpoint = ["http://us-central1-docker:${cache_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
    endpoint = ["http://quay:${cache_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
    endpoint = ["http://gcr:${cache_port}"]
EOF

kind create cluster --name kind${number} --config kind${number}.yaml

ipkind=$(docker inspect kind${number}-control-plane | jq -r '.[0].NetworkSettings.Networks[].GlobalIPv6Address')
networkkind=$(echo ${ipkind} | rev | cut -d: -f2- | rev):

#kubectl config set-cluster kind-kind${number} --server=https://${myip}:70${twodigits} --insecure-skip-tls-verify=true

docker network connect "kind" "${reg_name}" || true
docker network connect "kind" docker || true
docker network connect "kind" us-docker || true
docker network connect "kind" us-central1-docker || true
docker network connect "kind" quay || true
docker network connect "kind" gcr || true

# Preload images
cat << EOF >> images.txt
quay.io/metallb/controller:v0.14.8
quay.io/metallb/speaker:v0.14.8
EOF
cat images.txt | while read image; do
  docker pull $image || true
  kind load docker-image $image --name kind${number} || true
done
for i in 1 2 3 4 5; do kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml && break || sleep 15; done
kubectl --context=kind-kind${number} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl --context=kind-kind${number} -n metallb-system rollout status deploy controller || true

cat << EOF > metallb${number}.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${networkkind}${number}1-${networkkind}${number}9
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF

printf "Create IPAddressPool in kind-kind${number}\n"
for i in {1..10}; do
kubectl --context=kind-kind${number} apply -f metallb${number}.yaml && break
sleep 2
done

# connect the registry to the cluster network if not already connected
printf "Renaming context kind-kind${number} to ${name}\n"
for i in {1..100}; do
  (kubectl config get-contexts -oname | grep ${name}) && break
  kubectl config rename-context kind-kind${number} ${name} && break
  printf " $i"/100
  sleep 2
  [ $i -lt 100 ] || exit 1
done

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl --context=${name} apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
