
#!/usr/bin/env bash -l
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'if [ "x$?" != "x0" ]; then echo FAIL: "\"${last_command}\" command failed"; fi' EXIT

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

pushd "$SCRIPTDIR/../.."
  APP_URL=$(glooctl proxy url --port https | cut -d: -f1-2)
  curl $APP_URL/productpage -kis |grep 302
popd