# Solo.io workshops

## Gloo Edge workshops

- [Gloo Edge Workshop](gloo-edge/README.md)
- [Gloo Portal Workshop](gloo-portal/README.md)

## Gloo Mesh workshops

- [Gloo Mesh Workshop](gloo-mesh-2-2/default/README.md) - this is the standard workshop based on KinD and 3 Kubernetes clusters
- [Gloo Mesh Workshop using NodePort services](gloo-mesh-2-2/node-ports/README.md) - this is the same as the standard workshop but using NodePort services instead of LoadBalancer services
- [Gloo Mesh Workshop airgap](gloo-mesh-2-2/airgap/README.md) - this is the same as the standard workshop but downloading all the Docker images to show how to deploy everythin in an airgap environment
- [Gloo Mesh Workshop on Openshift](gloo-mesh-2-2/openshift/README.md) - this is the same as the standard workshop but based on 3 Openshift clusters
- [Gloo Mesh Workshop on EKS and Openshift](gloo-mesh-2-2/eks-and-openshift/README.md) - this is the same as the standard workshop but with cluster1 being an Openshift cluster and the other ones (mgmt and cluster2) being EKS clusters
- [Gloo Mesh Workshop using a single workspace](gloo-mesh-2-2/single-workspace/README.md) - this is the same as the standard workshop but with a single workspace (when no multi-tenancy is needed)
- [Gloo Mesh Workshop using a single cluster](gloo-mesh-2-2/single-cluster/README.md) - this is a workshop based on a single Kubernetes cluster (for both the management plane and Istio) which shows all the benefits when multi-cluster capabilities are not (yet) needed
- [Gloo Mesh Workshop using a single workspace on a single cluster](gloo-mesh-2-2/single-cluster-single-workspace/README.md) - this is a combination of the single cluster and the single workspace workshops 
