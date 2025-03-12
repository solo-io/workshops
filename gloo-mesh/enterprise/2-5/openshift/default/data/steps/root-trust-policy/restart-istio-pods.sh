#!/bin/bash
printf "\nWaiting until the secret is created in $1"
until kubectl --context $1 get secret -n istio-system cacerts &>/dev/null
do
  printf "%s" "."
  sleep 1
done
printf "\n"
kubectl --context $1 rollout restart deploy,ds -n istio-system
kubectl --context $1 rollout status deploy,ds -n istio-system
sleep 30
namespaces=$(kubectl --context $1 get namespaces -o jsonpath='{.items[*].metadata.name}')

for namespace in $namespaces; do
  if [ "$namespace" == "istio-system" ]; then
    continue
  fi
  pods=$(kubectl --context $1 get pods -n $namespace -o json | jq -r '.items[] | select(.metadata.annotations["sidecar.istio.io/status"] != null) | .metadata.name')
  for pod in $pods; do
    owner_kind=$(kubectl --context $1 get pod $pod -n $namespace -o jsonpath='{.metadata.ownerReferences[0].kind}')
    if [ "$owner_kind" == "ReplicaSet" ]; then
      replicaset=$(kubectl --context $1 get pod $pod -n $namespace -o jsonpath='{.metadata.ownerReferences[0].name}')
      deployment=$(kubectl --context $1 get replicaset $replicaset -n $namespace -o jsonpath='{.metadata.ownerReferences[0].name}')
      kubectl --context $1 rollout restart deploy $deployment -n $namespace
    else
      echo "Pod: $pod is not part of a Deployment"
      kubectl --context $1 delete pod $pod -n $namespace --wait=false
    fi
  done
done
