#!/usr/bin/env bash -le

INSTRUCTIONS_FILE="04-secure-services-with-istio.md"

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  cat "${INSTRUCTIONS_FILE}" | "../md-to-bash.sh" |bash
popd
