

# download meshctl

Gloo Mesh
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v1.1.0-beta12 sh

# set up ingress IP

MGMT_INGRESS_ADDRESS=$(kubectl --context $MGMT_CONTEXT get svc -n gloo-mesh enterprise-networking -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
RELAY_ADDRESS=${MGMT_INGRESS_ADDRESS}:9900

# cluster 1
echo "Registering cluster..."
echo "Using Relay: $RELAY_ADDRESS"
meshctl cluster register enterprise --remote-context=$CLUSTER_1  --relay-server-address $RELAY_ADDRESS $CLUSTER_1_NAME

# cluster 2

echo "Registering cluster..."
echo "Using Relay: $RELAY_ADDRESS"
meshctl cluster register enterprise --remote-context=$CLUSTER_2  --relay-server-address $RELAY_ADDRESS $CLUSTER_2_NAME

