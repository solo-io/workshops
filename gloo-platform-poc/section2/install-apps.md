# Install sample apps in istioinaction namespace

## cluster 1

echo "Installing sample apps" kubectl --context $CLUSTER\_1 create ns istioinaction kubectl --context $CLUSTER\_1 label ns istioinaction istio-injection=enabled kubectl --context $CLUSTER\_1 apply -k resources/sample-apps/overlays/cluster1 -n istioinaction

## cluster 2

echo "Installing sample apps" kubectl --context $CLUSTER\_2 create ns istioinaction kubectl --context $CLUSTER\_2 label ns istioinaction istio-injection=enabled kubectl --context $CLUSTER\_2 apply -k resources/sample-apps/overlays/cluster2 -n istioinaction

