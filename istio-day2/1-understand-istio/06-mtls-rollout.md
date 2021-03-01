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

kubectl annotate -n istioinaction deploy/web-api sidecar.istio.io/statsInclusionPrefixes=tls_inspector

