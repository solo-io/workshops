# Lab 2 :: Install Istio

Download Istio!
Explore unpacked binary
Introduce operator 
Explore helm?

istioctl operator init

istio-system ns

kubectl apply -f labs/02/istiod-service.yaml
istioctl install -n istio-system -f labs/02/control-plane.yaml --revision 1-8-2

understand any clusterrole?
understand configmap
can we call pilot xds?
install a single sample service (purchase histry)
manually inject
delete it and auto inject with the rev=1-8-2 label
kubectl label namespace istioinaction istio-injection- istio.io/rev=1-8-2

now need to restart services / kill pods

check pilot xds?
evernote:///view/21631000/s180/bf438755-28c9-4685-b832-5689b7db6a5e/60c6abd5-9e91-420d-b6d4-303a991351df
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

use some of the same URLs in previous lab (lab 0) to inspect config, stats, clusters
use istioctl proxy-config to dig in also
proxy-status to see what CP the DP is connected


what about istioctl analyze?

more here: http://blog.christianposta.com/istio-workshop/slides/#/13/4


