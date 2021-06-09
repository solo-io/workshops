curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

# create docker network if it does not exist
network=demo-1
docker network create $network || true

# setup the cluster
k3d cluster create istiocluster --image "rancher/k3s:v1.20.2-k3s1" --k3s-server-arg "--disable=traefik" --network $network

kube_ctx=k3d-istiocluster
k3d kubeconfig get istiocluster > ~/.kube/istiocluster