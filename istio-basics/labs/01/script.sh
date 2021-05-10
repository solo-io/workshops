curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.3 sh -
cd istio-1.9.3
export PATH=$PWD/bin:$PATH
istioctl version
istioctl x precheck
istioctl profile list
istioctl install --set profile=demo -y
kubectl apply -f samples/addons
