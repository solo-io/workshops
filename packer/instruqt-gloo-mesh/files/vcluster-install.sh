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
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

cat << EOF | kubectl apply -f -
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
      - 192.168.1.230-192.168.1.250
EOF


# Create vclusters and add kubeconfigs
clusters=( mesh-1 mesh-2 mesh-3 )
for cluster in ${clusters[@]}; do
  vcluster create $cluster -n $cluster --expose
  # wait until IP is attached
  until [ "$SVC" != "" ]; do  SVC=$(kubectl -n $cluster get svc $cluster -o jsonpath='{.status.loadBalancer.ingress[0].*}'); echo "wait"; sleep 1; done
  vcluster connect $cluster -n $cluster --update-current
done

kubectl --context=vcluster_mesh-2_mesh-2 label node kubernetes ingress-ready=true
kubectl --context=vcluster_mesh-2_mesh-2 label node kubernetes topology.kubernetes.io/region=us-west
kubectl --context=vcluster_mesh-2_mesh-2 label node kubernetes topology.kubernetes.io/zone=us-west-1

kubectl --context=vcluster_mesh-3_mesh-3 label node kubernetes ingress-ready=true
kubectl --context=vcluster_mesh-3_mesh-3 label node kubernetes topology.kubernetes.io/region=us-west
kubectl --context=vcluster_mesh-3_mesh-3 label node kubernetes topology.kubernetes.io/zone=us-west-2

systemctl stop k3s
