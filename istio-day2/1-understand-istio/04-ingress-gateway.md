# Lab 4 :: Ingress Gateway

istioctl install -n istio-system -f labs/04/ingress-gateways.yaml --revision 1-8-3

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
secrets need to be in the same namespace as the gateway (ie, in istio-system as needed)

```bash
kubectl create -n istio-system secret tls istioinaction-certs --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt
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

Problem is, this is self signed... we should just get a CA going and sign it from there so we can get it to work correctly


From here we should suggest one of two ways to mitigate the cross-NS cert/config issue:

1) user gateways + secrets in own NS
2) copy secrets over to istio-system
3) another workflow automated around vault/cert-manager?


# integration with a cloud Key management system (AWS/GCP)

# leave a note about how the second workshop will go into best practices here around security keys on kubernetes, etc incuding HSM/Vault



# private vs public gateway/LB 

# REDUCE CONFIG SIZE to only VSs with config.. using that Pilot Env Variable

# access logging for gateway

TODO
Go back and update ingress-gw resources with the "sleep command" on pre-stop with correct names and any other 
Say a few notes on Cloud LBs like ALB + HTTPS, etc

 


