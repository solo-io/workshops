# Lab 2 :: Install Istio

istioctl operator init

istioctl install -n istio-system -f control-plane.yaml --revision 1-8-0
istioctl install -n istio-system -f ingress-gateways.yaml --revision 1-8-0
