number=$1

if hostname -i; then
  myip=$(hostname -i)
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
    hostPort: ${number}000
  - containerPort: ${number}2000
    hostPort: ${number}2000
    protocol: TCP
networking:
  disableDefaultCNI: true
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
  networking:
    serviceSubnet: "10.96.$1.0/24"
    podSubnet: "192.168.$1.0/24"
- |
  kind: InitConfiguration
  nodeRegistration:
    kubeletExtraArgs:
      node-labels: "topology.kubernetes.io/region=us-east-1,topology.kubernetes.io/zone=us-east-1c"
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
EOF

kind create cluster --name kind${number} --config kind${number}.yaml

ipkind=$(docker inspect kind${number}-control-plane | jq -r '.[0].NetworkSettings.Networks[].IPAddress')
networkkind=$(echo ${ipkind} | sed 's/.$//')

kubectl config set-cluster kind-kind${number} --server=https://${myip}:${number}000 --insecure-skip-tls-verify=true

kubectl --context=kind-kind${number} apply -f https://docs.projectcalico.org/v3.15/manifests/calico.yaml
kubectl --context=kind-kind${number} -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true

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
      - ${networkkind}2${number}0-${networkkind}2${number}9
EOF

kubectl --context=kind-kind${number} apply -f metallb${number}.yaml

docker network connect "kind" "${reg_name}" || true

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

kubectl config rename-context kind-kind${number} $2