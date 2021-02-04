# Install Istio
echo "make sure Istio installed"
read -s
#istioctl manifest apply -y

# Install Sample app
kubectl create ns istioinaction
kubectl label namespace istioinaction istio-injection=enabled --overwrite
kubectl apply -n istioinaction -f web-api.yaml
kubectl apply -n istioinaction -f recommendation.yaml
kubectl apply -n istioinaction -f purchase-history-v1.yaml

kubectl apply -n istioinaction -f sleep.yaml

# Install Istio resources
kubectl apply -n istioinaction -f web-api-gw.yaml
kubectl apply -n istioinaction -f web-api-gw-vs.yaml