# Installing sleep app into sleep namespace

## cluster 1

kubectl --context $CLUSTER\_1 create ns sleep kubectl --context $CLUSTER\_1 label ns sleep istio-injection=enabled kubectl --context $CLUSTER\_1 apply -f resources/sleep.yaml -n sleep

kubectl --context $CLUSTER\_1 label ns default istio-injection- kubectl --context $CLUSTER\_1 apply -f resources/sleep.yaml -n default

## cluster 2

kubectl --context $CLUSTER\_2 create ns sleep kubectl --context $CLUSTER\_2 label ns sleep istio-injection=enabled kubectl --context $CLUSTER\_2 apply -f resources/sleep.yaml -n sleep

kubectl --context $CLUSTER\_2 label ns default istio-injection- kubectl --context $CLUSTER\_2 apply -f resources/sleep.yaml -n default

