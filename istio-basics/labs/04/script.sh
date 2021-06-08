cd /home/solo/workshops/istio-basics

kubectl get peerauthentication default -n istio-system -o yaml

kubectl apply -n istioinaction -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -n default -f sample-apps/sleep.yaml

sleep 5

kubectl exec -it deploy/sleep -n default -- curl http://web-api.istioinaction:8080/

kubectl exec -it deploy/sleep -n istioinaction -- curl http://web-api.istioinaction:8080/

kubectl exec $(kubectl get pod -l app=web-api -n istioinaction -o jsonpath={.items..metadata.name}) -c istio-proxy -n istioinaction -- cat /etc/certs/cert-chain.pem | openssl x509 -text -noout  | grep Validity -A 2

kubectl exec $(kubectl get pod -l app=web-api -n istioinaction -o jsonpath={.items..metadata.name}) -c istio-proxy -n istioinaction -- cat /etc/certs/cert-chain.pem | openssl x509 -text -noout  | grep 'Subject Alternative Name' -A 1
