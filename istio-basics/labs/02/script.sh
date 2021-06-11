cd /home/solo/workshops/istio-basics

kubectl create ns istioinaction

kubectl apply -n istioinaction -f sample-apps/web-api.yaml
kubectl apply -n istioinaction -f sample-apps/recommendation.yaml
kubectl apply -n istioinaction -f sample-apps/purchase-history-v1.yaml
kubectl apply -n istioinaction -f sample-apps/sleep.yaml

kubectl get po -n istioinaction
kubectl wait --for=condition=Ready pod --all -n istioinaction

kubectl get svc -n istio-system

GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

kubectl -n istioinaction apply -f sample-apps/ingress/

curl -H "Host: istioinaction.io" http://$GATEWAY_IP

istioctl proxy-config routes deploy/istio-ingressgateway.istio-system

istioctl proxy-config routes deploy/istio-ingressgateway.istio-system --name http.80 -o json

kubectl create -n istio-system secret tls istioinaction-cert --key labs/02/certs/istioinaction.io.key --cert labs/02/certs/istioinaction.io.crt

kubectl -n istioinaction apply -f labs/02/web-api-gw-https.yaml

sleep 5

curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP

echo "This should fail"
curl -H "Host: istioinaction.io" http://$GATEWAY_IP
