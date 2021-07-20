# Register Gloo Edge Gateways with Federation Plane

helm repo add gloo-fed [https://storage.googleapis.com/gloo-fed-helm](https://storage.googleapis.com/gloo-fed-helm) helm repo update kubectl --context $MGMT\_CONTEXT create namespace gloo-fed helm install -n gloo-fed gloo-fed gloo-fed/gloo-fed --kube-context $MGMT\_CONTEXT --version 1.7.7 --set license\_key=$GLOO\_LICENSE

