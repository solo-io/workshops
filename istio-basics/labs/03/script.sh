cd /home/solo/workshops/istio-basics

kubectl label namespace istioinaction istio-injection=enabled

kubectl get namespace -L istio-injection

kubectl rollout restart deployment web-api -n istioinaction

kubectl get pod -l app=web-api -n istioinaction

kubectl logs deploy/web-api -c web-api -n istioinaction

GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP

kubectl get pod -l app=web-api -n istioinaction -o yaml

kubectl exec deploy/web-api -c istio-proxy -n istioinaction -- /usr/local/bin/pilot-agent istio-iptables --help

kubectl rollout restart deployment purchase-history-v1 -n istioinaction
kubectl rollout restart deployment recommendation -n istioinaction
kubectl rollout restart deployment sleep -n istioinaction

for i in {1..10}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT  --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP; done

