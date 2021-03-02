* canary introduction of sidecars
* suggestions for rollout of sidecar using revisions/sidecar injection
* pre hook configurations
proxyConfig.holdApplicationUntilProxyStarts

* enable access logs for certain services
* tips avoid 503s on virtual service

== should use existing sample-apps/ dir

There are a couple ways to add a service to the mesh. What's meant by "adding the service to the mesh" is we install the Envoy proxy alongside the workload. We can do a manual injection of the sidecar or automatically do it. Let's start to deploy some workloads.

Now let's label this namespace with the appropriate labels to enable sidecar injection:

```bash
kubectl label namespace istioinaction istio.io/rev=1-8-3
```

Rolling restart all the deployment in this namespace:

```bash
kubectl rollout restart deployment -n istioinaction
```

Check the pods in this namespace:
```bash
kubectl get po -n istioinaction
```

As you can see from the output, each pod has the sidecar now with `2/2` under the `READY` column:
```
NAME                                  READY   STATUS    RESTARTS   AGE
purchase-history-v1-985b8776b-h7n5d   2/2     Running   0          10s
recommendation-8966c6b7d-p4xpt        2/2     Running   0          10s
web-api-69559c56b6-thkcc              2/2     Running   0          10s
```

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

## Digging into Proxy configuration

Coming back to our services in the `istioinaction` namespace, let's take a look at some of the Envoy configuration for the sidecar proxies. We will use the `istioctl proxy-config` command to inspect the configuration of the `web-api` pod's proxy. For example, to see the listeners configured on the proxy run this command:

```bash
istioctl proxy-config listener deploy/web-api.istioinaction 
```

We can also see the clusters that have been configured:

```bash
istioctl proxy-config clusters deploy/web-api.istioinaction
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

Note this is just a snippet, there are other configurations there specific to Istio and TLS connectivity. But if you recall the cluster configurations from the previous lab, you'll see they are similar. Istiod took information about the environment, user configurations, and service discovery, and translated this to an appropriate configuration _for this specific workload_







