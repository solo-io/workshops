# Create VirtualMesh to manage multiple clusters of Istio

kubectl --context $MGMT\_CONTEXT apply -f resources/virtual-mesh.yaml

. ./scripts/check-virtualmesh.sh

