
<!--bash
source ./scripts/assert.sh
-->



<center><img src="images/gloo-mesh.png" alt="Gloo Mesh Enterprise" style="width:70%;max-width:800px" /></center>

# <center>Gloo Mesh Core (2.6.5) Ambient Interoperability</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy a KinD cluster](#lab-1---deploy-a-kind-cluster-)
* [Lab 2 - Deploy and register Gloo Mesh](#lab-2---deploy-and-register-gloo-mesh-)
* [Lab 3 - Deploy Istio using Gloo Mesh Lifecycle Manager](#lab-3---deploy-istio-using-gloo-mesh-lifecycle-manager-)
* [Lab 4 - Deploy the Bookinfo demo app](#lab-4---deploy-the-bookinfo-demo-app-)
* [Lab 5 - Deploy the clients to make requests to other services](#lab-5---deploy-the-clients-to-make-requests-to-other-services-)
* [Lab 6 - Ambient L4 interoperability](#lab-6---ambient-l4-interoperability-)
* [Lab 7 - Ambient L7 interoperability](#lab-7---ambient-l7-interoperability-)
* [Lab 8 - Ambient L7 Routing interoperability](#lab-8---ambient-l7-routing-interoperability-)
* [Lab 9 - Ambient L7 Transforming traffic interoperability](#lab-9---ambient-l7-transforming-traffic-interoperability-)
* [Lab 10 - Ambient L7 Traffic shifting interoperability](#lab-10---ambient-l7-traffic-shifting-interoperability-)
* [Lab 11 - Ambient L7 Traffic resiliency interoperability](#lab-11---ambient-l7-traffic-resiliency-interoperability-)



## Introduction <a name="introduction"></a>

[Gloo Mesh Core](https://www.solo.io/products/gloo-mesh/) is a management plane that makes it easy to operate [Istio](https://istio.io) and adds additional features to Ambient.

Gloo Mesh Core works with community [Istio](https://istio.io/) out of the box.
You get instant insights into your Istio environment through a custom dashboard.
Observability pipelines let you analyze many data sources that you already have.
You can even automate installing and upgrading Istio with the Gloo lifecycle manager, on one or many Kubernetes clusters deployed anywhere.

But Gloo Mesh Core includes more than tooling to complement an existing Istio installation.
You can also replace community Istio with Solo's hardened Istio images. These images unlock enterprise-level support.
Later, you might choose to upgrade seamlessly to Gloo Mesh Enterprise for a full-stack service mesh and API gateway solution.
This approach lets you scale as you need more advanced routing and security features.

### Istio and Ambient support

The Gloo Mesh Core subscription includes end-to-end Istio support:

* Upstream feature development
* CI/CD-ready automated installation and upgrade
* End-to-end Istio support and CVE security patching
* Long-term n-4 version support with Solo images
* Special image builds for distroless and FIPS compliance
* 24x7 production support and one-hour Severity 1 SLA
* Ambient support for Istio
* L7 Telemetry support in Ztunnel

### Gloo Mesh Core overview

Gloo Mesh Core provides many unique features, including:

* Single pane of glass for operational management of Istio, including global observability
* Insights based on environment checks with corrective actions and best practices
* [Cilium](https://cilium.io/) support
* Seamless migration to full-stack service mesh

### Want to learn more about Gloo Mesh Core?

You can find more information about Gloo Mesh Core in the official documentation: <https://docs.solo.io/gloo-mesh-core>




## Lab 1 - Deploy a KinD cluster <a name="lab-1---deploy-a-kind-cluster-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variables:

```bash
export MGMT=cluster1
export CLUSTER1=cluster1
```

Run the following commands to deploy a Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):

```bash
./scripts/deploy-multi-with-calico.sh 1 cluster1 us-west us-west-1
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

**Note:** The CNI pods might be different, depending on which CNI you have deployed.

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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-kind-cluster/tests/cluster-healthy.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->




## Lab 2 - Deploy and register Gloo Mesh <a name="lab-2---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


Before we get started, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.6.5
curl -sL https://run.solo.io/meshctl/install | sh -
export PATH=$HOME/.gloo-mesh/bin:$PATH
```
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
    expect(process.env.MGMT).not.to.be.empty
    expect(process.env.CLUSTER1).not.to.be.empty
  });

  it("Gloo Mesh licence environment variables should not be empty", () => {
    expect(process.env.GLOO_MESH_LICENSE_KEY).not.to.be.empty
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->
Run the following commands to deploy the Gloo Mesh management plane:

```bash
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --set featureGates.insightsConfiguration=true \
  --version 2.6.5

helm upgrade --install gloo-platform-mgmt gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.6.5 \
  -f -<<EOF
licensing:
  glooTrialLicenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: cluster1
experimental:
  ambientEnabled: true
glooInsightsEngine:
  enabled: true
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
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: gloo-telemetry-gateway:4317
glooAgent:
  enabled: true
  relay:
    serverAddress: gloo-mesh-mgmt-server:9900
    authority: gloo-mesh-mgmt-server.gloo-mesh
featureGates:
  istioLifecycleAgent: true
EOF

kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->



## Lab 3 - Deploy Istio using Gloo Mesh Lifecycle Manager <a name="lab-3---deploy-istio-using-gloo-mesh-lifecycle-manager-"></a>
[<img src="https://img.youtube.com/vi/f76-KOEjqHs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/f76-KOEjqHs "Video Link")

We are going to deploy Istio using Gloo Mesh Lifecycle Manager.

<details>
  <summary>Install <code>istioctl</code></summary>

Install `istioctl` if not already installed as it will be useful in some of the labs that follow.

```bash
curl -L https://istio.io/downloadIstio | sh -

if [ -d "istio-"*/ ]; then
  cd istio-*/
  export PATH=$PWD/bin:$PATH
  cd ..
fi
```

That's it!
</details>

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
describe("istio_version is at least 1.23.0", () => {
  it("version should be at least 1.23.0", () => {
    // Compare the string istio_version to the number 1.23.0
    // example 1.23.0-patch0 is valid, but 1.22.6 is not
    let version = "1.23.1";
    let versionParts = version.split('-')[0].split('.');
    let major = parseInt(versionParts[0]);
    let minor = parseInt(versionParts[1]);
    let patch = parseInt(versionParts[2]);
    let minMajor = 1;
    let minMinor = 23;
    let minPatch = 0;
    expect(major).to.be.at.least(minMajor);
    if (major === minMajor) {
      expect(minor).to.be.at.least(minMinor);
      if (minor === minMinor) {
        expect(patch).to.be.at.least(minPatch);
      }
    }
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/istio-lifecycle-manager-install/tests/istio-version.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->

Let's create Kubernetes services for the gateways:

```bash
kubectl --context ${CLUSTER1} create ns istio-gateways

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: ingressgateway
  name: istio-ingressgateway
  namespace: istio-gateways
spec:
  ports:
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  type: LoadBalancer
EOF
```

It allows us to have full control on which Istio revision we want to use.

Then, we can tell Gloo Mesh to deploy the Istio control planes and the gateways in the cluster(s).

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: cluster1-installation
  namespace: gloo-mesh
spec:
  helmGlobal:
    repo: oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>
  installations:
    - clusters:
      - name: cluster1
      istioOperatorSpec:
        profile: ambient
        hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
        tag: 1.23.1-solo
        namespace: istio-system
        values:
          cni:
            ambient:
              dnsCapture: true
            excludeNamespaces:
            - istio-system
            - kube-system
            logLevel: info
          ztunnel:
            terminationGracePeriodSeconds: 29
            variant: distroless
            env:
              L7_ENABLED: "true"
        meshConfig:
          accessLogFile: /dev/stdout
          defaultConfig:
            proxyMetadata:
              ISTIO_META_DNS_CAPTURE: "true"
              ISTIO_META_DNS_AUTO_ALLOCATE: "true"
        components:
          pilot:
            k8s:
              env:
                - name: PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES
                  value: "false"
                - name: PILOT_ENABLE_IP_AUTOALLOCATE
                  value: "true"
          cni:
            enabled: true
            namespace: kube-system
          ingressGateways:
          - name: istio-ingressgateway
            enabled: false
EOF

kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: cluster1-ingress
  namespace: gloo-mesh
spec:
  helmGlobal:
    repo: oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>
  installations:
    - clusters:
      - name: cluster1
        activeGateway: false
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
        tag: 1.23.1-solo
        values:
          gateways:
            istio-ingressgateway:
              customService: true
        components:
          ingressGateways:
            - name: istio-ingressgateway
              namespace: istio-gateways
              enabled: true
              label:
                istio: ingressgateway
EOF

```

<!--bash
until kubectl --context ${MGMT} -n gloo-mesh wait --timeout=180s --for=jsonpath='{.status.clusters.cluster1.installations.*.state}'=HEALTHY istiolifecyclemanagers/cluster1-installation; do
  echo "Waiting for the Istio installation to complete"
  sleep 1
done
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-system get deploy -o json | jq '[.items[].status.readyReplicas] | add') -ge 1 ]]; do
  sleep 1
done"
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 ]]; do
  sleep 1
done"
-->

<!--bash
cat <<'EOF' > ./test.js

const helpers = require('./tests/chai-exec');

const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
const chai = require("chai");
const expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("Checking Istio installation", function() {
  it('istiod pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-system", labels: "app=istiod", instances: 1 }));
  it('gateway pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-gateways", labels: "app=istio-ingressgateway", instances: 1 }));
  it("Gateways have an ip attached in cluster " + process.env.CLUSTER1, () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get svc -l app=istio-ingressgateway -o jsonpath='{.items}'");
    cli.stderr.should.be.empty;
    let deployments = JSON.parse(cli.stdout.slice(1,-1));
    expect(deployments).to.have.lengthOf(1);
    deployments.forEach((deployment) => {
      expect(deployment.status.loadBalancer).to.have.property("ingress");
    });
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/istio-lifecycle-manager-install/tests/istio-ready.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->
<!--bash
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o json | jq '.items[0].status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

```bash
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
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

describe("Address '" + process.env.HOST_GW_CLUSTER1 + "' can be resolved in DNS", () => {
    it(process.env.HOST_GW_CLUSTER1 + ' can be resolved', (done) => {
        return dns.lookup(process.env.HOST_GW_CLUSTER1, (err, address, family) => {
            expect(address).to.be.an.ip;
            done();
        });
    });
});
EOF
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->
The Gateway APIs do not come installed by default on most Kubernetes clusters. Install the Gateway API CRDs if they are not present:

```bash
kubectl --context ${CLUSTER1} get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl --context ${CLUSTER1} apply -f -; }
```



## Lab 4 - Deploy the Bookinfo demo app <a name="lab-4---deploy-the-bookinfo-demo-app-"></a>
[<img src="https://img.youtube.com/vi/nzYcrjalY5A/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/nzYcrjalY5A "Video Link")

We're going to deploy the bookinfo application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](https://istio.io/latest/docs/examples/bookinfo/).

Run the following commands to deploy the bookinfo application on `cluster1`:

```bash
kubectl --context ${CLUSTER1} create ns bookinfo-frontends
kubectl --context ${CLUSTER1} create ns bookinfo-backends
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio-injection=enabled
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=enabled

# Deploy the frontend bookinfo service in the bookinfo-frontends namespace
kubectl --context ${CLUSTER1} -n bookinfo-frontends apply -f data/steps/deploy-bookinfo/productpage-v1.yaml

# Deploy the backend bookinfo services in the bookinfo-backends namespace for all versions less than v3
kubectl --context ${CLUSTER1} -n bookinfo-backends apply \
  -f data/steps/deploy-bookinfo/details-v1.yaml \
  -f data/steps/deploy-bookinfo/ratings-v1.yaml \
  -f data/steps/deploy-bookinfo/reviews-v1-v2.yaml

# Update the reviews service to display where it is coming from
kubectl --context ${CLUSTER1} -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=${CLUSTER1}
kubectl --context ${CLUSTER1} -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=${CLUSTER1}
```

<!--bash
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 4 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->

You can check that the app is running using the following command:

```shell
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->



## Lab 5 - Deploy the clients to make requests to other services <a name="lab-5---deploy-the-clients-to-make-requests-to-other-services-"></a>

We're going to deploy services that we'll use as clients to demonstrate several features of Gloo Mesh.

Run the following commands to deploy the client on `cluster1`. The deployment will be called `not-in-mesh` and won't have the sidecar injected, because of the annotation `sidecar.istio.io/inject: "false"` and its traffic won't be redirected to ztunnel because of the annotation `istio.io/dataplane-mode: none`.

```bash
kubectl --context ${CLUSTER1} create ns clients

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: not-in-mesh
  namespace: clients
---
apiVersion: v1
kind: Service
metadata:
  name: not-in-mesh
  namespace: clients
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
  namespace: clients
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
        istio.io/dataplane-mode: none
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
```
Then, we deploy a second version, which will be called `in-mesh-with-sidecar` and will have the sidecar injected (because of the label `istio-injection` in the Pod template)

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-mesh-with-sidecar
  namespace: clients
---
apiVersion: v1
kind: Service
metadata:
  name: in-mesh-with-sidecar
  namespace: clients
  labels:
    app: in-mesh-with-sidecar
    service: in-mesh-with-sidecar
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-mesh-with-sidecar
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-mesh-with-sidecar
  namespace: clients
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-mesh-with-sidecar
      version: v1
  template:
    metadata:
      labels:
        app: in-mesh-with-sidecar
        version: v1
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: in-mesh-with-sidecar
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
```

<!--bash
echo -n Waiting for clients to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n clients get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->
Add another client service which is deployed in Ambient.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-ambient
  namespace: clients
---
apiVersion: v1
kind: Service
metadata:
  name: in-ambient
  namespace: clients
  labels:
    app: in-ambient
    service: in-ambient
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-ambient
  namespace: clients
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-ambient
      version: v1
  template:
    metadata:
      labels:
        app: in-ambient
        version: v1
        istio.io/dataplane-mode: ambient
        sidecar.istio.io/inject: "false"
        istio-injection: disabled
    spec:
      serviceAccountName: in-ambient
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
```
You can follow the progress using the following command:

```bash
kubectl --context ${CLUSTER1} -n clients get pods
```

```,nocopy
NAME                           READY   STATUS    RESTARTS   AGE
in-ambient-5c64bb49cd-w3dmw    1/1     Running   0          4s
in-mesh-5d9d9549b5-qrdgd       2/2     Running   0          11s
not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("client apps", () => {
  let cluster = process.env.CLUSTER1
  
  let deployments = ["not-in-mesh", "in-mesh-with-sidecar", "in-ambient"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "clients", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/clients/deploy-clients/tests/check-clients.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->



## Lab 6 - Ambient L4 interoperability <a name="lab-6---ambient-l4-interoperability-"></a>

In this lab, we'll explore how services in different mesh configurations interact with each other at Layer 4 (L4). We'll start by testing communication to services that are in the mesh with sidecars, then migrate those to use Ambient.

Let's begin by testing the communication from different workloads to the `reviews` service in the `bookinfo-backends` namespace:

```bash
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
```

You'll notice that all requests succeed with a 200 status code. This is because, by default, Istio allows unauthenticated traffic to services in the mesh.

To enhance security, we can enforce mutual TLS (mTLS) authentication using a `PeerAuthentication` policy. Let's apply this policy to the `bookinfo-backends` namespace:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: bookinfo-backends
spec:
  mtls:
    mode: STRICT
EOF
```

This policy sets the mTLS mode to STRICT, meaning only authenticated requests will be allowed.
Now, let's run our test again:

```bash
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
```

This time, you'll see that the request from the `not-in-mesh` workload fails, while requests from `in-mesh-with-sidecar` and `in-ambient` workloads succeed. This is because the latter two can present valid mTLS certificates, while the not-in-mesh workload cannot.

Next, let's implement more granular control using an `AuthorizationPolicy`. We'll start by denying all traffic by default:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: bookinfo-backends
spec:
  {}
EOF
```

After applying this policy, all requests will be rejected

```bash
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
```

You'll see that all requests now return a 403 Forbidden status.

To allow specific traffic, we'll create an AuthorizationPolicy that permits requests from the `in-mesh-with-sidecar` and `in-ambient` workloads:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-admit-traffic
  namespace: bookinfo-backends
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/clients/sa/in-mesh-with-sidecar"
        - "cluster1/ns/clients/sa/in-ambient"
EOF
```

> NOTE: Pre-ambient, it was recommended to use `cluster.local` as a pointer to the local trust domain, however, in Ambient, this is not supported. For more details, see the following [issue](https://github.com/istio/ztunnel/issues/1260)

This policy allows traffic from the specified service accounts in the clients namespace.

Let's test our configuration one more time:

```bash
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
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
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("l4 interoperability", function() {
  const cluster = process.env.CLUSTER1

  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];
  for (const workload of workloads) {
    it(`traffic is authenticated from ${workload} to the reviews.bookinfo-backends workload`, () => {
      let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
      let cli = chaiExec(command);
      expect(cli).to.exit.with.code(0);
      expect(cli).output.to.contain('200');
    });
  }

  it(`traffic is not authenticated from not-in-mesh`, () => {
    let command = `kubectl --context ${cluster} -n clients exec deploy/not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
    let cli = chaiExec(command);
    expect(cli).output.to.contain('000');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l4-authn-interoperability/tests/validate-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->

Now, you should see that requests from `in-mesh-with-sidecar` and `in-ambient` workloads succeed with a `200` status code, while the `not-in-mesh` workload's request is still denied.

### Migrate `bookinfo-backends` to Ambient

Now that we've explored L4 interoperability, let's migrate the `bookinfo-backends` services to the Ambient mesh. This will demonstrate how we can transition seamlessly without impacting traffic while maintaining our existing L4 policies.

First, let's move the `bookinfo-backends` namespace to the Ambient mesh:

```bash
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=disabled --overwrite
```
These commands do two things:

1. Set the dataplane mode to 'ambient' for the namespace
2. Disable Istio sidecar injection, as it's not needed in the Ambient mesh

Now, let's restart the deployments in the `bookinfo-backends` namespace to apply these changes:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
```

Confirm that the sidecar is no longer injected in the `bookinfo-backends` workloads by running:

<!--bash
# wait for all pods to be running

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
-->

```bash
kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
```

You should see that the pods now have only one container each, instead of two (which would indicate the presence of a sidecar).

Now, let's validate that all traffic is still working as expected:

```bash
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
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
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("l4 interoperability", function() {
  const cluster = process.env.CLUSTER1

  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];
  for (const workload of workloads) {
    it(`traffic is authenticated from ${workload} to the reviews.bookinfo-backends workload`, () => {
      let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
      let cli = chaiExec(command);
      expect(cli).to.exit.with.code(0);
      expect(cli).output.to.contain('200');
    });
  }

  it(`traffic is not authenticated from not-in-mesh`, () => {
    let command = `kubectl --context ${cluster} -n clients exec deploy/not-in-mesh -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
    let cli = chaiExec(command);
    expect(cli).output.to.contain('000');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l4-authn-interoperability/tests/validate-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->

You should see that the requests from `in-mesh-with-sidecar` and `in-ambient` workloads still succeed with a 200 status code, while the `not-in-mesh` workload's request is still denied. This confirms that our L4 policies are still being enforced, even though the bookinfo-backends services are now in the Ambient mesh.

This validates that:

1. Workloads can migrate to the Ambient mesh without any downtime
2. The migration doesn't require any changes to the existing L4 policies
3. Services in different mesh modes (sidecar and Ambient) can interoperate seamlessly

Reset the `bookinfo-backends` workloads to use Sidecars, for subsequent steps.

```bash
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode-
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=enabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
```

<!--bash
# wait for all pods to be running

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
-->




## Lab 7 - Ambient L7 interoperability <a name="lab-7---ambient-l7-interoperability-"></a>

In this lab, we'll explore Layer 7 (L7) interoperability in the Ambient mesh. L7 policies allow for more granular control based on application-layer information, such as HTTP methods or paths. However, enforcing these policies requires special consideration when migrating to the Ambient mesh.

We'll go through the following steps:

1. Deploy a waypoint proxy for workloads in the `bookinfo-backends` namespace
2. Pre-configure policies for the waypoint to allow traffic
3. Configure workloads to use the waypoint and remove sidecars

### Step 1: Deploy the waypoint proxy

Create a Gateway resource for the workloads in the `bookinfo-backends` namespace:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    allowedRoutes:
      namespaces:
        from: Same
    port: 15008
    protocol: HBONE
EOF
```

This Gateway resource defines a waypoint for the namespace, but it won't have any impact until we configure workloads to use it.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("gateway API", function() {
  let cluster = process.env.CLUSTER1

  it("should create a waypoint deployment and pod ztunnel contains L4 and l7 metrics", () => {
    helpers.checkDeployment({ context: cluster, namespace: "bookinfo-backends", k8sObj: "waypoint" })
    helpers.checkDeploymentHasPod({ context: cluster, namespace: "bookinfo-backends", deployment: "waypoint" })
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/is-waypoint-created.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 1000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
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
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("l7 interoperability", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];

  describe("traffic is authorized", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    }
  })
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->

### Step 2: Pre-configure policies for the waypoint

Now, we'll add policies to allow traffic through the waypoint:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
# Allows all workloads to receive traffic from the waypoint
#
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ns-workloads-admit-waypoint
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-backends/sa/waypoint"
---
# Configure the waypoint to allow traffic from the specified workloads to reviews for GET requests
#
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: "reviews-rbac-waypoint"
  namespace: bookinfo-backends
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/clients/sa/in-mesh-with-sidecar"
        - "cluster1/ns/clients/sa/in-ambient"
    to:
    - operation:
        methods: ["GET"]
---
# Update the policy to use layer 7 feature
# (applied only while reviews has the sidecar injected)
#
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews-admit-traffic
  namespace: bookinfo-backends
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/clients/sa/in-mesh-with-sidecar"
        - "cluster1/ns/clients/sa/in-ambient"
    to:
    - operation:
        methods: ["GET"]  ## Update the policy to use layer 7 feature
EOF
```

These policies do the following:

1. Allow all workloads in the `bookinfo-backends` namespace to receive traffic from the waypoint
2. Configure the waypoint to allow GET requests from specified workloads to the reviews service
3. Update the existing policy to use L7 features (applied only while reviews has a sidecar injected)

> NOTE: The `targetRefs` in the policy `reviews-rbac-waypoint` limits the policy to apply only to traffic to the reviews service, if you want to apply it to all services, you can use Gateway as a target instead:
>
> ```,nocopy
>   targetRefs:
>   - kind: Gateway
>     group: gateway.networking.k8s.io
>     name: waypoint
> ```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("l7 interoperability", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];

  describe("traffic is authorized", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    }
  })
  describe("traffic is prohibited", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0" -X POST`;
        let cli = chaiExec(command);
        expect(cli).output.to.contain('403');
      });
    }
  })
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->


### Step 3: Configure workloads to use the waypoint and remove sidecars

Now we're ready to configure the workloads in the namespace to use the waypoint:

```bash
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint=waypoint
```

At this point, traffic is going through the waypoint to the reviews service, which still has a sidecar injected. Let's test the communication:

```bash
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
```
<!--bash
sleep 20
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
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("l7 interoperability", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];

  describe("traffic is authorized", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    }
  })
  describe("traffic is prohibited", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0" -X POST`;
        let cli = chaiExec(command);
        expect(cli).output.to.contain('403');
      });
    }
  })
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->


You should see that the traffic is still working. However, this setup incurs a performance penalty as the traffic goes through both the waypoint and the sidecar. To optimize this, we can migrate the reviews service to the Ambient mesh:

```bash
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=disabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
```
<!--bash
# wait for all pods to be ready

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
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
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("l7 interoperability", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];

  describe("traffic is authorized", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    }
  })
  describe("traffic is prohibited", function() {
    for (const workload of workloads) {
      it(`from ${workload} to the reviews.bookinfo-backends workload`, () => {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0" -X POST`;
        let cli = chaiExec(command);
        expect(cli).output.to.contain('403');
      });
    }
  })
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->


After this migration, run the test again, and you should see that the traffic still flows and policies are enforced, but now without the additional sidecar.

> NOTE: In open source Istio, if the target is in Ambient using a waypoint and a L7 policy is applied to it, it will be bypassed because sidecars (and Ingress Gateway) will NOT utilize the waypoint proxy.
> In Gloo, we have added sidecar and ingress interop support for waypoints.

After migrating all workloads to ambient, we can remove the policy `reviews-admit-traffic` as it was useful only while applied to reviews with a sidecar injected.

Finally, we can remove the policy that was only needed while the reviews service had a sidecar:

```bash
kubectl --context ${CLUSTER1} delete authorizationpolicy reviews-admit-traffic -n bookinfo-backends
```

This lab demonstrates how to migrate services to the Ambient mesh while maintaining L7 policy enforcement. It requires setting policies to permit traffic through a waypoint but as well directly from the services with sidecars.

Reset the `bookinfo-backends` workloads to use Sidecars, for subsequent steps.

```bash
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode-
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=enabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint-
kubectl --context ${CLUSTER1} delete gateway waypoint -n bookinfo-backends
kubectl --context ${CLUSTER1} delete authorizationpolicies -A --all
kubectl --context ${CLUSTER1} delete peerauthentications -A --all
```

<!--bash
# wait for all pods to be running

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
-->



## Lab 8 - Ambient L7 Routing interoperability <a name="lab-8---ambient-l7-routing-interoperability-"></a>

In this lab, we'll explore how Layer 7 (L7) routing rules interact with services in different mesh modes. We'll configure routing rules for traffic directed to the `reviews` service and observe how they apply to workloads with sidecars and those in Ambient mode.

We'll use the common use-case where you want to release a service to a subset of users, such as beta testers. We'll configure the `reviews` service to route traffic based on a custom header, `beta-tester`, and observe how this affects workloads in the Ambient mesh.

First, let's create subsets for our service versions:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF
```

Next, we can use those subsets to configure the routing rules:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: clients
spec:
  hosts:
  - reviews.bookinfo-backends.svc.cluster.local
  http:
  - match:
    - headers:
        beta-tester:
          exact: "true"
    route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        subset: v2
  - route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        subset: v1
EOF
```

Generate traffic with the beta user from both types of workloads. You'll find out that traffic from `in-mesh-with-sidecar` workload is routed to v2, in other words the routing rule is enforced. Meanwhile, traffic from the `in-ambient` workload is routed to both versions:

```shell
for workload in in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"

  kubectl --context ${CLUSTER1} -n clients exec deploy/${workload} -- bash -c "
  for i in {1..10}; do
    curl -s 'http://reviews.bookinfo-backends:9080/reviews/0' -H 'beta-tester: true' | jq .podname
  done"
  echo
done
```

This is because the sidecar within `in-mesh-with-sidecar` can inspect the custom header and enforce the routing rule, while the workload in Ambient uses ztunnel, which is a Layer 4 proxy and doesn't support Layer 7 features such as routing based on headers.

To enable L7 routing for Ambient workloads, we need to introduce a waypoint proxy:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    allowedRoutes:
      namespaces:
        from: Same
    port: 15008
    protocol: HBONE
EOF
```

And configure the workloads in `bookinfo-backends` to use the waypoint:

```bash
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint=waypoint
```

Next, we need to configure the waypoint on how to route traffic to the `reviews` service:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
  - reviews.bookinfo-backends.svc.cluster.local
  http:
  - match:
    - headers:
        beta-tester:
          exact: "true"
    route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        subset: v2
  - route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        subset: v1
EOF
```

Now generate traffic again with the beta user from both types of workloads:

```shell
for workload in in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"

  kubectl --context ${CLUSTER1} -n clients exec deploy/${workload} -- bash -c "
  for i in {1..10}; do
    curl -s 'http://reviews.bookinfo-backends:9080/reviews/0' -H 'beta-tester: true' | jq .podname
  done"
  echo
done
```

Both the `in-mesh-with-sidecar` and `in-ambient` will adhere to the policy and route traffic to v2 only. Next, validate that for requests without the `beta-tester` header, the traffic is routed to v1 for both types of workloads:

```shell
for workload in in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"

  kubectl --context ${CLUSTER1} -n clients exec deploy/${workload} -- bash -c "
  for i in {1..10}; do
    curl -s 'http://reviews.bookinfo-backends:9080/reviews/0' | jq .podname
  done"
  echo
done
```

It's important to note that with sidecars, policies are applied directly to the workload. In contrast, in Ambient mode, policies are enforced at the waypoint. In the following labs, we will consistently apply the same policies to both `in-mesh-with-sidecar` and `in-ambient` workloads, illustrating the interoperability of L7 routing rules across different mesh modes.

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

describe("virtual service and destination rules configure routing", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];
  const repetitions = 10;

  describe("for beta users (specified by the header 'beta-tester: true')", function() {
    for (const workload of workloads) {
      it(`to route to v2 for workload ${workload}`, () => {
        for (let i = 0; i < repetitions; i++) {
          let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- bash -c "curl -s 'http://reviews.bookinfo-backends:9080/reviews/0' -H 'beta-tester: true' | jq .podname"`;
          let cli = chaiExec(command);
          expect(cli).to.exit.with.code(0);
          expect(cli).output.to.contain('-v2');
        }
      });
    }
  })

  describe("for regular users", function() {
    for (const workload of workloads) {
      it(`to route to v1 for workload ${workload}`, () => {
        for (let i = 0; i < repetitions; i++) {
          let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- bash -c "curl -s 'http://reviews.bookinfo-backends:9080/reviews/0' | jq .podname"`;
          let cli = chaiExec(command);
          expect(cli).to.exit.with.code(0);
          expect(cli).output.to.contain('-v1');
        }
      });
    }
  })
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-routing-interoperability/tests/validate-routing-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->



## Lab 9 - Ambient L7 Transforming traffic interoperability <a name="lab-9---ambient-l7-transforming-traffic-interoperability-"></a>

In this lab, we'll explore how to transform traffic in the Ambient mesh using Istio's L7 features. We'll add a custom header to the response of the `reviews` service and observe how this transformation applies to the `in-mesh-with-sidecar` and `in-ambient`.

The `VirtualService` below adds a custom header to the response of the `reviews` service.

```bash
kubectl --context "${CLUSTER1}" apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: clients
spec:
  hosts:
  - reviews.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        port:
          number: 9080
    headers:
      response:
        add:
          my-added-header: added-value
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
  - reviews.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        port:
          number: 9080
    headers:
      response:
        add:
          my-added-header: added-value
EOF
```

Let's validate that the header is added when we make requests from different types of workloads:

```shell
kubectl --context "${CLUSTER1}" -n clients exec deploy/in-mesh-with-sidecar -- curl -s -I "http://reviews.bookinfo-backends:9080/reviews/0" | grep my-added-header
kubectl --context "${CLUSTER1}" -n clients exec deploy/in-ambient -- curl -s -I "http://reviews.bookinfo-backends:9080/reviews/0" | grep my-added-header
```

Expected output:

```shell,nocopy
my-added-header: added-value
my-added-header: added-value
```

You should see the custom header in responses for both types of workloads, demonstrating L7 routing interoperability between sidecar and Ambient modes.

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

describe("virtual service", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];

  for (const workload of workloads) {
    it(`adds header to responses for traffic from workload ${workload}`, () => {
      let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- bash -c "curl -s -I 'http://reviews.bookinfo-backends:9080/reviews/0' | grep my-added-header"`;
      let cli = chaiExec(command);
      expect(cli).to.exit.with.code(0);
      expect(cli).output.to.contain('added-value');
    });
  }
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-transforming-traffic-interoperability/tests/validate-traffic-transformation-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=10 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->



## Lab 10 - Ambient L7 Traffic shifting interoperability <a name="lab-10---ambient-l7-traffic-shifting-interoperability-"></a>

In this lab, we'll explore how to shift traffic between different versions of a service in both sidecar and Ambient modes.

Apply the following `VirtualService` to shift traffic between two versions of the `reviews` service:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: clients
spec:
  hosts:
  - reviews.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        subset: v1
      weight: 70
    - destination:
        host: reviews.bookinfo-backends.svc.cluster.local
        subset: v2
      weight: 30
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
  - reviews.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 70
    - destination:
        host: reviews
        subset: v2
      weight: 30
EOF
```

This configuration routes 70% of traffic to v1 and 30% to v2. Let's verify the traffic distribution:

```shell
for workload in in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"

  kubectl --context ${CLUSTER1} -n clients exec deploy/${workload} -- bash -c "
  for i in {1..10}; do
    curl -s 'http://reviews.bookinfo-backends:9080/reviews/0' | jq .podname
  done"
  echo
done
```

You should see that requests are distributed between v1 and v2 according to the specified weights, regardless of whether the client is using a sidecar or is in Ambient mode.





## Lab 11 - Ambient L7 Traffic resiliency interoperability <a name="lab-11---ambient-l7-traffic-resiliency-interoperability-"></a>

Let's deploy the echo service so that we can simulate failures and test retry logic in Ambient. First, create the echo service:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-backends create deployment echo-service --image=ealen/echo-server
kubectl --context ${CLUSTER1} -n bookinfo-backends expose deployment echo-service --port=80 --target-port=80 --name=echo-service --type=ClusterIP
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout status deployment/echo-service
```

Next create the virtual services for it:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: echo-service
  namespace: clients
spec:
  hosts:
  - echo-service.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: echo-service.bookinfo-backends.svc.cluster.local
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: echo-service
  namespace: bookinfo-backends
spec:
  hosts:
  - echo-service.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: echo-service.bookinfo-backends.svc.cluster.local
EOF
```

You should see a mix of successful (200) and failed (500) responses.

```shell
for workload in in-mesh-with-sidecar in-ambient; do
  echo "${workload} to echo-service.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- bash -c "
  for i in {1..10}; do
    curl -s -I 'http://echo-service.bookinfo-backends?echo_code=200-500' | grep 'HTTP/'
  done"
  echo
done
```

Now, let's add retry logic:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: echo-service
  namespace: clients
spec:
  hosts:
  - echo-service.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: echo-service.bookinfo-backends.svc.cluster.local
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: echo-service
  namespace: bookinfo-backends
spec:
  hosts:
  - echo-service.bookinfo-backends.svc.cluster.local
  http:
  - route:
    - destination:
        host: echo-service.bookinfo-backends.svc.cluster.local
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx
EOF
```

With this configuration in place, let's test again:

```shell
for workload in in-mesh-with-sidecar in-ambient; do
  echo "${workload} to echo-service.bookinfo-backends"
  kubectl --context="${CLUSTER1}" -n clients exec deploy/$workload -- bash -c "
  for i in {1..10}; do
    curl -s -I 'http://echo-service.bookinfo-backends?echo_code=200-500' | grep 'HTTP/'
  done"
  echo
done
```

You should now see far fewer failed requests, as the retry logic automatically attempts to recover from failures. This behavior should be consistent for both sidecar and Ambient mode clients.

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

describe("virtual service retry failed requests", function() {
  const cluster = process.env.CLUSTER1
  const workloads = ['in-mesh-with-sidecar', 'in-ambient'];
  const repetitions = 20;

  for (const workload of workloads) {
    it(`should retry for ${workload}`, function() {
      let countFailures = 0;
      let countSuccesses = 0;
      for (let i = 0; i < repetitions; i++) {
        let command = `kubectl --context ${cluster} -n clients exec deploy/${workload} -- bash -c "curl -s -I 'http://echo-service.bookinfo-backends?echo_code=200-500'"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        if (cli.output.includes('200 OK')) {
          countSuccesses++;
        } else if (cli.output.includes('500 Internal Server Error')) {
          countFailures++;
        } else {
          expect.fail('Unexpected response')
        }
      }

      expect(countSuccesses).to.be.at.least(16);
      expect(countFailures).to.be.lessThanOrEqual(4);
    });
  }
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-traffic-resiliency-interoperability/tests/validate-resiliency-interoperability.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=10 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 80000; exit 1; }
-->



