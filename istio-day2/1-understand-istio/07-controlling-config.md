sidecar, export-to, VS merging, and VS delegation

# Lab 7 :: Controlling configuration scope

By default, Istio networking resources and services are visible to all services running in all namespaces that are part of the Istio service mesh. As you add more services to the mesh, the amount of sidecar proxy's configuration increases dramatically which will grow your sidecar proxy's memory accordingly. Thus this default behavior is not desired when you have more than a few services and not all of your services communicate to all other services.

The `Sidecar` resource is designed to solve this problem from the service consumers perspective. This configuration allows you to configure the sidecar proxy that mediates inbound and outbound communication to the workload instance it is applicable to.  The `Export-To` configuration allows service producers to declare the scope of the services to be exported. With both of these configuration, service owners can effectively control the scope of the sidecar configuration. 

## Sidecar resource for service consumers

Let's declare services in the istioinaction namespace is allowed to reach out to the web-api service in the istioinaction namespace using the default sidecar resource below:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: istioinaction
spec:
  egress:
  - hosts:
    - "./web-api.istioinaction"
    - "istio-system/*"
```

Apply this resource:

```bash
kubectl apply -f labs/07/default-sidecar-web-api.yaml -n istioinaction
```

Let us reach to web-api service from the sleep pod in the istioinaction namespace.  

```bash
kubectl exec -it deploy/sleep -n istioinaction -- curl http://web-api.istioinaction:8080/
```

You will get a 500 error code:

```
Defaulting container name to sleep.
{
  "name": "web-api",
  "uri": "/",
  "type": "HTTP",
  "ip_addresses": [
    "192.168.1.168"
  ],
  "start_time": "2021-03-03T20:38:25.871661",
  "end_time": "2021-03-03T20:38:25.877065",
  "duration": "5.4049ms",
  "upstream_calls": [
    {
      "name": "recommendation",
      "uri": "http://recommendation:8080",
      "type": "HTTP",
      "ip_addresses": [
        "192.168.1.169"
      ],
      "start_time": "2021-03-03T20:38:25.873831",
      "end_time": "2021-03-03T20:38:25.876187",
      "duration": "2.3579ms",
      "upstream_calls": [
        {
          "uri": "http://purchase-history:8080",
          "code": -1,
          "error": "Error communicating with upstream service: Get http://purchase-history:8080/: EOF"
        }
      ],
      "code": 500,
      "error": "Error processing upstream request: http://recommendation:8080/"
    }
  ],
  "code": 500
}
```

This is because the web-api pod's sidecar doesn't know how to get to the recommendation service successfully, neither can the recommendation pod's sidecar know how to reach the purchase-history service. If you review the cluster output, you can see the web-api pod is not aware of the recommendation or purchase-history at all.

```bash
istioctl pc cluster deploy/web-api.istioinaction
```

You should get output like below with many services from the istio-system namespace and no service from the istioinaction namespace.
```      
SERVICE FQDN                                            PORT      SUBSET     DIRECTION     TYPE             DESTINATION RULE
...         
istio-ingressgateway.istio-system.svc.cluster.local     80        -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local     443       -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local     15012     -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local     15021     -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local     15443     -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local             443       -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local             15010     -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local             15012     -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local             15014     -          outbound      EDS              
istiod.istio-system.svc.cluster.local                   443       -          outbound      EDS              
istiod.istio-system.svc.cluster.local                   15010     -          outbound      EDS              
istiod.istio-system.svc.cluster.local                   15012     -          outbound      EDS              
istiod.istio-system.svc.cluster.local                   15014     -          outbound      EDS              
kiali.istio-system.svc.cluster.local                    9090      -          outbound      EDS              
kiali.istio-system.svc.cluster.local                    20001     -          outbound      EDS              
...
```

Let's modify the sidecar resource to allow all services within the same namespace:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: istioinaction
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
```

Apply this `default-sidecar-allows-all-egress.yaml` file to your cluster:

```bash
kubectl apply -f labs/07/default-sidecar-allows-all-egress.yaml -n istioinaction
```

Curl the web-api from the sleep pod in the istioinaction namespace:

```bash
kubectl exec -it deploy/sleep -n istioinaction -- curl http://web-api.istioinaction:8080/
```

You should see 200 code from the recommendation service and purchase-history services:

```
Defaulting container name to sleep.
{
  "name": "web-api",
  "uri": "/",
  "type": "HTTP",
  "ip_addresses": [
    "192.168.1.168"
  ],
  "start_time": "2021-03-03T20:54:04.694092",
  "end_time": "2021-03-03T20:54:04.706462",
  "duration": "12.3708ms",
  "body": "Hello From Web API",
  "upstream_calls": [
    {
      "name": "recommendation",
      "uri": "http://recommendation:8080",
      "type": "HTTP",
      "ip_addresses": [
        "192.168.1.169"
      ],
      "start_time": "2021-03-03T20:54:04.698750",
      "end_time": "2021-03-03T20:54:04.705537",
      "duration": "6.7868ms",
      "body": "Hello From Recommendations!",
      "upstream_calls": [
        {
          "name": "purchase-history-v1",
          "uri": "http://purchase-history:8080",
          "type": "HTTP",
          "ip_addresses": [
            "192.168.1.175"
          ],
          "start_time": "2021-03-03T20:54:04.704524",
          "end_time": "2021-03-03T20:54:04.704611",
          "duration": "88µs",
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

If you view the cluster configuration for the web-api pod in the istioinaction namespace:

```bash
istioctl pc cluster deploy/web-api.istioinactio
```

You should see the recommendation, purchase-history and sleep service from the istioinaction namespace in the output:

```
SERVICE FQDN                                            PORT      SUBSET     DIRECTION     TYPE             DESTINATION RULE
...           
purchase-history.istioinaction.svc.cluster.local        8080      -          outbound      EDS              
recommendation.istioinaction.svc.cluster.local          8080      -          outbound      EDS              
sds-grpc                                                -         -          -             STATIC           
sleep.istioinaction.svc.cluster.local                   80        -          outbound      EDS              
web-api.istioinaction.svc.cluster.local                 8080      -          outbound
EDS
...
```

TODO: remove this portion below as it doesn't seem to work yet.

Now reach to web-api service from the sleep pod in the default namespace.

```bash
kubectl exec -it deploy/sleep -- curl http://web-api.istioinaction:8080/
```

You should also get a 200 code because your sleep pod in the default namespace doesn't have a sidecar yet so there is no sidecar proxy to mediate the traffic.  Let's inject the sidecar proxy to the sleep pod in the default namespace.

```bash
istioctl kube-inject -f sample-apps/sleep.yaml --meshConfigMapName istio-1-8-3 --injectConfigMapName istio-sidecar-injector-1-8-3  | kubectl apply -n default -f -
```

Now reach to web-api service from the sleep pod in the default namespace.

```bash
kubectl exec -it deploy/sleep -n default -- curl http://web-api.istioinaction:8080/
```

You still get a 200 code because your sleep pod doesn't have any sidecar traffic mediation configured so the sleep pod in the default namespace still knows how to route to the web-api service in the istioinaction namespace.  

```
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: istioinaction
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
```

Apply this `default-sidecar.yaml` file in the default namespace to your cluster:

```bash
kubectl apply -f labs/07/default-sidecar.yaml -n default
```

Let's declare web-api is also added from the sleep service in the default namespace.


## Export-To scope for service producers

As the service owner for the recommendation service, you want to control that web-api service is only available for the istioinaction namespace

Call the recommendation service from the sleep service in the default namespace.


## Virtual service resource merging

Istio supports virtual service resource merging for resources that are not conflicted.

Explain VS merging with httpbin and web-api.

Test endpoint.

## Virtual service resource delegation

Gateway resource in istio-system, and delegate the VS resource to the service's namespace.  for example platform owner owns the gateway resources on which hosts and associated port numbers and TLS configuration but want to delegate the details of the virtual service resources to service owners.


Validate VS delegation working by visit the web-api:


## Next Lab

As you explore your services in Istio, things may not go smoothly.  In the [next lab](08-debugging-config.md), we will explore how to debug your services or Istio resources in your service mesh.

