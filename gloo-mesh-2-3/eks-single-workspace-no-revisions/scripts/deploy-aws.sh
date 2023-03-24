#!/usr/bin/env bash
# Here we use the script that includes the certificates to be able to execute some test lambda functions. If you are not going to try the lambda integration, you can use the `deploy.sh` script instead.

set -o errexit

number=$1
name=$2
region=$3
zone=$4
twodigits=$(printf "%02d\n" $number)
kindest_node='kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315'

if [ -z "$3" ]; then
  region=us-east-1
fi

if [ -z "$4" ]; then
  zone=us-east-1a
fi

if hostname -I 2>/dev/null; then
  myip=$(hostname -I | awk '{ print $1 }')
else
  myip=$(ipconfig getifaddr en0)
fi

reg_name='kind-registry'
reg_port='5000'
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "0.0.0.0:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

cache_port='5000'
cat > registries <<EOF
docker https://registry-1.docker.io
us-docker https://us-docker.pkg.dev
us-central1-docker https://us-central1-docker.pkg.dev
quay https://quay.io
gcr https://gcr.io
EOF

cat registries | while read cache_name cache_url; do
running="$(docker inspect -f '{{.State.Running}}' "${cache_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
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

  docker run \
    -d --restart=always -v ${HOME}/.${cache_name}-config.yml:/etc/docker/registry/config.yml --name "${cache_name}" \
    registry:2
fi
done

mkdir -p oidc

cat <<EOF >./oidc/sa-signer-pkcs8.pub
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

cat <<EOF >./oidc/sa-signer.key
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

cat << EOF > kind${number}.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
featureGates:
  EphemeralContainers: true
nodes:
- role: control-plane
  image: ${kindest_node}
  extraPortMappings:
  - containerPort: 6443
    hostPort: 70${twodigits}
  extraMounts:
  - containerPath: /etc/kubernetes/oidc
    hostPath: /${PWD}/oidc
networking:
  serviceSubnet: "10.$(echo $twodigits | sed 's/^0*//').0.0/16"
  podSubnet: "10.1${twodigits}.0.0/16"
kubeadmConfigPatches:
- |
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      "service-account-key-file": /etc/kubernetes/pki/sa.pub
      "service-account-key-file": /etc/kubernetes/oidc/sa-signer-pkcs8.pub
      "service-account-signing-key-file": /etc/kubernetes/oidc/sa-signer.key
      "service-account-issuer": https://solo-workshop-oidc.s3.us-east-1.amazonaws.com
      "api-audiences": sts.amazonaws.com
    extraVolumes:
    - name: oidc
      hostPath: /etc/kubernetes/oidc
      mountPath: /etc/kubernetes/oidc
      readOnly: true
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

ipkind=$(docker inspect kind${number}-control-plane | jq -r '.[0].NetworkSettings.Networks[].IPAddress')
networkkind=$(echo ${ipkind} | awk -F. '{ print $1"."$2 }')

kubectl config set-cluster kind-kind${number} --server=https://${myip}:70${twodigits} --insecure-skip-tls-verify=true

kubectl --context=kind-kind${number} apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
kubectl --context=kind-kind${number} create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl --context=kind-kind${number} -n metallb-system rollout status deploy controller

cat << EOF > metallb${number}.yaml
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

kubectl --context=kind-kind${number} apply -f metallb${number}.yaml

# connect the registry to the cluster network if not already connected
docker network connect "kind" "${reg_name}" || true
docker network connect "kind" docker || true
docker network connect "kind" us-docker || true
docker network connect "kind" us-central1-docker || true
docker network connect "kind" quay || true
docker network connect "kind" gcr || true

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

