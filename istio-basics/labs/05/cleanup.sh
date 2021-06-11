#!/usr/bin/env bash -le

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  kubectl delete -f labs/05/purchase-history-vs-all-v1.yaml -n istioinaction
  kubectl delete -f labs/05/purchase-history-dr.yaml -n istioinaction
  kubectl delete -f labs/05/purchase-history-v2.yaml -n istioinaction
popd