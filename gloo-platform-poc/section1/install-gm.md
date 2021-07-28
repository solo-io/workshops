# Install Gloo Mesh Management Plane

In this step, we install the Gloo Mesh management plane to simplify operations across multiple clusters including federation, security, and service failover.

## Prerequisites

Please see the assumptions we make about the environment [for this section](./README.md).

We will also need license keys to install Gloo Mesh Management plane. Make sure you have these environment variables populated with valid keys:


```bash
export GLOO_LICENSE=<key here>
export GLOO_MESH_LICENSE=<key here>
```

## Install with Helm

Make sure you're using the $MGMT_CONTEXT cluster and then add the correct Helm Repo:

```bash
kubectl config use-context $MGMT_CONTEXT

helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise

helm repo update
```

Next, create the `gloo-mesh` namespace and install using Helm:

```bash
kubectl create namespace gloo-mesh

# Helm Install GM
helm install gloo-mesh-enterprise gloo-mesh-enterprise/gloo-mesh-enterprise --kube-context $MGMT_CONTEXT -n gloo-mesh --version=1.1.0-beta11 --set licenseKey=${GLOO_MESH_LICENSE} --set rbac-webhook.enabled=false --set metricsBackend.prometheus.enabled=true
```

Lastly, validate the installation happened correctly:

```bash
kubectl --context $MGMT_CONTEXT -n gloo-mesh rollout status deploy/enterprise-networking 
kubectl --context $MGMT_CONTEXT -n gloo-mesh rollout status deploy/dashboard
kubectl --context $MGMT_CONTEXT -n gloo-mesh rollout status deploy/prometheus-server 
```

## Understanding the Gloo Mesh management plane

The Gloo Mesh management plane gives a single source of control over multiple service meshes running in multiple clusters. This will greatly simplify solving our intended usecases as we see in [section 3](../section3/README.md)