# Lab 3 :: Ingress Gateway

istioctl install -n istio-system -f labs/02/ingress-gateways.yaml --revision 1-8-2

ingress gateway is a simple envoy proxy (dig into real quick)

we can create our own user gateways (using operator in diff namespaces)

configure gateway
http://blog.christianposta.com/istio-workshop/slides/#/11/6

dig into istioctl proxy-config


