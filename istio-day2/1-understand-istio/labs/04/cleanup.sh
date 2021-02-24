istioctl x uninstall -f labs/04/ingress-gateways.yaml
istioctl x uninstall -f labs/04/my-user-gateway.yaml

# delete ssl secrets
kubectl delete secret -n istioinaction my-gateway-cert
kubectl delete secret -n istio-system istioinaction-cert