# Lab 2 :: Installing Istio

In the previous lab we saw how Envoy works. We also saw that Envoy needs a control plane to configure it in a dynamic environment like a cloud platform built on containers or Kubernetes. 

Istio provides that control plane to drive the behavior of the network. Istio provides mechanisms for getting the Envoy proxy (also known as Istio service proxy, sidecar proxy, or data plane) integrated with workloads deployed to a system and for them to automatically connect to the control plane securely. Users can then use the control plane's API to drive the behavior of the network. Let's start installing and configuring Istio in this lab.

## Prequisites

You will need access to a Kubernetes cluster. If you're doing this via the Solo.io Workshop format, you should have everything ready to go. If you are using Docker Desktop or kind, validate that you have 16.0 GB of memory and 8 CPUs.

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-day2/1-understand-istio/`. 

In the workshop material, you should already have Istio 1.8.3 installed and ready to go. Although at the time of this writing Istio 1.9 is the latest, we will start on Istio 1.8.x and show how to do upgrades in the second part of this workshop. 

To verify, run 

```bash
istioctl version
```

You should see something similar to this:

```
no running Istio pods in "istio-system"
1.8.3
```

We don't have Istio installed and running yet. Let's go ahead and do that. There are three ways to install Istio:

* `istioctl` CLI tool
* Istio Operator
* Helm

We will use the `istioctl` approach to install Istio following some best practices to set you up for future success. In the second part of this lab (series 2) we'll explore how to use Helm. 

## Install existing services

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
```

After running these commands, we should check the pods running in the `istioinaction` namespace:

```bash
kubectl get po -n istioinaction
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
purchase-history-v1-b47996677-lskt9   1/1     Running   0          14s
recommendation-69995f55c9-rddwz       1/1     Running   0          17s
web-api-745fdb5bdf-jbbp4              1/1     Running   0          19s
```

You now have some existing workloads in your cluster. Let's proceed to install the Istio control plane.

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

Lastly, we will install the Istio control plane using a _revisions_. You can check the Istio docs [for more on revisions](https://istio.io/latest/docs/setup/upgrade/canary/#control-plane)

NOTE: Again, there might be some slight deviations from the Istio doc here as these instructions are intended to be used to support Istio upgrades going forward.. ie "day 2". We are working with the Istio community to get this learning back into the offical docs.

Now let's install the control plane. This installation uses the IstioOperator CR along with `istioctl`. The IstioOperator looks like this:

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

So we have the control plane up and running, but we don't have any services in the mesh. Let's add one!

From here, we can query the Istio control plane's debug endpoints to see what services we have running and what Istio has discovered.

```bash
kubectl exec -n istio-system -it deploy/istiod-1-8-3 -- pilot-discovery request GET /debug/registryz 
```

The output of this command can be quite verbose as it lists all of the services in the Istio registry. Workloads are included in the Istio registry even if they are not officially part of the mesh (ie, have a sidecar deployed next to it). We leave it to the reader to grep for some of the previously deployed services (`web-api`, `recommendation` and `purchase-history` services).

## Additional debug paths

Istio provides a nice `debug` interface on the Istio control plane. We can call it with the convenience command on the `pilot-discovery` like we did in the previous step. We could also call it from `curl` or any HTTP client like:

```bash
kubectl exec -it deploy/sleep -- curl http://istiod.istio-system:15014/debug/registryz
```

Some additional paths that are definitely useful for debugging the control plane:

| Path | Description |
| ---- | ----------- |
| /debug/edsz | Status and debug interface for EDS |
| /debug/ndsz | Status and debug interface for NDS |
| /debug/adsz | Status and debug interface for ADS |
| /debug/adsz?push=true | Initiates push of the current state to all connected endpoints | 
| /debug/syncz | Synchronization status of all Envoys connected to this Pilot instance |
| /debug/config_distribution | Version status of all Envoys connected to this Pilot instance |
| /debug/registryz | Debug support for registry |
| /debug/endpointz | Debug support for endpoints |
| /debug/endpointShardz | Info about the endpoint shards |
| /debug/cachez | Info about the internal XDS caches |
| /debug/configz | Debug support for config |
| /debug/resourcesz | Debug support for watched resources |
| /debug/instancesz | Debug support for service instances |
| /debug/authorizations | Internal authorization policies |
| /debug/config_dump | ConfigDump in the form of the Envoy admin config dump API for passed in proxyID |
| /debug/push_status | Last PushContext Details |
| /debug/inject | Active inject template |


## Digging into the Istio sidecar proxy

In the previous lab we saw an introduction to the Envoy proxy data plane. In Istio, we deploy a sidecar proxy next to each workload to enhance the capabilities of the application network. When a service gets called, or makes a call, all traffic is routed to the sidecar Envoy proxy first. How can we be certain that's the case?

In this section, we'll install a sidecar onto the `httpbin` service from the previous lab and explore it. We will manually inject it so we can fiddle with the security permissions because by default the Istio sidecar has privileges disabled.

Run the following command to add the Istio sidecar to the `httpbin` service in the `default` namespasce:

```bash
istioctl kube-inject -f labs/01/httpbin.yaml --meshConfigMapName istio-1-8-3 --injectConfigMapName istio-sidecar-injector-1-8-3  | kubectl apply -f -
```

Note in the above command we configure `istioctl` to use the configmaps from our `1-8-3` revision. We can run multiple versions of Istio concurrently and can specify exactly which revision gets applied in the tooling.

To update the security configuration of the sidecar container, run the following command from the cli:

```
kubectl edit deploy/httpbin -n default
```

Update the sidecar container to have security context like this:

```
      containers:
      - name: istio-proxy 
        image: docker.io/istio/proxyv2:1.8.3       
        securityContext:
          allowPrivilegeEscalation: true
          privileged: true
        
```

Specifically the `allowPrivilegeEscalation` and `privileged` fields change to true. Once you save this change, we should see a new `httpbin` pod with updated security privilege and we can explore some of the `iptables` rules that redirect traffic:

```
kubectl exec -it deploy/httpbin -c istio-proxy -- sudo iptables -L -t nat
```

We should see an output similar to:

```
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
ISTIO_INBOUND  tcp  --  anywhere             anywhere            

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
ISTIO_OUTPUT  tcp  --  anywhere             anywhere            

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain ISTIO_INBOUND (1 references)
target     prot opt source               destination         
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15008
RETURN     tcp  --  anywhere             anywhere             tcp dpt:22
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15090
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15021
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15020
ISTIO_IN_REDIRECT  tcp  --  anywhere             anywhere            

Chain ISTIO_IN_REDIRECT (3 references)
target     prot opt source               destination         
REDIRECT   tcp  --  anywhere             anywhere             redir ports 15006

Chain ISTIO_OUTPUT (1 references)
target     prot opt source               destination         
RETURN     all  --  127.0.0.6            anywhere            
ISTIO_IN_REDIRECT  all  --  anywhere            !localhost            owner UID match istio-proxy
RETURN     all  --  anywhere             anywhere             ! owner UID match istio-proxy
RETURN     all  --  anywhere             anywhere             owner UID match istio-proxy
ISTIO_IN_REDIRECT  all  --  anywhere            !localhost            owner GID match istio-proxy
RETURN     all  --  anywhere             anywhere             ! owner GID match istio-proxy
RETURN     all  --  anywhere             anywhere             owner GID match istio-proxy
RETURN     all  --  anywhere             localhost           
ISTIO_REDIRECT  all  --  anywhere             anywhere            

Chain ISTIO_REDIRECT (1 references)
target     prot opt source               destination         
REDIRECT   tcp  --  anywhere             anywhere             redir ports 15001
```

We can see here iptables is used to redirect incoming and outgoing traffic to Istio's data plane proxy. Incoming traffic goes to port `15006` of the Istio proxy while outgoing traffic will go through `15001`. If we check the Envoy listeners for those ports, we can see exactly how the traffic gets handled.

## Next Lab

In the next lab, we will leverage Istio's telemetry collection and scrap it into Prometheus, Grafana, and Kiali. Istio ships with some sample addons to install those components in a POC environment, but we'll look at a more realistic environment.                   
