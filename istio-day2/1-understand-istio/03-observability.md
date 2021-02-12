# Lab 3 :: Connecting to observability systems

Prometheus federation https://prometheus.io/docs/prometheus/latest/federation/#hierarchical-federation

Helm: kube-prometheus-stack:
https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
https://github.com/prometheus-operator/kube-prometheus

Prometheus operator:
https://github.com/prometheus-operator/prometheus-operator
doc: https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md

design doc with CRD description:
https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/design.md


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


## Installing Kiali

Links here:
https://kiali.io/documentation/latest/installation-guide/

kubectl create ns kiali-operator
helm install \
    --set cr.create=true \
    --set cr.namespace=istio-system \
    --namespace kiali-operator \
    --repo https://kiali.org/helm-charts \
    --version 1.29.1 \
    kiali-operator \
    kiali-operator

kubectl apply -f labs/03/kiali.yaml 

https://kiali.io/documentation/latest/configuration/authentication/
set up SA and binding:
kubectl create serviceaccount kiali-dashboard -n istio-system
kubectl create clusterrolebinding kiali-dashboard-admin --clusterrole=cluster-admin --serviceaccount=istio-system:kiali-dashboard

get token:
k get secret -n istio-system -o jsonpath="{.data.token}" $(k get secret -n istio-system | grep kiali-dashboard | awk '{print $1}' ) | base64 --decode


# TODO
Should we add a section to configure TLS for the app scraping when merging is turned off?
https://github.com/istio/istio/issues/27940#issuecomment-759305377

Should we add a section on securing the communication between Kiali and Prometheus?


# clean up
helm uninstall prom -n prometheus
kubectl delete ns prometheus
cleancrd coreos

useful notes:
https://github.com/istio/istio/issues/30063
https://github.com/istio/istio/blob/4461a6b2324bceabd6f0ef3896ca1ca338180c45/samples/addons/extras/prometheus-operator.yaml

by default, istio does metric merging:
https://istio.io/latest/docs/ops/integrations/prometheus/#option-1-metrics-merging

setting up with TLS requires injecting a sidecar with no redirect rules:
https://istio.io/latest/docs/ops/integrations/prometheus/#tls-settings