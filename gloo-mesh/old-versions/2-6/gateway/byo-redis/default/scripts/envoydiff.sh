mv /tmp/current-output /tmp/previous-output 2>/dev/null
./istio-*/bin/istioctl --context cluster1 pc all -n istio-gateways deploy/istio-ingressgateway -o json > /tmp/current-output
json-diff /tmp/previous-output /tmp/current-output
