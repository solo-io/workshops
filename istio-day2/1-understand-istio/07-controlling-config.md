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
    - "./web-api.istioinaction.svc.cluster.local"    
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
  "start_time": "2021-03-04T04:03:58.041278",
  "end_time": "2021-03-04T04:03:58.044000",
  "duration": "2.7219ms",
  "upstream_calls": [
    {
      "uri": "http://recommendation:8080",
      "code": 503,
      "error": "Error processing upstream request: http://recommendation:8080/"
    }
  ],
  "code": 500
}
```

This is because the web-api pod's sidecar doesn't know how to get to the recommendation service successfully. If you review the cluster output, you can see the web-api pod is not aware of the recommendation or purchase-history at all.

```bash
istioctl pc cluster deploy/web-api.istioinaction
```

You should get output like below with many services from the istio-system namespace and only the web-api service from the istioinaction namespace:

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
web-api.istioinaction.svc.cluster.local                 8080      -          outbound      EDS              
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
sleep.istioinaction.svc.cluster.local                   80        -          outbound      EDS              
web-api.istioinaction.svc.cluster.local                 8080      -          outbound      EDS
...
```

Check if your sleep pod has sidecar proxy injected.  If not, deploy it with sidecar proxy injected:

```bash
istioctl kube-inject -f sample-apps/sleep.yaml --meshConfigMapName istio-1-8-3 --injectConfigMapName istio-sidecar-injector-1-8-3  | kubectl apply -n default -f -
```

Now reach to web-api service from the sleep pod in the default namespace.

```bash
kubectl exec -it deploy/sleep -n default -- curl http://web-api.istioinaction:8080/
```

You will get a 200 status code because the sleep pod in the default namespace doesn't have any sidecar resource thus can see all the configuration for the web-api service in istioinaction.  

In summary, sidecar resource can be used per namespace as shown above or per workload by using label selector, or globally.  It is recommended to enable it per namespace or workload first before enable it globally.  Sidecar resource controls the visibility of configurations and what gets pushed to the sidecar proxy.  Further, sidecar resource should NOT be used as security enforcement to prevent service A to reach to service B.  Istio authorization policy (or network policy for layer 3/4 traffic) should be used instead to enforce the security boundry.

## export-To scope for service producers

Service owners can apply `export-To` to define a list of namespaces that the Istio networking resources can be applied to. This configuration is only available for Virtual Service, Destination Rule and Service Entry resources in Istio. By default, if nothing is specified for `export-To` for these resources, they are made available to all namespaces in the mesh. However, it is best practice to trim the unnecessary proxy configurations. For example, as the service owner for the recommendation service, you may want to control that web-api service is only available for the istioinaction namespace and the istio-system namespace.

Recall how to get the ingress gateway IP:

```bash
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

Now send some traffic through the ingress gateway:

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

You should get 200 status code because in lab04, you have configured the gateway resource and virtual service resource in the istioinaction namespace, along with the `istioinaction-cert` secret in the istio-system namespace.

Now, let us try create the `web-api-gateway` resource in the istio-system namespace, and continue to have the `web-api-gw-vs` virtual service resource in the istioinaction namespace and explore `exportTo` on this virtual service resource.

First, delete the `web-api-gateway` gateway resource in the istioinaction namespace:

```bash
kubectl delete gw web-api-gateway -n istioinaction
```

Create the `web-api-gateway` gateway resource for the istio-system namespace instead:

```
kubectl apply -f labs/07/web-api-gw-https-istiosystem.yaml -n istio-system
```

Update the `web-api-gw-vs` virtual service resource in the istioinaction namespace, under ``gateways` section to refer to the `web-api-gateway` in the istio-system namespace.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: web-api-gw-vs
  namespace: istioinaction
spec:
  hosts:
  - "istioinaction.io"
  gateways:
  - istio-system/web-api-gateway
  http:
  - route:
    - destination:
        host: web-api.istioinaction.svc.cluster.local
        port:
          number: 8080
```

Apply the virtual service resource:

```bash
kubectl apply -f labs/07/web-api-gw-vs.yaml -n istioinaction
```

Send some traffic to web-api through the istio ingress gateway via https:

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

You should continue to get 200 status code.  Now as web-api's service producer, you want to limit its virtual service scope to within the current namespace, with the `exportTo` configuration:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: web-api-gw-vs
  namespace: istioinaction
spec:
  hosts:
  - "istioinaction.io"
  gateways:
  - istio-system/web-api-gateway
  exportTo:
  - "."
  http:
  - route:
    - destination:
        host: web-api.istioinaction.svc.cluster.local
        port:
          number: 8080
```

Apply the updated virtual service resource:

```bash
kubectl apply -f labs/07/web-api-gw-vs-exportto.yaml -n istioinaction
```

Send some traffic to web-api through the istio ingress gateway via https:

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

Because istio ingress gateway doesn't know how to route to the web-api service in the istioinaction namespace, you will get an empty reply instead.

## Gateway resource merging

Istio supports virtual service resource merging for resources that are not conflicted.

Explain VS merging with httpbin and web-api.

Test endpoint.

## Virtual service resource delegation

Gateway resource in istio-system, and delegate the VS resource to the service's namespace.  for example platform owner owns the gateway resources on which hosts and associated port numbers and TLS configuration but want to delegate the details of the virtual service resources to service owners.


Validate VS delegation working by visit the web-api:


## Next Lab

As you explore your services in Istio, things may not go smoothly.  In the [next lab](08-debugging-config.md), we will explore how to debug your services or Istio resources in your service mesh.

