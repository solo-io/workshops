* canary introduction of sidecars
* suggestions for rollout of sidecar using revisions/sidecar injection
* pre hook configurations
proxyConfig.holdApplicationUntilProxyStarts

* enable access logs for certain services
* tips avoid 503s on virtual service

== should use existing sample-apps/ dir

## Adding services to the mesh

There are a couple ways to add a service to the mesh. What's meant by "adding the service to the mesh" is we install the Envoy proxy alongside the workload. We can do a manual injection of the sidecar or automatically do it. Let's start to deploy some workloads.

Now let's label this namespace with the appropriate labels to enable sidecar injection:

```bash
kubectl label namespace istioinaction istio.io/rev=1-8-3
```

Rolling restart the web-api deployment in this namespace:

```bash
kubectl rollout restart deployment web-api -n istioinaction
```

Check the pods in this namespace:
```bash
kubectl get po -n istioinaction
```

As you can see from the output, the web-api pod has the sidecar now with `2/2` under the `READY` column:
```
NAME                                  READY   STATUS    RESTARTS   AGE
purchase-history-v1-985b8776b-h7n5d   1/1     Running   0          10h
recommendation-8966c6b7d-p4xpt        1/1     Running   0          10h
web-api-69559c56b6-thkcc              2/2     Running   0          10s
```

Now that we have our web-api pod up and running, we should be able to call it:

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

Let's add the recommendation and purchase-history-v1 deployments to the mesh.

```bash
kubectl rollout restart deployment purchase-history-v1 -n istioinaction
kubectl rollout restart deployment recommendation -n istioinaction
```

Tip: If you want to conveniently rollout restart all deployments in the istioinaction namespace, you can just run the command below:

```bash
kubectl rollout restart deployment -n istioinaction
```

## Digging into Proxy configuration

Coming back to our services in the `istioinaction` namespace, let's take a look at some of the Envoy configuration for the sidecar proxies. We will use the `istioctl proxy-config` command to inspect the configuration of the `web-api` pod's proxy. For example, to see the listeners configured on the proxy run this command:

```bash
istioctl proxy-config listener deploy/web-api.istioinaction 
```

```
ADDRESS       PORT  MATCH                                                                 DESTINATION
10.96.1.10    53    ALL                                                                   Cluster: outbound|53||kube-dns.kube-system.svc.cluster.local
0.0.0.0       80    Trans: raw_buffer; App: HTTP                                          Route: 80
0.0.0.0       80    ALL                                                                   PassthroughCluster
10.96.1.166   80    Trans: raw_buffer; App: HTTP                                          Route: frontend.custom-application.svc.cluster.local:80
10.96.1.166   80    ALL                                                                   Cluster: outbound|80||frontend.custom-application.svc.cluster.local
10.96.1.215   80    Trans: raw_buffer; App: HTTP                                          Route: prom-grafana.prometheus.svc.cluster.local:80
10.96.1.215   80    ALL                                                                   Cluster: outbound|80||prom-grafana.prometheus.svc.cluster.local
10.96.1.1     443   ALL                                                                   Cluster: outbound|443||kubernetes.default.svc.cluster.local
10.96.1.164   443   ALL                                                                   Cluster: outbound|443||echo.default.svc.cluster.local
10.96.1.204   443   ALL                                                                   Cluster: outbound|443||prom-kube-prometheus-stack-operator.prometheus.svc.cluster.local
...
```

We can also see the clusters that have been configured:

```bash
istioctl proxy-config clusters deploy/web-api.istioinaction
```

```
SERVICE FQDN                                                                         PORT      SUBSET     DIRECTION     TYPE             DESTINATION RULE
                                                                                     8080      -          inbound       STATIC           
BlackHoleCluster                                                                     -         -          -             STATIC           
InboundPassthroughClusterIpv4                                                        -         -          -             ORIGINAL_DST     
InboundPassthroughClusterIpv6                                                        -         -          -             ORIGINAL_DST     
PassthroughCluster                                                                   -         -          -             ORIGINAL_DST     
agent                                                                                -         -          -             STATIC           
echo.default.svc.cluster.local                                                       80        -          outbound      EDS              
echo.default.svc.cluster.local                                                       443       -          outbound      EDS              
echo.default.svc.cluster.local                                                       7070      -          outbound      EDS              
echo.default.svc.cluster.local                                                       9090      -          outbound      EDS              
echo.default.svc.cluster.local                                                       9091      -          outbound      EDS              
envoy.default.svc.cluster.local                                                      80        -          outbound      EDS              
envoy.default.svc.cluster.local                                                      15000     -          outbound      EDS              
foo-service.default.svc.cluster.local                                                5678      -          outbound      EDS              
frontend.custom-application.svc.cluster.local                                        80        -          outbound      EDS              
httpbin.default.svc.cluster.local                                                    8000      -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local                                  80        -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local                                  443       -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local                                  15012     -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local                                  15021     -          outbound      EDS              
istio-ingressgateway.istio-system.svc.cluster.local                                  15443     -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local                                          443       -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local                                          15010     -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local                                          15012     -          outbound      EDS              
istiod-1-8-3.istio-system.svc.cluster.local                                          15014     -          outbound      EDS              
istiod.istio-system.svc.cluster.local                                                443       -          outbound      EDS              
istiod.istio-system.svc.cluster.local                                                15010     -          outbound      EDS              
istiod.istio-system.svc.cluster.local                                                15012     -          outbound      EDS              
istiod.istio-system.svc.cluster.local                                                15014     -          outbound      EDS              
kiali-operator-metrics.kiali-operator.svc.cluster.local                              8383      -          outbound      EDS
...  
```

If we want to see more information about how the cluster for `recommendation.istioinaction` has been configured by Istio, run this command:

```bash
istioctl proxy-config clusters deploy/web-api.istioinaction --fqdn recommendation.istioinaction.svc.cluster.local -o json
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

Note this is just a snippet, there are other configurations there specific to Istio and TLS connectivity. But if you recall the cluster configurations from the previous lab, you'll see they are similar. Istiod took information about the environment, user configurations, and service discovery, and translated this to an appropriate configuration _for this specific workload_.









