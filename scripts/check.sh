until [ $(kubectl --context $1 -n kube-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  echo "Waiting for all the kube-system pods to become ready"
  sleep 1
done

until [ $(kubectl --context $1 -n metallb-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  echo "Waiting for all the metallb-system pods to become ready"
  sleep 1
done