kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: 
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF