# Lab 8 :: Debugging Istio configuration

## istioctl analyze

should create some scenarios earlier in the labs and by the time we get here, we should debug them?

* analyzes live cluster
* analyze config before applying to cluster (using live cluster)
https://istio.io/latest/docs/ops/diagnostic-tools/istioctl-analyze/

## istioctl proxy-status

determind diff between Istiod push and what Envoy has!! This is awesome!
istioctl proxy-status details-v1-6dcc6fbb9d-wsjz4.default


## istioctl proxy-config

for specific snippet by name
bootstrap
secret

enabling logging for Envoy, some tips and tricks

## istioctl x describe 

maybe to show mTLS config, destination rules, VS apply to a specific workload? we should have those settings in the lab up until this point

https://istio.io/latest/docs/ops/diagnostic-tools/istioctl-describe/



## profile dumps of control plane / agent / envoy?

## debug endpoints on CP (maybe move that from lab 02?)

what about controlz?

enabling logging for istiod
by cli flag:
https://istio.io/latest/docs/reference/commands/pilot-discovery/

more here:
https://istio.io/latest/docs/ops/diagnostic-tools/component-logging/


also envoy version: kubectl exec -it productpage-v1-6b746f74dc-9stvs -c istio-proxy -n default  -- pilot-agent request GET server_info --log_as_json | jq {version}


## health checking on proxy/agent via health ports

curl localhost:15021/healthz/ready

maybe worth calling out all ports on envoy/control plane?
