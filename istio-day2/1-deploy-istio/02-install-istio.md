# Lab 2 :: Installing Istio

In the previous lab we saw how Envoy works. We also saw that Envoy needs a control plane to configure it in a dynamic environment like a cloud platform built on containers or Kubernetes. 

Istio provides that control plane to drive the behavior of the network. Istio provides mechanisms for getting the Envoy proxy (also known as Istio service proxy, sidecar proxy, or data plane) integrated with workloads deployed to a system and for them to automatically connect to the control plane securely. Users can then use the control plane's API to drive the behavior of the network. Let's start installing and configuring Istio in this lab.

## Prerequisites

Will start this lab by deploying some services in Kubernetes. The scenario we are replicating is one where Istio is being added to a set of workloads and that existing services are deployed into the cluster. In this lab (Lab 02) we will focus on getting Istio installed and in a later lab show how to iteratively roll out the mesh functionality to the workloads.

Let's set up the `sample-apps`:

```bash
kubectl create ns istioinaction
```

Now let's create some services:

```bash
kubectl apply -n istioinaction -f sample-apps/web-api.yaml
kubectl apply -n istioinaction -f sample-apps/recommendation.yaml
kubectl apply -n istioinaction -f sample-apps/purchase-history-v1.yaml
kubectl apply -n istioinaction -f sample-apps/sleep.yaml
```

After running these commands, we should check the pods running in the `istioinaction` namespace:

```bash
kubectl get po -n istioinaction
```

```
NAME                                   READY   STATUS    RESTARTS   AGE
purchase-history-v1-6c8cb7f8f8-wn4dr   1/1     Running   0          22s
recommendation-c9f7cc86f-nfvmk         1/1     Running   0          22s
sleep-8f795f47d-5jfbn                  1/1     Running   0          14s
web-api-6d544cff77-drrbm               1/1     Running   0          22s
```

You now have some existing workloads in your cluster. Let's proceed to install the Istio control plane.


### Verify Istio CLI installation
You will need access to a Kubernetes cluster. If you're doing this via the Solo.io Workshop format, you should have everything ready to go. 

{% hint style="info" %}
If you are using Docker Desktop or kind locally, expect to use 16.0 GB of memory and 4-8 CPUs depending how much of the lab you wish to do. We end up downloading and using a lot of components. 
{% endhint %}

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-day2/1-deploy-istio/`. 

In the workshop material, you should already have Istio `1.8.3` cli installed and ready to go. 

{% hint style="info" %}
Although at the time of this writing Istio `1.9` is the latest, we will start on Istio `1.8.x` and show how to do upgrades in the second part of this workshop. 
{% endhint %}

To verify, run 

```bash
istioctl version
```

You should see something similar to this:

```
no running Istio pods in "istio-system"
1.8.3
```

We don't have the Istio control plane installed and running yet. Let's go ahead and do that. There are three ways to install Istio:

* `istioctl` CLI tool
* Istio Operator
* Helm

We will use the `istioctl` approach to install Istio following some best practices to set you up for future success. In the second part of this lab (series 2) we'll explore how to use Helm. 

{% hint style="success" %}
Helm 3 is another common approach to installing and upgrading Istio. We'll see labs on Helm 3 in the second part of this workshop series.
{% endhint %}


## Installing Istio

Before we install Istio, we will create a namespace into which to deploy Istio and create a Kubernetes service to represent the Istio control plane. These steps may be slightly different than what you see in other docs, but this is an important step to be able to use Istio's revision capabilities until the Istio "tags" functionality makes it into the project. (See more [here](https://docs.google.com/document/d/13IGuJg8swtLdNGW5cpF7ZdVkgge8voNp9DWBD93Wb1Q/edit#heading=h.xw1gqgyqs5b) for more on Istio tags. In the instructor led version of this workshop we will explain it)

Start with creating the namespace:

```bash
kubectl create ns istio-system
```

Next let's create the control plane service `istiod`:

```bash 
kubectl apply -f labs/02/istiod-service.yaml
```

{% hint style="info" %}
This is an additional step you may not see very clearly in the Istio docs; we need this step to workaround a long-standing issue with Istio revisions which we'll use in the next steps. Istio revisions allow us to run multiple versions of the Istio control plane.
{% endhint %}

Lastly, we will install the Istio control plane using a _revisions_. You can check the Istio docs [for more on revisions](https://istio.io/latest/docs/setup/upgrade/canary/#control-plane)

Now let's install the control plane. This installation uses the `IstioOperator` CR along with `istioctl`. The IstioOperator looks like this:

```
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: control-plane
spec:
  profile: minimal
```

It is purposefully "minimal" here as we will only be installing the `istiod` part of the control plane. 

```bash
istioctl install -y -n istio-system -f labs/02/control-plane.yaml --revision 1-8-3
```

You should see output similar to this:

```
✔ Istio core installed                                                                                                                                                                            
✔ Istiod installed                                                                                                                                                                                
✔ Installation complete 
```

We now have Istio installed! This `istiod` component includes various functionality like:

* xDS server for Envoy config
* Certificate Authority for signing workload certs
* Service discovery
* Sidecar injection webhook

If we check the `istio-system` workspace, we should see the control plane running:

```bash
kubectl get pod -n istio-system
```

```
NAME                            READY   STATUS    RESTARTS   AGE
istiod-1-8-3-78b88c997d-rpnck   1/1     Running   0          2m1s
```

From here, we can query the Istio control plane's debug endpoints to see what services we have running and what Istio has discovered.

```bash
kubectl exec -n istio-system -it deploy/istiod-1-8-3 -- pilot-discovery request GET /debug/registryz 
```

The output of this command can be quite verbose as it lists all of the services in the Istio registry. Workloads are included in the Istio registry even if they are not officially part of the mesh (ie, have a sidecar deployed next to it). We leave it to the reader to grep for some of the previously deployed services (`web-api`, `recommendation` and `purchase-history` services).

{% hint style="info" %}
We will cover more of the `debug` endpoints in [Lab 08](./08-debugging-config.md)
{% endhint %}

## Install sidecar for demo app

In this section, we'll install a sidecar onto the `httpbin` service from the previous lab and explore it. We will manually inject the sidecar so that in the bonus section we can fiddle with the security permissions because by default the Istio sidecar has privileges disabled.

Run the following command to add the Istio sidecar to the `httpbin` service in the `default` namespasce:

```bash
istioctl kube-inject -f labs/01/httpbin.yaml --meshConfigMapName istio-1-8-3 --injectConfigMapName istio-sidecar-injector-1-8-3  | kubectl apply -f -
```

{% hint style="info" %}
In the above command we configure `istioctl` to use the configmaps from our `1-8-3` revision. We can run multiple versions of Istio concurrently and can specify exactly which revision gets applied in the tooling.
{% endhint %}

## Recap

At this point, we've installed the Istio control plane following a slightly different method than the official docs, but one that sets us up for success for operating Istio. 

## Bonus Content

In the bonus section, we tie together our understanding of the Istio sidecar proxy (Envoy) that we gained in Lab 01 with the Istio control plane. We dig into how the Istio sidecar proxy works. 

[See the Lab 02 bonus section](02a-bonus.md).

## Next Lab

In the [next lab](03-observability.md), we will leverage Istio's telemetry collection and scrap it into Prometheus, Grafana, and Kiali. Istio ships with some sample addons to install those components in a POC environment, but we'll look at a more realistic environment.                   
