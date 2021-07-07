# Section 1: Set up POC 

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

See the script `./scripts/env.sh` in the root of this POC source code for an example of how to set these variables.

## License Keys for the Solo.io products

You will need license keys for gloo mesh and edge corresponding to these environment variables:

```bash
export GLOO_LICENSE=<key here>
export GLOO_MESH_LICENSE=<key here>
```

Please reach out to your Solo.io account team to get these license keys before starting with Section 1 of the POC.