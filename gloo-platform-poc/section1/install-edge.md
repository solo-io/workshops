# cluster 1
source ~/bin/gloo-license-key-env 
helm install gloo-edge glooe/gloo-ee --kube-context $CLUSTER_1 -f ./gloo/values-west.yaml --version 1.7.7 --create-namespace --namespace gloo-system --set gloo.crds.create=true --set-string license_key=$GLOO_LICENSE

kubectl --context $CLUSTER_1 rollout status deploy/gloo -n gloo-system 
kubectl --context $CLUSTER_1 rollout status deploy/gateway-proxy -n gloo-system 


# cluster 2
source ~/bin/gloo-license-key-env 
helm install gloo-edge glooe/gloo-ee --kube-context $CLUSTER_2 -f ./gloo/values-east.yaml --version 1.7.7 --create-namespace --namespace gloo-system --set gloo.crds.create=true --set-string license_key=$GLOO_LICENSE

kubectl --context $CLUSTER_2 rollout status deploy/gloo -n gloo-system
kubectl --context $CLUSTER_2 rollout status deploy/gateway-proxy -n gloo-system 