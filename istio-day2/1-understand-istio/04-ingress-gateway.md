# Lab 4 :: Ingress Gateway

Typically, people start by adopting the ingress gateway.. if you need something more capable, check out gloo edge

istioctl install -y -n istio-system -f labs/04/ingress-gateways.yaml --revision 1-8-3

# expose our sample apps
kubectl -n istioinaction apply -f sample-apps/ingress/

# we should curl the gateway
NOTE we need to use kind (or give hints for how to find the ingress gw ip)

curl -H "Host: istioinaction.io" http://35.202.132.20

# using istioctl pc
ingress gateway is a simple envoy proxy (dig into real quick) / dig into istioctl proxy-config

istioctl pc routes istio-ingressgateway-7967d894f7-2frnd.istio-system 

```bash
istioctl pc routes istio-ingressgateway-7967d894f7-2frnd.istio-system --name http.80 -o json
```

Output: 
```
[
    {
        "name": "http.80",
        "virtualHosts": [
            {
                "name": "istioinaction.io:80",
                "domains": [
                    "istioinaction.io",
                    "istioinaction.io:*"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/"
                        },
                        "route": {
                            "cluster": "outbound|8080||web-api.istioinaction.svc.cluster.local",
                            "timeout": "0s",
                            "retryPolicy": {
                                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes",
                                "numRetries": 2,
                                "retryHostPredicate": [
                                    {
                                        "name": "envoy.retry_host_predicates.previous_hosts"
                                    }
                                ],
                                "hostSelectionRetryMaxAttempts": "5",
                                "retriableStatusCodes": [
                                    503
                                ]
                            },
                            "maxStreamDuration": {
                                "maxStreamDuration": "0s"
                            }
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/istioinaction/virtual-service/web-api-gw-vs"
                                }
                            }
                        },
                        "decorator": {
                            "operation": "web-api.istioinaction.svc.cluster.local:8080/*"
                        }
                    }
                ],
                "includeRequestAttemptCount": true
            }
        ],
        "validateClusters": false
    }
]
```

# https on gateway 
securing the traffic coming into the cluster
secrets need to be in the same namespace as the gateway (ie, in istio-system as needed)

the secrets are in labs/04/certs
but they can be auto generated again if needed with the ./generate-*.sh scripts

```bash
kubectl create -n istio-system secret tls istioinaction-cert --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt
```

Create the HTTPS gateway
(should cat it to see it here)

```bash
kubectl -n istioinaction apply -f labs/04/web-api-gw-https.yaml
```

Example calling it:

```bash
curl -k -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:35.202.132.20
```

TODO: we don't want to use -k, we should use a cert signed by a CA
Problem is, this is self signed... we should just get a CA going and sign it from there so we can get it to work correctly

```
curl --cacert ./labs/04/certs/ca/root-ca.crt  -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:35.202.132.20
```


From here we should suggest one of two ways to mitigate the cross-NS cert/config issue:

1) user gateways + secrets in own NS
2) copy secrets over to istio-system with kubed
3) another workflow automated around vault/cert-manager?



# With cert manager with resources in own namesapces, deploy certificate to istio-system

kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

install CRDs??
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.crds.yaml

helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.2.0 --create-namespace --set installCRDs=true

create CA as a kube secret

kubectl create -n cert-manager secret tls cert-manager-cacerts --cert labs/04/certs/ca/root-ca.crt --key labs/04/certs/ca/root-ca.key

create cluster issuer
kubectl apply -f labs/04/cert-manager/ca-cluster-issuer.yaml 

create certificate
kubectl apply -f labs/04/cert-manager/istioinaction-io-cert.yaml 

check certificate
kubectl get secret -n istio-system example-istioinaction-cert -o jsonpath="{.data['tls\.crt']}" | base64 -D | step certificate inspect -

# deploy config and secret in own namespace, copy over to istio-system
https://appscode.com/products/kubed/v0.11.0/guides/config-syncer/intra-cluster/


install kubed
helm repo add appscode https://charts.appscode.com/stable/
helm repo update
helm install kubed appscode/kubed --version v0.12.0 --namespace kube-system

clean up previous step
kubectl delete -f ./labs/04/cert-manager/istioinaction-io-cert.yaml
kubectl -n istio-system delete secret istioinaction-cert
kubectl rollout restart deploy/istio-ingressgateway -n istio-system
try curl to make sure it fails

create cert in own namespace

kubectl create -n istioinaction secret tls istioinaction-cert --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt

label istio-system
kubectl label namespace istio-system secrets-sync=true

label the secret locally:
kubectl -n istioinaction annotate secret istioinaction-cert kubed.appscode.com/sync="secrets-sync=true"

cleanup:
remove annotation
kubectl -n istioinaction annotate secret istioinaction-cert kubed.appscode.com/sync-
kubectl -n istio-system delete secret istioinaction-cert
kubectl -n istioinaction delete secret istioinaction-cert
kubectl rollout restart deploy/istio-ingressgateway -n istio-system
curl to make sure it fails

# resource + cert in own namespace
istioctl install -y -n istioinaction -f labs/04/my-user-gateway.yaml --revision 1-8-3

$ k get po -n istioinaction
NAME                                  READY   STATUS    RESTARTS   AGE
my-user-gateway-6746b98474-tkzn7      1/1     Running   0          12s
purchase-history-v1-b47996677-lskt9   1/1     Running   0          31h
recommendation-69995f55c9-rddwz       1/1     Running   0          31h
web-api-745fdb5bdf-jbbp4              1/1     Running   0          31h

$ k get svc -n istioinaction
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                                                      AGE
my-user-gateway    LoadBalancer   10.44.0.7      <pending>     15021:32133/TCP,80:31427/TCP,443:32496/TCP,15443:30130/TCP   19s
purchase-history   ClusterIP      10.44.9.192    <none>        8080/TCP                                                     31h
recommendation     ClusterIP      10.44.2.120    <none>        8080/TCP                                                     31h
web-api            ClusterIP      10.44.12.150   <none>        8080/TCP   

add secret:
kubectl create -n istioinaction secret tls my-user-gw-istioinaction-cert --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt

kubectl apply -f labs/04/my-user-gw-https.yaml


# leave a note about how the second workshop will go into best practices here around security keys on kubernetes, etc incuding HSM/Vault

# private vs public gateway/LB -- integrating with ALB/NLB

understand AWS LB: 
https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html

Install AWS LB Controller
https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/

Use NLB-IP mode:
https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/nlb_ip_mode/

See following gateway resources:

cat ./labs/04/ingress-gateways-public.yaml
cat ./labs/04/ingress-gateways-private.yaml
cat ./labs/04/ingress-gateways-nlb-hc.yaml

# REDUCE CONFIG SIZE to only VSs with config.. using that Pilot Env Variable
check clusters known by ing gw
istioctl pc clusters istio-ingressgateway-97c7688bb-sjnrd.istio-system

istioctl install -y -n istio-system -f labs/04/control-plane-reduce-gw-config.yaml --revision 1-8-3

check deployment of istiod
k get deploy/istiod-1-8-3 -n istio-system -o jsonpath="{.spec.template.spec.containers[].env[0]}"
should see something like this:
{"name":"PILOT_FILTER_GATEWAY_CLUSTER_CONFIG","value":"true"}

check gw again:
istioctl pc clusters istio-ingressgateway-97c7688bb-sjnrd.istio-system

Should be a trimmed down version of clusters:

SERVICE FQDN         PORT     SUBSET     DIRECTION     TYPE           DESTINATION RULE                                                                                           BlackHoleCluster     -        -          -             STATIC                           
agent                -        -          -             STATIC                                                                                                                    
prometheus_stats     -        -          -             STATIC                                                                                                                    sds-grpc             -        -          -             STATIC                                                                                                                    xds-grpc             -        -          -             STATIC                                                                                                                    zipkin               -        -          -             STRICT_DNS  

# access logging for gateway
should cat the file:

apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingressgateway-access-logging
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: GATEWAY
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


kubectl apply -f labs/04/ingress-gw-access-logging.yaml


# uninstall my-gateway
>>> this doesn't work <<< we need to figure out right way to delete resources based on a file
istioctl install -y -n istioinaction -f labs/04/my-user-gateway.yaml --revision 1-8-3


TODO
Say a few notes on Cloud LBs like ALB + HTTPS, etc

 


