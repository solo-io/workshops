
<!--bash
#!/usr/bin/env bash

source ./scripts/assert.sh
-->



![Gloo Mesh Enterprise](images/gloo-mesh-enterprise.png)
# <center>Gloo Mesh Workshop</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy EKS clusters](#Lab-1)
* [Lab 2 - Deploy and register Gloo Mesh](#Lab-2)
* [Lab 3 - Deploy Istio](#Lab-3)
* [Lab 4 - Deploy the Bookinfo demo app](#Lab-4)
* [Lab 5 - Create the Virtual Mesh](#Lab-5)
* [Lab 6 - Access control](#Lab-6)
* [Lab 7 - Traffic policy](#Lab-7)
* [Lab 8 - Multi-cluster Traffic](#Lab-8)
* [Lab 9 - Traffic failover](#Lab-9)
* [Lab 10 - Extend Envoy with WebAssembly](#Lab-10)
* [Lab 11 - Observability](#Lab-11)
* [Lab 12 - Exploring the Gloo Mesh Enterprise UI](#Lab-12)
* [Lab 13 - Gloo Mesh Enterprise RBAC](#Lab-13)
* [Lab 14 - Deploy Keycloak](#Lab-14)
* [Lab 15 - Expose the productpage through a gateway](#Lab-15)
* [Lab 16 - Multi-cluster Traffic with Gateway](#Lab-16)
* [Lab 17 - Traffic failover with Gateway](#Lab-17)
* [Lab 18 - Apply rate limiting to the Gateway](#Lab-18)
* [Lab 19 - Securing the access with OAuth](#Lab-19)



## Introduction <a name="introduction"></a>

[Gloo Mesh Enterprise](https://www.solo.io/products/gloo-mesh/) is a distribution of [Istio Service Mesh](https://istio.io) with production support, CVE patching, FIPS builds, and a multi-cluster operational management plane to simplify running a service mesh across multiple clusters or a hybrid deployment. 

Gloo Mesh also has enterprise features around multi-tenancy, global failover and routing, observability, and east-west rate limiting and policy enforcement (through AuthZ/AuthN plugins). 


![Gloo Mesh](images/gloo-mesh.png)

### Istio support

The Gloo Mesh Enterprise subscription includes end to end Istio support:

- Upstream first
- Specialty builds available (FIPS, ARM, etc)
- Long Term Support (LTS) N-4 
- Critical security patches
- Production break-fix
- One hour SLA Severity 1
- Install / upgrade
- Architecture and operational guidance, 
best practices

### Service discovery

One of the common problems related to cross-cluster communication with Istio is discovery.

![Istio discovery](images/istio-discovery.png)

Istio Endpoint Discovery Service (EDS) requires each Istio control plane to have access to the Kubernetes API server of each cluster. There are some security concerns with this approach, but it also means that an Istio control plane can’t start if it’s not able to contact one of the clusters.

![Gloo Mesh discovery](images/gloo-mesh-discovery.png)

Gloo Mesh is solving these problems. An agent running on each cluster is watching the local Kubernetes API server and passes the information to the Gloo Mesh management plane through a secured gRPC channel. Gloo Mesh is then telling the agents to create the Istio ServiceEntries corresponding to the workloads discovered on the other clusters.

### Observability

Gloo Mesh is also using these agents to consolidate all the metrics and access logs from the different clusters. Graphs can then be used to monitor all the communication happening globally.

![Gloo Mesh graph](images/gloo-mesh-graph.png)

And you can view the access logs on demand:

![Gloo Mesh access logs](images/gloo-mesh-access-logs.png)

### Zero trust

Gloo Mesh makes it very easy for you to implement a zero-trust architecture where trust is established by the attributes of the connection/caller/environment and by default no communication is allowed.

You can then use Gloo Mesh **AccessPolicies**  to specify what services can talk together globally. Here is an example:

```
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: reviews
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: bookinfo-reviews
          namespace: default
          clusterName: cluster1
        - name: bookinfo-reviews
          namespace: default
          clusterName: cluster2
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: ratings
```

Gloo Mesh **AccessPolicies** are translating into Istio **AuthorizationPolicies** in the different clusters.

And what makes Gloo Mesh really unique is that you can then go to the UI and check what are the services currently running that are matching the criterias defined in your policy:

![Gloo Mesh accesspolicy](images/gloo-mesh-accesspolicy.png)

### Multi-cluster traffic and failover

Gloo Makes also provides an abstraction called **TrafficPolicies** that makes it very easy for you to define how services behave and interract globally. Here is an example:

```
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  namespace: gloo-mesh
  name: simple
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      namespaces:
      - default
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  policy:
    trafficShift:
      destinations:
        - kubeService:
            clusterName: cluster2
            name: reviews
            namespace: default
            subset:
              version: v3
          weight: 75
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v1
          weight: 15
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v2
          weight: 10
```

Gloo Mesh **TrafficPolicies** are translating into Istio **VirtualServices** and **DestinationRules** in the different clusters.

Providing high-availability of applications across clusters, zones, and regions can be a significant challenge. Ideally, source traffic should be routed to the closest available destination, or be routed to a failover destination if issues occur.

Gloo Mesh **VirtualDestinations** are providing this capability. Here is an example:

```
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: VirtualDestination
metadata:
  name: reviews-global
  namespace: gloo-mesh
spec:
  hostname: reviews.global
  port:
    number: 9080
    protocol: http
  localized:
    outlierDetection:
      consecutiveErrors: 1
      maxEjectionPercent: 100
      interval: 5s
      baseEjectionTime: 120s
    destinationSelectors:
    - kubeServiceMatcher:
        labels:
          app: reviews
  virtualMesh:
    name: virtual-mesh
    namespace: gloo-mesh
```

Gloo Mesh **VirtualDestinations** are translating into Istio ** DestinationRules** and **ServiceEntries** in the different clusters.

### RBAC

Gloo Mesh is simplifying the way users consume the Service Mesh globally by providing all the abstractions described previously (**AccessPolicies**, **TrafficPolicies**, ...).

But using the Gloo Mesh objects has another benefit. You can now define Gloo Mesh roles that are very fine grained.

Here are a few examples about what you can do with Gloo Mesh RBAC:

- Create a role to allow a user to use a specific Virtual Mesh
- Create a role to allow a user to use a specific cluster in a Virtual Mesh
- Create a role to allow a user to only define Access Policies
- Create a role to allow a user to only define Traffic Policies
- Create a role to allow a user to only define Failover Services
- Create a role to allow a user to only create policies that target the services running in his namespace (but coming from services in any namespace) 

One common use case is to create a role corresponding to a global namespace admin.

### Gloo Mesh Gateway

Using the Istio Ingress Gateway provides many benefits, like the ability to configure a traffic shift for both north-south and easy-west traffic or to leverage the Istio `ServiceEntries`.

But the Istio Ingress Gateway doesn't provide all the capabilities that are usually available in a proper API Gateway (authentication with OAuth, authorization with OPA, rate limiting, ...).

You can configure an API Gateway like Gloo Edge to securely expose some applications running in the Mesh, but you lose some of the advantages of the Istio Ingress Gateway in that case.

Gloo Mesh Gateway provides the best of both world.

It leverages the simplicity of the Gloo Mesh API and the capabilities of Gloo Edge, to enhance the Istio Ingress Gateway.

Gloo Mesh objects called `VirtualGateways`, `VirtualHosts` and `RouteTables` are created by users and translated by Gloo Mesh into Istio `VirtualService`, `DestinationRules` and `EnvoyFilters`.

### Gloo Mesh objects

Here is a representation of the most important Gloo Mesh objects and how they interract together.

![Gloo Mesh objects](images/gloo-mesh-objects.png)

### Wants to learn more about Gloo Mesh

You can find more information about Gloo Mesh in the official documentation:

[https://docs.solo.io/gloo-mesh/latest/](https://docs.solo.io/gloo-mesh/latest/)



## Lab 1 - Deploy EKS clusters <a name="Lab-1"></a>

Set the context environment variables:

```bash
export MGMT=mgmt
export CLUSTER1=cluster1
export CLUSTER2=cluster2
```

> Note that in case you can't have a Kubernetes cluster dedicated for the management plane, you would set the variables like that:
> ```
> export MGMT=cluster1
> export CLUSTER1=cluster1
> export CLUSTER2=cluster2
> ```

For this workshop, you need to deploy 3 EKS clusters.

All the instructions have been tested with each EKS cluster composed of 3 `t3.large` instances (2 CPUs and 8 GB of RAM).

Gloo Mesh can be run in its own cluster or co-located with an existing mesh.  In this exercise, Gloo Mesh will run in its own dedicated management cluster, while the two managed Istio meshes will run in separate clusters.

You also need to rename the Kubernete contexts of each EKS cluster to match `mgmt`, `cluster1` and `cluster2`.

Here is an example showing how to rename a Kubernetes context:

```
kubectl config rename-context <context to rename> <new context name>
```

Run the following command to make `mgmt` the current cluster.

```bash
kubectl config use-context ${MGMT}
```



## Lab 2 - Deploy and register Gloo Mesh <a name="Lab-2"></a>

First of all, you need to install the *meshctl* CLI:

```bash
export GLOO_MESH_VERSION=v1.1.0
curl -sL https://run.solo.io/meshctl/install | sh -
export PATH=$HOME/.gloo-mesh/bin:$PATH
```


<!--bash
log_header "Test :: Test meshctl version"
installedVersion=$(meshctl version | jq -r '.client.version')
result_message="Installed version is $GLOO_MESH_VERSION"
assert_eq "$GLOO_MESH_VERSION" "v$installedVersion" "$result_message" && log_success "$result_message"
-->

Gloo Mesh Enterprise is adding unique features on top of Gloo Mesh Open Source (RBAC, UI, WASM, ...).

Run the following commands to deploy Gloo Mesh Enterprise:




<!--bash
log_header "Test :: Verify license"

assert_not_empty "$GLOO_MESH_LICENSE_KEY" "Environment variable GLOO_MESH_LICENSE_KEY cannot be empty"
log_success "Gloo License exist"
-->

```bash
helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise 
helm repo update
kubectl --context ${MGMT} create ns gloo-mesh 
helm install gloo-mesh-enterprise gloo-mesh-enterprise/gloo-mesh-enterprise \
--namespace gloo-mesh --kube-context ${MGMT} \
--version=1.1.0 \
--set gloo-mesh-ui.relayClientAuthority=enterprise-networking.gloo-mesh \
--set rbac-webhook.enabled=true \
--set licenseKey=${GLOO_MESH_LICENSE_KEY} \
--set "rbac-webhook.adminSubjects[0].kind=User" \
--set "rbac-webhook.adminSubjects[0].name=system:serviceaccount:kube-system:eks-admin"
kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/enterprise-networking
```



Then, you need to set the environment variable for the service of the Gloo Mesh Enterprise networking component:

```bash
SVC=$(kubectl --context ${MGMT} -n gloo-mesh get svc enterprise-networking -o jsonpath='{.status.loadBalancer.ingress[0].*}')
```

Finally, you need to register the two other clusters:

```bash

meshctl cluster register --mgmt-context=${MGMT} --remote-context=${CLUSTER1} --relay-server-address=$SVC:9900 enterprise cluster1 --cluster-domain cluster.local
meshctl cluster register --mgmt-context=${MGMT} --remote-context=${CLUSTER2} --relay-server-address=$SVC:9900 enterprise cluster2 --cluster-domain cluster.local
```

You can list the registered cluster using the following command:

```bash
kubectl get kubernetescluster -n gloo-mesh
```

You should get the following output:

```
NAME       AGE
cluster1   27s
cluster2   23s
```


<!--bash
log_header "Test :: Cluster registration"
clusters_names=$(kubectl --context ${MGMT} get kubernetescluster -A -o jsonpath='{.items..name}')
expected_cluster_names="cluster1 cluster2"
result_message="Clusters got registered"
assert_eq "$clusters_names" "$expected_cluster_names" "$result_message" && log_success "$result_message"
-->

> ### Note that you can also register the remote clusters with Helm:
> 
> #### Get the value of the root CA certificate on the management cluster and create a secret in the remote clusters
> ```
> kubectl --context ${MGMT} -n gloo-mesh get secret relay-root-tls-secret -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
> kubectl --context ${CLUSTER1} create ns gloo-mesh
> kubectl --context ${CLUSTER1} -n gloo-mesh create secret generic relay-root-tls-secret --from-file ca.crt=ca.crt
> kubectl --context ${CLUSTER2} create ns gloo-mesh
> kubectl --context ${CLUSTER2} -n gloo-mesh create secret generic relay-root-tls-secret --from-file ca.crt=ca.crt
> ```
> #### We also need to copy over the bootstrap token used for initial communication
> ```
> kubectl --context ${MGMT} -n gloo-mesh get secret relay-identity-token-secret -o jsonpath='{.data.token}' | base64 -d > token
> kubectl --context ${CLUSTER1} -n gloo-mesh create secret generic relay-identity-token-secret --from-file token=token
> kubectl --context ${CLUSTER2} -n gloo-mesh create secret generic relay-identity-token-secret --from-file token=token
> ```
> #### Install the Helm charts
> ```
> helm repo add enterprise-agent https://storage.googleapis.com/gloo-mesh-enterprise/enterprise-agent
> helm repo update
> helm install enterprise-agent enterprise-agent/enterprise-agent \
>   --namespace gloo-mesh \
>   --set relay.serverAddress=${SVC}:9900 \
>   --set relay.cluster=cluster1 \
>   --kube-context=${CLUSTER1} \
>   --version 1.1.0
> 
> helm install enterprise-agent enterprise-agent/enterprise-agent \
>   --namespace gloo-mesh \
>   --set relay.serverAddress=${SVC}:9900 \
>   --set relay.cluster=cluster2 \
>   --kube-context=${CLUSTER2} \
>   --version 1.1.0
> ```
> #### Create the `KubernetesCluster` objects
> ```
> kubectl apply --context ${MGMT} -f- <<EOF
> apiVersion: multicluster.solo.io/v1alpha1
> kind: KubernetesCluster
> metadata:
>   name: cluster1
>   namespace: gloo-mesh
> spec:
>   clusterDomain: cluster.local
> EOF
> 
> kubectl apply --context ${MGMT} -f- <<EOF
> apiVersion: multicluster.solo.io/v1alpha1
> kind: KubernetesCluster
> metadata:
>   name: cluster2
>   namespace: gloo-mesh
> spec:
>   clusterDomain: cluster.local
> EOF
> ```


To use the Gloo Mesh Gateway advanced features, you need to install the Gloo Mesh addons.

First, you need to create a namespace for the addons, with Istio injection enabled:

```bash
kubectl --context ${CLUSTER1} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER1} label namespace gloo-mesh-addons istio-injection=enabled
kubectl --context ${CLUSTER2} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER2} label namespace gloo-mesh-addons istio-injection=enabled


```

Then, you can deploy the addons using Helm:

```bash
helm repo add enterprise-agent https://storage.googleapis.com/gloo-mesh-enterprise/enterprise-agent
helm repo update
helm install enterprise-agent-addons enterprise-agent/enterprise-agent --kube-context=${CLUSTER1} --version=1.1.0 --namespace gloo-mesh-addons --set enterpriseAgent.enabled=false --set rate-limiter.enabled=true --set ext-auth-service.enabled=true
helm install enterprise-agent-addons enterprise-agent/enterprise-agent --kube-context=${CLUSTER2} --version=1.1.0 --namespace gloo-mesh-addons --set enterpriseAgent.enabled=false --set rate-limiter.enabled=true --set ext-auth-service.enabled=true
```

Finally, we need to create an `AccessPolicy` for the Istio Ingress Gateways to communicate with the addons and for the addons to communicate together:

```bash
kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: gloo-mesh-addons
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: istio-ingressgateway-service-account
          namespace: istio-system
          clusterName: cluster1
        - name: istio-ingressgateway-service-account
          namespace: istio-system
          clusterName: cluster2
  - kubeIdentityMatcher:
      namespaces:
      - gloo-mesh-addons
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - gloo-mesh-addons
EOF
```





## Lab 3 - Deploy Istio <a name="Lab-3"></a>



Download istio 1.10.3:

```bash
export ISTIO_VERSION=1.10.3
curl -L https://istio.io/downloadIstio | sh -
```


<!--bash
log_header "Test :: Istio version"
expected_istio_client_version=$(./istio-1.10.3/bin/istioctl version --remote=false)
result_message="Installed version is $ISTIO_VERSION"
assert_eq "$ISTIO_VERSION" "$expected_istio_client_version" "$result_message" && log_success "$result_message"
-->

Now let's deploy Istio on the first cluster:

```bash


kubectl --context ${CLUSTER1} create ns istio-operator

./istio-1.10.3/bin/istioctl --context ${CLUSTER1} operator init 

kubectl --context ${CLUSTER1} create ns istio-system

cat << EOF | kubectl --context ${CLUSTER1} apply -f -

apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istiocontrolplane-default
  namespace: istio-system
spec:
  profile: default
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
  values:
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
        vm-network:
  components:
    ingressGateways:
    - name: istio-ingressgateway
      label:
        topology.istio.io/network: network1
      enabled: true
      k8s:
        env:
          # sni-dnat adds the clusters required for AUTO_PASSTHROUGH mode
          - name: ISTIO_META_ROUTER_MODE
            value: "sni-dnat"
          # traffic through this gateway should be routed inside the network
          - name: ISTIO_META_REQUESTED_NETWORK_VIEW
            value: network1
        service:
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
    pilot:
      k8s:
        env:
          - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
            value: "true"
EOF
```

And deploy Istio on the second cluster:

```bash


kubectl --context ${CLUSTER2} create ns istio-operator

./istio-1.10.3/bin/istioctl --context ${CLUSTER2} operator init 

kubectl --context ${CLUSTER2} create ns istio-system

cat << EOF | kubectl --context ${CLUSTER2} apply -f -

apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istiocontrolplane-default
  namespace: istio-system
spec:
  profile: default
  meshConfig:
    trustDomain: cluster2
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
        GLOO_MESH_CLUSTER_NAME: cluster2
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster2
      network: network1
      meshNetworks:
        network1:
          endpoints:
          - fromRegistry: cluster2
          gateways:
          - registryServiceName: istio-ingressgateway.istio-system.svc.cluster.local
            port: 443
        vm-network:
  components:
    ingressGateways:
    - name: istio-ingressgateway
      label:
        topology.istio.io/network: network1
      enabled: true
      k8s:
        env:
          # sni-dnat adds the clusters required for AUTO_PASSTHROUGH mode
          - name: ISTIO_META_ROUTER_MODE
            value: "sni-dnat"
          # traffic through this gateway should be routed inside the network
          - name: ISTIO_META_REQUESTED_NETWORK_VIEW
            value: network1
        service:
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
    pilot:
      k8s:
        env:
          - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
            value: "true"
EOF
```


<!--bash
log_header "Test :: Waiting for Istio to be deployed and ready on both clusters"

until kubectl --context ${CLUSTER1} get ns istio-system
do
  sleep 1
done

printf "\nWaiting for all the Istio pods to become ready."
until [ $(kubectl --context ${CLUSTER1} -n istio-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep true -c) -gt 0 -a $(kubectl --context ${CLUSTER1} -n istio-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Istio ready in $CLUSTER1"

printf "\nWaiting for istio-system to be created."
until kubectl --context ${CLUSTER2} get ns istio-system
do
  printf "%s" "."
  sleep 1
done
printf "\n"

printf "\nWaiting for all the Istio pods to become ready"
until [ $(kubectl --context ${CLUSTER2} -n istio-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep true -c) -gt 0 -a $(kubectl --context ${CLUSTER2} -n istio-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"

log_success "Istio ready in $CLUSTER2"
-->

Run the following command until all the Istio Pods are ready:

```
kubectl --context ${CLUSTER1} get pods -n istio-system
```

When they are ready, you should get this output:

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-5c7759c8cb-52r2j   1/1     Running   0          22s
istiod-7884b57b4c-rvr2c                 1/1     Running   0          30s
```

Check the status on the second cluster using `kubectl --context ${CLUSTER2} get pods -n istio-system`



Set the environment variable for the service of the Istio Ingress Gateway of cluster1:

```bash
SVC_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].*}')
```



## Lab 4 - Deploy the Bookinfo demo app <a name="Lab-4"></a>





Run the following commands to deploy the bookinfo app on `cluster1`:

```bash


bookinfo_yaml=https://raw.githubusercontent.com/istio/istio/1.10.3/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl --context ${CLUSTER1} label namespace default istio-injection=enabled
# deploy bookinfo application components for all versions less than v3
kubectl --context ${CLUSTER1} apply -f ${bookinfo_yaml} -l 'app,version notin (v3)'
# deploy all bookinfo service accounts
kubectl --context ${CLUSTER1} apply -f ${bookinfo_yaml} -l 'account'
# configure ingress gateway to access bookinfo
kubectl --context ${CLUSTER1} apply -f https://raw.githubusercontent.com/istio/istio/1.10.3/samples/bookinfo/networking/bookinfo-gateway.yaml
```

You can check that the app is running using `kubectl --context ${CLUSTER1} get pods`:

```
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-558b8b4b76-w9qp8       2/2     Running   0          2m33s
productpage-v1-6987489c74-54lvk   2/2     Running   0          2m34s
ratings-v1-7dc98c7588-pgsxv       2/2     Running   0          2m34s
reviews-v1-7f99cc4496-lwtsr       2/2     Running   0          2m34s
reviews-v2-7d79d5bd5d-mpsk2       2/2     Running   0          2m34s
```

As you can see, it deployed the `v1` and `v2` versions of the `reviews` microservice.  But as expected, it did not deploy `v3` of `reviews`.

Now, run the following commands to deploy the bookinfo app on `cluster2`:

```bash

kubectl --context ${CLUSTER2} label namespace default istio-injection=enabled
# deploy all bookinfo service accounts and application components for all versions
kubectl --context ${CLUSTER2} apply -f ${bookinfo_yaml}
# configure ingress gateway to access bookinfo
kubectl --context ${CLUSTER2} apply -f https://raw.githubusercontent.com/istio/istio/1.10.3/samples/bookinfo/networking/bookinfo-gateway.yaml
```

You can check that the app is running using `kubectl --context ${CLUSTER2} get pods`:

```
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-558b8b4b76-gs9z2       2/2     Running   0          2m22s
productpage-v1-6987489c74-x45vd   2/2     Running   0          2m21s
ratings-v1-7dc98c7588-2n6bg       2/2     Running   0          2m21s
reviews-v1-7f99cc4496-4r48m       2/2     Running   0          2m21s
reviews-v2-7d79d5bd5d-cx9lp       2/2     Running   0          2m22s
reviews-v3-7dbcdcbc56-trjdx       2/2     Running   0          2m22s
```

As you can see, it deployed all three versions of the `reviews` microservice.

![Initial setup](images/steps/deploy-bookinfo/initial-setup.png)



Get the URL to access the `productpage` service from your web browser using the following command:

```
echo "http://${SVC_GW_CLUSTER1}/productpage"
```

![Bookinfo working](images/steps/deploy-bookinfo/bookinfo-working.png)

As you can see, you can access the Bookinfo demo app.


<!--bash
log_header "Test :: Waiting for the Bookinfo application to be deployed and ready on both clusters"

printf "\nWaiting for all the pods of the default namespace to become ready in ${CLUSTER1}"
until [ $(kubectl --context ${CLUSTER1} get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Bookinfo ready in $CLUSTER1"

printf "\nWaiting for all the pods of the default namespace to become ready in ${CLUSTER2}"
until [ $(kubectl --context ${CLUSTER2} get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Bookinfo ready in $CLUSTER2"
-->



## Lab 5 - Create the Virtual Mesh <a name="Lab-5"></a>

Gloo Mesh can help unify the root identity between multiple service mesh installations so any intermediates are signed by the same Root CA and end-to-end mTLS between clusters and services can be established correctly.

Run this command to see how the communication between microservices occurs currently:

```bash
kubectl --context ${CLUSTER1} exec -t deploy/reviews-v1 -c istio-proxy \
-- openssl s_client -showcerts -connect ratings:9080
```


<!--bash
log_header "Test :: No certificate issued in ${CLUSTER1}"
printf "\nWaiting until no certificate is issued in $CLUSTER1"
search1="CONNECTED"
search2="No client certificate CA names sent"
while true
do
  output=$(kubectl --context ${CLUSTER1} exec -t deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition2 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="No certificate issued in $CLUSTER1"
log_success "$result_message"
-->

You should get something like that:

```
CONNECTED(00000005)
139706332271040:error:1408F10B:SSL routines:ssl3_get_record:wrong version number:../ssl/record/ssl3_record.c:332:
---
no peer certificate available
---
No client certificate CA names sent
---
SSL handshake has read 5 bytes and written 309 bytes
Verification: OK
---
New, (NONE), Cipher is (NONE)
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 0 (ok)
---
command terminated with exit code 1
```

It means that the traffic is currently not encrypted.

Enable TLS on both clusters:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF

kubectl --context ${CLUSTER2} apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF
```

Run the command again:

```bash
kubectl --context ${CLUSTER1} exec -t deploy/reviews-v1 -c istio-proxy \
-- openssl s_client -showcerts -connect ratings:9080
```


<!--bash
log_header "Test :: Certificate issued by Istio in $CLUSTER1"
printf "\nWaiting until certificate issuer is $CLUSTER1"
search1="CONNECTED"
search2="i:O = cluster1"
while true
do
  output=$(kubectl --context $CLUSTER1 exec -t deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition2 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="Certificate issued in $CLUSTER1"
log_success "$result_message"
-->

Now, the output should be like that:

```
...
Certificate chain
 0 s:
   i:O = cluster1
-----BEGIN CERTIFICATE-----
MIIDFzCCAf+gAwIBAgIRALsoWlroVcCc1n+VROhATrcwDQYJKoZIhvcNAQELBQAw
...
BPiAYRMH5j0gyBqiZZEwCfzfQe1e6aAgie9T
-----END CERTIFICATE-----
 1 s:O = cluster1
   i:O = cluster1
-----BEGIN CERTIFICATE-----
MIICzjCCAbagAwIBAgIRAKIx2hzMbAYzM74OC4Lj1FUwDQYJKoZIhvcNAQELBQAw
...
uMTPjt7p/sv74fsLgrx8WMI0pVQ7+2plpjaiIZ8KvEK9ye/0Mx8uyzTG7bpmVVWo
ugY=
-----END CERTIFICATE-----
...
```

As you can see, mTLS is now enabled.

Now, run the same command on the second cluster:

```bash
kubectl --context ${CLUSTER2} exec -t deploy/reviews-v1 -c istio-proxy \
-- openssl s_client -showcerts -connect ratings:9080
```


<!--bash
log_header "Test :: Certificate issued by Istio in $CLUSTER2"
printf "\nWaiting until certificate issuer is $CLUSTER2"
search1="CONNECTED"
search2="i:O = cluster2"
while true
do
  output=$(kubectl --context $CLUSTER2 exec -t deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition2 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="Certificate issued in $CLUSTER2"
log_success "$result_message"
-->

The output should be like that:

```
...
Certificate chain
 0 s:
   i:O = cluster2
-----BEGIN CERTIFICATE-----
MIIDFzCCAf+gAwIBAgIRALo1dmnbbP0hs1G82iBa2oAwDQYJKoZIhvcNAQELBQAw
...
YvDrZfKNOKwFWKMKKhCSi2rmCvLKuXXQJGhy
-----END CERTIFICATE-----
 1 s:O = cluster2
   i:O = cluster2
-----BEGIN CERTIFICATE-----
MIICzjCCAbagAwIBAgIRAIjegnzq/hN/NbMm3dmllnYwDQYJKoZIhvcNAQELBQAw
...
GZRM4zV9BopZg745Tdk2LVoHiBR536QxQv/0h1P0CdN9hNLklAhGN/Yf9SbDgLTw
6Sk=
-----END CERTIFICATE-----
...
```

The first certificate in the chain is the certificate of the workload and the second one is the Istio CA’s signing (CA) certificate.

As you can see, the Istio CA’s signing (CA) certificates are different in the 2 clusters, so one cluster can't validate certificates issued by the other cluster.

Creating a Virtual Mesh will unify these two CAs with a common root identity.

Run the following command to create the *Virtual Mesh*:



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
  meshes:
  - name: istiod-istio-system-cluster1
    namespace: gloo-mesh
  - name: istiod-istio-system-cluster2
    namespace: gloo-mesh
EOF
```

When we create the VirtualMesh and set the trust model to shared, Gloo Mesh will kick off the process of unifying identities under a shared root.

First, Gloo Mesh will create the Root CA.

Then, Gloo Mesh will use the Certificate Request Agent on each of the clusters to create a new key/cert pair that will form an intermediate CA used by the mesh on that cluster. It will then create a Certificate Request (CR).

![Virtual Mesh Creation](images/steps/create-virtual-mesh/virtualmesh-creation.png)

Gloo Mesh will then sign the intermediate certificates with the Root CA. 

At that point, we want Istio to pick up the new intermediate CA and start using that for its workloads. To do that Gloo Mesh creates a Kubernetes secret called `cacerts` in the `istio-system` namespace.

You can have a look at the Istio documentation [here](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/#plugging-in-existing-certificates-and-key) if you want to get more information about this process.

Check that the secret containing the new Istio CA has been created in the istio namespace, on the first cluster:

```bash
kubectl --context ${CLUSTER1} get secret -n istio-system cacerts -o yaml
```

Here is the expected output:

```
apiVersion: v1
data:
  ca-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRUG5kRDkwejN4dytYeTBzYzNmcjRmekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  jFWVlZtSWl3Si8va0NnNGVzWTkvZXdxSGlTMFByWDJmSDVDCmhrWnQ4dz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
  ca-key.pem: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS0FJQkFBS0NBZ0VBczh6U0ZWcEFxeVNodXpMaHVXUlNFMEJJMXVwbnNBc3VnNjE2TzlKdzBlTmhhc3RtClUvZERZS...
  DT2t1bzBhdTFhb1VsS1NucldpL3kyYUtKbz0KLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0K
  cert-chain.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRUG5kRDkwejN4dytYeTBzYzNmcjRmekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  RBTHpzQUp2ZzFLRUR4T2QwT1JHZFhFbU9CZDBVUDk0KzJCN0tjM2tkNwpzNHYycEV2YVlnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  key.pem: ""
  root-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUU0ekNDQXN1Z0F3SUJBZ0lRT2lZbXFGdTF6Q3NzR0RFQ3JOdnBMakFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  UNBVEUtLS0tLQo=
kind: Secret
metadata:
  labels:
    agent.certificates.mesh.gloo.solo.io: gloo-mesh
    cluster.multicluster.solo.io: ""
  name: cacerts
  namespace: istio-system
type: certificates.mesh.gloo.solo.io/issued_certificate
```

Same operation on the second cluster:

```bash
kubectl --context ${CLUSTER2} get secret -n istio-system cacerts -o yaml
```

Here is the expected output:

```
apiVersion: v1
data:
  ca-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRWXE1V29iWFhGM1gwTjlNL3BYYkNKekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  XpqQ1RtK2QwNm9YaDI2d1JPSjdQTlNJOTkrR29KUHEraXltCkZIekhVdz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
  ca-key.pem: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS1FJQkFBS0NBZ0VBMGJPMTdSRklNTnh4K1lMUkEwcFJqRmRvbG1SdW9Oc3gxNUUvb3BMQ1l1RjFwUEptCndhR1U1V...
  MNU9JWk5ObDA4dUE1aE1Ca2gxNCtPKy9HMkoKLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0K
  cert-chain.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRWXE1V29iWFhGM1gwTjlNL3BYYkNKekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  RBTHpzQUp2ZzFLRUR4T2QwT1JHZFhFbU9CZDBVUDk0KzJCN0tjM2tkNwpzNHYycEV2YVlnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  key.pem: ""
  root-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUU0ekNDQXN1Z0F3SUJBZ0lRT2lZbXFGdTF6Q3NzR0RFQ3JOdnBMakFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  UNBVEUtLS0tLQo=
kind: Secret
metadata:
  labels:
    agent.certificates.mesh.gloo.solo.io: gloo-mesh
    cluster.multicluster.solo.io: ""
  name: cacerts
  namespace: istio-system
type: certificates.mesh.gloo.solo.io/issued_certificate
```

As you can see, the secrets contain the same Root CA (base64 encoded), but different intermediate certs.

Have a look at the `VirtualMesh` object we've just created and notice the `autoRestartPods: true` in the `mtlsConfig`. This instructs Gloo Mesh to restart the Istio pods in the relevant clusters.

This is due to a limitation of Istio. The Istio control plane picks up the CA for Citadel and does not rotate it often enough.

<!--bash
printf "\nWaiting until the secret is created in $CLUSTER1"
until kubectl --context ${CLUSTER1} get secret -n istio-system cacerts &>/dev/null
do
  printf "%s" "."
  sleep 1
done
printf "\n"

printf "\nWaiting until the secret is created in $CLUSTER2"
until kubectl --context ${CLUSTER2} get secret -n istio-system cacerts &>/dev/null
do
  printf "%s" "."
  sleep 1
done
printf "\n"
-->

Now, let's check what certificates we get when we run the same commands we ran before we created the Virtual Mesh:

```bash
kubectl --context ${CLUSTER1} exec -t deploy/reviews-v1 -c istio-proxy \
-- openssl s_client -showcerts -connect ratings:9080
```


<!--bash
log_header "Test :: Certificate issued by GlooMesh in $CLUSTER1"
printf "\nWaiting until certificate issuer is gloo-mesh in $CLUSTER1"
found=false
search1="CONNECTED"
search2="i:O = gloo-mesh"
while true
do
  output=$(kubectl --context $CLUSTER1 exec -t deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition2 == 0 ]; then
    found=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="Certificate issued by gloo-mesh in $CLUSTER1"
log_success "$result_message"
-->

The output should be like that:

```
...
Certificate chain
 0 s:
   i:
-----BEGIN CERTIFICATE-----
MIIEBzCCAe+gAwIBAgIRAK1yjsFkisSjNqm5tzmKQS8wDQYJKoZIhvcNAQELBQAw
...
T77lFKXx0eGtDNtWm/1IPiOutIMlFz/olVuN
-----END CERTIFICATE-----
 1 s:
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIFEDCCAvigAwIBAgIQPndD90z3xw+Xy0sc3fr4fzANBgkqhkiG9w0BAQsFADAb
...
hkZt8w==
-----END CERTIFICATE-----
 2 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
 3 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
...
```

And let's compare with what we get on the second cluster:

```bash
kubectl --context ${CLUSTER2} exec -t deploy/reviews-v1 -c istio-proxy \
-- openssl s_client -showcerts -connect ratings:9080
```


<!--bash
log_header "Test :: Certificate issued by GlooMesh in $CLUSTER2"
printf "\nWaiting until certificate issuer is gloo-mesh in $CLUSTER2"
found=false
search1="CONNECTED"
search2="i:O = gloo-mesh"
while true
do
  output=$(kubectl --context $CLUSTER2 exec -t deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition2 == 0 ]; then
    found=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="Certificate issued by gloo-mesh in $CLUSTER2"
log_success "$result_message"
-->

The output should be like that:

```
...
Certificate chain
 0 s:
   i:
-----BEGIN CERTIFICATE-----
MIIEBjCCAe6gAwIBAgIQfSeujXiz3KsbG01+zEcXGjANBgkqhkiG9w0BAQsFADAA
...
EtTlhPLbyf2GwkUgzXhdcu2G8uf6o16b0qU=
-----END CERTIFICATE-----
 1 s:
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIFEDCCAvigAwIBAgIQYq5WobXXF3X0N9M/pXbCJzANBgkqhkiG9w0BAQsFADAb
...
FHzHUw==
-----END CERTIFICATE-----
 2 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
 3 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
...
```

You can see that the last certificate in the chain is now identical on both clusters. It's the new root certificate.

The first certificate is the certificate of the service. Let's decrypt it.

Copy and paste the content of the certificate (including the BEGIN and END CERTIFICATE lines) in a new file called `/tmp/cert` and run the following command:

```
openssl x509 -in /tmp/cert -text
```

The output should be as follow:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            7d:27:ae:8d:78:b3:dc:ab:1b:1b:4d:7e:cc:47:17:1a
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: 
        Validity
            Not Before: Sep 17 08:21:08 2020 GMT
            Not After : Sep 18 08:21:08 2020 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Alternative Name: critical
                URI:spiffe://cluster2/ns/default/sa/bookinfo-ratings
    Signature Algorithm: sha256WithRSAEncryption
...
-----BEGIN CERTIFICATE-----
MIIEBjCCAe6gAwIBAgIQfSeujXiz3KsbG01+zEcXGjANBgkqhkiG9w0BAQsFADAA
...
EtTlhPLbyf2GwkUgzXhdcu2G8uf6o16b0qU=
-----END CERTIFICATE-----
```

The Subject Alternative Name (SAN) is the most interesting part. It allows the sidecar proxy of the `reviews` service to validate that it talks to the sidecar proxy of the `rating` service.




## Lab 6 - Access control <a name="Lab-6"></a>

In the previous guide, we federated multiple meshes and established a shared root CA for a shared identity domain. Now that we have a logical VirtualMesh, we need a way to establish access policies across the multiple meshes, without treating each of them individually. Gloo Mesh helps by establishing a single, unified API that understands the logical VirtualMesh construct.

The application works correctly because RBAC isn't enforced.

Let's update the VirtualMesh to enable it:



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
  - name: istiod-istio-system-cluster1
    namespace: gloo-mesh
  - name: istiod-istio-system-cluster2
    namespace: gloo-mesh
EOF
```


<!--bash
log_header "Test :: Access should be denied"

printf "\nWaiting for error code 403"
while true
do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://${SVC_GW_CLUSTER1}/productpage")
  expected_code=403
  if [ "$status_code" == "$expected_code" ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="Got the expected status code $expected_code"
log_success "$result_message"
-->

After a few seconds, if you refresh the web page, you should see that you don't have access to the application anymore.

You should get the following error message:

```
RBAC: access denied
```

You need to create a Gloo Mesh Access Policy to allow the Istio Ingress Gateway to access the `productpage` microservice:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: istio-ingressgateway
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: istio-ingressgateway-service-account
          namespace: istio-system
          clusterName: cluster1
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: productpage
EOF
```


<!--bash
log_header "Test :: Only productpage should be accessible"
search1="Error fetching product details"
search2="Error fetching product reviews"
printf "\nWaiting for condition"
while true
do
  output=$(curl -s "http://${SVC_GW_CLUSTER1}/productpage" 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition2 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Details is unavailable"
log_success "Reviews is unavailable"
-->

Now, refresh the page again and you should be able to access the application, but neither the `details` nor the `reviews`:

![Bookinfo RBAC 1](images/steps/access-control/bookinfo-rbac1.png)

You can create another Gloo Mesh Access Policy to allow the `productpage` microservice to talk to these 2 microservices:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: productpage
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: bookinfo-productpage
          namespace: default
          clusterName: cluster1
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: details
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: reviews
EOF
```


<!--bash
log_header "Test :: Reviews and details should also be accessible, but ratings shouldn't"
printf "\nWaiting for conditions"
search1="Error fetching product details"
search2="Error fetching product reviews"
search3="Ratings service is currently unavailable"
while true
do
  output=$(curl -s "http://${SVC_GW_CLUSTER1}/productpage" 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  echo "$output" | grep "$search3" &>/dev/null
  condition3=$?
  if [ $condition1 != 0 ] && [ $condition2 != 0 ] && [ $condition3 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Details is available"
log_success "Reviews is available"
log_success "Ratings is unavailable"
-->

If you refresh the page, you should be able to see the product `details` and the `reviews`, but the `reviews` microservice can't access the `ratings` microservice:

![Bookinfo RBAC 2](images/steps/access-control/bookinfo-rbac2.png)

Create another AccessPolicy to fix the issue:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: reviews
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: bookinfo-reviews
          namespace: default
          clusterName: cluster1
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: ratings
EOF
```


<!--bash
log_header "Test :: All services should be accessible"
printf "\nWaiting for condition"
search1="Error fetching product details"
search2="Error fetching product reviews"
search3="Ratings service is currently unavailable"
while true
do
  output=$(curl -s "http://${SVC_GW_CLUSTER1}/productpage" 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  echo "$output" | grep "$search3" &>/dev/null
  condition3=$?
  if [ $condition1 != 0 ] && [ $condition2 != 0 ] && [ $condition3 != 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Details is available"
log_success "Reviews is available"
log_success "Ratings is available"
-->

Refresh the page another time and all the services should now work:

![Bookinfo working](images/steps/access-control/bookinfo-working.png)

If you refresh the web page several times, you should see only the versions `v1` (no stars) and `v2` (black stars), which means that all the requests are still handled by the first cluster.



## Lab 7 - Traffic policy <a name="Lab-7"></a>

We're going to use Gloo Mesh Traffic Policies to inject faults and configure timeouts.

Let's create the following TrafficPolicy to inject a delay when the `v2` version of the `reviews` service talk to the `ratings` service on cluster1.:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  name: ratings-fault-injection
  namespace: gloo-mesh
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      labels:
        app: reviews
        version: v2
      namespaces:
      - default
      clusters:
      - cluster1
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: ratings
          namespace: default
  policy:
    faultInjection:
      fixedDelay: 2s
      percentage: 100
EOF
```

If you refresh the webpage, you should see that it takes longer to get the `productpage` loaded when version `v2` of the `reviews` services is called.

Now, let's configure a 0.5s request timeout when the `productpage` service calls the `reviews` service on cluster1.

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  name: reviews-request-timeout
  namespace: gloo-mesh
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      labels:
        app: productpage
      namespaces:
      - default
      clusters:
      - cluster1
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  policy:
    requestTimeout: 0.5s
EOF
```


<!--bash
log_header "Test :: Reviews shouldn't be available"
rating_service_unvailable=false
printf "\nWait for condition"
while true
do
  curl -s "http://${SVC_GW_CLUSTER1}/productpage" | grep "Sorry, product reviews are currently unavailable for this book." &>/dev/null
  if [ $? == 0 ]; then
    rating_service_unvailable=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Reviews is unavailable"
-->

If you refresh the page several times, you'll see an error message telling that reviews are unavailable when the productpage is trying to communicate with the version `v2` of the `reviews` service.

![Bookinfo v3](images/steps/traffic-policy/reviews-unavailable.png)

Let's delete the TrafficPolicied:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete trafficpolicy ratings-fault-injection
kubectl --context ${MGMT} -n gloo-mesh delete trafficpolicy reviews-request-timeout
```



## Lab 8 - Multi-cluster Traffic <a name="Lab-8"></a>

On the first cluster, the `v3` version of the `reviews` microservice doesn't exist, so we're going to redirect some of the traffic to the second cluster to make it available.

![Multicluster traffic](images/steps/multicluster-traffic/multicluster-traffic.png)

Let's create the following TrafficPolicy:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  namespace: gloo-mesh
  name: simple
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      namespaces:
      - default
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  policy:
    trafficShift:
      destinations:
        - kubeService:
            clusterName: cluster2
            name: reviews
            namespace: default
            subset:
              version: v3
          weight: 75
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v1
          weight: 15
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v2
          weight: 10
EOF
```


<!--bash
log_header "Test :: Should get reviews v3 from cluster2 but not ratings"
rating_service_unvailable=false
printf "\nWait for condition"
while true
do
  curl -s "http://${SVC_GW_CLUSTER1}/productpage" | grep "Ratings service is currently unavailable" &>/dev/null
  if [ $? == 0 ]; then
    rating_service_unvailable=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Got reviews v3 from cluster2 but not ratings"
-->

If you refresh the page several times, you'll see the `v3` version of the `reviews` microservice:

![Bookinfo v3](images/steps/multicluster-traffic/bookinfo-v3-no-ratings.png)

But as you can see, the `ratings` aren't available. That's because we only allowed the `reviews` microservice of the first cluster to talk to the `ratings` microservice.

Let's update the AccessPolicy to fix the issue:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: reviews
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: bookinfo-reviews
          namespace: default
          clusterName: cluster1
        - name: bookinfo-reviews
          namespace: default
          clusterName: cluster2
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: ratings
EOF
```


<!--bash
log_header "Test :: Should get reviews v3 from cluster2 with ratings"
is_red_star_visible=false
printf "\nWait for condition"
while true
do
  curl -s "http://${SVC_GW_CLUSTER1}/productpage" | grep 'color="red"' &>/dev/null
  if [ $? == 0 ]; then
    is_red_star_visible=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Got reviews v3 from cluster2 with ratings"
-->

If you refresh the page several times again, you'll see the `v3` version of the `reviews` microservice with the red stars:

![Bookinfo v3](images/steps/multicluster-traffic/bookinfo-v3.png)

Let's delete the TrafficPolicy:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete trafficpolicy simple
```



## Lab 9 - Traffic failover <a name="Lab-9"></a>

If you refresh the web page several times, you should see only the versions `v1` (no stars) and `v2` (black stars), which means that all the requests are handled by the first cluster.

Another interesting feature of Gloo Mesh is its ability to manage failover between clusters.

In this lab, we're going to configure a failover for the `reviews` service:

![After failover](images/steps/traffic-failover/after-failover.png)

Then, we create a VirtualDestination to define a new hostname (`reviews-global.default.global`) that will be backed by the `reviews` microservice runnings on both clusters. 

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: VirtualDestination
metadata:
  name: reviews-global
  namespace: gloo-mesh
spec:
  hostname: reviews.global
  port:
    number: 9080
    protocol: http
  localized:
    outlierDetection:
      consecutiveErrors: 1
      maxEjectionPercent: 100
      interval: 5s
      baseEjectionTime: 120s
    destinationSelectors:
    - kubeServiceMatcher:
        labels:
          app: reviews
  virtualMesh:
    name: virtual-mesh
    namespace: gloo-mesh
EOF
```

Finally, we can define another TrafficPolicy to make sure all the requests for the `reviews` microservice on the local cluster will be handled by the VirtualDestination we've just created.

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  name: reviews-shift-failover
  namespace: default
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      namespaces:
      - default
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  policy:
    trafficShift:
      destinations:
        - virtualDestination:
            name: reviews-global
            namespace: gloo-mesh
EOF
```

We're going to make the `reviews` services unavailable on the first cluster.

```bash
kubectl --context ${CLUSTER1} patch deploy reviews-v1 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'
kubectl --context ${CLUSTER1} patch deploy reviews-v2 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'
```


<!--bash
log_header "Test :: Access reviews from cluster2 since the ones from cluster1 are in sleep mode"
printf "\nWaiting for all the pods to become ready in ${CLUSTER1}."
sleep 1
until [ $(kubectl --context ${CLUSTER1} get pods -l app=reviews -o json | jq -r '[.items[].status.containerStatuses[].ready | select(. == true)] | length') -eq 4 ]; do
  printf "%s" "."
  sleep 1
done
printf "\n"

printf "\nWaiting to have two pods with label app=reviews and 'sleep' command"
while true
do
  count=$(kubectl get po --context ${CLUSTER1} -l app=reviews -o json | jq -r '[.items[].spec.containers[0].command[0] | select(. == "sleep")] | length')
  if [ $count == 2 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "There are two pods with label app=reviews and 'sleep' command"

printf "\nWaiting for Reviews service to be available"
search1="product reviews are currently unavailable"
while true
do
  output=$(curl -s "http://${SVC_GW_CLUSTER1}/productpage" 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  if [ $condition1 != 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Reviews service is still available"
-->

If you refresh the web page several times again, you should still see the `reviews` displayed while there's no `reviews` service available anymore on the first cluster.

You can use the following command to validate that the requests are handled by the second cluster:

```
kubectl --context ${CLUSTER2} logs -l app=reviews -c istio-proxy -f
```

You should see a line like below each time you refresh the web page:

```
[2020-10-12T14:19:35.996Z] "GET /reviews/0 HTTP/1.1" 200 - "-" "-" 0 295 6 6 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36" "d18da89b-8682-4e8d-9284-b3d5ff78f2f7" "reviews:9080" "127.0.0.1:9080" inbound|9080|http|reviews.default.svc.cluster.local 127.0.0.1:41542 192.168.163.201:9080 192.168.163.221:42110 outbound_.9080_.version-v1_.reviews.default.svc.cluster.local default
```

We're going to make the `reviews` services available again on the first cluster.

```bash
kubectl --context ${CLUSTER1} patch deployment reviews-v1  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
kubectl --context ${CLUSTER1} patch deployment reviews-v2  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
```

Afer 2 minutes, you can validate that the requests are now handled by the first cluster using the following command:

```
kubectl --context ${CLUSTER1} logs -l app=reviews -c istio-proxy -f
```

Let's delete the VirtualDestination and the TrafficPolicy:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete virtualdestination reviews-global
kubectl --context ${MGMT} -n default delete trafficpolicy reviews-shift-failover
```

> ### Note that you can combine traffic shift with failover
> ```
> cat << EOF | kubectl --context ${MGMT} apply -f -
> apiVersion: networking.mesh.gloo.solo.io/v1
> kind: TrafficPolicy
> metadata:
>   name: reviews-shift-failover
>   namespace: gloo-mesh
> spec:
>   sourceSelector:
>   - kubeWorkloadMatcher:
>       namespaces:
>       - default
>   destinationSelector:
>   - kubeServiceRefs:
>       services:
>         - clusterName: cluster1
>           name: reviews
>           namespace: default
>   policy:
>     trafficShift:
>       destinations:
>         - virtualDestination:
>             name: reviews-global
>             namespace: gloo-mesh
>             subset:
>               version: v1
>           weight: 50
>         - virtualDestination:
>             name: reviews-global
>             namespace: gloo-mesh
>             subset:
>               version: v2
>           weight: 50
> EOF
> ```



## Lab 10 - Extend Envoy with WebAssembly <a name="Lab-10"></a>

WebAssembly (WASM) is the future of cloud-native infrastructure extensibility.

WASM is a safe, secure, and dynamic way of extending infrastructure with the language of your choice. WASM tool chains compile your code from any of the supported languages into a type-safe, binary format that can be loaded dynamically in a WASM sandbox/VM.

The Envoy Wasm filter is already available, but it's not ready for production use yet. More info available in [this Blog Post](https://www.solo.io/blog/the-state-of-webassembly-in-envoy-proxy/).

Both Gloo Edge and Istio are based on Envoy, so they can take advantage of WebAssembly.

One of the projects for working with WASM and Envoy proxy is [WebAssembly Hub](https://webassemblyhub.io/).

WebAssembly Hub is a meeting place for the community to share and consume WebAssembly Envoy extensions. You can easily search and find extensions that meet the functionality you want to add and give them a try.

Gloo Mesh Enterprise CLI comes with all the features you need to develop, build, push and deploy your Wasm filters on Istio.

Install or update the Gloo Mesh Enterprise CLI plugin manager :

```bash
if meshctl plugin; then
  meshctl plugin update
else
  meshctl init-plugin-manager
fi
```

Install or upgrade the accesslog meshctl plugin:

```bash
if meshctl accesslog --help; then
  meshctl plugin upgrade wasm@v1.1.0
else
  meshctl plugin install wasm@v1.1.0
fi
```

The main advantage of building a Wasm Envoy filter is that you can manipulate requests (and responses) exactly the way it makes sense for your specific use cases.

Perhaps you want to gather some metrics only when the request contain specific headers, or you want to enrich the request by getting information from another API, it doesn't matter, you're now free to do exactly what you want.

The first decision you need to take is to decide which SDK (so which language) you want to use. SDKs are currently available for C++, AssemblyScript, RUST and TinyGo.

Not all the languages can be compiled to WebAssembly and don't expect that you'll be able to import any external packages (like the Amazon SDK).

There are 2 main reasons why you won't be able to do that:

- The first one is that you'll need to tell Envoy to send HTTP requests for you (if you need to get information from an API, for example).
- The second one is that most of these languages are not supporting all the standard packages you expect. For example, TinyGo doesn't have a JSON package and AssemblyScript doesn't have a Regexp package.

So, you need to determine what you want your filter to do, look at what kind of packages you'll need (Regexp, ...) and check which one of the language you already know is matching your requirements.

For example, if you want to manipulate the response headers with a regular expression and you have some experience with Golang, then you'll probably choose TinyGo.

In this lab, we won't focus on developing a filter, but on how to build, push and deploy filters.

### Prepare

Our Envoy instances will fetch their wasm filters from an envoy cluster that must be defined in the static bootstrap config. We must therefore perform a one-time operation to add the wasm-agent as a cluster in the Envoy bootstrap:

```bash
cat <<EOF | kubectl apply --context ${CLUSTER1} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gloo-mesh-custom-envoy-bootstrap
  namespace: default
data:
  custom_bootstrap.json: |
    {
      "static_resources": {
        "clusters": [{
          "name": "enterprise_agent_cluster",
          "type" : "STRICT_DNS",
          "connect_timeout": "1s",
          "lb_policy": "ROUND_ROBIN",
          "load_assignment": {
            "cluster_name": "enterprise_agent_cluster",
            "endpoints": [{
              "lb_endpoints": [{
                "endpoint": {
                  "address":{
                    "socket_address": {
                      "address": "enterprise-agent.gloo-mesh.svc.cluster.local",
                      "port_value": 9977
                    }
                  }
                }
              }]
            }]
          },
          "circuit_breakers": {
            "thresholds": [
              {
                "priority": "DEFAULT",
                "max_connections": 100000,
                "max_pending_requests": 100000,
                "max_requests": 100000
              },
              {
                "priority": "HIGH",
                "max_connections": 100000,
                "max_pending_requests": 100000,
                "max_requests": 100000
              }
            ]
          },
          "upstream_connection_options": {
            "tcp_keepalive": {
              "keepalive_time": 300
            }
          },
          "max_requests_per_connection": 1,
          "http2_protocol_options": { }
        }]
      }
    }
EOF

cat <<EOF | kubectl apply --context ${CLUSTER2} -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gloo-mesh-custom-envoy-bootstrap
  namespace: default
data:
  custom_bootstrap.json: |
    {
      "static_resources": {
        "clusters": [{
          "name": "enterprise_agent_cluster",
          "type" : "STRICT_DNS",
          "connect_timeout": "1s",
          "lb_policy": "ROUND_ROBIN",
          "load_assignment": {
            "cluster_name": "enterprise_agent_cluster",
            "endpoints": [{
              "lb_endpoints": [{
                "endpoint": {
                  "address":{
                    "socket_address": {
                      "address": "enterprise-agent.gloo-mesh.svc.cluster.local",
                      "port_value": 9977
                    }
                  }
                }
              }]
            }]
          },
          "circuit_breakers": {
            "thresholds": [
              {
                "priority": "DEFAULT",
                "max_connections": 100000,
                "max_pending_requests": 100000,
                "max_requests": 100000
              },
              {
                "priority": "HIGH",
                "max_connections": 100000,
                "max_pending_requests": 100000,
                "max_requests": 100000
              }
            ]
          },
          "upstream_connection_options": {
            "tcp_keepalive": {
              "keepalive_time": 300
            }
          },
          "max_requests_per_connection": 1,
          "http2_protocol_options": { }
        }]
      }
    }
EOF
```


<!--bash
log_header "Test :: ConfigMaps are created"
kubectl --context ${CLUSTER1} get cm gloo-mesh-custom-envoy-bootstrap &>/dev/null
result=$?
result_message="ConfigMap in ${CLUSTER1} exists"
assert_eq $result 0 "$result_message" && log_success "$result_message"
kubectl --context ${CLUSTER2} get cm gloo-mesh-custom-envoy-bootstrap &>/dev/null
result=$?
result_message="ConfigMap in ${CLUSTER2} exists"
assert_eq $result 0 "$result_message" && log_success "$result_message"
-->

### Develop

The Gloo Mesh CLI, meshctl can be used to create the skeleton for you.

Let's take a look at the help of the meshctl wasme option:

```
meshctl wasm

The interface for managing Gloo Mesh WASM filters

Usage:
  wasm [command]

Available Commands:
  build       Build a wasm image from the filter source directory.
  deploy      Deploy an Envoy WASM Filter to Istio Sidecar Proxies (Envoy).
  help        Help about any command
  init        Initialize a project directory for a new Envoy WASM Filter.
  list        List Envoy WASM Filters stored locally or published to webassemblyhub.io.
  login       Log in so you can push images to the remote server.
  pull        Pull wasm filters from remote registry
  push        Push a wasm filter to remote registry
```

The following command will create the skeleton to build a Wasm filter using AssemblyScript:

```
meshctl wasm init myfilter --language=assemblyscript
```

It will ask what platform you will run your filter on (because the SDK version can be different based on the ABI corresponding to the version of Envoy used by this Platform).

And it will create the following file structure under the directory you have indicated:

```
./package-lock.json
./.gitignore
./assembly
./assembly/index.ts
./assembly/tsconfig.json
./package.json
./runtime-config.json
```

The most interesting file is the index.ts one, where you'll write the code corresponding to your filter:

```
export * from "@solo-io/proxy-runtime/proxy";
import { RootContext, Context, RootContextHelper, ContextHelper, registerRootContext, FilterHeadersStatusValues, stream_context } from "@solo-io/proxy-runtime";

class AddHeaderRoot extends RootContext {
  configuration : string;

  onConfigure(): bool {
    let conf_buffer = super.getConfiguration();
    let result = String.UTF8.decode(conf_buffer);
    this.configuration = result;
    return true;
  }

  createContext(): Context {
    return ContextHelper.wrap(new AddHeader(this));
  }
}

class AddHeader extends Context {
  root_context : AddHeaderRoot;
  constructor(root_context:AddHeaderRoot){
    super();
    this.root_context = root_context;
  }
  onResponseHeaders(a: u32): FilterHeadersStatusValues {
    const root_context = this.root_context;
    if (root_context.configuration == "") {
      stream_context.headers.response.add("hello", "world!");
    } else {
      stream_context.headers.response.add("hello", root_context.configuration);
    }
    return FilterHeadersStatusValues.Continue;
  }
}

registerRootContext(() => { return RootContextHelper.wrap(new AddHeaderRoot()); }, "add_header");
```

We'll keep the default content, so the filter will add a new Header in all the Responses with the key hello and the value passed to the filter (or world! if no value is passed to it).

### Build

We're ready to compile the code into WebAssembly.

The Gloo Mesh Enterprise CLI will make your life easier again.

You simply need to run the following command:

```
cd myfilter
meshctl wasm build assemblyscript -t webassemblyhub.io/djannot/myfilter:0.1 .
```

You can see that I've indicated that I wanted to use `webassemblyhub.io/djannot/myfilter:0.1` for the Image reference.

`meshctl` will create an OCI compliant image with this tag. It's exactly the same as when you use the Docker CLI and the Docker Hub.

### Push

The image has been built, so we can now push it to the Web Assembly Hub.

But you would need to create a free account and to run `meshctl login` to authenticate.

To simplify the lab, we will use the image that has already been pushed.

![Gloo Mesh Overview](images/steps/web-assembly/web-assembly-hub.png)

But note that the command to push the Image is the following one:

```bash
wasm_image=webassemblyhub.io/djannot/myfilter:0.2
```

```
meshctl wasm push $wasm_image
```

Then, if you go to the Web Assembly Hub, you'll be able to see the Image of your Wasm filter


<!--bash
log_header "Test :: Check image webassembly"
meshctl wasm pull $wasm_image &>/dev/null
result=$?
result_message="Image $wasm_image exists in the repository"
assert_eq $result 0 "$result_message" && log_success "$result_message"
-->

### Deploy

It's now time to deploy your Wasm filter on Istio !

Note that you can also deploy it on Gloo Edge.

Run the following command to make `cluster1` the current cluster.

```bash
kubectl config use-context ${CLUSTER1}
```

You can deploy it using `meshctl wasm deploy`, but we now live in a Declarative world, so let's do it the proper way.

Gloo Mesh Enteprise has a `WasmDeployment` CRD (Custom Resource Definition) for that purpose.

To deploy your Wasm filter on all the Pods corresponding to the version v1 of the reviews service and running in the default namespace of the cluster1 cluster, use the following commands:

```bash
kubectl patch deployment reviews-v1 --context ${CLUSTER1} --patch='{"spec":{"template": {"metadata": {"annotations": {"sidecar.istio.io/bootstrapOverride": "gloo-mesh-custom-envoy-bootstrap"}}}}}' --type=merge

cat << EOF | kubectl --context ${MGMT} apply -f-
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: WasmDeployment
metadata:
  name: reviews-wasm
  namespace: gloo-mesh
spec:
  filters:
  - filterContext: SIDECAR_INBOUND
    wasmImageSource:
      wasmImageTag: webassemblyhub.io/djannot/myfilter:0.2
    staticFilterConfig:
      '@type': type.googleapis.com/google.protobuf.StringValue
      value: "Gloo Mesh Enterprise"
  workloadSelector:
  - kubeWorkloadMatcher:
      clusters:
      - cluster1
      labels:
        app: reviews
        version: v1
      namespaces:
      - default
EOF
```


<!--bash
log_header "Test :: Check WasmDeployment"
kubectl --context ${MGMT} get wasmdeployment reviews-wasm -n gloo-mesh
result=$?
result_message="wasmdeployment created in ${MGMT}"
assert_eq $result 0 "$result_message" && log_success "$result_message"

printf "\nWaiting for wasmdeployment to create envoyfilter"
result_message="envoyfilter created in ${CLUSTER1}"
result=false
for i in {1..20}; do
  kubectl --context ${CLUSTER1} get envoyfilter reviews-v1-wasm &>/dev/null
  if [ $? == 0 ]; then
    result=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
assert_true $result "$result_message" && log_success "$result_message"
-->

Let's send a request from the `productpage` service to the `reviews` service:

```
kubectl exec -it $(kubectl  get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- python -c "import requests; r = requests.get('http://reviews:9080/reviews/0'); print(r.headers)"
```


<!--bash
log_header "Test :: Get WasmDeployment log traces"
printf "\nWaiting for log traces"
search1="hello"
search2="Gloo Mesh Enterprise Beta"
while true
do
  output=$(kubectl exec $(kubectl  get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- python -c "import requests; r = requests.get('http://reviews:9080/reviews/0'); print(r.headers)")
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition1 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Got the new header"
-->

You should get either:

```
{'x-powered-by': 'Servlet/3.1', 'content-type': 'application/json', 'date': 'Tue, 15 Dec 2020 08:23:24 GMT', 'content-language': 'en-US', 'content-length': '295', 'x-envoy-upstream-service-time': '10', 'server': 'envoy'}
```

or:

```
{'x-powered-by': 'Servlet/3.1', 'content-type': 'application/json', 'date': 'Tue, 15 Dec 2020 08:23:25 GMT', 'content-language': 'en-US', 'content-length': '295', 'x-envoy-upstream-service-time': '17', 'hello': 'Gloo Mesh Enterprise Beta', 'server': 'envoy'}
```

We have deployed the Istio Bookinfo application with the versions `v1` and `v2` of the `reviews` service, so the new header is added half of the time.

### Observe

Gloo Mesh Enterprise has processed the `WasmDeployment` object and has added status information on it:

```
status:
  observedGeneration: 1
  workloadStates:
    reviews-v1-default-cluster1-deployment.gloo-mesh.: FILTERS_DEPLOYED
```

Very useful, no ?

Delete the WasmDeployment:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete wasmdeployment reviews-wasm
```



## Lab 11 - Observability <a name="Lab-11"></a>

Gloo Mesh can also be used to collect the access logs from any Pod running in any cluster.

Create the following `AccessLogRecord` object to collect all the access logs of the `reviews` services running on any cluster:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: observability.enterprise.mesh.gloo.solo.io/v1
kind: AccessLogRecord
metadata:
  name: access-log-reviews
  namespace: gloo-mesh
spec:
  workloadSelectors:
  - kubeWorkloadMatcher:
      namespaces:
      - default
      labels:
        app: reviews
EOF
```


<!--bash
log_header "Test :: create AccessLogRecord"
printf "\nWaiting for AccessLogRecord to be created"
while true
do
  kubectl --context ${MGMT} get accesslogrecord access-log-reviews -n gloo-mesh &>/dev/null
  if [ $? == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Accesslogrecord has been created"
-->

You can see the access logs in the web interface or using `meshctl`.

To see them with `meshctl` you need to install the corresponding plugin.

Install or update the Gloo Mesh Enterprise CLI plugin manager :

```bash
if meshctl plugin; then
  meshctl plugin update
else
  meshctl init-plugin-manager
fi
```

Install or upgrade the accesslog meshctl plugin:

```bash
if meshctl accesslog --help; then
  meshctl plugin upgrade accesslog@v1.1.0
else
  meshctl plugin install accesslog@v1.1.0
fi
```

Gather the latest access logs:

```bash
kubectl config use-context ${MGMT}
meshctl accesslog --kubecontext ${MGMT} -o json
```


<!--bash
printf "\nCreate some traffic and check log traces"
search1="httpAccessLog"
search2="workloadRef"
while true
do
  curl -s http://${SVC_GW_CLUSTER1}/productpage &>/dev/null
  output=$(meshctl accesslog --kubecontext ${MGMT} -o json 2>&1)
  echo "$output" | grep "$search1" &>/dev/null
  condition1=$?
  echo "$output" | grep "$search2" &>/dev/null
  condition2=$?
  if [ $condition1 == 0 ] && [ $condition1 == 0 ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Log traces as expected"
-->

You should get an output similar to the following one:

```
{
  "result": {
    "workloadRef": {
      "name": "reviews-v2",
      "namespace": "default",
      "clusterName": "cluster1"
    },
    "httpAccessLog": {
      "commonProperties": {
        "downstreamRemoteAddress": {
          "socketAddress": {
            "address": "10.102.158.19",
            "portValue": 47198
          }
        },
        "downstreamLocalAddress": {
          "socketAddress": {
            "address": "10.102.158.25",
            "portValue": 9080
          }
        },
        "tlsProperties": {
          "tlsVersion": "TLSv1_2",
          "tlsCipherSuite": 49200,
          "tlsSniHostname": "outbound_.9080_._.reviews.default.svc.cluster.local",
          "localCertificateProperties": {
            "subjectAltName": [
              {
                "uri": "spiffe://cluster1/ns/default/sa/bookinfo-reviews"
              }
            ]
          },
          "peerCertificateProperties": {
            "subjectAltName": [
              {
                "uri": "spiffe://cluster1/ns/default/sa/bookinfo-productpage"
              }
            ]
          }
        },
        "startTime": "2021-03-21T17:33:46.182478Z",
        "timeToLastRxByte": "0.000062572s",
        "timeToFirstUpstreamTxByte": "0.000428530s",
        "timeToLastUpstreamTxByte": "0.000436843s",
        "timeToFirstUpstreamRxByte": "0.040638581s",
        "timeToLastUpstreamRxByte": "0.040692768s",
        "timeToFirstDownstreamTxByte": "0.040671495s",
        "timeToLastDownstreamTxByte": "0.040708877s",
        "upstreamRemoteAddress": {
          "socketAddress": {
            "address": "127.0.0.1",
            "portValue": 9080
          }
        },
        "upstreamLocalAddress": {
          "socketAddress": {
            "address": "127.0.0.1",
            "portValue": 43078
          }
        },
        "upstreamCluster": "inbound|9080||",
        "metadata": {
          "filterMetadata": {
            "istio_authn": {
              "request.auth.principal": "cluster1/ns/default/sa/bookinfo-productpage",
              "source.namespace": "default",
              "source.principal": "cluster1/ns/default/sa/bookinfo-productpage",
              "source.user": "cluster1/ns/default/sa/bookinfo-productpage"
            }
          }
        },
        "routeName": "default",
        "downstreamDirectRemoteAddress": {
          "socketAddress": {
            "address": "10.102.158.19",
            "portValue": 47198
          }
        }
      },
      "protocolVersion": "HTTP11",
      "request": {
        "requestMethod": "GET",
        "scheme": "http",
        "authority": "reviews:9080",
        "path": "/reviews/0",
        "userAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36",
        "requestId": "b0522245-d300-46a4-bfd3-727fcfa42efd",
        "requestHeadersBytes": "644"
      },
      "response": {
        "responseCode": 200,
        "responseHeadersBytes": "1340",
        "responseBodyBytes": "379",
        "responseCodeDetails": "via_upstream"
      }
    }
  }
}
...
```

Interesting, no ?

Delete the `AccessLogRecord`:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete accesslogrecords.observability.enterprise.mesh.gloo.solo.io access-log-reviews                 
```



## Lab 12 - Exploring the Gloo Mesh Enterprise UI <a name="Lab-12"></a>

To access the UI, run the following command:

```
kubectl --context ${MGMT} port-forward -n gloo-mesh svc/dashboard 8090
```

The UI is available at http://localhost:8090

![Gloo Mesh Overview](images/steps/ui/smh-ui-1.png)

If you click on `Meshes`, you can the VirtualMesh we've configured previously:

![Gloo Mesh VirtualMesh](images/steps/ui/smh-ui-2.png)

You can see that Global Access Policy is enabled and get more details when you click on `View Virtual Mesh Details`.

For example, you can see the `reviews` AccessPolicy we've configured in the previous lab:

![Gloo Mesh VirtualMesh](images/steps/ui/smh-ui-3.png)

If you click on the Settings icon on the top right corner, you can see the clusters and the RBAC policies:

![Gloo Mesh VirtualMesh](images/steps/ui/smh-ui-4.png)

You can also use the Gloo Mesh Enterprise UI to see the different Wasm filters that have been deployed globally:

![Gloo Mesh Overview](images/steps/ui/gloo-mesh-wasm.png)

And you can even see the workloads were a Wasm filter has been deployed on:

![Gloo Mesh Overview](images/steps/ui/gloo-mesh-wasm-filter.png)

Take the time to explore the `Policies` and `Debug` tab to see what other information is available.



## Lab 13 - Gloo Mesh Enterprise RBAC <a name="Lab-13"></a>

In large organizations, several teams are using the same Kubernetes cluster. They use Kubernetes RBAC to define who can do what and where.

When using a Service Mesh like Istio, users need to create different kind of objects (VirtualServices, DestinationRules, ...) and Kubernetes RBAC doesn't allow to restrict what specs they define in these objects.

Gloo Mesh abstracts the complexity with AccessPolicies and TrafficPolicies, but the problem remains the same.

The good news is that Gloo Mesh comes with an RBAC capability that is filling this gap.

With Gloo Mesh RBAC, you can define Roles and RoleBindings to determine what users can do in a very fine grained manner.

When we deployed Gloo Mesh, we applied an `admin.yaml` file that has granted the Gloo Mesh admin Role to the current user.

Let's delete the corresponding `RoleBinding`:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete rolebindings.rbac.enterprise.mesh.gloo.solo.io admin-role-binding
```

Now, if you try to create the multi cluster Traffic Policy we used before, you shouldn't be allowed to do it.

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  namespace: gloo-mesh
  name: simple
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      namespaces:
      - default
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  policy:
    trafficShift:
      destinations:
        - kubeService:
            clusterName: cluster2
            name: reviews
            namespace: default
            subset:
              version: v3
          weight: 75
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v1
          weight: 15
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v2
          weight: 10
EOF
```


<!--bash
log_header "Test :: Not enough permissions to create the TrafficPolicy"
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  name: test
  namespace: gloo-mesh
EOF
result=$?
result_message="User cannot create the TrafficPolicy"
assert_not_eq $result 0 "$result_message" && log_success "$result_message"
-->

Here is the expected output:

```
Error from server (User kubernetes-admin does not have the permissions necessary to perform this action.): error when creating "STDIN": admission webhook "rbac-webhook.gloo-mesh.svc" denied the request: User kubernetes-admin does not have the permissions necessary to perform this action.
```

Let's create a namespace admin Role:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: rbac.enterprise.mesh.gloo.solo.io/v1
kind: Role
metadata:
  name: default-namespace-admin-role
  namespace: gloo-mesh
spec:
  trafficPolicyScopes:
    - trafficPolicyActions:
        - ALL
      destinationSelectors:
        - kubeServiceMatcher:
            labels:
              "*": "*"
            namespaces:
              - "default"
            clusters:
              - "*"
        - kubeServiceRefs:
            services:
              - name: "*"
                namespace: "default"
                clusterName: "*"
      workloadSelectors:
        - kubeWorkloadMatcher:
            labels:
              "*": "*"
            namespaces:
              - "default"
            clusters:
              - "*"
  virtualMeshScopes:
    - virtualMeshActions:
        - ALL
      meshRefs:
        - name: "*"
          namespace: "default"
  accessPolicyScopes:
    - identitySelectors:
        - kubeIdentityMatcher:
            namespaces:
              - "default"
            clusters:
              - "*"
          kubeServiceAccountRefs:
            serviceAccounts:
              - name: "*"
                namespace: "default"
                clusterName: "*"
      destinationSelectors:
        - kubeServiceMatcher:
            labels:
              "*": "*"
            namespaces:
              - "default"
            clusters:
              - "*"
          kubeServiceRefs:
            services:
              - name: "*"
                namespace: "default"
                clusterName: "*"
  virtualDestinationScopes:
    - virtualMeshRefs:
        - name: "*"
          namespace: "default"
      meshRefs:
        - name: "*"
          namespace: "default"
      destinationSelectors:
        - kubeServiceMatcher:
            labels:
              "*": "*"
            namespaces:
              - "default"
            clusters:
              - "*"
          kubeServiceRefs:
            services:
              - name: "*"
                namespace: "default"
                clusterName: "*"
      destinations:
        - kubeService:
            name: "*"
            namespace: "default"
            clusterName: "*"
  wasmDeploymentScopes:
    - workloadSelectors:
        - kubeWorkloadMatcher:
            labels:
              "*": "*"
            namespaces:
              - "default"
            clusters:
              - "*"
  accessLogRecordScopes:
    - workloadSelectors:
        - kubeWorkloadMatcher:
            labels:
              "*": "*"
            namespaces:
              - "default"
            clusters:
              - "*"
EOF
```

With this role, a user can create policies on the `default` namespace (globally).

Then, you need to create a Role Binding to grant this Role to the current user:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: rbac.enterprise.mesh.gloo.solo.io/v1
kind: RoleBinding
metadata:
  labels:
    app: gloo-mesh
  name: default-namespace-admin-role-binding
  namespace: gloo-mesh
spec:
  roleRef:
    name: default-namespace-admin-role
    namespace: gloo-mesh
  subjects:
    - kind: User
      name: system:serviceaccount:kube-system:eks-admin
EOF
```

You can try to create the Traffic Policy again:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  namespace: gloo-mesh
  name: simple
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      namespaces:
      - default
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  policy:
    trafficShift:
      destinations:
        - kubeService:
            clusterName: cluster2
            name: reviews
            namespace: default
            subset:
              version: v3
          weight: 75
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v1
          weight: 15
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v2
          weight: 10
EOF
```


<!--bash
log_header "Test :: User is allowed to create the TrafficPolicy"
kubectl --context ${MGMT} get trafficpolicy simple -n gloo-mesh &>/dev/null
result=$?
result_message="User can create the TrafficPolicy"
assert_eq $result 0 "$result_message" && log_success "$result_message"
-->

And this time it should work.

We’ve covered a simple (but very common) use case, but as you can see in the Role definition, we can do much more, for example:

- Create a role to allow a user to use a specific Virtual Mesh
- Create a role to allow a user to use a specific cluster in a Virtual Mesh
- Create a role to allow a user to only define Access Policies
- Create a role to allow a user to only define Traffic Policies
- Create a role to allow a user to only define Failover Services
- Create a role to allow a user to only create policies that target the services running in his namespace (but coming from services in any namespace)

Let's delete the TrafficPolicy we've created in the previous lab:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete trafficpolicy simple
```

We also need to grant the admin role back to the current user:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete rolebindings.rbac.enterprise.mesh.gloo.solo.io default-namespace-admin-role-binding

cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: rbac.enterprise.mesh.gloo.solo.io/v1
kind: RoleBinding
metadata:
  labels:
    app: gloo-mesh
  name: admin-role-binding
  namespace: gloo-mesh
spec:
  roleRef:
    name: admin-role
    namespace: gloo-mesh
  subjects:
    - kind: User
      name: system:serviceaccount:kube-system:eks-admin
EOF
```



## Lab 14 - Deploy Keycloak <a name="Lab-14"></a>

In many use cases, you need to restrict the access to your applications to authenticated users. 

OIDC (OpenID Connect) is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal, if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

Let's install Keycloak:

```bash
kubectl --context ${CLUSTER1} create namespace keycloak

kubectl --context ${CLUSTER1} -n keycloak apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  labels:
    app: keycloak
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  selector:
    app: keycloak
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  labels:
    app: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:12.0.4
        env:
        - name: KEYCLOAK_USER
          value: "admin"
        - name: KEYCLOAK_PASSWORD
          value: "admin"
        - name: PROXY_ADDRESS_FORWARDING
          value: "true"
        ports:
        - name: http
          containerPort: 8080
        - name: https
          containerPort: 8443
        readinessProbe:
          httpGet:
            path: /auth/realms/master
            port: 8080
EOF

kubectl --context ${CLUSTER1} -n keycloak rollout status deploy/keycloak
```

<!--bash
sleep 30
-->


<!--bash
fqdn=$(kubectl --context ${CLUSTER1} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].*}')
until nslookup ${fqdn} 1>/dev/null; do
  printf "%s" "."
  sleep 1
done
-->


Then, we will configure it and create two users:

- User1 credentials: `user1/password`
  Email: user1@solo.io

- User2 credentials: `user2/password`
  Email: user2@example.com

```bash
# Get Keycloak URL and token
KEYCLOAK_URL=http://$(kubectl --context ${CLUSTER1} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].*}'):8080/auth
KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)

# Create initial token to register the client
read -r client token <<<$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' $KEYCLOAK_URL/admin/realms/master/clients-initial-access | jq -r '[.id, .token] | @tsv')

# Register the client
read -r id secret <<<$(curl -X POST -d "{ \"clientId\": \"${client}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${token}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default| jq -r '[.id, .secret] | @tsv')

# Add allowed redirect URIs
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"serviceAccountsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["'https://${SVC_GW_CLUSTER1}'/callback"]}' $KEYCLOAK_URL/admin/realms/master/clients/${id}

# Add the group attribute in the JWT token returned by Keycloak
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models

# Create first user
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@solo.io", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users

# Create second user
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user2", "email": "user2@example.com", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users
```

> **Note:** If you get a *Not Authorized* error, please, re-run this command and continue from the command started to fail:

```
KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```



## Lab 15 - Expose the productpage through a gateway <a name="Lab-15"></a>


In this step, we're going to expose the `productpage` through a Gateway using Gloo Mesh.

First of all, let's delete the Istio `VirtualService` and `Gateway` objects we've created when we deployed the `bookinfo` application:

```bash
kubectl --context ${CLUSTER1} delete -f https://raw.githubusercontent.com/istio/istio/1.10.3/samples/bookinfo/networking/bookinfo-gateway.yaml
kubectl --context ${CLUSTER2} delete -f https://raw.githubusercontent.com/istio/istio/1.10.3/samples/bookinfo/networking/bookinfo-gateway.yaml
```

Then, we need to create a Gloo Mesh `VirtualGateway`.

A VirtualGateway resource will define the Envoy listeners, i.e. the protocols and ports to listen on. It will also define which Envoy filters are attached, by allowing users to specify a FilterChain (or multiple FilterChains). It attaches to existing ingress gateway workloads via a workload selector, and specifies one or more VirtualHost configurations to configure routing rules. A single VirtualGateway can apply to multiple ingress gateway deployments across all meshes and clusters contained within a VirtualMesh.

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: VirtualGateway
metadata:
  name: bookinfo-virtualgateway
  namespace: gloo-mesh
spec:
  connectionHandlers:
  - http:
      routeConfig:
      - virtualHostSelector:
          namespaces:
          - "gloo-mesh"
  ingressGatewaySelectors:
  - portName: http2
    destinationSelectors:
    - kubeServiceMatcher:
        clusters:
        - cluster1
        labels:
          istio: ingressgateway
        namespaces:
        - istio-system
EOF
```

After that, we need to create a Gloo Mesh `VirtualHost`.

VirtualHosts are selected by a VirtualGateway. A single VirtualHost can be selected by multiple VirtualGateways. VirtualHosts are responsible for configuring top level settings, such as domains. In addition, a VirtualHost can set route options that apply to all child routes, which will be inherited as a default unless explicitly overridden at the route level. A VirtualHost contains a list of Routes, which can contain various matchers and actions.

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: VirtualHost
metadata:
  name: bookinfo-virtualhost
  namespace: gloo-mesh
spec:
  domains:
  - '*'
  routes:
  - matchers:
    - uri:
        prefix: /
    delegateAction:
      selector:
        namespaces:
        - "gloo-mesh"
EOF
```

Finally, we need to create a Gloo Mesh `RouteTable`.

A RouteTable is effectively a list of Routes. It exists only to be delegated to from VirtualHosts, or other RouteTables. This allows users to separate configuration and ownership across the organization. For example an app-level team may want to configure all of the low-level endpoints that are sent to their service, but may not have control over which domains they can serve traffic on, or what the authorization policies are. Routes configured in RouteTables will by default inherit any options configured by their parent delegating resource (RouteTable or VirtualHost), for example, timeout or retry settings.

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```

You can check that you can still access the `productpage` application through the browser.

Now, let's secure the access through TLS.

Let's first create a private key and a self-signed certificate to use in your Virtual Service:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

Then, you have to store them in a Kubernetes secret running the following command:

```bash
kubectl --context ${CLUSTER1} -n istio-system create secret generic tls-secret \
--from-file=tls.key=tls.key \
--from-file=tls.crt=tls.crt
```

Finally, you need to update the `VirtualGateway` to use this secret:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: VirtualGateway
metadata:
  name: bookinfo-virtualgateway
  namespace: gloo-mesh
spec:
  connectionHandlers:
# ---------------- SSL config ---------------------------
  - connectionOptions:
      sslConfig:
        secretName: tls-secret
        tlsMode: SIMPLE
# -------------------------------------------------------  
    http:
      routeConfig:
      - virtualHostSelector:
          namespaces:
          - "gloo-mesh"
  ingressGatewaySelectors:
# ---------------- SSL config ---------------------------
  - portName: https
# ------------------------------------------------------- 
    destinationSelectors:
    - kubeServiceMatcher:
        clusters:
        - cluster1
        labels:
          istio: ingressgateway
        namespaces:
        - istio-system
EOF
```


The Load Balancer created on AWS for the Service Type Load Balancer corresponding to the Istio Ingress Gateway has a health check port configured to use the HTTP port.

The Gloo Mesh Gateway is now configuring the Istio Ingress Gateway to listen on HTTPS, so we need to patch the Kubernetes Service as follow.

```bash
cat << EOF > svc-patch.yaml
spec:
  ports:
  - port: 80
    targetPort: 8443
EOF

kubectl --context ${CLUSTER1} patch -n istio-system svc istio-ingressgateway -p "$(cat svc-patch.yaml)"
```


Get the URL to securely access the `productpage` service from your web browser using the following command:

```
echo "https://${SVC_GW_CLUSTER1}/productpage"
```



## Lab 16 - Multi-cluster Traffic with Gateway <a name="Lab-16"></a>

On the first cluster, the `v3` version of the `reviews` microservice doesn't exist, so we're going to redirect some of the traffic to the second cluster to make it available.

Let's create the following TrafficPolicy:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: TrafficPolicy
metadata:
  namespace: gloo-mesh
  name: simple
spec:
  sourceSelector:
  - kubeWorkloadMatcher:
      namespaces:
      - default
  destinationSelector:
  - kubeServiceRefs:
      services:
        - clusterName: cluster1
          name: reviews
          namespace: default
  routeSelector:
  - virtualHostSelector:
     namespaces:
     - "gloo-mesh"
  - routeTableSelector:
     namespaces:
     - "gloo-mesh"
  policy:
    trafficShift:
      destinations:
        - kubeService:
            clusterName: cluster2
            name: reviews
            namespace: default
            subset:
              version: v3
          weight: 75
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v1
          weight: 15
        - kubeService:
            clusterName: cluster1
            name: reviews
            namespace: default
            subset:
              version: v2
          weight: 10
EOF
```

Then, we need to update the `RouteTable` to expose the `reviews` service through the Gateway:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
# ---------------- Expose reviews -----------------------
  - matchers:
    - uri:
        prefix: /reviews
    name: reviews
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: reviews
          namespace: default
# -------------------------------------------------------  
EOF
```

After that, we need to update the `AccessPolicy` to allow the Ingress Gateway to communicate with the `reviews` service.

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: istio-ingressgateway
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: istio-ingressgateway-service-account
          namespace: istio-system
          clusterName: cluster1
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: productpage
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: reviews
EOF
```


<!--bash
log_header "Test :: Should get reviews v3 from cluster2"
is_red_star_visible=false
printf "\nWait for condition"
while true
do
  curl -k -s "https://${SVC_GW_CLUSTER1}/reviews/0" | grep '"color": "red"' &>/dev/null
  if [ $? == 0 ]; then
    is_red_star_visible=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Got reviews v3 from cluster2"
-->

Now, run the following command several times.

```
curl -k https://$SVC_GW_CLUSTER1/reviews/0
```

You should get responses from `v3` 75% of the time:

```
{"id": "0","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!", "rating": {"stars": 5, "color": "red"}},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare.", "rating": {"stars": 4, "color": "red"}}]}
```

Let's delete the TrafficPolicy:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete trafficpolicy simple
```

Let's apply the original `RouteTable` yaml:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```



## Lab 17 - Traffic failover with Gateway <a name="Lab-17"></a>

In this lab, we're going to configure a failover for the `reviews` service:

Let's create a VirtualDestination to define a new hostname (`reviews-global.default.global`) that will be backed by the `reviews` microservice runnings on both clusters. 

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: VirtualDestination
metadata:
  name: reviews-global
  namespace: gloo-mesh
spec:
  hostname: reviews.global
  port:
    number: 9080
    protocol: http
  localized:
    outlierDetection:
      consecutiveErrors: 1
      maxEjectionPercent: 100
      interval: 5s
      baseEjectionTime: 120s
    destinationSelectors:
    - kubeServiceMatcher:
        labels:
          app: reviews
  virtualMesh:
    name: virtual-mesh
    namespace: gloo-mesh
EOF
```

Then, we need to update the `RouteTable` to expose the `VirtualDestination` through the Gateway:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
# ---------------- Expose reviews -----------------------
  - matchers:
    - uri:
        prefix: /reviews
    name: reviews
    routeAction:
      destinations:
      - virtualDestination:
          name: reviews-global
          namespace: gloo-mesh
# -------------------------------------------------------  
EOF
```

After that, we need to update the `AccessPolicy` to allow the Ingress Gateway to communicate with the `reviews` service.

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
apiVersion: networking.mesh.gloo.solo.io/v1
kind: AccessPolicy
metadata:
  namespace: gloo-mesh
  name: istio-ingressgateway
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: istio-ingressgateway-service-account
          namespace: istio-system
          clusterName: cluster1
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: productpage
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: reviews
EOF
```
Now, run the following command several times.

```
curl -k https://$SVC_GW_CLUSTER1/reviews/0
```

You should get responses from either `v1`:

```
{"id": "0","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!"},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare."}]}
```

Or `v2`:

```
{"id": "0","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!", "rating": {"stars": 5, "color": "black"}},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare.", "rating": {"stars": 4, "color": "black"}}]}```

We're going to make the `reviews` services unavailable on the first cluster.

```bash
kubectl --context ${CLUSTER1} patch deploy reviews-v1 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'
kubectl --context ${CLUSTER1} patch deploy reviews-v2 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'
```


<!--bash
log_header "Test :: Should get reviews v3 from cluster2"
is_red_star_visible=false
printf "\nWait for condition"
while true
do
  curl -k -s "https://${SVC_GW_CLUSTER1}/reviews/0" | grep '"color": "red"' &>/dev/null
  if [ $? == 0 ]; then
    is_red_star_visible=true
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Got reviews v3 from cluster2"
-->

If you run the curl command again several times again, you should start to see responses from `v3`:

```
{"id": "0","reviews": [{  "reviewer": "Reviewer1",  "text": "An extremely entertaining play by Shakespeare. The slapstick humour is refreshing!", "rating": {"stars": 5, "color": "red"}},{  "reviewer": "Reviewer2",  "text": "Absolutely fun and entertaining. The play lacks thematic depth when compared to other plays by Shakespeare.", "rating": {"stars": 4, "color": "red"}}]}
```

We're going to make the `reviews` services available again on the first cluster.

```bash
kubectl --context ${CLUSTER1} patch deployment reviews-v1  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
kubectl --context ${CLUSTER1} patch deployment reviews-v2  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
```

Afer 2 minutes, you can check that the curl command only returns responses from `v1` and `v2`/

Let's delete the VirtualDestination and the TrafficPolicy:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete virtualdestination reviews-global
```

Let's apply the original `RouteTable` yaml:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```



## Lab 18 - Apply rate limiting to the Gateway <a name="Lab-18"></a>


In this step, we're going to apply rate limiting to the Gateway.

First, we need to create a `RateLimitServerConfig` object:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RateLimitServerConfig
metadata:
  labels:
    app: bookinfo-policies
    app.kubernetes.io/name: bookinfo-policies
  name: rl-config
  namespace: gloo-mesh
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: type
            value: a
          - key: number
            value: one
        rateLimit:
          requestsPerUnit: 1
          unit: MINUTE
EOF
```

Finally, you need to update the `RouteTable` to use this `AuthConfig`:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
# ---------------- rate limiting config -----------------
    options:
      rateLimit:
        raw:
          rateLimits:
          - setActions:
            - requestHeaders:
                descriptorKey: number
                headerName: x-number
            - requestHeaders:
                descriptorKey: type
                headerName: x-type
        ratelimitServerConfigSelector:
          namespaces:
          - gloo-mesh
# -------------------------------------------------------  
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```

Now, run the following command several times.

```
curl -k https://$SVC_GW_CLUSTER1/productpage -I -H "x-type: a" -H "x-number: one"
```


<!--bash
log_header "Test :: Access should be rate limited"

printf "\nWaiting for error code 429"
while true
do
  status_code=$(curl -k -s -o /dev/null -w "%{http_code}" "https://${SVC_GW_CLUSTER1}/productpage" -H "x-type: a" -H "x-number: one")
  expected_code=429
  if [ "$status_code" == "$expected_code" ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
result_message="Got the expected status code $expected_code"
log_success "$result_message"
-->

You should get a `200` response code the first time and a `429` response code after.

Let's apply the original `RouteTable` yaml:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```



## Lab 19 - Securing the access with OAuth <a name="Lab-19"></a>


In this step, we're going to secure the access to the `productpage` using OAuth.

First, we need to create a Kubernetes Secret that contains the OIDC secret:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-mesh
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${secret} | base64)
EOF
```

Then, you will create an AuthConfig, which is a CRD that contains authentication information: 

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: gloo-mesh
spec:
  configs:
  - oauth2:
      oidcAuthorizationCode:
        appUrl: https://${SVC_GW_CLUSTER1}
        callbackPath: /callback
        clientId: ${client}
        clientSecretRef:
          name: oauth
          namespace: gloo-mesh
        issuerUrl: "${KEYCLOAK_URL}/realms/master/"
        scopes:
        - email
        headers:
          idTokenHeader: jwt
EOF
```

Finally, you need to update the `RouteTable` to use this `AuthConfig`:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
# ---------------- Oauth config -------------------------
    - uri:
        prefix: /callback
# -------------------------------------------------------  
    name: productpage
# ---------------- Oauth config -------------------------
    options:
      extauth:
        configRef:
          name: oauth
          namespace: gloo-mesh
# -------------------------------------------------------  
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```


<!--bash
log_header "Test :: Verify Authentication"

printf "\nWaiting until bookinfo returns 302 redirecting to Auth server"
while true
do
  http_status=$(curl -k -o /dev/null -s -w "%{http_code}\n" "https://${SVC_GW_CLUSTER1}/productpage")
  condition=$?
  if [ "$http_status" == "302" ]; then
    break
  fi
  printf "%s" "."
  sleep 1
done
printf "\n"
log_success "Bookinfo access requires Authentication"
-->

If you refresh the web browser, you will be redirected to the authentication page.

```
/opt/google/chrome/chrome https://$SVC_GW_CLUSTER1/productpage 
```

If you use the username `user1` and the password `password` Gloo should redirect you back to the `productpage` application.

You can also perform authorization using OPA.

First, you need to create a `ConfigMap` with the policy written in rego:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: v1
data:
  policy.rego: |-
    package test

    default allow = false

    allow {
        [header, payload, signature] = io.jwt.decode(input.state.jwt)
        endswith(payload["email"], "@solo.io")
    }

kind: ConfigMap
metadata:
  name: allow-solo-email-users
  namespace: gloo-mesh
EOF
```

Then, you need to update the `AuthConfig` object to add the authorization step:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: gloo-mesh
spec:
  configs:
  - oauth2:
      oidcAuthorizationCode:
        appUrl: https://${SVC_GW_CLUSTER1}
        callbackPath: /callback
        clientId: ${client}
        clientSecretRef:
          name: oauth
          namespace: gloo-mesh
        issuerUrl: "${KEYCLOAK_URL}/realms/master/"
        scopes:
        - email
        headers:
          idTokenHeader: jwt
  - opaAuth:
      modules:
      - name: allow-solo-email-users
        namespace: gloo-mesh
      query: "data.test.allow == true"
EOF
```

Let's try again in incognito window using the second user's credentials:

```
/opt/google/chrome/chrome --incognito $(glooctl proxy url --port https)/productpage
```

If you open the browser in incognito and login using the username `user2` and the password `password`, you will not be able to access since the user's email ends with `@example.com`.

Let's apply the original `RouteTable` yaml:

```bash
kubectl --context ${MGMT} apply -f - <<EOF
apiVersion: networking.enterprise.mesh.gloo.solo.io/v1beta1
kind: RouteTable
metadata:
  name: bookinfo-routetable
  namespace: gloo-mesh
spec:
  routes:
  - matchers:
    - uri:
        exact: /productpage
    - uri:
        prefix: /static
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    name: productpage
    routeAction:
      destinations:
      - kubeService:
          clusterName: cluster1
          name: productpage
          namespace: default
EOF
```


