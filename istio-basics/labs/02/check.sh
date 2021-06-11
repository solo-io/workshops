#!/usr/bin/env bash -le

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'if [ "x$?" != "x0" ]; then echo FAIL: "\"${last_command}\" command failed"; fi' EXIT

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
  SECURE_INGRESS_PORT=443
  curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP
  curl -H "Host: istioinaction.io" http://istioinaction.io --resolve istioinaction.io:80:$GATEWAY_IP 2> /tmp/capture.out || true
  cat /tmp/capture.out | grep "Connection refused"
popd