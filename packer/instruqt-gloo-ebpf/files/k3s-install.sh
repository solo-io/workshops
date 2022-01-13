#!/bin/bash
set -ex

export HOME=/root

IP=$(ip addr show ens4 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo $IP > /etc/oldip

hostname kubernetes
hostnamectl set-hostname kubernetes
sed -i 's/localhost$/localhost kubernetes/' /etc/hosts

ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo "waiting 180 seconds for cloud-init to update /etc/apt/sources.list"
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install \
    git curl wget \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    conntrack \
    jq vim nano emacs joe \
    inotify-tools \
    socat make golang-go \
    unzip \
    bash-completion \
    dnsutils \
    iputils-ping \
    docker-ce docker-ce-cli containerd.io

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

if [ "$K3S_VERSION" != "latest" ]; then
    export INSTALL_K3S_VERSION=$K3S_VERSION
fi

mkdir -p /var/lib/rancher/k3s/server/manifests
touch /var/lib/rancher/k3s/server/manifests/traefik.yaml.skip

mkdir -p /etc/rancher/k3s
cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "http://kubernetes:5000"
EOF

export INSTALL_K3S_SKIP_START=true
curl -sfL https://get.k3s.io | sh -

echo "alias k=kubectl" >> /root/.bash_aliases
kubectl completion bash >/etc/bash_completion.d/kubectl
mkdir -p /root/.kube
ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config

wget https://dl.step.sm/gh-release/cli/docs-cli-install/v0.18.0/step-cli_0.18.0_amd64.deb
sudo dpkg -i step-cli_0.18.0_amd64.deb
