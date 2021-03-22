# Lab 5 - Onboarding services to the mesh

In this lab, we'll add services gradually to the Istio service mesh we installed in earlier labs. We will cover how to examine envoy configuration for your services, how to delay your application from starting until the sidecar proxy is ready, how to enable access logs for a given service and some tips to avoid 503s.

## Prerequisites

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-day2/1-deploy-istio/`.

This lab builds on both lab 02, 03 and 04 where we already installed Istio control plane using a minimal profile and ingress gateway using revisions.

## Adding services to the mesh

There are a couple ways to add a service to the mesh. What's meant by "adding the service to the mesh" is we install the Istio sidecar proxy \(Envoy\) alongside the workload. We can do a manual injection of the sidecar or automatically do it. Let's start to deploy some workloads.

Now let's label this namespace with the appropriate labels to enable sidecar injection:

```bash
kubectl label namespace istioinaction istio.io/rev=1-8-3
```

{% hint style="info" %}
As you can see here we're using a different label than the normal `istio-injection` label; we are leveraging revisions which allows us to control which control plane to which an istio sidecar connects
{% endhint %}

Next, we deploy a `web-api` _canary_ deployment in the `istioinaction` namespace:

```bash
kubectl apply -f labs/05/web-api-canary.yaml -n istioinaction
```

{% hint style="info" %}
The purpose of this deployment is to not touch any of the existing services yet but to deploy a sidecar next to one instance of the `web-api` service as a _canary_
{% endhint %}

Check the pods in this namespace:

```bash
kubectl get po -n istioinaction
```

As you can see from the output, the web-api-canary pod has the sidecar now with `2/2` under the `READY` column:

```text
NAME                                  READY   STATUS    RESTARTS   AGE
purchase-history-v1-985b8776b-h7n5d   1/1     Running   0          10h
recommendation-8966c6b7d-p4xpt        1/1     Running   0          10h
sleep-854565cb79-8mpgv                1/1     Running   0          10h
web-api-69559c56b6-thkcc              1/1     Running   0          10h
web-api-canary-6d87d9c4-jx82w         2/2     Running   0          10s
```

Now that we have our web-api pod up and running, we should be able to call it:

```bash
kubectl exec -it deploy/sleep -- curl http://web-api.istioinaction:8080/
```

```text
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

Now we can add more canary versions of our services:

```bash
kubectl apply -f labs/05/purchase-history-v1-canary.yaml -n istioinaction
kubectl apply -f labs/05/recommendation-canary.yaml -n istioinaction
kubectl apply -f labs/05/sleep-canary.yaml -n istioinaction
```

Check that the canary workloads got the sidecar deployed:

```bash
kubectl get po -n istioinaction
```

Let's send some more traffic to the `web-api` service:

```bash
for i in {1..10}; do kubectl exec -it deploy/sleep -n default -- curl http://httpbin.default:8000/headers; done
```

If everything looks good, we can introduce the sidecar to the rest of the services and delete the canary:

```text
kubectl rollout restart deployment web-api -n istioinaction
kubectl rollout restart deployment purchase-history-v1 -n istioinaction
kubectl rollout restart deployment recommendation -n istioinaction
kubectl rollout restart deployment sleep -n istioinaction
```

```bash
kubectl delete deployment web-api-canary purchase-history-v1-canary recommendation-canary sleep-canary -n istioinaction
```

Congratulations! You have successfully added all of your services in the istioinaction namespace to the mesh without any downtime.

## Digging into Proxy configuration

Coming back to our services in the `istioinaction` namespace, let's take a look at some of the Envoy configuration for the sidecar proxies. We will use the `istioctl proxy-config` command to inspect the configuration of the `web-api` pod's proxy. For example, to see the listeners configured on the proxy run this command:

```bash
istioctl proxy-config listener deploy/web-api.istioinaction
```

```text
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

```text
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

```text
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

## Hold application until sidecar proxy is ready

Kubernetes lacks a standard way to declare container dependencies. There is a [Sidecar](https://github.com/kubernetes/enhancements/issues/753) Kubernetes Enhancement Proposal \(KEP\) out there, however it is not yet implemented in a Kubernetes release. In the meantime, service owners may observe unexpected behavior at startup or stop times because the application container may start before sidecar proxy finishes starting or sidecar proxy could be stopped before application container is stopped.

To help mediate the issue, Istio has implemented a pod level configuration called `holdApplicationUntilProxyStarts` for service owners to delay application start until the sidecar proxy is ready. For example, you can add this annotation snippet to the web-api deployment yaml to hold the web-api application until the sidecar proxy is ready:

```yaml
...
  template:
    metadata:
      labels:
        app: web-api
        version: v1
      annotations:
        proxy.istio.io/config: '{ "holdApplicationUntilProxyStarts": false }'
    spec:
      containers:
...
```

Deploy the yaml that has the `holdApplicationUntilProxyStarts` configuration:

```bash
kubectl delete -f sample-apps/web-api-holdapp.yaml -n istioinaction
kubectl apply -f sample-apps/web-api-holdapp.yaml -n istioinaction
```

To validate the web-api container starts after its sidecar proxy starts, check the Kubernetes event for the pod:

```bash
kubectl describe pod/web-api-56d679cf7d-tfxdj -n istioinaction
```

From the events, the istio-proxy container is created and started first, then the web-api container is created and started:

```text
Events:
  Type    Reason     Age    From               Message
  ----    ------     ----   ----               -------
  Normal  Scheduled  3m56s  default-scheduler  Successfully assigned istioinaction/web-api-56d679cf7d-tfxdj to kind1-control-plane
  Normal  Pulling    3m55s  kubelet            Pulling image "docker.io/istio/proxyv2:1.8.3"
  Normal  Pulled     3m55s  kubelet            Successfully pulled image "docker.io/istio/proxyv2:1.8.3" in 490.680774ms
  Normal  Created    3m55s  kubelet            Created container istio-init
  Normal  Started    3m55s  kubelet            Started container istio-init
  Normal  Pulling    3m54s  kubelet            Pulling image "docker.io/istio/proxyv2:1.8.3"
  Normal  Pulled     3m54s  kubelet            Successfully pulled image "docker.io/istio/proxyv2:1.8.3" in 405.035063ms
  Normal  Created    3m54s  kubelet            Created container istio-proxy
  Normal  Started    3m54s  kubelet            Started container istio-proxy
  Normal  Pulled     3m53s  kubelet            Container image "nicholasjackson/fake-service:v0.7.8" already present on machine
  Normal  Created    3m53s  kubelet            Created container web-api
  Normal  Started    3m53s  kubelet            Started container web-api
```

## Recap

Introducing the Istio sidecar to existing services so that they can participate in the service mesh requires care and attention. In this lab we saw approaches to canary the services into the mesh as well as functionality to play nicely with existing workloads where timing and app ordering/startup matters.

## Bonus

Other areas of bringing existing services which we cover are enabling access logs for your service, and more detailed subset routing configurations where there are some gotchas.

[See the Lab 05 bonus section](05a-bonus.md).

## Next Lab

Istio can automatically encrypt traffic between services in the mesh with mutual TLS. In the [next lab](../06-mtls-rollout.md), we will show you how to gradually roll out mTLS to your services in your Istio service mesh.

