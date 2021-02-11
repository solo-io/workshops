# delete all istio
istioctl x uninstall --purge
kubectl delete ns istio-system