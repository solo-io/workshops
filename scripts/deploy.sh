number=$1
name=$2
region=$3
zone=$4
twodigits=$(printf "%02d\n" $number)

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
featureGates:
  TokenRequest: true
  EphemeralContainers: true
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 6443
    hostPort: 70${twodigits}
networking:
  disableDefaultCNI: true
  serviceSubnet: "10.0${twodigits}.0.0/16"
  podSubnet: "10.1${twodigits}.0.0/16"
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      service-account-signing-key-file: /etc/kubernetes/pki/sa.key
      service-account-key-file: /etc/kubernetes/pki/sa.pub
      service-account-issuer: api
      service-account-api-audiences: api,vault,factors
  metadata:
    name: config
- |
  kind: InitConfiguration
  nodeRegistration:
    kubeletExtraArgs:
      node-labels: "ingress-ready=true,topology.kubernetes.io/region=${region},topology.kubernetes.io/zone=${zone}"
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["http://${cache_name}:${cache_port}"]
EOF

kind create cluster --name kind${number} --config kind${number}.yaml

ipkind=$(docker inspect kind${number}-control-plane | jq -r '.[0].NetworkSettings.Networks[].IPAddress')
networkkind=$(echo ${ipkind} | awk -F. '{ print $1"."$2 }')

kubectl config set-cluster kind-kind${number} --server=https://${myip}:70${twodigits} --insecure-skip-tls-verify=true

kubectl --context=kind-kind${number} apply -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml

kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl --context=kind-kind${number} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

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
      - ${networkkind}.0${twodigits}.1-${networkkind}.0${twodigits}.254
EOF

kubectl --context=kind-kind${number} apply -f metallb${number}.yaml

docker network connect "kind" "${reg_name}" || true
docker network connect "kind" "${cache_name}" || true

cat <<EOF | kubectl apply -f -
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

kubectl config rename-context kind-kind${number} ${name}
