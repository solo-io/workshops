# Lab 6 :: Rollout mTLS to your services

Istio can automatically encrypt traffic between services in the mesh with mutual TLS. For this to happen, both sides of the connection must be in the mesh and configured for mTLS. By default, with no configuration specified, Istio will adopt a "permissive" policy which means services will be able to communicate with plaintext or mTLS, depending on what the client can do. This makes it easier to introduce Istio's sidecar proxy to existing services without breaking those services that still expect plaintext. 

In the previous lab, we iteratively introduced the sidecar proxies to our services. In this lab, we'll see how to iteratively roll out mTLS to our services in a safe way.

## Prequisites

In this lab we assume you have the sample services deployed into the `istioinaction` namespace with the Istio sidecar proxy deployed with each instance. In other words, we assume that the services in the `istioinaction` namespace are all part of the mesh.

```bash
kubectl get po -n istioinaction
```

Should look something like this:

```bash
NAME                                   READY   STATUS    RESTARTS   AGE
purchase-history-v1-54c8956877-5cxq6   2/2     Running   0          3h35m
recommendation-7f66565d54-bl8s2        2/2     Running   0          3h36m
sleep-854565cb79-vz7bb                 2/2     Running   0          3h35m
web-api-5d56f44d8b-bklll               2/2     Running   0          3h35m
```

We also assume that you have the `httpbin` and `sleep` services deployed into the `default` namespace with the `sleep` service NOT part of the service mesh:

```bash
kubectl get po -n default
```

```
NAME                       READY   STATUS    RESTARTS   AGE
httpbin-5dfd48f68d-77sfb   2/2     Running   0          5d12h
sleep-854565cb79-h9qbl     1/1     Running   0          5d11h
```

## First steps

By default, Istio adopts a PERMISSIVE mode for mTLS. Even though that's the case, we want to always be explicit with our configuration especially as we introduce new services to the mesh. Let's create an explicit policy setting the authentication/mTLS to permissive for the entire mesh:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE

```


```bash
kubectl apply -f labs/06/default-peerauth-permissive.yaml
```

At this point, services within the mesh should be able to call others in the mesh and mTLS will be enabled automatically. Any services outside of the mesh should also still be able to call into the mesh over plaintext. Let's see.

For services in the mesh:

```bash
kubectl exec -it deploy/sleep -c sleep -n istioinaction -- curl httpbin.default:8000/headers
```

```
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.default:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Parentspanid": "5a4877d55f03bdb7", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "b63dc7b91a144175", 
    "X-B3-Traceid": "5e393151e48acc3c5a4877d55f03bdb7", 
    "X-Envoy-Attempt-Count": "1", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/default/sa/httpbin;Hash=8b578c6aa4df3ab70c6de5f22e858a5d94a80c42f18b94d2f341442f5b653f82;Subject=\"\";URI=spiffe://cluster.local/ns/istioinaction/sa/sleep"
  }
}
```

We see above both the `httpbin` and `sleep` services are part of the mesh and we can verify that mTLS is used because the `x-forwarded-client-cert` are part of the request headers.

If we run the following command for a service outside of the mesh talking to one inside the mesh:

```bash
kubectl exec -it deploy/sleep -c sleep -n default -- curl httpbin.default:8000/headers
```

Now you should see a response similar to this:

```
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.default:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "6dfdddfdeb747568", 
    "X-B3-Traceid": "7ed8b978c898d7e46dfdddfdeb747568"
  }
}
```

We can see no certificate information was passed in the headers but the call still completed successfully. 

Since we can call either plaintext or mTLS then our services should work for clients in the mesh and outside of the mesh. So how do we start _enforcing_ mTLS?

## Introduce strict mTLS one service at a time

We can enforce mTLS one workload at a time using matchLabels and selectors like the following:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: purchase-history-strict
  namespace: istioinaction
spec:
  selector:
    matchLabels:
      app: purchase-history
  mtls:
    mode: STRICT

```

If we enable mTLS one workload at a time, we need to also create destination rules for those clients:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: purchase-history-dr
  namespace: istioinaction
spec:
  host: purchase-history.istioinaction.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

Let's try enable this:


```bash
kubectl apply -f labs/06/purchase-history-strict.yaml
```

Let's try call our services in the `istioinaction` namespace from _outside_ that namespace:

```bash
kubectl exec -it -n default deploy/sleep -- curl web-api.istioinaction:8080
```

It still works because we called a service different than the one we locked down with mTLS. But since that service, `purchase-history` is part of the call graph, we should verify that indeed it was mTLS. We can do this by looking at the Kiali dashboard we installed in Lab 03. 

Port-forward Kiali and navigate to the dashboard:

```bash
kubectl port-forward -n istio-system deploy/kiali 20001
```

And navigate to [http://localhost:20001](http://localhost:20001) and select the Graph tab.

On the "Display" drop down, select "Security":

![](./images/kiali-check-security.png)

Now click on the call graph between `recommendation` and `purchase-history` service. You should see that indeed this call is enforced with mTLS.

![](./images/kiali-check-mtls.png)

Kiali is one way to verify mTLS connectivity, but not all services will show up in Kiali unfortunately. 

So what if you have services that take traffic from services outside of the mesh and are not immediately apparent to Kiali? How can we switch to `STRICT` mTLS safely without breaking them?


## Who's calling with mTLS or Plaintext?

In the previous lab we enabled `STRICT` mTLS for a particular service in the call graph without regard for whether any non-mesh services may be calling it. If they had, they would begin to fail as they wouldn't be participating in mTLS unless they were in the mesh. 

We have some options for reviewing whether a service is taking plaintext connections and deciding to enable `STRICT` mTLS for that service only when it does NOT take any plaintext calls anymore. 

To do this, we can use a combination of Envoy metrics and request logging. In our examples above, the `web-api` service can take plaintext or mTLS traffic. Let's see how we can tell the difference.

First, let's enable some new metrics on the `web-api` workload called `tls_inspector` and `listener.*.ssl`. With these metrics we can determine whether connections coming in are only mTLS or plaintext. 

To enable these metrics in Istio for the `web-api` workload, we need to whitelist them. We can do that [mesh wide](https://istio.io/latest/docs/ops/configuration/telemetry/envoy-stats/) or per workload with the following annotation:

```yaml
  template:
    metadata:
      labels:
        app: web-api
        version: v1
      annotations:
        sidecar.istio.io/statsInclusionPrefixes: "tls_inspector,listener.0.0.0.0_15006"
    spec:
```

Let's apply this deployment:

```bash
kubectl -n istioinaction apply -f labs/06/web-api-incl-stats.yaml
```

Now let's curl some of the stats available for the newly exposed `tls_inspector`:

```bash
kubectl exec -it -n istioinaction deploy/web-api -c istio-proxy -- curl localhost:15000/stats | grep tls_inspector
```

```
tls_inspector.alpn_found: 0
tls_inspector.alpn_not_found: 0
tls_inspector.client_hello_too_large: 0
tls_inspector.connection_closed: 0
tls_inspector.read_error: 0
tls_inspector.sni_found: 0
tls_inspector.sni_not_found: 0
tls_inspector.tls_found: 0
tls_inspector.tls_not_found: 0
```

You can find more information about the Envoy `tls_inspector` [on the Envoy documentation](https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listener_filters/tls_inspector). 

We can also see connection/ssl information from the listener:

```bash
kubectl exec -it -n istioinaction deploy/web-api -c istio-proxy -- curl localhost:15000/stats | grep listener.0.0.0.0
```

In this set of metrics, we see the following interesting stats (among others):

```
listener.0.0.0.0_15006.downstream_cx_active: 0
listener.0.0.0.0_15006.downstream_cx_destroy: 0
listener.0.0.0.0_15006.downstream_cx_overflow: 0
listener.0.0.0.0_15006.downstream_cx_total: 0
...
listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_1xx: 0
listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_2xx: 0
listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_3xx: 0
listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_4xx: 0
listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_5xx: 0
listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_completed: 0
listener.0.0.0.0_15006.no_filter_chain_match: 0
listener.0.0.0.0_15006.server_ssl_socket_factory.downstream_context_secrets_not_ready: 0
listener.0.0.0.0_15006.server_ssl_socket_factory.ssl_context_update_by_sds: 6
listener.0.0.0.0_15006.server_ssl_socket_factory.upstream_context_secrets_not_ready: 0
listener.0.0.0.0_15006.ssl.connection_error: 0
listener.0.0.0.0_15006.ssl.fail_verify_cert_hash: 0
listener.0.0.0.0_15006.ssl.fail_verify_error: 0
listener.0.0.0.0_15006.ssl.fail_verify_no_cert: 0
listener.0.0.0.0_15006.ssl.fail_verify_san: 0
listener.0.0.0.0_15006.ssl.handshake: 0
listener.0.0.0.0_15006.ssl.no_certificate: 0
listener.0.0.0.0_15006.ssl.ocsp_staple_failed: 0
listener.0.0.0.0_15006.ssl.ocsp_staple_omitted: 0
listener.0.0.0.0_15006.ssl.ocsp_staple_requests: 0
listener.0.0.0.0_15006.ssl.ocsp_staple_responses: 0
listener.0.0.0.0_15006.ssl.session_reused: 0
```

These metrics can be used to determine whether plaintext connections are still coming in when we expect only mTLS connections (for those services in the mesh). For example, let's send a plaintext call into the `web-api` service and review some of these metrics:

```bash
kubectl exec -it -n default deploy/sleep -- curl web-api.istioinaction:8080
```

If we check `tls_inspector`

```bash
kubectl exec -it -n istioinaction deploy/web-api -c istio-proxy -- curl localhost:15000/stats | grep tls_inspector
```
```
tls_inspector.sni_found: 0
tls_inspector.sni_not_found: 0
tls_inspector.tls_found: 0
tls_inspector.tls_not_found: 2
```

We see that the `tls_not_found` stat incremented... (it incremented by 2, we'll explain this in the workshop).

Let's check the listener stats:

```bash
kubectl exec -it -n istioinaction deploy/web-api -c istio-proxy -- curl localhost:15000/stats | grep listener.0.0.0.0
```

```
listener.0.0.0.0_15006.downstream_cx_active: 0
listener.0.0.0.0_15006.downstream_cx_destroy: 1
listener.0.0.0.0_15006.downstream_cx_overflow: 0
listener.0.0.0.0_15006.downstream_cx_total: 1
...

listener.0.0.0.0_15006.http.inbound_0.0.0.0_8080.downstream_rq_completed: 1
...
listener.0.0.0.0_15006.ssl.handshake: 0
...
```

We can see we had a connection come in to the listener, but we did not have a corresponding `ssl.handshake` increment. 

For the user: try calling with a service in the mesh that will establish TLS/mTLS and evaluate what the stats look like:

```bash
kubectl exec -it -n istioinaction deploy/sleep -c sleep -- curl web-api.istioinaction:8080
```

By whitelisting these stats for workloads that you're trying to evaluate whether or not to convert to `STRICT` mTLS, you can tell whether it's safe to do so. You could pull these stats into a TSDB/Prometheus to get a holistic view of all replicas in a workload (exercise left to the reader). 

This is not the only way, however. Let's see how we can use access logging and authorization policies to do something similar.


## Use AuthorizationPolicy and Access Logging to evaluate whether it's safe to convert to STRICT mTLS

Another way to help evaluate whether it's safe to migrate a mesh workload to `STRICT` mTLS is to examine access logging to determine whether an incoming request is on a TLS connection or not. We can combine this with Istio's AuthorizationPolicy and identify when a request does not have a source identity (Istio uses SPIFFE for it's identity model).

Let's see what this looks like in practice. Let's specify an AuthorizationPolicy that checks whether a source principal is not from within a certain namespace. You could open this up wider than just the namespace, but we can focus on namespace to start.

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: audit-web-api-authpolicy
 namespace: istioinaction
spec:
  selector:
    matchLabels:
      app: web-api
  action: AUDIT
  rules:
  - from:
    - source:
        notNamespaces: ["istioinaction"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/*"]

```

Note, with this policy, we're saying that if traffic coming to our `web-api` service does not have a mTLS identity that originates in the `istioinaction` namespace, then we should `AUDIT` the request. This means we will still allow the request, but will annotate the request so we know it was triggered by this policy. For plaintext connections, this source identity will be blank so this will trigger the `AUDIT` rule. 

```bash
kubectl apply -f labs/06/audit-auth-policy.yaml
```

Now, we need some way to see whether a request has been audited or not. We can do that with access logging:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: web-api-access-log
  namespace: istioinaction
spec:
  workloadSelector:
    labels:
      app: web-api
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: SIDECAR_INBOUND
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
              format: "[%START_TIME%] \"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%\" %RESPONSE_CODE% %RESPONSE_FLAGS% \"%UPSTREAM_TRANSPORT_FAILURE_REASON%\" %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% \"%REQ(X-FORWARDED-FOR)%\" cert: \"%REQ(X-FORWARDED-CLIENT-CERT)%\" audit_flag: \"%DYNAMIC_METADATA(envoy.common:access_log_hint)%\"\n"

```

The important bits of the access log are the `format` section. We added `%REQ(X-FORWARDED-CLIENT-CERT)%` and `%DYNAMIC_METADATA(envoy.common:access_log_hint)%` The former field will print out any TLS/mTLS cert information. For plaintext connections, this will be empty. The latter field is set to `true` when it triggers the `AUDIT` authorization policy from above. Let's apply this `EnvoyFilter` :

```bash
kubectl apply -f labs/06/web-api-access-logging-audit.yaml
```

Now call the `web-api` service from within the mesh with mTLS:

```bash
kubectl exec -it -n istioinaction deploy/sleep -c sleep -- curl web-api.istioinaction:8080
```

If we check the logs of the `web-api` service, we should see something similar to the following:

```bash
[2021-03-02T14:26:28.710Z] "GET / HTTP/1.1" 200 - "-" 0 1102 9 8 "-" cert: "By=spiffe://cluster.local/ns/istioinaction/sa/web-api;Hash=6db8be07ebcbaffdd88c7652e0cc34e264c0d6b484b98074ffa61a6e7cb1aec3;Subject="";URI=spiffe://cluster.local/ns/istioinaction/sa/sleep" audit_flag: "false"
```

Notice the `X-Forwarded-Client-Cert` header and the `audit_flag` field.

Now let's call the service from outside the mesh:

```bash
kubectl exec -it -n default deploy/sleep -- curl web-api.istioinaction:8080
```

Now if we check the access logging, we should see there is no X-F-C-C header and the `audit_flag` is `true`:

```
[2021-03-02T14:27:12.765Z] "GET / HTTP/1.1" 200 - "-" 0 1102 9 8 "-" cert: "-" audit_flag: "true"
```

We can scrape all of these access logs into Splunk or Elastic Search and determine whether it's safe to enable mTLS when there are no longer any calls without proper mTLS identity and credentials. 

## Apply strict mTLS

When you are comfortable that there are no more plaintext connections coming into your service, you can apply a `STRICT` mTLS policy to your namespace:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istioinaction
spec:
  mtls:
    mode: STRICT

```

```bash
kubectl apply -f labs/06/istioinaction-peerauth-strict.yaml
```
