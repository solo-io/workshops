# delete all istio
istioctl x uninstall -y --purge
kubectl delete ns istio-system