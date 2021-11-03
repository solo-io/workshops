#!/bin/bash +x

METADATA_ENDPOINT="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
K3S_CONTROL_PLANE_HOSTNAME=$(curl -sfH "Metadata-Flavor: Google" "${METADATA_ENDPOINT}/K3S_CONTROL_PLANE_HOSTNAME")
K3S_FLAGS=$(curl -sfH "Metadata-Flavor: Google" "${METADATA_ENDPOINT}/K3S_FLAGS")

K3S_CMD=server
K3S_NODE_NAME=$(hostname)
export K3S_NODE_NAME

if [ -n "$K3S_CONTROL_PLANE_HOSTNAME" ]; then
    # Run k3s in agent mode
    K3S_CMD=agent

    # Try to fetch node-token from control plane server
    RETRIES=300
    while [ $RETRIES -gt 0 ]; do
        if ! nc -z "$K3S_CONTROL_PLANE_HOSTNAME" 6443; then
            echo "Waiting for k3s api"
            sleep 1
            RETRIES=$((RETRIES-1))
            continue
        fi

        K3S_TOKEN=$(ssh -qo StrictHostKeyChecking=no "${K3S_CONTROL_PLANE_HOSTNAME}" cat /var/lib/rancher/k3s/server/node-token)
        if [ -n "${K3S_TOKEN}" ]; then
            export K3S_TOKEN
            break
        fi

        echo "Waiting for server token to be available"
        sleep 1
        RETRIES=$((RETRIES-1))
    done

    K3S_CONTROL_PLANE_IP=$(host "$K3S_CONTROL_PLANE_HOSTNAME" | grep ' has address ' | awk '{print $NF}')
    K3S_URL="https://${K3S_CONTROL_PLANE_IP}:6443/"
    export K3S_URL
else
    systemctl enable kubectl-proxy
    systemctl start kubectl-proxy &
fi

/usr/local/bin/k3s "$K3S_CMD" ${K3S_FLAGS}
