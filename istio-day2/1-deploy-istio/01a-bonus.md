# Lab 1 Bonus :: Run Envoy Proxy

## Bonus: Additional notes about Envoy configuration

So far we've taken a basic approach to understanding what the Envoy proxy is and how to configure it. We've also seen how it can alter the behavior of a network call and give us very valuable information about how the network is behaving at the request/message level. We can even do more complicated networking things like:

### Circuit breaking

```
    circuitBreakers:
      thresholds:
      - maxConnections: 1
        maxPendingRequests: 1
        maxRequests: 1
        maxRetries: 1
```

### Outlier detection

```
    outlierDetection:
      consecutive_5xx: 5
      maxEjectionPercent: 100
      interval: 3000ms                                    
```

SPECIAL NOTE: Understanding `healthy_panic_threshold`

```
    outlierDetection:
      consecutive_5xx: 5
      maxEjectionPercent: 100
      interval: 3000ms    
    commonLbConfig:
        healthyPanicThreshold: 100.0
      
```

### Load balancing/client-side load balancing

`lb_type`:

* ROUND_ROBIN
* LEAST_REQUEST
* RING_HASH
* RANDOM
* ORIGINAL_DST_LB
* MAGLEV

```
    lbPolicy: LEAST_REQUEST
```

### Traffic routing

```
routes:
    - match: { prefix: "/foo" }
    route: 
        auto_host_rewrite: true
        cluster: httpbin_service_v1   
        runtime:
        runtime_key: "routing.traffic_shift.helloworld"
        default_value: 100                                    
    - match: { prefix: "/" }
    route: 
        auto_host_rewrite: true
        cluster: httpbin_service_v2 
```        

### Traffic splitting

```
routes:
- match: { prefix: "/" }
    route: 
    auto_host_rewrite: true 
    weighted_clusters:
        runtime_key_prefix: routing.traffic_split.httpbin_service
        clusters:
            - name: httpbin_service.v1
            weight: 33 
            - name: httpbin_service.v2
            weight: 33
            - name: httpbin_service.v3
            weight: 33                                            

```


...and MANY other things. We didn't even crack the surface of the security features Envoy can implement. Envoy is an incredibly powerful and versatile proxy. Take a look at a configuration file with some more substance:

```bash
cat labs/01/envoy-conf-lb.yaml
```

```
admin:
  accessLogPath: /dev/stdout
  address:
    socketAddress:
      address: 0.0.0.0
      portValue: 15000
staticResources:
  listeners:
  - name: httpbin-listener
    address:
      socketAddress:
        address: 0.0.0.0
        portValue: 15001
    filterChains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typedConfig:
          '@type': type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          httpFilters:
          - name: envoy.filters.http.router
          routeConfig:
            name: simple_httpbin_route
            virtualHosts:
            - domains:
              - '*'
              name: httpbin_host
              routes:
              - match:
                  prefix: /
                route:
                  cluster: httpbin_service
                  timeout: 1s
          statPrefix: httpbin
  clusters:
  - connectTimeout: 5s
    loadAssignment:
      clusterName: httpbin_service
      endpoints:
      - lbEndpoints:
        - endpoint:
            address:
              socketAddress:
                address: httpbin
                portValue: 8000
    name: httpbin_service
    circuitBreakers:
      thresholds:
      - maxConnections: 1
        maxPendingRequests: 1
        maxRequests: 1
        maxRetries: 1
    outlierDetection:
      consecutive_5xx: 5
      maxEjectionPercent: 100
      interval: 3000ms
    lbPolicy: LEAST_REQUEST
    respectDnsTtl: true
    dnsLookupFamily: V4_ONLY
    type: STRICT_DNS
    upstreamConnectionOptions:
      tcpKeepalive: {}
```

In the next sections we take a brief look at these configurations and then dig into how Istio actually leverages Envoy. Istio doesn't write files to disk and do a _restart_ or even "hot" restart of the proxy. Istio controls Envoy via a dynamic API and can change values on the fly. Istio provides the "control plane" for Envoy as the "data plane". Let's dig into this a bit more.


## Envoy Discovery (XDS)

Envoy is driven by a set of APIs that configure certain aspects of the proxy. We saw earlier how we specified clusters, listeners, and routes. We can also configure those over Envoy's _xDS_ APIs:

* Listener discovery service (LDS)
* Route discovery service (RDS)
* Cluster discovery service (CDS)
* Service discovery service (SDS/EDS)
* Aggregated discovery service


For example, to dynamically specify listeners over the API, you can configure Envoy's configuration file like this to connect to a gRPC service:

```
dynamic_resources:
    lds_config:   
    api_config_source:
        api_type: GRPC
        grpc_services:
        - envoy_grpc:
            cluster_name: xds_cluster
clusters:
- name: xds_cluster
    connect_timeout: 0.25s
    type: STATIC
    lb_policy: ROUND_ROBIN
    http2_protocol_options: {}
    hosts: [{ socket_address: { address: 127.0.0.3, port_value: 5678 }}]
            
```

Now we don't have to specify listeners ahead of time. We can open them up or close them at runtime based on what use cases a user wants to implement. 

We can do the same thing for the various other sections of the config. To specify ALL of the config through an "aggregate" API, we can configure Envoy like this:

```
dynamic_resources:
    ads_config:   
    api_config_source:
        api_type: GRPC
        grpc_services:
        - envoy_grpc:
            cluster_name: xds_cluster
clusters:
- name: xds_cluster
    connect_timeout: 0.25s
    type: STATIC
    lb_policy: ROUND_ROBIN
    http2_protocol_options: {}
    hosts: [{ socket_address: { address: 127.0.0.3, port_value: 5678 }}]
```


Configuring Envoy through this API is exactly what Istio's control plane does. With Istio we specify configurations in a more user-friendly format and Istio _translates_ that configuration into something Envoy can understand and delivers this configuration through Envoy's _xDS_ API. 

## Next Lab

In the [next lab](02-install-istio.md), we will dig into Istio's control plane a bit more. We'll also see how we can leverage all of these Envoy capabilities (resilience features, routing, observability, security, etc) to implement a secure, observable microservices architecture.                    
