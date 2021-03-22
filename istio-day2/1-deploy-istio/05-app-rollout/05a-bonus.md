# Lab 5 - Bonus

## Bonus: Enable access logs for your service

In this section of this lab, we will see how to enable access logging for a service. Access logging is instrumental in understanding what traffic is coming and what are the results of that traffic. In this section, we will enable access logging for _just_ the web-api application. The UX around this is continuously improving, so in the future there may be an easier way to do this. These steps were accurate for Istio 1.8.3.

Let's take a look at the configuration we'll use to configure access logging for the web-api application:

```bash
cat labs/05/web-api-access-logging.yaml
```

We should see a file similar to this:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: web-api-access-logging
  namespace: istioinaction
spec:
  workloadSelector:
    labels:
      app: web-api
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: ANY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: MERGE
      value:
        typed_config:
          "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager"
          access_log:
          - name: envoy.access_loggers.file
            typed_config:
              "@type": "type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog"
              path: /dev/stdout
              format: "[%START_TIME%] \"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%\" %RESPONSE_CODE% %RESPONSE_FLAGS% \"%UPSTREAM_TRANSPORT_FAILURE_REASON%\" %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% \"%REQ(X-FORWARDED-FOR)%\" \"%REQ(USER-AGENT)%\" \"%REQ(X-REQUEST-ID)%\" \"%REQ(:AUTHORITY)%\" \"%UPSTREAM_HOST%\" %UPSTREAM_CLUSTER% %UPSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_REMOTE_ADDRESS% %REQUESTED_SERVER_NAME% %ROUTE_NAME%\n"
```

You can see we are using an `EnvoyFilter` resource to affect the configuration of the web-api's sidecar proxy. Let's apply this resource:

```bash
kubectl apply -f labs/05/web-api-access-logging.yaml
```

Now send some traffic from the sleep pod to the web-api service:

```bash
kubectl exec -it deploy/sleep -- curl http://web-api.istioinaction:8080/
```

After sending some traffic, check the web-api's sidecar proxy logs:

```bash
kubectl logs -n istioinaction deploy/web-api -c istio-proxy
```

You should see something like the following access log:

```text
[2021-03-03T14:40:21.793Z] "GET / HTTP/1.1" 200 - "-" 0 676 10 9 "-" "curl/7.69.1" "6e7a9242-b5f0-45d8-a519-58053bd16eed" "recommendation:8080" "192.168.1.130:8080" outbound|8080||recommendation.istioinaction.svc.cluster.local 192.168.1.139:43462 10.96.1.230:8080 192.168.1.139:41098 - default
```

## Bonus: Subsets for virtual service resources

DestinationRule defines destination policies when client reaches its server and they are applied after routing has occurred. DestinationRule resources are optional. For example, in lab04, our `web-api-gw-vs` doesn't have any DestinationRule resources associated with it. In Istio, subsets are used to describe service versions in virtual service and destination rule resources. You must have a destination rule resource for your service if you have subsets in your virtual service resource. Additionally, if your service need to overwrite the traffic policy from the default, you can configure its traffic policy in your service's destination rule resource.

Let us add `subset: v1` to the `web-api-gw-vs` virtual service resource:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: web-api-gw-vs
spec:
  hosts:
  - "istioinaction.io"
  gateways:
  - web-api-gateway
  http:
  - route:
    - destination:
        host: web-api.istioinaction.svc.cluster.local
        subset: v1
        port:
          number: 8080
```

Deploy this updated resource:

```bash
kubectl apply -f labs/05/web-api-gw-vs-subset.yaml -n istio-system
```

Send some traffic to web-api via istio-ingressgateway:

```bash
curl -H "Host: istioinaction.io" http://istioinaction.io/hello --resolve istioinaction.io:80:$GATEWAY_IP
```

You'll get an empty reply, because the istio-ingressgateway doesn't know how to reach web-api service v1. Create a destination rule resource for web-api service v1.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: web-api-dr
spec:
  host: web-api.istioinaction.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
```

Apply this destination rule resource:

```bash
kubectl apply -f labs/05/web-api-dr.yaml   -n istioinaction
```

Send some traffic to web-api via istio-ingressgateway, you should get 200 status code now.

```bash
curl -H "Host: istioinaction.io" http://istioinaction.io/hello --resolve istioinaction.io:80:$GATEWAY_IP
```

Examine the clusters configuration for istio-ingressgateway:

```bash
istioctl pc clusters deploy/istio-ingressgateway.istio-system
```

Clusters output with subset v1:

```text
SERVICE FQDN                                PORT     SUBSET     DIRECTION     TYPE           DESTINATION RULE
BlackHoleCluster                            -        -          -             STATIC         
agent                                       -        -          -             STATIC         
prometheus_stats                            -        -          -             STATIC         
sds-grpc                                    -        -          -             STATIC         
web-api.istioinaction.svc.cluster.local     8080     -          outbound      EDS            web-api-dr.istioinaction
web-api.istioinaction.svc.cluster.local     8080     v1         outbound      EDS            web-api-dr.istioinaction
xds-grpc                                    -        -          -             STATIC         
zipkin                                      -        -          -             STRICT_DNS
```

Examine the endpoints configuration for istio-ingressgateway:

```bash
istioctl pc endpoint deploy/istio-ingressgateway.istio-system
```

Endpoints output with subset v1:

```text
ENDPOINT                         STATUS      OUTLIER CHECK     CLUSTER
127.0.0.1:15000                  HEALTHY     OK                prometheus_stats
127.0.0.1:15020                  HEALTHY     OK                agent
192.168.1.155:8080               HEALTHY     OK                outbound|8080|v1|web-api.istioinaction.svc.cluster.local
192.168.1.155:8080               HEALTHY     OK                outbound|8080||web-api.istioinaction.svc.cluster.local
unix://./etc/istio/proxy/SDS     HEALTHY     OK                sds-grpc
unix://./etc/istio/proxy/XDS     HEALTHY     OK                xds-grpc
```

## Next Lab

Istio can automatically encrypt traffic between services in the mesh with mutual TLS. In the [next lab](../06-mtls-rollout.md), we will show you how to gradually roll out mTLS to your services in your Istio service mesh.

