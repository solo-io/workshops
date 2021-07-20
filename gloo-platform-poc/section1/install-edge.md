# Install Gloo Edge on both clusters

## cluster 1

source ~/bin/gloo-license-key-env helm install gloo-edge glooe/gloo-ee --kube-context $CLUSTER\_1 -f ./gloo/values-west.yaml --version 1.7.7 --create-namespace --namespace gloo-system --set gloo.crds.create=true --set-string license\_key=$GLOO\_LICENSE

kubectl --context $CLUSTER\_1 rollout status deploy/gloo -n gloo-system kubectl --context $CLUSTER\_1 rollout status deploy/gateway-proxy -n gloo-system

## cluster 2

source ~/bin/gloo-license-key-env helm install gloo-edge glooe/gloo-ee --kube-context $CLUSTER\_2 -f ./gloo/values-east.yaml --version 1.7.7 --create-namespace --namespace gloo-system --set gloo.crds.create=true --set-string license\_key=$GLOO\_LICENSE

kubectl --context $CLUSTER\_2 rollout status deploy/gloo -n gloo-system kubectl --context $CLUSTER\_2 rollout status deploy/gateway-proxy -n gloo-system

