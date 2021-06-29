

# cluster 1
echo "Installing sample apps"
kubectl --context $CLUSTER_1 create ns istioinaction
kubectl --context $CLUSTER_1 label ns istioinaction istio-injection=enabled
kubectl --context $CLUSTER_1 apply -k resources/sample-apps/overlays/cluster1 -n istioinaction

# cluster 2


echo "Installing sample apps"
kubectl --context $CLUSTER_2 create ns istioinaction
kubectl --context $CLUSTER_2 label ns istioinaction istio-injection=enabled
kubectl --context $CLUSTER_2 apply -k resources/sample-apps/overlays/cluster2 -n istioinaction