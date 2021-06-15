#!/usr/bin/env bash -le

INSTRUCTIONS_FILE=$1
LAB_NO=$2
EXECDIR=$( cd "$( dirname "$1" )" && pwd )
SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$EXECDIR"
  cat "${INSTRUCTIONS_FILE}" | "${SCRIPTDIR}/extract-lab.sh" "${LAB_NO}" | "${SCRIPTDIR}/../md-to-bash.sh" | bash
popd