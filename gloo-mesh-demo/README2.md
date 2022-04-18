
<!--bash
#!/usr/bin/env bash

#source ./scripts/assert.sh
-->

![Gloo Mesh Enterprise](images/gloo-mesh-enterprise.png)
# <center>Gloo Mesh Workshop</center>

## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Environment Setup](#Lab-1)
* [Lab 2 - Workspaces](#Lab-2)
* [Lab 3 - Expose Frontend](#Lab-3)
* [Lab 4 - Multi-cluster Routing](#Lab-4)
* [Lab 5 - Policies](#Lab-5)

```sh

export MGMT_CLUSTER=mgmt
export REMOTE_CLUSTER1=cluster1
export REMOTE_CLUSTER2=cluster2

export MGMT_CONTEXT=mgmt
export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2

export ISTIO_REPO=gcr.io/istio-release
export ISTIO_VERSION=1.12.6

export GLOO_MESH_VERSION=v2.0.0-beta27

curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=${GLOO_MESH_VERSION} sh -

meshctl install \
  --kubecontext $MGMT_CONTEXT \
  --license $GLOO_MESH_LICENSE_KEY \
  --version $GLOO_MESH_VERSION \
  --set mgmtClusterName=$MGMT_CLUSTER

MGMT_SERVER_NETWORKING_DOMAIN=$(kubectl get svc -n gloo-mesh gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
MGMT_SERVER_NETWORKING_PORT=$(kubectl -n gloo-mesh get service gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
MGMT_SERVER_NETWORKING_ADDRESS=${MGMT_SERVER_NETWORKING_DOMAIN}:${MGMT_SERVER_NETWORKING_PORT}
echo $MGMT_SERVER_NETWORKING_ADDRESS

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

## Install Istio using GM Istio Lifecycle [Not Implmented yet]

```yaml
# https://github.com/solo-io/gloo-mesh-enterprise/issues/1641
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: admin.enterprise.mesh.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: gloo-mesh-istio
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

## Manually installing Istio using istioctl

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
  hub: $ISTIO_REPO
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
    # Specify if http1.1 connections should be upgraded to http2 by default. 
    # Can be overridden using DestinationRule
    h2UpgradePolicy: UPGRADE

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
            # main http ingress port
            - port: 80
              targetPort: 8080
              name: http2
            # main https ingress port
            - port: 443
              targetPort: 8443
              name: https
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
          # Disable workload entries from matching local kubernetes service endpoints
          - name: PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES
            value: "false"
  values:
    gateways:
      istio-ingressgateway:
        # Enable gateway injection
        injectionTemplate: gateway
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
  hub: $ISTIO_REPO
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
    # Specify if http1.1 connections should be upgraded to http2 by default. 
    # Can be overridden using DestinationRule
    h2UpgradePolicy: UPGRADE

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
            # main http ingress port
            - port: 80
              targetPort: 8080
              name: http2
            # main https ingress port
            - port: 443
              targetPort: 8443
              name: https
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
          # Disable workload entries from matching local kubernetes service endpoints
          - name: PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES
            value: "false"
  values:
    gateways:
      istio-ingressgateway:
        # Enable gateway injection
        injectionTemplate: gateway
    # https://istio.io/v1.5/docs/reference/config/installation-options/#global-options
    global:
      # needed for connecting VirtualMachines to the mesh
      network: ${CLUSTER_NAME}
      # needed for annotating istio metrics with cluster (should match trust domain and GLOO_MESH_CLUSTER_NAME)
      multiCluster:
        clusterName: ${CLUSTER_NAME}
EOF
```
# Deploy RootTrustPolicy

```sh
cat << EOF | kubectl --context $MGMT_CONTEXT apply -f -
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
    autoRestartPods: true
EOF
```


# install apps

```sh
kubectl apply -n web-ui -f data/online-boutique/web-ui.yaml --context $REMOTE_CONTEXT1
kubectl apply -n backend-apis -f data/online-boutique/backend-apis-cluster1.yaml --context $REMOTE_CONTEXT1
```

## Gloo Mesh Configuration


```sh
kubectl create namespace ops-team --context $MGMT_CONTEXT
kubectl create namespace web-team --context $MGMT_CONTEXT
kubectl create namespace backend-apis-team --context $MGMT_CONTEXT

# Create ops workspace
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: ops-team
  namespace: gloo-mesh
spec:
  workloadClusters:
  - name: 'mgmt'
    namespaces:
    - name: ops-team
  - name: '*'
    namespaces:
    - name: istio-gateways
---
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: ops-team
  namespace: ops-team
spec:
  options:
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
  importFrom:
  - workspaces:
    - name: web-team
    - name: backend-apis-team
EOF
# Create Web Team workspace
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: web-team
  namespace: gloo-mesh
spec:
  workloadClusters:
  - name: 'mgmt'
    namespaces:
    - name: web-team
  - name: '*'
    namespaces:
    - name: web-ui
---
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: web-team
  namespace: web-team
spec:
  importFrom:
  - workspaces:
    - name: backend-apis-team
  exportTo:
  - workspaces:
    - name: ops-team
  options:
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
    federation:
      enabled: true
      serviceSelector:
      - namespace: web-ui
EOF
# Create Backend Team workspace
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: backend-apis-team
  namespace: gloo-mesh
spec:
  workloadClusters:
  - name: 'mgmt'
    namespaces:
    - name: backend-apis-team
  - name: '*'
    namespaces:
    - name: backend-apis
---
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: backend-apis-team
  namespace: backend-apis-team
spec:
  exportTo:
  - workspaces:
    - name: web-team
    - name: ops-team
  options:
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
    federation:
      enabled: true
      serviceSelector:
      - namespace: backend-apis
EOF
```

# expose frontend

```yaml
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: north-south-gw
  namespace: ops-team
spec:
  workloads:
    - selector:
        labels:
          istio: ingressgateway
        cluster: cluster1
  listeners: 
    - http: {}
      port:
        name: http2
      allowedRouteTables:
        - host: '*'
    - http: {}
      port:
        name: https
      allowedRouteTables:
        - host: '*'
EOF
cat << EOF | kubectl apply --context $MGMT_CONTEXT -f -
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: frontend
  namespace: web-team
spec:
  hosts:
    - '*'
  virtualGateways:
    - name: north-south-gw
      namespace: ops-team
      cluster: mgmt
  workloadSelectors: []
  http:
    - name: frontend
      forwardTo:
        destinations:
          - ref:
              name: frontend
              namespace: web-ui
              cluster: cluster1
            port:
              number: 80
EOF
```


## Checkout Serivce Implementation

Deploy Checkout in cluster2:
```
kubectl apply -n backend-apis -f data/online-boutique/checkout-service.yaml --context $REMOTE_CONTEXT2
```

Create a VirtualDestination so it can be reachable from everywhere:
```
kubectl apply -n backend-apis-team -f data/online-boutique/virtual-destinations.yaml --context $MGMT_CONTEXT
```

Update webui to use checkout virtualdestination:
```
kubectl apply -n web-ui -f data/online-boutique/web-ui-with-checkout.yaml --context $REMOTE_CONTEXT1
```
