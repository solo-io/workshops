

# cluster 1

kubectl --context $CLUSTER_1 create ns sleep
kubectl --context $CLUSTER_1 label ns sleep istio-injection=enabled
kubectl --context $CLUSTER_1 apply -f resources/sleep.yaml -n sleep

kubectl --context $CLUSTER_1 label ns default istio-injection-
kubectl --context $CLUSTER_1 apply -f resources/sleep.yaml -n default




# cluster 2

kubectl --context $CLUSTER_2 create ns sleep
kubectl --context $CLUSTER_2 label ns sleep istio-injection=enabled
kubectl --context $CLUSTER_2 apply -f resources/sleep.yaml -n sleep

kubectl --context $CLUSTER_2 label ns default istio-injection-
kubectl --context $CLUSTER_2 apply -f resources/sleep.yaml -n default