# Install Istio into two clusters

# download istio CLI 1.10.2

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.10.2 sh -
should add istioctl to path...
export PATH=$ISTIO_LOCATION/bin:$PATH


## Set up on cluster 1

istioctl --context $CLUSTER_1 install -y -f ./resources/istio/istio-control-plane-c1.yaml

# fips
istioctl --context $CLUSTER_1 install -y -f ./resources/istio/fips/istio-control-plane-c1.yaml

# enable peer auth
kubectl --context $CLUSTER_1 apply -f ./resources/istio/default-peer-authentication.yaml



## Set up on cluster 2

istioctl --context $CLUSTER_2 install -y -f ./resources/istio/istio-control-plane-c2.yaml

# fips
istioctl --context $CLUSTER_2 install -y -f ./resources/istio/fips/istio-control-plane-c2.yaml

# enable peer auth
kubectl --context $CLUSTER_2 apply -f ./resources/istio/default-peer-authentication.yaml


# notes
Note, we are working at solo to improve the experience of installation much better, stay tuned!
