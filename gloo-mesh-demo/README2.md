
<!--bash
#!/usr/bin/env bash

#source ./scripts/assert.sh
-->

![Gloo Mesh Enterprise](images/gloo-mesh-enterprise.png)
# <center>Gloo Mesh Workshop</center>

## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy Application](#Lab-1)
* [Lab 2 - Deploy Gloo Mesh](#Lab-2)
* [Lab 3 - Deploy Istio](#Lab-3)
* [Lab 4 - Setup Workspaces](#Lab-4)
* [Lab 5 - Expose Application](#Lab-5)


* [Lab 2 - Deploy Istio](#Lab-2)
* [Lab 3 - Deploy the Bookinfo demo app](#Lab-3)
* [Lab 4 - Deploy the httpbin demo app](#Lab-4)
* [Lab 5 - Deploy and register Gloo Mesh](#Lab-5)
* [Lab 6 - Create workspaces](#Lab-6)
* [Lab 7 - Expose the productpage through a gateway](#Lab-7)
* [Lab 8 - Traffic policies](#Lab-8)
* [Lab 9 - Create the Root Trust Policy](#Lab-9)
* [Lab 10 - Multi-cluster Traffic](#Lab-10)
* [Lab 11 - Leverage Virtual Destinations](#Lab-11)
* [Lab 12 - Zero trust](#Lab-12)
* [Lab 13 - Deploy Keycloak](#Lab-13)
* [Lab 14 - Securing the access with OAuth](#Lab-14)
* [Lab 15 - Apply rate limiting to the Gateway](#Lab-15)

```sh

export MGMT_CLUSTER=mgmt
export REMOTE_CLUSTER1=cluster1
export REMOTE_CLUSTER2=cluster2

export MGMT_CONTEXT=mgmt
export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2

export REPO=gcr.io/istio-release
export ISTIO_VERSION=1.12.5

GLOO_MESH_VERSION=v2.0.0-beta23

curl --insecure -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=${GLOO_MESH_VERSION} sh -

meshctl install --kubecontext $MGMT_CONTEXT --license $GLOO_MESH_LICENSE_KEY --version $GLOO_MESH_VERSION

MGMT_SERVER_NETWORKING_DOMAIN=$(kubectl get svc -n gloo-mesh gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
MGMT_SERVER_NETWORKING_PORT=$(kubectl -n gloo-mesh get service gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
MGMT_SERVER_NETWORKING_ADDRESS=${MGMT_SERVER_NETWORKING_DOMAIN}:${MGMT_SERVER_NETWORKING_PORT}
echo $MGMT_SERVER_NETWORKING_ADDRESS

meshctl cluster register \
  --kubecontext=$MGMT_CONTEXT \
  --remote-context=$MGMT_CONTEXT \
  --relay-server-address $MGMT_SERVER_NETWORKING_ADDRESS \
  --version $GLOO_MESH_VERSION \
  $MGMT_CLUSTER

meshctl cluster register \
  --kubecontext=$MGMT_CONTEXT \
  --remote-context=$REMOTE_CONTEXT1 \
  --relay-server-address $MGMT_SERVER_NETWORKING_ADDRESS \
  --version $GLOO_MESH_VERSION \
  $REMOTE_CLUSTER1

meshctl cluster register \
  --kubecontext=$MGMT_CONTEXT \
  --remote-context=$REMOTE_CONTEXT2 \
  --relay-server-address $MGMT_SERVER_NETWORKING_ADDRESS \
  --version $GLOO_MESH_VERSION \
  $REMOTE_CLUSTER2

```


# Install Istio

```yaml
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: admin.enterprise.mesh.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: lifecycle-demo
  namespace: gloo-mesh
spec:
  clusters:
    - name: cluster1
    - name: cluster2
  installations:
    - name: control-plane
      istioOperatorSpec:
        profile: minimal
        tag: 1.12.5
        components:
          ingressGateways:
          - name: istio-ingressgateway
            enabled: false
    - name: ingress-gateway
      istioOperatorSpec:
        profile: empty
        tag: 1.12.5
        components:
          ingressGateways:
          - name: istio-ingressgateway
            namespace: istio-gateways
            enabled: true
            k8s:
              service:
                type: LoadBalancer
                ports:
                  # health check port (required to be first for aws elbs)
                  - name: status-port
                    port: 15021
                    targetPort: 15021
                  # main http ingress port
                  - port: 80
                    targetPort: 8080
                    name: http2
                  # main https ingress port
                  - port: 443
                    targetPort: 8443
                    name: https
    - name: eastwest-gateway
      istioOperatorSpec:
        profile: empty
        tag: 1.12.5
        components:
          ingressGateways:
          - name: istio-eastwestgateway
            namespace: istio-gateways
            enabled: true
            k8s:
              service:
                type: LoadBalancer
                ports:
                  # health check port (required to be first for aws elbs)
                  - name: status-port
                    port: 15021
                    targetPort: 15021
                  # Port for gloo-mesh multi-cluster mTLS passthrough (Required for Gloo Mesh east/west routing)
                  - port: 15443
                    targetPort: 15443
                    # Gloo Mesh looks for this default name 'tls' on an ingress gateway
                    name: tls
EOF
```

## Istio install temporary
```sh
kubectl create ns istio-gateways --context $REMOTE_CONTEXT1
kubectl create ns istio-gateways --context $REMOTE_CONTEXT2

CLUSTER_NAME=$REMOTE_CLUSTER1
cat << EOF | istioctl install -y --context $REMOTE_CONTEXT1 -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: gloo-mesh-istio
  namespace: istio-system
spec:
  # only the control plane components are installed (https://istio.io/latest/docs/setup/additional-setup/config-profiles/)
  profile: minimal
  # Solo.io Istio distribution repository
  hub: $REPO
  # Solo.io Gloo Mesh Istio tag
  tag: ${ISTIO_VERSION}

  meshConfig:
    # enable access logging to standard output
    accessLogFile: /dev/stdout

    defaultConfig:
      # wait for the istio-proxy to start before application pods
      holdApplicationUntilProxyStarts: true
      # enable Gloo Mesh metrics service (required for Gloo Mesh UI)
      envoyMetricsService:
        address: gloo-mesh-agent.gloo-mesh:9977
       # enable GlooMesh accesslog service (required for Gloo Mesh Access Logging)
      envoyAccessLogService:
        address: gloo-mesh-agent.gloo-mesh:9977
      proxyMetadata:
        # Enable Istio agent to handle DNS requests for known hosts
        # Unknown hosts will automatically be resolved using upstream dns servers in resolv.conf
        # (for proxy-dns)
        ISTIO_META_DNS_CAPTURE: "true"
        # Enable automatic address allocation (for proxy-dns)
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
        # Used for gloo mesh metrics aggregation
        # should match trustDomain (required for Gloo Mesh UI)
        GLOO_MESH_CLUSTER_NAME: ${CLUSTER_NAME}

    # Set the default behavior of the sidecar for handling outbound traffic from the application.
    outboundTrafficPolicy:
      mode: ALLOW_ANY
    # The trust domain corresponds to the trust root of a system. 
    # For Gloo Mesh this should be the name of the cluster that cooresponds with the CA certificate CommonName identity
    trustDomain: ${CLUSTER_NAME}
  components:
    ingressGateways:
    # enable the default ingress gateway
    - name: istio-ingressgateway
      namespace: istio-gateways
      enabled: true
      k8s:
        service:
          type: LoadBalancer
          ports:
            # health check port (required to be first for aws elbs)
            - name: status-port
              port: 15021
              targetPort: 15021
            # main http ingress port
            - port: 80
              targetPort: 8080
              name: http2
            # main https ingress port
            - port: 443
              targetPort: 8443
              name: https
            # Port for gloo-mesh multi-cluster mTLS passthrough (Required for Gloo Mesh east/west routing)
            - port: 15443
              targetPort: 15443
              # Gloo Mesh looks for this default name 'tls' on an ingress gateway
              name: tls
    - name: istio-eastwestgateway
      enabled: true
      namespace: istio-gateways
      label:
        istio: eastwestgateway
      k8s:
        env:
          # Required by Gloo Mesh for east/west routing
          - name: ISTIO_META_ROUTER_MODE
            value: "sni-dnat"
        service:
          type: LoadBalancer
          selector:
            istio: eastwestgateway
          # Default ports
          ports:
            # Health check port. For AWS ELBs, this port must be listed first.
            - name: status-port
              port: 15021
              targetPort: 15021
            # Port for multicluster mTLS passthrough; required for Gloo Mesh east/west routing
            - port: 15443
              targetPort: 15443
              # Gloo Mesh looks for this default name 'tls' on a gateway
              name: tls
    pilot:
      k8s:
        env:
         # Allow multiple trust domains (Required for Gloo Mesh east/west routing)
          - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
            value: "true"
  values:
    # https://istio.io/v1.5/docs/reference/config/installation-options/#global-options
    global:
      # needed for connecting VirtualMachines to the mesh
      network: ${CLUSTER_NAME}
      # needed for annotating istio metrics with cluster (should match trust domain and GLOO_MESH_CLUSTER_NAME)
      multiCluster:
        clusterName: ${CLUSTER_NAME}
EOF
CLUSTER_NAME=$REMOTE_CLUSTER2
cat << EOF | istioctl install -y --context $REMOTE_CONTEXT2 -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: gloo-mesh-istio
  namespace: istio-system
spec:
  # only the control plane components are installed (https://istio.io/latest/docs/setup/additional-setup/config-profiles/)
  profile: minimal
  # Solo.io Istio distribution repository
  hub: $REPO
  # Solo.io Gloo Mesh Istio tag
  tag: ${ISTIO_VERSION}

  meshConfig:
    # enable access logging to standard output
    accessLogFile: /dev/stdout

    defaultConfig:
      # wait for the istio-proxy to start before application pods
      holdApplicationUntilProxyStarts: true
      # enable Gloo Mesh metrics service (required for Gloo Mesh UI)
      envoyMetricsService:
        address: gloo-mesh-agent.gloo-mesh:9977
       # enable GlooMesh accesslog service (required for Gloo Mesh Access Logging)
      envoyAccessLogService:
        address: gloo-mesh-agent.gloo-mesh:9977
      proxyMetadata:
        # Enable Istio agent to handle DNS requests for known hosts
        # Unknown hosts will automatically be resolved using upstream dns servers in resolv.conf
        # (for proxy-dns)
        ISTIO_META_DNS_CAPTURE: "true"
        # Enable automatic address allocation (for proxy-dns)
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
        # Used for gloo mesh metrics aggregation
        # should match trustDomain (required for Gloo Mesh UI)
        GLOO_MESH_CLUSTER_NAME: ${CLUSTER_NAME}

    # Set the default behavior of the sidecar for handling outbound traffic from the application.
    outboundTrafficPolicy:
      mode: ALLOW_ANY
    # The trust domain corresponds to the trust root of a system. 
    # For Gloo Mesh this should be the name of the cluster that cooresponds with the CA certificate CommonName identity
    trustDomain: ${CLUSTER_NAME}
  components:
    ingressGateways:
    # enable the default ingress gateway
    - name: istio-ingressgateway
      namespace: istio-gateways
      enabled: true
      k8s:
        service:
          type: LoadBalancer
          ports:
            # health check port (required to be first for aws elbs)
            - name: status-port
              port: 15021
              targetPort: 15021
            # main http ingress port
            - port: 80
              targetPort: 8080
              name: http2
            # main https ingress port
            - port: 443
              targetPort: 8443
              name: https
            # Port for gloo-mesh multi-cluster mTLS passthrough (Required for Gloo Mesh east/west routing)
            - port: 15443
              targetPort: 15443
              # Gloo Mesh looks for this default name 'tls' on an ingress gateway
              name: tls
    - name: istio-eastwestgateway
      enabled: true
      namespace: istio-gateways
      label:
        istio: eastwestgateway
      k8s:
        env:
          # Required by Gloo Mesh for east/west routing
          - name: ISTIO_META_ROUTER_MODE
            value: "sni-dnat"
        service:
          type: LoadBalancer
          selector:
            istio: eastwestgateway
          # Default ports
          ports:
            # Health check port. For AWS ELBs, this port must be listed first.
            - name: status-port
              port: 15021
              targetPort: 15021
            # Port for multicluster mTLS passthrough; required for Gloo Mesh east/west routing
            - port: 15443
              targetPort: 15443
              # Gloo Mesh looks for this default name 'tls' on a gateway
              name: tls
    pilot:
      k8s:
        env:
         # Allow multiple trust domains (Required for Gloo Mesh east/west routing)
          - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
            value: "true"
  values:
    # https://istio.io/v1.5/docs/reference/config/installation-options/#global-options
    global:
      # needed for connecting VirtualMachines to the mesh
      network: ${CLUSTER_NAME}
      # needed for annotating istio metrics with cluster (should match trust domain and GLOO_MESH_CLUSTER_NAME)
      multiCluster:
        clusterName: ${CLUSTER_NAME}
EOF
```



# install apps

```sh
kubectl apply -n web-ui -f data/online-boutique/web-ui.yaml --context cluster1
kubectl apply -n backend-apis -f data/online-boutique/backend-apis.yaml --context cluster1

kubectl apply -n web-ui -f data/online-boutique/web-ui.yaml --context cluster2
```

# expose frontend