# Upgrading Istio 

## Adding the second installation

Download istio 1.11.5:

```bash
export ISTIO_VERSION=1.11.5
curl -L https://istio.io/downloadIstio | sh -
```

Install istio

```bash
helm --kube-context=${CLUSTER1} upgrade istio-base istio-1.11.5/manifests/charts/base -n istio-system

helm --kube-context=${CLUSTER1} install istio-1-11-5 istio-1.11.5/manifests/charts/istio-control/istio-discovery -n istio-system --values  - <<EOF
meshConfig:
  trustDomain: cluster1
  accessLogFile: /dev/stdout
  enableAutoMtls: true
  defaultConfig:
    envoyMetricsService:
      address: enterprise-agent.gloo-mesh:9977
    envoyAccessLogService:
      address: enterprise-agent.gloo-mesh:9977
    proxyMetadata:
      ISTIO_META_DNS_CAPTURE: "true"
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      GLOO_MESH_CLUSTER_NAME: cluster1

global:
  meshID: mesh1
  multiCluster:
    clusterName: cluster1
  network: network1
  meshNetworks:
    network1:
      endpoints:
      - fromRegistry: cluster1
      gateways:
      - registryServiceName: istio-ingressgateway.istio-system.svc.cluster.local
        port: 443
    vm-network: {}

pilot:
  env:
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
    ENABLE_LEGACY_FSGROUP_INJECTION: "false"

revision: "1-11-5"
EOF
```


Now if we check we will see two deployments:

```
kubectl --context="cluster1" get pods -n istio-system
```

Output:
```
NAME                             READY   STATUS    RESTARTS   AGE
istiod-1-11-4-77686f9955-p4fzc   1/1     Running   0          88s
istiod-1-11-5-8d8dc9699-sc9ws    1/1     Running   0          9s
```

Additionally, still all deployments will stay on the old revision i.e. `istiod-1-11-4`
```
istioctl --context="cluster1" proxy-status
```
Output:
```
NAME                                      ISTIOD                             VERSION
details-v1-79f774bdb9-jrczh.default       istiod-1-11-4-77686f9955-p4fzc     1.11.4
istio-ingressgateway-5fcd6555c8-7nz5v...  istiod-1-11-4-77686f9955-p4fzc     1.11.4
productpage-v1-6b746f74dc-8w98m.default   istiod-1-11-4-77686f9955-p4fzc     1.11.4
ratings-v1-b6994bb9-xf7kh.default         istiod-1-11-4-77686f9955-p4fzc     1.11.4
reviews-v1-545db77b95-ssk97.default       istiod-1-11-4-77686f9955-p4fzc     1.11.4
reviews-v2-7bf8c9648f-d8xtx.default       istiod-1-11-4-77686f9955-p4fzc     1.11.4
```

We need to update VirtualMesh to have the new mesh. You can find the available meshes using the following command `kubectl --context ${MGMT} get meshes -n gloo-mesh` :

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: VirtualMesh
metadata:
  name: virtual-mesh
  namespace: gloo-mesh
spec:
  mtlsConfig:
    autoRestartPods: true
    shared:
      rootCertificateAuthority:
        generated: {}
  federation:
    selectors:
    - {}
  globalAccessPolicy: ENABLED
  meshes:
  - name: istiod-1-11-4-istio-system-cluster1
    namespace: gloo-mesh
  - name: istiod-1-11-5-istio-system-cluster1
    namespace: gloo-mesh
  - name: istiod-1-11-4-istio-system-cluster2
    namespace: gloo-mesh
EOF
```

Update the ingress gateway to the new revision
```
helm --kube-context=${CLUSTER1} upgrade istio-ingress istio-1.11.5/manifests/charts/gateways/istio-ingress \
    -n istio-ingress --values - <<EOF
gateways:
  istio-ingressgateway:
    name: istio-ingressgateway
    labels:
      app: istio-ingressgateway
      istio: ingressgateway
      topology.istio.io/network: network1
    ports:
    - name: http2
      port: 80
      targetPort: 8080
    - name: https
      port: 443
      targetPort: 8443
    - name: tcp-status-port
      port: 15021
      targetPort: 15021
    - name: tls
      port: 15443
      targetPort: 15443
    - name: tcp-istiod
      port: 15012
      targetPort: 15012
    - name: tcp-webhook
      port: 15017
      targetPort: 15017

    type: LoadBalancer #change to NodePort, ClusterIP or LoadBalancer if need be
  
    env:
      ISTIO_META_ROUTER_MODE: "sni-dnat"
      ISTIO_META_REQUESTED_NETWORK_VIEW: "network1"

    injectionTemplate: gateway

global:
  meshID: "mesh1"
  multiCluster:
    enabled: true
    clusterName: "cluster1"
  network: "network1"

meshConfig:
  trustDomain: "cluster.local"

revision: "1-11-5"
EOF
```

See the progress of the upgrade
```
kubectl --context ${CLUSTER1} get pods -n istio-ingress -w
```
Output:

```
NAME                                    READY   STATUS              RESTARTS   AGE
istio-ingressgateway-5fcd6555c8-7nz5v   1/1     Running             0          83m
istio-ingressgateway-785f5cd787-tqgfl   0/1     ContainerCreating   0          8s
istio-ingressgateway-785f5cd787-tqgfl   0/1     Running             0          27s
istio-ingressgateway-785f5cd787-tqgfl   1/1     Running             0          28s
istio-ingressgateway-5fcd6555c8-7nz5v   1/1     Terminating         0          83m
istio-ingressgateway-5fcd6555c8-7nz5v   0/1     Terminating         0          84m
istio-ingressgateway-5fcd6555c8-7nz5v   0/1     Terminating         0          84m
istio-ingressgateway-5fcd6555c8-7nz5v   0/1     Terminating         0          84m
```

Verify that the gateway is upgraded:
```
istioctl --context="cluster1" proxy-status
```
The output:

```
NAME                                        ISTIOD                             VERSION
details-v1-79f774bdb9-jrczh.default         istiod-1-11-4-77686f9955-p4fzc     1.11.4
istio-ingressgateway-785f5cd787-tqgfl...    istiod-1-11-5-8d8dc9699-sc9ws      1.11.5 #1
productpage-v1-6b746f74dc-8w98m.default     istiod-1-11-4-77686f9955-p4fzc     1.11.4
ratings-v1-b6994bb9-xf7kh.default           istiod-1-11-4-77686f9955-p4fzc     1.11.4
reviews-v1-545db77b95-ssk97.default         istiod-1-11-4-77686f9955-p4fzc     1.11.4
reviews-v2-7bf8c9648f-d8xtx.default         istiod-1-11-4-77686f9955-p4fzc     1.11.4
```
#1 The gateway is managed by istio 1.11.5

Verify that the product page is accessible:
```
echo "http://${ENDPOINT_HTTP_GW_CLUSTER1}/productpage"
```

To update the workloads label the namespace with the new revision:
```
kubectl --context ${CLUSTER1} label namespace default istio.io/rev=1-11-5 --overwrite
```
```
kubectl --context ${CLUSTER1} rollout restart deploy productpage-v1
kubectl --context ${CLUSTER1} rollout status deploy productpage-v1
```

Verify that the gateway is upgraded:
```
istioctl --context="cluster1" proxy-status
```
The output:

```
NAME                                      ISTIOD                             VERSION
details-v1-79f774bdb9-jrczh.default       istiod-1-11-4-77686f9955-p4fzc     1.11.4
istio-ingressgateway-785f5cd787-tqgfl...  istiod-1-11-5-8d8dc9699-sc9ws      1.11.5 #1
productpage-v1-64989dbfb7-598th.default   istiod-1-11-5-8d8dc9699-sc9ws      1.11.5 #1
ratings-v1-b6994bb9-xf7kh.default         istiod-1-11-4-77686f9955-p4fzc     1.11.4
reviews-v1-545db77b95-ssk97.default       istiod-1-11-4-77686f9955-p4fzc     1.11.4
reviews-v2-7bf8c9648f-d8xtx.default       istiod-1-11-4-77686f9955-p4fzc     1.11.4
```
#1 The gateway is managed by istio 1.11.5

Let's delete all pods so the new ones connect to istio 1.11.5:
```
kubectl --context ${CLUSTER1} delete pods --all
```

Now all pods are connected to the latest revision. Let's cleanup the old revision:
```
helm uninstall istio-1-11-4 -n istio-system
```

That's it!
