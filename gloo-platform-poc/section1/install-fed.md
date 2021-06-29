helm repo add gloo-fed https://storage.googleapis.com/gloo-fed-helm
helm repo update
kubectl --context $MGMT_CONTEXT create namespace gloo-fed
helm install -n gloo-fed gloo-fed gloo-fed/gloo-fed --kube-context $MGMT_CONTEXT --version 1.7.7 --set license_key=$GLOO_LICENSE