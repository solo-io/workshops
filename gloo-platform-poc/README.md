# Gloo Platform POC

This document will guide you through a Proof of Concept / Proof of Value of the Gloo  Platform including components Gloo Edge Gateway, Istio service mesh, and Gloo Mesh. The POC will be conducted assuming a multi-cluster set up consisting of two Kubernetes clusters. These two clusters should be connected with network connectivity, but they should be in their own networks (ie, overlapping CIDR range for Pod IPs is fine). 


## Success Criteria

TBD

## Lab environment and prep

We will use multiple CLI tools and two Kubernetes clusters for this POC. 

### Set up Kubernetes clusters for the POC

You will need two Kubernetes clusters for this workshop. See how to set up an environment using these platform-specific guides:

* [GKE](./platform-setup/gke.md)
* [EKS](./platform-setup/eks.md)
* [AKS](./platform-setup/aks.md)
* [OpenShift](./platform-setup/openshift.md)
* [Kind](./platform-setup/kind.md)


## Components and Clusters used for POC

One you've bootstrapped your Kubernetes clusters, you'll need to begin setting up the infrastructure for the POC. For this POC, we will assume two Kubernetes clusters `cluster 1` and `cluster 2`. The following will be deployed to each cluster to run the POC:

Cluster 1:
* Istio 
* Sample workloads
* Gloo Mesh agent
* Gloo Mesh Management Plane
* Gloo Edge
* Gloo Edge Federation

Cluster 2:
* Istio
* Sample workloads
* Gloo Mesh agent
* Gloo Edge


You can see above that there are some management/federation components that will be deployed onto `cluster 1`. In a real production environment, you'd want to deploy these _management_ components to their own cluster, however for this POC, we will reduce the number of clusters required by co-locating management components with workload components into the same cluster. 

The KUBECONFIG Kubernetes contexts are named `gloo-mesh-1` and `gloo-mesh-2` respectively for `cluster-1` and `cluster-2`. We will use environment variables to refer to the KUBECONFIG context for the following:

* `$CLUSTER_1` - Istio workloads for the first cluster
* `$CLUSTER_2` - Istio workloads for the second cluster
* `$MGMT_CONTEXT` - Management components (note as mentioned above, management components wil be co-located with the workloads in `cluster 1`)
 
In the POC, the following environment variables are expected to be set:

```bash
export CLUSTER_1=gloo-mesh-1
export CLUSTER_2=gloo-mesh-2
export MGMT_CONTEXT=gloo-mesh-2
```

If you've given your KUBECONFIG context names for `cluster 1` and `cluster 2` different names, update the environment variables accordingly.

See the script `env.sh` in the root of this POC source code for an example of how to set these variables.

## Running the POC

The POC is conducted in three separate sections:

1. Set up Istio, Gloo Mesh, Gloo Edge 
2. Set up sample applications across both clusters
3. Test out specific scenarios as outlined in the success criteria section

### POC Section 1: Set up Istio, Gloo Mesh, Gloo Edge

Note: You will need license keys for gloo mesh and edge corresponding to these environment variables:

```bash
export GLOO_LICENSE=<key here>
export GLOO_MESH_LICENSE=<key here>
```

Please reach out to your Solo.io account team to get these license keys before starting with Section 1 of the POC.

* [Step 1 - Install Istio on both clusters](./section1/install-istio.md)
* [Step 2 - Install Gloo Mesh Management Plane](./section1/install-gm.md)
* [Step 3 - Register Istio meshes with Management Plane](./section1/register-clusters.md)
* [Step 4 - Create VirtualMesh to manage multiple clusters of Istio](./section1/create-virtual-mesh.md)
* [Step 5 - Install Gloo Edge on both clusters](./section1/install-edge.md)
* [Step 6 - Install Gloo Edge Federation on Management Plane](./section1/install-fed.md)
* [Step 7 - Register Gloo Edge Gateways with Federation Plane](./section1/install-fed.md)

### POC Section 2: Set up and configure sample applications

* [Step 1 - Install sample apps in `istioinaction` namespace](./section2/install-apps.md)
* [Step 2 - Installing sleep app into sleep namespace](./section2/install-sleep.md)


### POC Section 3: Test specific scenarios

* [Scenario 1 - Verify connectivity between services](./section3/verify-connectivity.md)
* [Scenario 1 - Lock down all traffic in the mesh](./section3/01.md)
* [Scenario 1 - Enable access between two services in same cluster](./section3/02.md)
* [Scenario 1 - Create globally routable service names](./section3/02.md)
* [Scenario 1 - Enable access between two services in different cluster](./section3/02.md)
* [Scenario 1 - Demonstrate service failover across clusters](./section3/02.md)
* [Scenario 1 - Demonstrate service failover between edge gateways](./section3/02.md)


