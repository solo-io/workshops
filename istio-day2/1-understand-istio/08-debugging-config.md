# Lab 8 :: Debugging Istio configuration

The service mesh contains proxies that are on the request path between services. When anomalies are detected, it's typically because of a misconfiguration. In this lab, we explore tools to troubleshoot misconfiguration and turn different knobs to tell us more information about where to look. 

## istioctl analyze

The `istioctl` CLI tool contains a few useful tools to help sanity-check configuration. For example, run the following:

```bash
istioctl analyze
```

This will output a set of reports about the state of your Istio configuration; you should see something like this:

```
Info [IST0102] (Namespace default) The namespace is not enabled for Istio injection. Run 'kubectl label namespace default istio-injection=enabled' to enable it, or 'kubectl label namespace default istio-injection=disabled' to explicitly mark it as not needing injection.
Info [IST0118] (Service envoy.default) Port name admin (port: 15000, targetPort: 15000) doesn't follow the naming convention of Istio port.
```

Let's put our configuration in a state of misconfiguration and verify `istioctl analyze` will catch it:

```bash
kubectl delete secret -n istio-system istioinaction-cert
```

The TLS/SSL secret for the `istioinaction.io` hostname should now be missing. Let's run analyze:

```bash
istioctl analyze -n istioinaction
```

Indeed we caught this misconfiguration as an `Error`:

```
Error [IST0101] (Gateway web-api-gateway.istioinaction) Referenced credentialName not found: "istioinaction-cert"
Error: Analyzers found issues when analyzing namespace: istioinaction.
See https://istio.io/v1.8/docs/reference/config/analysis for more information about causes and resolutions.
```

We can also run diagnostics against new configuration **before** we add it to the cluster and detect problems using the state of the cluster as context. Let's see what would happen if we created a `VirtualService` resource that references a `Gateway` that does not exist in the same namespace:

```bash
istioctl analyze labs/08/web-api-gw-vs.yaml -n default
```

```
Error [IST0101] (VirtualService web-api-gw-vs.default labs/08/web-api-gw-vs.yaml:10) Referenced gateway not found: "web-api-gateway"
Info [IST0102] (Namespace default) The namespace is not enabled for Istio injection. Run 'kubectl label namespace default istio-injection=enabled' to enable it, or 'kubectl label namespace default istio-injection=disabled' to explicitly mark it as not needing injection.
Info [IST0118] (Service envoy.default) Port name admin (port: 15000, targetPort: 15000) doesn't follow the naming convention of Istio port.
Error: Analyzers found issues when analyzing namespace: default.
See https://istio.io/v1.8/docs/reference/config/analysis for more information about causes and resolutions.
```

Again, we didn't add the configuration to the cluster yet but we were able to detect forthcoming misconfigurations. 

If some of the errors are too verbose, or you're not interested in seeing them (ie, maybe you don't care that certain namespaces aren't labeled with Istio injection), you can supress them like this:

```bash
istioctl analyze labs/08/web-api-gw-vs.yaml -n default -S "IST0102=Namespace *"
```

Please see the [Istio documentation about `istioctl analyze` for more](https://istio.io/latest/docs/ops/diagnostic-tools/istioctl-analyze/).


## istioctl x describe 

With a lot of different configurations affecting the edge between two services, it can be helpful to ask Istio "what configurations apply to a workload". You can do exactly that with the `istioctl x describe` command. For example, to see what configurations apply to the `web-api` workload, run the following:

```bash
istioctl x describe service web-api -n istioinaction
```

In our simple environment, we can see the following rules:

```
Service: web-api
   Port: http 8080/HTTP targets pod port 8080
RBAC policies: ns[istioinaction]-policy[audit-web-api-authpolicy]-rule[0]


Exposed on Ingress Gateway http://35.202.132.20
VirtualService: web-api-gw-vs
   1 HTTP route(s)
```

This command can make it apparent when a configuration you intended to affect service behavior is present/not present and give you indications about which resources to review. 

Please see the [Istio documentation about `istioctl x describe` for more](https://istio.io/latest/docs/ops/diagnostic-tools/istioctl-describe/).


## istioctl proxy-status

The `istioctl proxy-status` command can be used to get a quick overview about whether configuration from the control plane to the data plane has been sync'd, what `istiod` control plane a workload considers its source of truth, and what version of the proxy a workload is running. For example:

```bash
istioctl proxy-status
```

Here we can see all of the workloads in the mesh with useful details:

```
NAME                                                   CDS        LDS        EDS        RDS        ISTIOD                            VERSION
httpbin-9d9dbcd4-xr8tw.default                         SYNCED     SYNCED     SYNCED     SYNCED     istiod-1-8-3-84c6b6cdc7-ztj84     1.8.3
istio-ingressgateway-5bc557575f-dsc2c.istio-system     SYNCED     SYNCED     SYNCED     SYNCED     istiod-1-8-3-84c6b6cdc7-ztj84     1.8.3
purchase-history-v1-54c8956877-s79qn.istioinaction     SYNCED     SYNCED     SYNCED     SYNCED     istiod-1-8-3-84c6b6cdc7-ztj84     1.8.3
recommendation-7f66565d54-l2d4t.istioinaction          SYNCED     SYNCED     SYNCED     SYNCED     istiod-1-8-3-84c6b6cdc7-ztj84     1.8.3
sleep-854565cb79-krhks.istioinaction                   SYNCED     SYNCED     SYNCED     SYNCED     istiod-1-8-3-84c6b6cdc7-ztj84     1.8.3
web-api-5d56f44d8b-b7pxm.istioinaction                 SYNCED     SYNCED     SYNCED     SYNCED     istiod-1-8-3-84c6b6cdc7-ztj84     1.8.3
```

The most powerful part of the `proxy-status` command is being able to detect drift between the control plane and data plane configurations. For example...

```bash
istioctl proxy-status deploy/web-api -n istioinaction
```

TODO: inject some drift here and see whether proxy-status can detect the diff...

```
Clusters Match
Listeners Match
Routes Match (RDS last loaded at Thu, 04 Mar 2021 08:05:33 MST)
```


## istioctl proxy-config

As we've seen in previous labs, the `istioctl proxy-config` command can be used to query the proxy for its configuration for particular elements. You can see the [Istio docs for](https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/#deep-dive-into-envoy-configuration) more information. In this lab we will cover two critical parts of the `istioctl proxy-config` command: data plane configuration and data plane logging

### Config

The `istioctl proxy-config` command allows you to review the data plane configuration which effectively comes from the `/config_dump` endpoint on Envoy's admin module. We can go right to the admin API with the following command:

```bash
istioctl dashboard envoy <pod-name[.namespace]>
```

This takes us to the Envoy dashboard and gives access to things like `/stats`, `/server_info`, and the full `/config_dump`. Another important endpoint is the `/clusters` endpoint which gives detailed information for all of the Envoy clusters including the specific endpoints that make up a cluster. You can also see endpoint information (EDS) in the full config dump with `/config_dump?include_eds`.

> :pushpin: As an exercise for the reader, try to run the `istioctl dashboard envoy` command and explore these different endpoints

### Logging

Envoy proxy can be configured to increase logging levels to very fine-grained "debug" level which will help you understand more about what's happening on the data plane. Envoy also categorizes different modules for logging, so you can enable/disable logging for just the components you need to review. 

For example, to turn on `debug` logging for a particular pod:

```bash
istioctl proxy-config log deploy/web-api -n istioinaction --level debug
```

To configure just a specific module for debug:

```bash
istioctl proxy-config log deploy/web-api -n istioinaction --level connection:debug,conn_handler:debug,filter:debug,router:debug,http:debug,upstream:debug
```

The following logging levels are available:

* trace
* debug
* info
* warning
* error
* critical
* off

Some of the common subsections used to debug connection/routing issues are seen above. The full list is in this table:


<table>
<tr>
    <td>admin</td>
    <td>aws</td>
    <td>assert</td>
    <td>backtrace</td>
    <td>client</td>
</tr>
<tr>
    <td>config</td>
    <td>connection</td>
    <td>conn_handler</td>
    <td>dubbo</td>
    <td>file</td>
</tr>
<tr>
    <td>filter</td>
    <td>forward_proxy</td>
    <td>grpc</td>
    <td>hc</td>
    <td>health_checker</td>
</tr>
<tr>
    <td>http</td>
    <td>http2</td>
    <td>hystrix</td>
    <td>init</td>
    <td>io</td>
</tr>
<tr>
    <td>jwt</td>
    <td>kafka</td>
    <td>lua</td>
    <td>main</td>
    <td>misc</td>
</tr>
<tr>
    <td>mongo</td>
    <td>quic</td>
    <td>pool</td>
    <td>rbac</td>
    <td>redis</td>
</tr>
<tr>
    <td>router</td>
    <td>runtime</td>
    <td>stats</td>
    <td>secret</td>
    <td>tap</td>
</tr>
<tr>
    <td>testing</td>
    <td>thrift</td>
    <td>tracing</td>
    <td>upstream</td>
    <td>udp</td>
</tr>
<tr>
    <td>wasm</td>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
</tr>
</table>


## profile dumps of control plane / agent / envoy?

kubectl port-forward -n istio-system deploy/istiod 8080:8080

More notes:

https://docs.google.com/document/d/1QXsh3m2UQY00OHh2Uyi7W9Cj8XoY69Bn5rrBTarMOKk/edit#

https://github.com/istio/istio/wiki/Analyzing-Istio-Performance#cpu-profile

## Additional debug paths

Istio provides a nice `debug` interface on the Istio control plane. We can call it with the convenience command on the `pilot-discovery` like we did in the previous step. We could also call it from `curl` or any HTTP client like:

```bash
kubectl exec -it deploy/sleep -- curl http://istiod.istio-system:15014/debug/registryz
```

Some additional paths that are definitely useful for debugging the control plane:

| Path | Description |
| ---- | ----------- |
| /debug/edsz | Status and debug interface for EDS |
| /debug/ndsz | Status and debug interface for NDS |
| /debug/adsz | Status and debug interface for ADS |
| /debug/adsz?push=true | Initiates push of the current state to all connected endpoints | 
| /debug/syncz | Synchronization status of all Envoys connected to this Pilot instance |
| /debug/config_distribution | Version status of all Envoys connected to this Pilot instance |
| /debug/registryz | Debug support for registry |
| /debug/endpointz | Debug support for endpoints |
| /debug/endpointShardz | Info about the endpoint shards |
| /debug/cachez | Info about the internal XDS caches |
| /debug/configz | Debug support for config |
| /debug/resourcesz | Debug support for watched resources |
| /debug/instancesz | Debug support for service instances |
| /debug/authorizations | Internal authorization policies |
| /debug/config_dump | ConfigDump in the form of the Envoy admin config dump API for passed in proxyID |
| /debug/push_status | Last PushContext Details |
| /debug/inject | Active inject template |

For example, to get the EDS debug info for the httpbin service proxy:

```bash
export HTTPBIN_ID=$(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it deploy/sleep -- curl http://istiod.istio-system:15014/debug/edsz?proxyID=$HTTPBIN_ID
```

To get Prometheus metrics for the `istiod` control plane:

```bash
kubectl exec -it deploy/sleep -- curl http://istiod.istio-system:15014/metrics
```

To get Istiod version:

```bash
kubectl exec -it deploy/sleep -- curl http://istiod.istio-system:15014/version
```


## debug endpoints on CP (maybe move that from lab 02?)

what about controlz?
istioctl dashboard controlz deploy/istiod-1-8-3

http://localhost:8080/debug

To get the profile:

http://localhost:8080/debug/pprof/profile?seconds=30



enabling logging for istiod
by cli flag:
https://istio.io/latest/docs/reference/commands/pilot-discovery/

more here:
https://istio.io/latest/docs/ops/diagnostic-tools/component-logging/


also envoy version: 

kubectl exec -it productpage-v1-6b746f74dc-9stvs -c istio-proxy -n default  -- pilot-agent request GET server_info --log_as_json | jq {version}


## health checking on proxy/agent via health ports

curl localhost:15021/healthz/ready

maybe worth calling out all ports on envoy/control plane?
