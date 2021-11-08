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

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install \
    git curl wget \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    conntrack \
    jq vim nano emacs joe \
    inotify-tools \
    socat make golang-go \
    unzip \
    bash-completion \
    dnsutils \
    iputils-ping

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

if [ "$K3S_VERSION" != "latest" ]; then
    export INSTALL_K3S_VERSION=$K3S_VERSION
fi

export INSTALL_K3S_SKIP_START=true
curl -sfL https://get.k3s.io | sh -

echo "alias k=kubectl" >> /root/.bash_aliases
kubectl completion bash >/etc/bash_completion.d/kubectl
mkdir -p /root/.kube
ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config
