kubectl delete -n istio-system deploy/istio-ingressgateway
kubectl delete -n istio-system svc/istio-ingressgateway
kubectl delete -n istio-system sa/istio-ingressgateway-service-account 

kubectl delete -n istioinaction deploy/my-user-gateway
kubectl delete -n istioinaction svc/my-user-gateway
kubectl delete -n istioinaction sa/my-user-gateway-service-account 

# delete ssl secrets
kubectl delete secret -n istioinaction my-gateway-cert
kubectl delete secret -n istio-system istioinaction-cert

kubectl delete ns cert-manager