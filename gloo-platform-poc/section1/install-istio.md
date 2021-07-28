# Install Istio into two clusters

In this step, we'll install Gloo Mesh Istio into two Kubernetes clusters. You can choose to install an upstream build of Istio or a FIPS variant.

## Prerequisites

Please see the assumptions we make about the environment [for this section](./README.md).

We will also need the Istio CLI. Let's download the Istio CLI as follows:

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.10.2 sh -
```

You should also place the Istio CLI on your system path. This may vary depending on your OS platform:

```bash
export PATH=$ISTIO_LOCATION/bin:$PATH
```

## Install Istio on cluster 1

Next, use the Istio CLI to install Istio on `cluster 1`

```bash
istioctl --context $CLUSTER_1 install -y -f ./resources/istio/istio-control-plane-c1.yaml
```

Let's also enable mTLS for all workloads in the mesh:

```bash
kubectl --context $CLUSTER_1 apply -f ./resources/istio/default-peer-authentication.yaml
```

{% hint style="success" %}
If you need FIPS builds of Istio, you can install with the following:

```bash
# fips
istioctl --context $CLUSTER_1 install -y -f ./resources/istio/fips/istio-control-plane-c1.yaml
```
{% endhint %}

To verify Istio was installed, check the `istio-system` namespace:

```bash
kubectl --context $CLUSTER_1 get po -n istio-system 
```

You should see something similar to this:

```
NAME                                READY   STATUS    RESTARTS   AGE
east-west-gateway-96d8574cc-f8c4j   1/1     Running   0          32s
istiod-5b886994fd-gc4x8             1/1     Running   0          42s
```




## Set up on cluster 2

Next, use the Istio CLI to install Istio on `cluster 2`

```bash
istioctl --context $CLUSTER_2 install -y -f ./resources/istio/istio-control-plane-c2.yaml
```

Let's also enable mTLS for all workloads in the mesh:

```bash
kubectl --context $CLUSTER_2 apply -f ./resources/istio/default-peer-authentication.yaml
```

{% hint style="success" %}
If you need FIPS builds of Istio, you can install with the following:

```bash
# fips
istioctl --context $CLUSTER_2 install -y -f ./resources/istio/fips/istio-control-plane-c2.yaml
```
{% endhint %}

To verify Istio was installed, check the `istio-system` namespace:

```bash
kubectl --context $CLUSTER_2 get po -n istio-system 
```

You should see something similar to this:

```
NAME                                READY   STATUS    RESTARTS   AGE
east-west-gateway-96d8574cc-f8c4j   1/1     Running   0          32s
istiod-5b886994fd-gc4x8             1/1     Running   0          42s
```

## Understanding the Istio deployment

We deployed Istio using a `minimal` profile with an `east-west` gateway. We use an `east-west` gateway to handle any of the cross-cluster traffic. It will be secured and configured differently than traffic entering out cluster from an untrusted source. We will use either Gloo Edge or Istio ingress gateway for incoming traffic at the edge.