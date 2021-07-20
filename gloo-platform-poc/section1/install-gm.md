# Install Gloo Mesh Management Plane

source ./env.sh source ~/bin/gloo-mesh-license-env

kubectl config use-context $MGMT\_CONTEXT helm repo add gloo-mesh-enterprise [https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise](https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise) helm repo update

## we may need a beta version?

## helm search repo gloo-mesh-enterprise --devel

kubectl create namespace gloo-mesh

## Helm Install GM

helm install gloo-mesh-enterprise gloo-mesh-enterprise/gloo-mesh-enterprise --kube-context $MGMT\_CONTEXT -n gloo-mesh --version=1.1.0-beta11 --set licenseKey=${GLOO\_MESH\_LICENSE} --set rbac-webhook.enabled=false --set metricsBackend.prometheus.enabled=true

kubectl --context $MGMT\_CONTEXT -n gloo-mesh rollout status deploy/enterprise-networking kubectl --context $MGMT\_CONTEXT -n gloo-mesh rollout status deploy/dashboard

Let's explain binding here... kubectl --context $MGMT\_CONTEXT apply -f ./resources/admin-binding-kube-admin.yaml

