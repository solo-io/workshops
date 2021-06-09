cd

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.10.0 sh -
cd istio-1.10.0
sudo cp bin/istioctl /usr/local/bin
istioctl version
istioctl x precheck
istioctl profile list
istioctl install --set profile=demo -y
kubectl apply -f samples/addons

# rerun in case kiali monitoring cr failed
sleep 10
kubectl apply -f samples/addons
