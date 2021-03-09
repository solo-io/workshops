# Lab 3 Bonus :: Connecting to observability systems

## Bonus: Prometheus Kube Stack tips and tricks

If you're familiar with Prometheus, you know that Prometheus gets configured by updating its rules in a `configmap` following the configuration options from [the Prometheus doc](https://prometheus.io/docs/introduction/overview/). Since we're using the operator here, [and specifically the Custom Resources that drive the Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/design.md), there is a level of indirection that can be difficult to translate back to the Prometheus rules, but here's a simple trick to get the underlying Prometheus rules.

The Prometheus rule `configmap` is actually stored as a secret and is updated through the operator configurations. 

```bash
kubectl get secret -n prometheus prometheus-prom-kube-prometheus-stack-prometheus -o jsonpath="{.data['prometheus\.yaml\.gz']}" | base64 -d | gunzip
```

You would see something like this (truncated for brevity):

```
global:                                   
  evaluation_interval: 30s                                                               
  scrape_interval: 30s
  external_labels:                                                                       
    prometheus: prometheus/prom-kube-prometheus-stack-prometheus                         
    prometheus_replica: $(POD_NAME)       
rule_files:               
- /etc/prometheus/rules/prometheus-prom-kube-prometheus-stack-prometheus-rulefiles-0/*.yaml
scrape_configs:                                                                          
- job_name: prometheus/istio-component-monitor/0                                         
  honor_labels: false            
  kubernetes_sd_configs:                                                                 
  - role: endpoints                                                                      
  scrape_interval: 15s                                                                   
  relabel_configs:              
  - action: keep                                                                         
    source_labels:                                                                       
    - __meta_kubernetes_service_label_istio                                              
    regex: pilot                                                                         
  - action: keep                                                                         
    source_labels:                                                                       
    - __meta_kubernetes_endpoint_port_name
    regex: http-monitoring    
```

Now that we have Prometheus and Grafana installed, we can continue to layer observability tools on top. In the next section we install Kiali using the Kiali operator.


## Bonus: Metrics Merging
By default, Istio can [merge ](https://istio.io/latest/docs/ops/integrations/prometheus/#option-1-metrics-merging) your microservice's metrics with the sidecar proxy and Istio agent's metrics.  This ensures the metrics emitted by your microservice can continue to flow to Prometheus while it joins the mesh. As you gradually add sidecars to your services, it is often good practice to evaluate if you still need to emit metrics from your microservice as the sidecar proxies and Istio agents also provide many useful metrics for traffic going through the sidecar proxies.

Below is how you would normally configure your Kubernetes service's associated deployment to have its metrics scraped by Prometheus:

```yaml
  template:
    metadata:
      annotations:
        prometheus.io/path: /stats/prometheus
        prometheus.io/port: "15020"
        prometheus.io/scrape: "true"
```

Let us check if the httpbin service has emitted any metrics:

```bash
kubectl exec -it deploy/httpbin -n default -c istio-proxy -- curl http://localhost:15020/metrics
```

You will get `404 page not found` here because httpbin doesn't emit any metrics at the moment. If your service does emit any metrics, the result should be displayed in the output.

Next, let us check the sidecar proxy's metrics here:

```bash
kubectl exec -it deploy/httpbin -n default -c istio-proxy -- curl http://localhost:15090/stats/prometheus
```

You will get a lot of useful metrics, such as:

```
# TYPE envoy_cluster_internal_upstream_rq_200 counter
envoy_cluster_internal_upstream_rq_200{cluster_name="xds-grpc"} 3

# TYPE envoy_cluster_lb_healthy_panic counter
envoy_cluster_lb_healthy_panic{cluster_name="xds-grpc"} 0

# TYPE envoy_cluster_lb_local_cluster_not_ok counter
envoy_cluster_lb_local_cluster_not_ok{cluster_name="xds-grpc"} 0

# TYPE envoy_cluster_upstream_rq_pending_total counter
envoy_cluster_upstream_rq_pending_total{cluster_name="xds-grpc"} 3

# TYPE envoy_cluster_upstream_rq_per_try_timeout counter
envoy_cluster_upstream_rq_per_try_timeout{cluster_name="xds-grpc"} 0

# TYPE envoy_cluster_upstream_rq_retry counter
envoy_cluster_upstream_rq_retry{cluster_name="xds-grpc"} 0
...
```

You can also view the merged metrics which include any potential metrics from httpbin (none here) and its envoy sidecar and Istio agent:

```bash
kubectl exec -it deploy/httpbin -n default -c istio-proxy -- curl http://localhost:15020/stats/prometheus
```

Some metrics from Istio agent are very interesting, for example:
```
# HELP istio_agent_istio_build Istio component build info
# TYPE istio_agent_istio_build gauge
istio_agent_istio_build{component="citadel_agent",tag="1.8.3"} 1
# HELP istio_agent_scrapes_total The total number of scrapes.
# TYPE istio_agent_scrapes_total counter
istio_agent_scrapes_total 382
# HELP istio_agent_startup_duration_seconds The time from the process starting to being marked ready.
# TYPE istio_agent_startup_duration_seconds gauge
istio_agent_startup_duration_seconds 2.220800518
# HELP istio_agent_total_active_connections The total number of active SDS connections.
# TYPE istio_agent_total_active_connections counter
istio_agent_total_active_connections 2
# HELP istio_agent_total_pushes The total number of SDS pushes.
# TYPE istio_agent_total_pushes counter
istio_agent_total_pushes 2
...
```

With the Istio sidecar proxy running next to your app, you immediately gain access to many metrics provided by Envoy and the Istio agent. You can observe what level of Istio agent you are using, how many total pushes, active connections, total scrapes, along with number of total 200 requests, errors, request retries etc.

TBD: Should we add a section to configure TLS for the app scraping when merging is turned off?
https://github.com/istio/istio/issues/27940#issuecomment-759305377

setting up with TLS requires injecting a sidecar with no redirect rules:
https://istio.io/latest/docs/ops/integrations/prometheus/#tls-settings

## Next Lab

In the [next lab](04-ingress-gateway.md), we will leverage Istio's ingress gateway to secure an edge service and share some tips on how to configure and debug the gateway.        
