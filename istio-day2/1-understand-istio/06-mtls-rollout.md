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

We can see no certificate information was passed in the headers but the call still completed. 

Since we can call either plaintext or mTLS then our services should work for clients in the mesh and outside of the mesh. So how do we start _enforcing_ mTLS?

## Introduce a workload at a time




leverage auto-mtls, permissive mode, and rollout mtls namespace to ns



Show that by default mTLS is enabled:
kubectl exec -it -n istioinaction deploy/sleep -c sleep -- curl httpbin.default:8000/headers

Should see `x-forwarded-client-cert` header:
{
  "headers": {
    "Accept": "*/*", 
    "Content-Length": "0", 
    "Host": "httpbin.default:8000", 
    "User-Agent": "curl/7.69.1", 
    "X-B3-Parentspanid": "9ea78459ca201580", 
    "X-B3-Sampled": "0", 
    "X-B3-Spanid": "73a9eb7dca72f737", 
    "X-B3-Traceid": "041d7e9dba5e7a319ea78459ca201580", 
    "X-Envoy-Attempt-Count": "1", 
    "X-Forwarded-Client-Cert": "By=spiffe://cluster.local/ns/default/sa/httpbin;Hash=99f34e523aa8cabfae710350e2dcb21819261be1ef9ea448ff55855a974de69a;Subject=\"\";URI=spiffe://cluster.local/ns/istioinaction/sa/sleep"
  }
}



add as annnotation.. or on proxyconfig directly:
https://istio.io/latest/docs/ops/configuration/telemetry/envoy-stats/



check stats on the listener

put the namespace is PERMISSIVE mode first (or maybe the entire mesh...)
slowly lockdown specific workloads/ports?
use kiali to review
continue lock down until entire namespace is in strict mode


