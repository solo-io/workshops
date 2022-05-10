#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT 

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] name namespace

This script will print out any Istio resources it can find corresponding to the Gloo Mesh Enterprise name.
The name and namespace arguments are required.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
EOF
    exit
}

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
}

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
    else
        NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
    fi
}

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    msg "$msg"
    exit "$code"
}

parse_params() {
    # default values of variables set from params
    name=''
    namespace=''

    while :; do
        case "${1-}" in 
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        --no-color) NO_COLOR=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    [[ ${#args[@]} -ne 2 ]] && die "Missing required arguments.  Must have name and namespace"

    return 0
}

parse_params "$@"
setup_colors

name="${args[0]}"
namespace="${args[1]}"

# Script logic
echo "Looking for Istio translation for ${name} in ${namespace}"
for crd in `kubectl get crd | grep istio | cut -f 1 -d ' '`; do 
    echo "Looking for objects of type ${crd}"
    kubectl get ${crd} -l gloo.solo.io/parent_name=${name} -n ${namespace} --ignore-not-found=true
done


# Cleanup
cleanup