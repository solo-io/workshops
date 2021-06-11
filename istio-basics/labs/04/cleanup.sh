#!/usr/bin/env bash -le

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  kubectl delete -n default -f sample-apps/sleep.yaml
  kubectl delete PeerAuthentication default -n istio-system
popd