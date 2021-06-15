
#!/usr/bin/env bash -l
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'if [ "x$?" != "x0" ]; then echo FAIL: "\"${last_command}\" command failed"; fi' EXIT

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  glooctl get upstream bookinfo-productpage-9080
  glooctl get upstream bookinfo-beta-productpage-9080
  curl $(glooctl proxy url)/productpage -is -o /dev/null
popd