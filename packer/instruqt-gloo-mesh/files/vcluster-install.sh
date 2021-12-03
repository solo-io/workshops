#!/bin/bash
mkdir -p /var/lib/rancher/k3s/server/manifests
touch /var/lib/rancher/k3s/server/manifests/traefik.yaml.skip
export K3S_NODE_NAME=kubernetes
systemctl daemon-reload
systemctl start k3s

while ! nc -z kubernetes 6443 -v; do sleep 1; done

# Install vcluster cli
curl -s -L "https://github.com/loft-sh/vcluster/releases/$VCLUSTER_VERSION" | sed -nE 's!.*"([^"]*vcluster-linux-amd64)".*!https://github.com\1!p' | xargs -n 1 curl -L -o vcluster && chmod +x vcluster;
sudo mv vcluster /usr/local/bin;

# Add some aliases to help
cat <<EOF >> /root/.bash_aliases
alias km='kubectl --context vcluster_mesh-1_mesh-1 '
alias k1='kubectl --context vcluster_mesh-2_mesh-2 '
alias k2='kubectl --context vcluster_mesh-3_mesh-3 '

alias kmg='kubectl --context vcluster_mesh-1_mesh-1 -n gloo-mesh '
alias k1i='kubectl --context vcluster_mesh-2_mesh-2 -n istio-system '
alias k2i='kubectl --context vcluster_mesh-3_mesh-3 -n istio-system '
EOF

# Load environment variables to .bashrc
cat <<EOF >> /root/.env
export MGMT=vcluster_mesh-1_mesh-1
export CLUSTER1=vcluster_mesh-2_mesh-2
export CLUSTER2=vcluster_mesh-3_mesh-3
EOF

# Install metallb
helm repo add metallb https://metallb.github.io/metallb
helm repo update
cat <<EOF >> /tmp/metallb-values.yaml
configInline:
  address-pools:
   - name: default
     protocol: layer2
     addresses:
     - 192.168.1.0/24
EOF
helm install metallb metallb/metallb --version=0.11.0 -f /tmp/metallb-values.yaml

# Create vclusters and add kubeconfigs
clusters=( mesh-2 mesh-3 mesh-1 )
for cluster in ${clusters[@]}; do
  vcluster create $cluster -n $cluster --expose
  # wait until IP is attached
  until [ "$SVC" != "" ]; do  SVC=$(kubectl -n $cluster get svc $cluster -o jsonpath='{.status.loadBalancer.ingress[0].*}'); echo "wait"; sleep 1; done
  vcluster connect $cluster -n $cluster --update-current
done

# Give some time for the nodes to be available
sleep 5

kubectl --context=vcluster_mesh-2_mesh-2 label node kubernetes ingress-ready=true topology.kubernetes.io/region=us-west topology.kubernetes.io/zone=us-west-1
kubectl --context=vcluster_mesh-3_mesh-3 label node kubernetes ingress-ready=true topology.kubernetes.io/region=us-west topology.kubernetes.io/zone=us-west-2

#/usr/local/bin/k3s-killall.sh
systemctl stop k3s
