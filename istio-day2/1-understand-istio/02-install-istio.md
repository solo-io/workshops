# Lab 2 :: Install Istio

Download Istio!
Explore unpacked binary
Introduce operator 
Explore helm?

istioctl operator init

create istio-system ns?

kubectl apply -f labs/02/istiod-service.yaml
istioctl install -n istio-system -f labs/02/control-plane.yaml --revision 1-8-2

understand any clusterrole?
understand configmap
can we call pilot xds?
install a single sample service (purchase histry)
manually inject
delete it and auto inject with the rev=canary label
kubectl label namespace istioinaction istio-injection- istio.io/rev=1-8-2

check pilot xds?
Call the service and see the sidecar

Dig into the istio proxy
$  kubectl get pod 
$  kubectl exec -it httpbin-865958259-k8qfd -c istio-proxy  sh
(proxy)$  ps aux
(proxy)$  ls -l /etc/istio/proxy
(proxy)$  cat /etc/istio/proxy/envoy-rev0.json


check the iptables
(proxy)$  sudo su -
(proxy)$  iptables -t nat -L

^^ may need to enable priv

use some of the same URLs in previous lab to inspect config, stats, clusters
use istioctl proxy-config to dig in also


istioctl install -n istio-system -f labs/02/ingress-gateways.yaml --revision 1-8-2

# ns needs to be properly labled

