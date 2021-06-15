#!/usr/bin/env bash -l
set +e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
INSTRUCTIONS_FILE="README.md"

pushd "$SCRIPTDIR"
  ../../../../scripts/solve.sh ${SCRIPTDIR}/../../$INSTRUCTIONS_FILE $((${PWD##*/}))
popd