#!/usr/bin/env bash
set -o errexit

number="3"
name="cluster2"
region=""
zone=""
twodigits=$(printf "%02d\n" $number)

kindest_node=${KINDEST_NODE}

if [ -z "$kindest_node" ]; then
  export k8s_version="1.32.0"

  [[ ${k8s_version::1} != 'v' ]] && export k8s_version=v${k8s_version}
  kindest_node_ver=$(curl --silent "https://registry.hub.docker.com/v2/repositories/kindest/node/tags?page_size=100" \
                      | jq -r '.results | .[] | select(.name==env.k8s_version) | .name+"@"+.digest')

  if [ -z "$kindest_node_ver" ]; then
    echo "Incorrect Kubernetes version provided: ${k8s_version}."
    exit 1
  fi
  kindest_node=kindest/node:${kindest_node_ver}
fi
echo "Using KinD image: ${kindest_node}"

if [ -z "$3" ]; then
  case $name in
    cluster1)
      region=us-west-1
      ;;
    cluster2)
      region=us-west-2
      ;;
    *)
      region=us-east-1
      ;;
  esac
fi

if [ -z "$4" ]; then
  case $name in
    cluster1)
      zone=us-west-1a
      ;;
    cluster2)
      zone=us-west-2a
      ;;
    *)
      zone=us-east-1a
      ;;
  esac
fi

if hostname -I 2>/dev/null; then
  myip=$(hostname -I | awk '{ print $1 }')
else
  myip=$(ipconfig getifaddr en0)
fi

# Function to determine the next available cluster number
get_next_cluster_number() {
    if ! kind get clusters 2>&1 | grep "^kind" > /dev/null; then
        echo 1
    else
        highest_num=$(kind get clusters | grep "^kind" | tail -1 | cut -c 5-)
        echo $((highest_num + 1))
    fi
}

if [ -f /.dockerenv ]; then
myip=$HOST_IP
container=$(docker inspect $(docker ps -q) | jq -r ".[] | select(.Config.Hostname == \"$HOSTNAME\") | .Name" | cut -d/ -f2)
docker network connect "kind" $container || true
number=$(get_next_cluster_number)
twodigits=$(printf "%02d\n" $number)
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

echo Contents of kind${number}.yaml
cat << EOF | tee kind${number}.yaml
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
- role: worker
  image: ${kindest_node}
  labels:
    ingress-ready: true
    topology.kubernetes.io/region: ${region}
    topology.kubernetes.io/zone: ${zone}
networking:
  serviceSubnet: "10.$(echo $twodigits | sed 's/^0*//').0.0/16"
  podSubnet: "10.1${twodigits}.0.0/16"
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
echo -----------------------------------------------------

kind create cluster --name kind${number} --config kind${number}.yaml
ipkind=$(docker inspect kind${number}-control-plane | jq -r '.[0].NetworkSettings.Networks[].IPAddress')
networkkind=$(echo ${ipkind} | awk -F. '{ print $1"."$2 }')
kubectl config set-cluster kind-kind${number} --server=https://${myip}:70${twodigits} --insecure-skip-tls-verify=true
# Preload images
cat << EOF >> images.txt
quay.io/metallb/controller:v0.14.9
quay.io/metallb/speaker:v0.14.9
EOF
sort images.txt | uniq | while read image; do
  docker pull $image || true
  kind load docker-image $image --name kind${number} || true
done
docker network connect "kind" "${reg_name}" || true
docker network connect "kind" docker || true
docker network connect "kind" us-docker || true
docker network connect "kind" us-central1-docker || true
docker network connect "kind" quay || true
docker network connect "kind" gcr || true
for i in 1 2 3 4 5; do kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml && break || sleep 15; done
kubectl --context=kind-kind${number} patch daemonset speaker -n metallb-system -p "
spec:
  template:
    spec:
      containers:
      - name: speaker
        args:
        - --port=7472
        - --log-level=info
        - --ignore-exclude-lb
"
kubectl --context=kind-kind${number} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl --context=kind-kind${number} -n metallb-system rollout status deploy controller || true

cat << EOF | tee metallb${number}.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${networkkind}.1${twodigits}.1-${networkkind}.1${twodigits}.254
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
