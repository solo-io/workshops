#!/usr/bin/env bash
set -o errexit

number="1"
name="mgmt"
region=""
zone=""
twodigits=$(printf "%02d\n" $number)

kindest_node=${KINDEST_NODE}

if [ -z "$kindest_node" ]; then
  export k8s_version="1.30.8"

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
mkdir -p /tmp/oidc

cat <<'EOF' >/tmp/oidc/sa-signer-pkcs8.pub
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA53YiBcrn7+ZK0Vb4odeA
1riYdvEb8To4H6/HtF+OKzuCIXFQ+bRy7yMrDGITYpfYPrTZOgfdeTLZqOiAj+cL
395nvxdly83SUrdh7ItfOPRluuuiPHnFn111wpyjBw5nut4Kx+M5MksNfA1hU0Zw
zIM9OviX8iEF8xHWUtz4BAMDG8N6+zpLo0pAzaei5hKuLZ9dZOzHBC8VOW82cQMm
5X5uOKsCHMtNSjqYUNB1DxN6xxM+odGWT/6xthPGk6YCxmO28YHPFZfiS2eAIpD8
2p/16KQKU6TkZSrldkYxiHIPhu+5f9faZJG7dB9pLN1SfdTBio4PK5Mz9muLUCv9
ywIDAQAB
-----END PUBLIC KEY-----
EOF

cat <<'EOF' >/tmp/oidc/sa-signer.key
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA53YiBcrn7+ZK0Vb4odeA1riYdvEb8To4H6/HtF+OKzuCIXFQ
+bRy7yMrDGITYpfYPrTZOgfdeTLZqOiAj+cL395nvxdly83SUrdh7ItfOPRluuui
PHnFn111wpyjBw5nut4Kx+M5MksNfA1hU0ZwzIM9OviX8iEF8xHWUtz4BAMDG8N6
+zpLo0pAzaei5hKuLZ9dZOzHBC8VOW82cQMm5X5uOKsCHMtNSjqYUNB1DxN6xxM+
odGWT/6xthPGk6YCxmO28YHPFZfiS2eAIpD82p/16KQKU6TkZSrldkYxiHIPhu+5
f9faZJG7dB9pLN1SfdTBio4PK5Mz9muLUCv9ywIDAQABAoIBAB8tro+RMYUDRHjG
el9ypAxIeWEsQVNRQFYkW4ZUiNYSAgl3Ni0svX6xAg989peFVL+9pLVIcfDthJxY
FVlNCjBxyQ/YmwHFC9vQkARJEd6eLUXsj8INtS0ubbp1VxCQRDDL0C/0z7OSoJJh
SwboqjEiTJExA2a+RArmEDTBRzdi3t+kT8G23JcqOivrITt17K6bQYyJXw7/vUdc
r/R+hfd5TqVq92VddzDT7RNJAxsbPPXjGnESlq1GALBDs+uBGYsP0fiEJb2nicSv
z9fBnBeERhut1gcE0C0iLRQZb+3r8TitBtxrZv+0BHgXrkKtXDwWTqGEKOwC4dBn
7nxkH2ECgYEA6+/DOTABGYOWOQftFkJMjcugzDrjoGpuXuVOTb65T+3FHAzU93zy
3bt3wQxrlugluyy9Sc/PL3ck2LgUsPHZ+s7zsdGvvGALBD6bOSSKATz9JgjwifO8
PgqUz1kXRwez2CtKLOOCFFtcIzEdWIzsa1ubNqLzgN7rD+XBkUc2uEcCgYEA+yTy
72EDMQVoIZOygytHsDNdy0iS2RsBbdurT27wkYuFpFUVWdbNSL+8haE+wJHseHcw
BD4WIMpU+hnS4p4OO8+6V7PiXOS5E/se91EJigZAoixgDUiC8ihojWgK9PYEavUo
hULWbayO59SxYWeUI4Ze0GP8Jw8vdB86ib4ulF0CgYEAgyzRuLjk05+iZODwQyDn
WSquov3W0rh51s7cw0LX2wWSQm8r9NGGYhs5kJ5sLwGxAKj2MNSWF4jBdrCZ6Gr+
y4BGY0X209/+IAUC3jlfdSLIiF4OBlT6AvB1HfclhvtUVUp0OhLfnpvQ1UwYScRI
KcRLvovIoIzP2g3emfwjAz8CgYEAxUHhOhm1mwRHJNBQTuxok0HVMrze8n1eov39
0RcvBvJSVp+pdHXdqX1HwqHCmxhCZuAeq8ZkNP8WvZYY6HwCbAIdt5MHgbT4lXQR
f2l8F5gPnhFCpExG5ZLNg/urV3oAQE4stHap21zEpdyOMhZb6Yc5424U+EzaFdgN
b3EcPtUCgYAkKvUlSnBbgiJz1iaN6fuTqH0efavuFGMhjNmG7GtpNXdgyl1OWIuc
Yu+tZtHXtKYf3B99GwPrFzw/7yfDwae5YeWmi2/pFTH96wv3brJBqkAWY8G5Rsmd
qF50p34vIFqUBniNRwSArx8t2dq/CuAMgLAtSjh70Q6ZAnCF85PD8Q==
-----END RSA PRIVATE KEY-----
EOF

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
  extraMounts:
  - containerPath: /etc/kubernetes/oidc
    hostPath: /tmp/oidc
  labels:
    ingress-ready: true
    topology.kubernetes.io/region: ${region}
    topology.kubernetes.io/zone: ${zone}
networking:
  serviceSubnet: "10.$(echo $twodigits | sed 's/^0*//').0.0/16"
  podSubnet: "10.1${twodigits}.0.0/16"
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      service-account-key-file: /etc/kubernetes/pki/sa.pub
      service-account-key-file: /etc/kubernetes/oidc/sa-signer-pkcs8.pub
      service-account-signing-key-file: /etc/kubernetes/oidc/sa-signer.key
      service-account-issuer: https://solo-workshop-oidc.s3.us-east-1.amazonaws.com
      api-audiences: sts.amazonaws.com
    extraVolumes:
    - name: oidc
      hostPath: /etc/kubernetes/oidc
      mountPath: /etc/kubernetes/oidc
      readOnly: true
  metadata:
    name: config
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
