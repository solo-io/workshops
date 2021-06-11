#!/usr/bin/env bash -le

INSTRUCTIONS_FILE="02-secure-service-ingress.md"

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  cat "${INSTRUCTIONS_FILE}" | "../md-to-bash.sh" |bash
popd
