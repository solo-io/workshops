istioctl x uninstall -y -n istio-system -f labs/02/control-plane.yaml --revision 1-8-3
kubectl delete namespace istio-system