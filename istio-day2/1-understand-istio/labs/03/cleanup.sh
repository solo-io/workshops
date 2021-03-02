kubectl delete -f kiali.yaml -n istio-system
helm uninstall prom -n prometheus
helm uninstall kiali-operator -n kiali-operator 
kubectl delete ns prometheus
kubectl delete ns kiali-operator
kubectl delete clusterrolebinding kiali-dashboard-admin 