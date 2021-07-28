# Register meshes with management plane

We have installed Istio in two clusters and installed the Gloo Mesh management plane. Now we need to register the two Istio meshes with the management plane. Once the management plane knows about the two Istio meshes, it can discover workloads and set security and traffic policies as we'll see in [section 3](../section3/README.md)

## Prerequisites

Please see the assumptions we make about the environment [for this section](./README.md).

We will need to download the `meshctl` CLI tool for this step:

```bash
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v1.1.0-beta12 sh
```

## Getting the management plane address

Before we register the meshes, we need to know the location of the Gloo Mesh management plane registration port. Run the following

```bash
MGMT_INGRESS_ADDRESS=$(kubectl --context $MGMT_CONTEXT get svc -n gloo-mesh | grep '^enterprise-networking\s' | awk '{print $4}')
RELAY_ADDRESS=${MGMT_INGRESS_ADDRESS}:9900
```

{% hint style="warning" %}
You may have slightly different steps to get the Gloo Mesh management plane registration port depending on your networking stepup. Please reach out to Solo.io through your account team and we can assist.
{% endhint %}

## Register cluster 1

You may wish to source the `./scripts/env.sh` file with the correct values for the environment variables. 

```bash
source ./scripts/env.sh
```

Then run the following:

```bash
echo "Using Relay: $RELAY_ADDRESS"
meshctl cluster register enterprise --remote-context=$CLUSTER_1  --relay-server-address $RELAY_ADDRESS $CLUSTER_1_NAME
```

## Register cluster 2

You may wish to source the `./scripts/env.sh` file with the correct values for the environment variables. 

```bash
source ./scripts/env.sh
```

Then run the following:

```bash
echo "Using Relay: $RELAY_ADDRESS"
meshctl cluster register enterprise --remote-context=$CLUSTER_2  --relay-server-address $RELAY_ADDRESS $CLUSTER_2_NAME
```

## Understanding the registration process

Gloo Mesh management plane can automatically discover running meshes, services, and gateways. This allows the platform administrator and mesh user to write consistent configurations for managing security, traffic, and failover across multiple meshes with ease. We will prove this out in [section 3](../section3/README.md) of this POC.
