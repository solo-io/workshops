# Install Istio on both clusters

## Install Istio into two clusters

## download istio CLI 1.10.2

curl -L [https://istio.io/downloadIstio](https://istio.io/downloadIstio) \| ISTIO\_VERSION=1.10.2 sh - should add istioctl to path... export PATH=$ISTIO\_LOCATION/bin:$PATH

### Set up on cluster 1

istioctl --context $CLUSTER\_1 install -y -f ./resources/istio/istio-control-plane-c1.yaml

## fips

istioctl --context $CLUSTER\_1 install -y -f ./resources/istio/fips/istio-control-plane-c1.yaml

## enable peer auth

kubectl --context $CLUSTER\_1 apply -f ./resources/istio/default-peer-authentication.yaml

### Set up on cluster 2

istioctl --context $CLUSTER\_2 install -y -f ./resources/istio/istio-control-plane-c2.yaml

## fips

istioctl --context $CLUSTER\_2 install -y -f ./resources/istio/fips/istio-control-plane-c2.yaml

## enable peer auth

kubectl --context $CLUSTER\_2 apply -f ./resources/istio/default-peer-authentication.yaml

## notes

Note, we are working at solo to improve the experience of installation much better, stay tuned!

