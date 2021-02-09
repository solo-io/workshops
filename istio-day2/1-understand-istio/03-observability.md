# Lab 3 :: Installing observability components for Istio

Prometheus federation https://prometheus.io/docs/prometheus/latest/federation/#hierarchical-federation

Helm: kube-prometheus-stack:
https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
https://github.com/prometheus-operator/kube-prometheus

Prometheus operator:
https://github.com/prometheus-operator/prometheus-operator
doc: https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md


Install prometheus:
kubectl create ns prometheus
helm install prom prometheus-community/kube-prometheus-stack -n prometheus

# Consider using prom-values.yaml to exclude some parts of the dployment

helm install prom prometheus-community/kube-prometheus-stack -n prometheus -f labs/03/prom-values.yaml

# un/pw for grafana is 
kubectl -n prometheus port-forward svc/prom-grafana 3000:80
admin/prom-operator

# installing istio grafana dashboards
kubectl -n prometheus create cm istio-dashboards --from-file=pilot-dashboard.json=labs/03/dashboards/pilot-dashboard.json --from-file=istio-workload-dashboard.json=labs/03/dashboards/istio-workload-dashboard.json --from-file=istio-service-dashboard.json=labs/03/dashboards/istio-service-dashboard.json --from-file=istio-performance-dashboard.json=labs/03/dashboards/istio-performance-dashboard.json --from-file=istio-mesh-dashboard.json=labs/03/dashboards/istio-mesh-dashboard.json --from-file=istio-extension-dashboard.json=labs/03/dashboards/istio-extension-dashboard.json


k label -n prometheus cm istio-dashboards grafana_dashboard=1

# can check prom values directly with:
kubectl get secret -n prometheus prometheus-prom-kube-prometheus-stack-prometheus -o jsonpath="{.data['prometheus\.yaml\.gz']}" | base64 -D > /tmp/prometheus.yaml.gz
gunzip /tmp/prometheus.yaml.gz

# create the right pod and service monitors
kubectl apply -f monitor-control-plane.yaml
kubectl apply -f monitor-data-plane.yaml



# clean up
helm uninstall prom -n prometheus
kubectl delete ns prometheus
cleancrd coreos