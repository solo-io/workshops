

## Prerequisites

Please see the assumptions we make about the environment [for this section](./README.md).

# download glooctl

curl -sL https://run.solo.io/gloo/install | GLOO_VERSION=v1.7.11 sh
export PATH=$HOME/.gloo/bin:$PATH

# register cluster 1

# Register cluster for gloo federation
# unfortunately, glooctl doesn't allow for context passing, so we ahve to switch to it
kubectl config use-context $MGMT_CONTEXT
glooctl cluster register --cluster-name cluster-1 --remote-context $CLUSTER_1
kubectl --context $CLUSTER_1 apply -f ./gloo/certs/secrets/edge-west-failover-downstream.yaml
kubectl --context $CLUSTER_1 apply -f ./gloo/certs/secrets/edge-west-failover-upstream.yaml
kubectl --context $CLUSTER_1 apply -f ./resources/gloo-ingress/web-api-ingress.yaml
kubectl --context $CLUSTER_1 apply -f ./resources/gloo-ingress/web-api-upstream-istio-mtls.yaml


# register cluster 2

kubectl config use-context $MGMT_CONTEXT
glooctl cluster register --cluster-name cluster-2 --remote-context $CLUSTER_2
kubectl --context $CLUSTER_2 apply -f ./gloo/certs/secrets/edge-east-failover-downstream.yaml
kubectl --context $CLUSTER_2 apply -f ./gloo/certs/secrets/edge-east-failover-upstream.yaml
kubectl --context $CLUSTER_2 apply -f ./resources/gloo-ingress/web-api-ingress.yaml
kubectl --context $CLUSTER_2 apply -f ./resources/gloo-ingress/web-api-upstream-istio-mtls.yaml
