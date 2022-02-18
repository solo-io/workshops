#!/bin/sh
trap "clear; exec /bin/bash;" INT TERM
if ! curl --silent --fail --output /dev/null http://localhost:8001/api/v1/namespaces/default/services/kubernetes/; then
  echo "Starting Kubernetes, this may take a minute or so"
  while ! curl --silent --fail --output /dev/null http://localhost:8001/api/v1/namespaces/default/services/kubernetes/; do printf "." && sleep 1; done
  printf "done."
  echo ""
fi
if ! grep "source /root/.env" /root/.bashrc; then
  touch /root/.env
  echo "source /root/.env" >> /root/.bashrc
fi
source /root/.env
clear
echo ""
echo " ^ ^ "
echo "(O,O)"
echo "(   )"
echo "-\"-\"---solo.io  Copy/paste with Ctrl-Insert/Shift-Insert. Please contact us at slack.solo.io for support"
exec /bin/bash