
# Lab 1 :: Run Envoy Proxy

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-day2/1-understand-istio/` 

#### Install supporting services
kubectl apply -f httpbin.yaml
kubectl apply -f sleep.yaml

$ kubectl exec -it deploy/sleep -- curl httpbin:8000/headers
{
  "headers": {
    "Accept": "*/*", 
    "Host": "httpbin:8000", 
    "User-Agent": "curl/7.69.1"
  }
}

#### Review envoy config
cat envoy-conf.yaml
kubectl create cm envoy --from-file=envoy.yaml=./envoy-conf.yaml -o yaml --dry-run=client | k apply -f -
kubectl rollout restart deploy/envoy
kubectl apply -f envoy-proxy.yaml

$ kubectl exec -it deploy/sleep -- curl http://envoy/headers
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "envoy", 
    "User-Agent": "curl/7.69.1", 
    "X-Envoy-Expected-Rq-Timeout-Ms": "15000"
  }
}


### Let's change the expected timeout

```
- match: { prefix: "/" }
    route: 
        auto_host_rewrite: true
        cluster: httpbin_service   
        timeout: 1s
```

kubectl create cm envoy --from-file=envoy.yaml=./envoy-conf-timeout.yaml -o yaml --dry-run=client | k apply -f -
kubectl rollout restart deploy/envoy

$ kubectl exec -it deploy/sleep -- curl http://envoy/headers
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "envoy", 
    "User-Agent": "curl/7.69.1", 
    "X-Envoy-Expected-Rq-Timeout-Ms": "1000"
  }
}
    
                            

### Admin stats

Let's curl the admin stats API

$ kubectl exec -it deploy/sleep -- curl http://envoy:15000/stats



### Admin stats

Wow, that's a lot of good info! Let's trim it down:

$ kubectl exec -it deploy/sleep -- curl http://envoy:15000/stats | grep retry

cluster.httpbin_service.circuit_breakers.default.rq_retry_open: 0
cluster.httpbin_service.circuit_breakers.high.rq_retry_open: 0
cluster.httpbin_service.retry_or_shadow_abandoned: 0
cluster.httpbin_service.upstream_rq_retry: 0
cluster.httpbin_service.upstream_rq_retry_backoff_exponential: 0
cluster.httpbin_service.upstream_rq_retry_backoff_ratelimited: 0
cluster.httpbin_service.upstream_rq_retry_limit_exceeded: 0
cluster.httpbin_service.upstream_rq_retry_overflow: 0
cluster.httpbin_service.upstream_rq_retry_success: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry_limit_exceeded: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry_overflow: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry_success: 0


### Retries

Let's add some retry semantics to `httpbin_service`. 
Open The `conf/simple.yaml` file and add (or see the `conf/simple_retry.yaml` file):

```
- match: { prefix: "/" }
    route: 
    auto_host_rewrite: true
    cluster: httpbin_service   
    retry_policy:
        retry_on: 5xx
        num_retries: 3    
```




### Restart with new config

kubectl create cm envoy --from-file=envoy.yaml=./envoy-conf-retry.yaml -o yaml --dry-run=client | k apply -f -
kubectl rollout restart deploy/envoy


### Call an endpoint in error

Curl the proxy to generate a `500`

$ kubectl exec -it deploy/sleep -- curl http://envoy/status/500

Review the envoy admin stats:
$ kubectl exec -it deploy/sleep -- curl http://envoy:15000/stats | grep retry

cluster.httpbin_service.circuit_breakers.default.rq_retry_open: 0
cluster.httpbin_service.circuit_breakers.high.rq_retry_open: 0
cluster.httpbin_service.retry.upstream_rq_500: 3
cluster.httpbin_service.retry.upstream_rq_5xx: 3
cluster.httpbin_service.retry.upstream_rq_completed: 3
cluster.httpbin_service.retry_or_shadow_abandoned: 0
cluster.httpbin_service.upstream_rq_retry: 3
cluster.httpbin_service.upstream_rq_retry_backoff_exponential: 3
cluster.httpbin_service.upstream_rq_retry_backoff_ratelimited: 0
cluster.httpbin_service.upstream_rq_retry_limit_exceeded: 1
cluster.httpbin_service.upstream_rq_retry_overflow: 0
cluster.httpbin_service.upstream_rq_retry_success: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry_limit_exceeded: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry_overflow: 0
vhost.httpbin_host.vcluster.other.upstream_rq_retry_success: 0


### Additional config: circuit breaking

```
    circuitBreakers:
      thresholds:
      - maxConnections: 1
        maxPendingRequests: 1
        maxRequests: 1
        maxRetries: 1
```



### Additional config: outlier detection

```
    outlierDetection:
      consecutive_5xx: 5
      maxEjectionPercent: 100
      interval: 3000ms                                    
```

### SPECIAL NOTE for outlier detection

Understanding `healthy_panic_threshold`

```
    outlierDetection:
      consecutive_5xx: 5
      maxEjectionPercent: 100
      interval: 3000ms    
    commonLbConfig:
        healthyPanicThreshold: 100.0
      
```
                      



### Additional config: load balancing

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



### Additional config: traffic shifting

```
routes:
    - match: { prefix: "/" }
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



### Additional config: traffic splitting

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




### Envoy Discovery (XDS)

* Listener discovery service (LDS)
* Route discovery service (RDS)
* Cluster discovery service (CDS)
* Service discovery service (SDS/EDS)
* Aggregated discovery service



### Envoy Discovery (LDS)
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


### Envoy Discovery (EDS)
```
clusters:
- name: httpbin_service
    dns_lookup_family: V4_ONLY
    connect_timeout: 5s
    type: EDS
    lb_policy: ROUND_ROBIN
    eds_cluster_config:
    eds_config:
        api_config_source:
        api_type: GRPC
        cluster_names: [xds_cluster]
```



### Aggregated Discovery (ADS)
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
                    
