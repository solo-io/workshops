# Lab 2 :: Install Istio

In the previous lab we saw how Envoy works. We also saw that Envoy needs a control plane to configure it in a dynamic environment like a cloud platform built on containers or Kubernetes. 

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


## Adding a service to the mesh

There are a couple ways to add a service to the mesh. What's meant by "adding the service to the mesh" is we install the Envoy proxy alongside the workload. We can do a manual injection of the sidecar or automatically do it. Let's start to deploy some workloads.

```bash
kubectl create ns istioinaction
```

Now let's label this namespace with the appropriate labels to enable sidecar injection:

```bash
kubectl label namespace istioinaction istio.io/rev=1-8-3
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
purchase-history-v1-b8dc86db6-lw8s2   2/2     Running   0          27s
recommendation-58c475d67b-xl87v       2/2     Running   0          28s
web-api-7b79c4d9c8-6w8g5              2/2     Running   0          29s
```

From here, we can query the Istio control plane's debug endpoints to see what services we have running and what Istio has discovered.

```bash
kubectl exec -n istio-system -it deploy/istiod-1-8-3 -- pilot-discovery request GET /debug/registryz 
```

The output of this command can be quite verbose as it lists all of the services in the Istio registry. As an exercise for the reader, find the entries for the new services we deployed in the Istio registry.

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


## Digging into the Istio proxy behavior

Now that we have our service up and running, we should be able to call it:

```bash
kubectl exec -it deploy/sleep -- curl http://web-api.istioinaction:8080/
```

```
{
  "name": "web-api",
  "uri": "/",
  "type": "HTTP",
  "ip_addresses": [
    "10.40.9.22"
  ],
  "start_time": "2021-02-12T13:11:44.868851",
  "end_time": "2021-02-12T13:11:44.972806",
  "duration": "103.95516ms",
  "body": "Hello From Web API",
  "upstream_calls": [
    {
      "name": "recommendation",
      "uri": "http://recommendation:8080",
      "type": "HTTP",
      "ip_addresses": [
        "10.40.9.23"
      ],
      "start_time": "2021-02-12T13:11:44.879324",
      "end_time": "2021-02-12T13:11:44.935277",
      "duration": "55.952768ms",
      "body": "Hello From Recommendations!",
      "upstream_calls": [
        {
          "name": "purchase-history-v1",
          "uri": "http://purchase-history:8080",
          "type": "HTTP",
          "ip_addresses": [
            "10.40.8.45"
          ],
          "start_time": "2021-02-12T13:11:44.895947",
          "end_time": "2021-02-12T13:11:44.896300",
          "duration": "353.182µs",
          "body": "Hello From Purchase History (v1)!",
          "code": 200
        }
      ],
      "code": 200
    }
  ],
  "code": 200
}
```
As we know, the Envoy sidecar is in the data path here. When a service gets called, or makes a call, all traffic is routed to the sidecar Envoy proxy first. How can we be certain that's the case?

Let's install a sidecar onto the `httpbin` service from the previous lab and explore it. We will manually inject it so we can fiddle with the security permissions because by default the Istio sidecar has privileges disabled.

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

## Digging into Proxy configuration

Coming back to our services in the `istioinaction` namespace, let's take a look at some of the Envoy configuration for the sidecar proxies.

```bash
kubectl get po -n istioinaction
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
purchase-history-v1-b8dc86db6-wfpvm   2/2     Running   0          28m
recommendation-58c475d67b-f6k8s       2/2     Running   0          28m
web-api-7b79c4d9c8-7l2l7              2/2     Running   0          72s
```

We will use the `istioctl proxy-config` command to inspect the configuration of the `web-api` pod's proxy. For example, to see the listeners configured on the proxy run something like this:

```bash
istioctl proxy-config listener web-api-7b79c4d9c8-7l2l7.istioinaction
```

Note the name of the pod and namespaces here might be different for your system.

We can also see the clusters that have been configured:

```bash
istioctl proxy-config clusters web-api-7b79c4d9c8-7l2l7.istioinaction
```

If we want to see more information about how the cluster for `recommendation.istioinaction` has been configured by Istio, run this command:

```bash
istioctl proxy-config clusters web-api-7b79c4d9c8-7l2l7.istioinaction --fqdn recommendation.istioinaction.svc.cluster.local -o json
```

```
[
    
        "name": "outbound|8080||recommendation.istioinaction.svc.cluster.local",
        "type": "EDS",
        "edsClusterConfig": {
            "edsConfig": {
                "ads": {},
                "resourceApiVersion": "V3"
            },
            "serviceName": "outbound|8080||recommendation.istioinaction.svc.cluster.local"
        },
        "connectTimeout": "10s",
        "circuitBreakers": {
            "thresholds": [
                {
                    "maxConnections": 4294967295,
                    "maxPendingRequests": 4294967295,
                    "maxRequests": 4294967295,
                    "maxRetries": 4294967295
                }
            ]
        },
    }
]

```

Note this is just a snippet, there are other configurations there specific to Istio and TLS connectivity. But if you recall the cluster configurations from the previous lab, you'll see they are similar. Istiod took information about the environment, user configurations, and service discovery, and translated this to an appropriate configuration _for this specific workload_

## Next Lab

In the next lab, we will leverage Istio's telemetry collection and scrap it into Prometheus, Grafana, and Kiali. Istio ships with some sample addons to install those components in a POC environment, but we'll look at a more realistic environment.                   
