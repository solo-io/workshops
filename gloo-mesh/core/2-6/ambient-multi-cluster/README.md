
<!--bash
source ./scripts/assert.sh
-->



<center>
<img src="images/document-gloo-mesh.svg" style="height: 100px;"/>
</center>

# <center>Gloo Mesh Core (2.6.7) Ambient</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD Cluster(s)](#lab-1---deploy-kind-cluster(s)-)
* [Lab 2 - Deploy and register Gloo Mesh](#lab-2---deploy-and-register-gloo-mesh-)
* [Lab 3 - Configure common trust certificates in both clusters](#lab-3---configure-common-trust-certificates-in-both-clusters-)
* [Lab 4 - Deploy Istio using Helm](#lab-4---deploy-istio-using-helm-)
* [Lab 5 - Deploy the httpbin demo app](#lab-5---deploy-the-httpbin-demo-app-)
* [Lab 6 - Deploy the httpbin demo app](#lab-6---deploy-the-httpbin-demo-app-)
* [Lab 7 - Deploy the clients to make requests to other services](#lab-7---deploy-the-clients-to-make-requests-to-other-services-)
* [Lab 8 - Link Clusters](#lab-8---link-clusters-)



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




## Lab 1 - Deploy KinD Cluster(s) <a name="lab-1---deploy-kind-cluster(s)-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variables:

```bash
export MGMT=cluster1
export CLUSTER1=cluster1
export CLUSTER2=cluster2
```

Deploy the KinD clusters:

```bash
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
bash ./data/steps/deploy-kind-clusters/deploy-cluster2.sh
```
Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh cluster1
./scripts/check.sh cluster2
```

**Note:** If you run the `check.sh` script immediately after the `deploy.sh` script, you may see a jsonpath error. If that happens, simply wait a few seconds and try again.

Once the `check.sh` script completes, execute the `kubectl get pods -A` command, and verify that all pods are in a running state.
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = ["cluster1", "cluster2"];

    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 2 - Deploy and register Gloo Mesh <a name="lab-2---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


Before we get started, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.6.7
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
    expect(process.env.CLUSTER2).not.to.be.empty
  });

  it("Gloo Mesh licence environment variables should not be empty", () => {
    expect(process.env.GLOO_MESH_LICENSE_KEY).not.to.be.empty
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->

Run the following commands to deploy the Gloo Mesh management plane:

```bash
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --set featureGates.insightsConfiguration=true \
  --version 2.6.7

helm upgrade --install gloo-platform-mgmt gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.6.7 \
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
kubectl wait --context ${MGMT} --for=condition=Ready -n gloo-mesh --all pod
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

Then, you need to set the environment variable to tell the Gloo Mesh agents how to communicate with the management plane:
<!--bash
cat <<'EOF' > ./test.js

const helpers = require('./tests/chai-exec');

describe("MGMT server is healthy", () => {
  let cluster = process.env.MGMT;
  let deployments = ["gloo-mesh-mgmt-server","gloo-mesh-redis","gloo-telemetry-gateway","prometheus-server"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-mesh", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/check-deployment.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
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
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/get-gloo-mesh-mgmt-server-ip.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->

```bash
export ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].*}'):9900
export HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH%:*})
export ENDPOINT_TELEMETRY_GATEWAY=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-telemetry-gateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):4317
export ENDPOINT_GLOO_MESH_UI=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-ui -o jsonpath='{.status.loadBalancer.ingress[0].*}'):8090
```

Check that the variables have correct values:
```
echo $HOST_GLOO_MESH
echo $ENDPOINT_GLOO_MESH
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

describe("Address '" + process.env.HOST_GLOO_MESH + "' can be resolved in DNS", () => {
    it(process.env.HOST_GLOO_MESH + ' can be resolved', (done) => {
        return dns.lookup(process.env.HOST_GLOO_MESH, (err, address, family) => {
            expect(address).to.be.an.ip;
            done();
        });
    });
});
EOF
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->
Finally, you need to register the cluster(s).


And here is how you register the second one:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: cluster2
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF

kubectl --context ${CLUSTER2} create ns gloo-mesh

kubectl get secret relay-root-tls-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context ${CLUSTER2} --from-file ca.crt=ca.crt
rm ca.crt

kubectl get secret relay-identity-token-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.token}' | base64 -d > token
kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context ${CLUSTER2} --from-file token=token
rm token

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.6.7

helm upgrade --install gloo-platform-agent gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.6.7 \
  -f -<<EOF
common:
  cluster: cluster2
glooAgent:
  enabled: true
  relay:
    serverAddress: "${ENDPOINT_GLOO_MESH}"
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: "${ENDPOINT_TELEMETRY_GATEWAY}"
glooAnalyzer:
  enabled: true
EOF
```

You can check the cluster(s) have been registered correctly using the following commands:
```
meshctl --kubecontext ${MGMT} check
```

```
pod=$(kubectl --context ${MGMT} -n gloo-mesh get pods -l app=gloo-mesh-mgmt-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${MGMT} -n gloo-mesh debug -q -i ${pod} --image=curlimages/curl -- curl -s http://localhost:9091/metrics | grep relay_push_clients_connected
```

You should get an output similar to this:
```,nocopy
# HELP relay_push_clients_connected Current number of connected Relay push clients (Relay Agents).
# TYPE relay_push_clients_connected gauge
relay_push_clients_connected{cluster="cluster1"} 1
relay_push_clients_connected{cluster="cluster2"} 1
```
Finally, you need to specify which gateways you want to use for cross cluster traffic:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: global
  namespace: gloo-mesh
spec:
  options:
    eastWestGateways:
      - selector:
          labels:
            istio: eastwestgateway
EOF
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
  it("cluster2 is registered", () => {
    podName = helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh get pods -l app=gloo-mesh-mgmt-server -o jsonpath='{.items[0].metadata.name}' --context " + process.env.MGMT }).replaceAll("'", "");
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh debug -q -i " + podName + " --image=curlimages/curl -- curl -s http://localhost:9091/metrics" }).replaceAll("'", "");
    expect(command).to.contain("cluster2");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 3 - Configure common trust certificates in both clusters <a name="lab-3---configure-common-trust-certificates-in-both-clusters-"></a>

Create intermediate CAs in both clusters and the Root CA.

```bash
echo "Generating new certificates"
mkdir -p "./certs/${CLUSTER1}"
mkdir -p "./certs/${CLUSTER2}"

if ! [ -x "$(command -v step)" ]; then
  echo 'Error: Install the smallstep cli (https://github.com/smallstep/cli)'
  exit 1
fi

step certificate create root.istio.ca ./certs/root-cert.pem ./certs/root-ca.key \
  --profile root-ca --no-password --insecure --san root.istio.ca \
  --not-after 87600h --kty RSA

step certificate create $CLUSTER1 \
  ./certs/$CLUSTER1/ca-cert.pem \
  ./certs/$CLUSTER1/ca-key.pem \
  --ca ./certs/root-cert.pem \
  --ca-key ./certs/root-ca.key \
  --profile intermediate-ca \
  --not-after 87600h \
  --no-password \
  --san $CLUSTER1 \
  --kty RSA \
  --insecure

step certificate create $CLUSTER2 \
  ./certs/$CLUSTER2/ca-cert.pem \
  ./certs/$CLUSTER2/ca-key.pem \
  --ca ./certs/root-cert.pem \
  --ca-key ./certs/root-ca.key \
  --profile intermediate-ca \
  --not-after 87600h \
  --no-password \
  --san $CLUSTER2 \
  --kty RSA \
  --insecure

cat ./certs/$CLUSTER1/ca-cert.pem ./certs/root-cert.pem > ./certs/$CLUSTER1/cert-chain.pem
cat ./certs/$CLUSTER2/ca-cert.pem ./certs/root-cert.pem > ./certs/$CLUSTER2/cert-chain.pem
```


Now let's apply the certificates to the clusters.
```bash
kubectl --context="${CLUSTER1}" create namespace istio-system || true
kubectl --context="${CLUSTER1}" create secret generic cacerts -n istio-system \
  --from-file=./certs/$CLUSTER1/ca-cert.pem \
  --from-file=./certs/$CLUSTER1/ca-key.pem \
  --from-file=./certs/root-cert.pem \
  --from-file=./certs/$CLUSTER1/cert-chain.pem

kubectl --context="${CLUSTER2}" create namespace istio-system || true
kubectl --context="${CLUSTER2}" create secret generic cacerts -n istio-system \
  --from-file=./certs/$CLUSTER2/ca-cert.pem \
  --from-file=./certs/$CLUSTER2/ca-key.pem \
  --from-file=./certs/root-cert.pem \
  --from-file=./certs/$CLUSTER2/cert-chain.pem
```



## Lab 4 - Deploy Istio using Helm <a name="lab-4---deploy-istio-using-helm-"></a>


It is convenient to have the `istioctl` command line tool installed on your local machine. If you don't have it installed, you can install it by following the instructions below.

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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-helm/tests/istio-version.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
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

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: eastwestgateway
  name: istio-eastwestgateway
  namespace: istio-gateways
spec:
  ports:
  - name: status-port
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: tls
    port: 15443
    protocol: TCP
    targetPort: 15443
  - name: hbone
    port: 15008
    protocol: TCP
    targetPort: 15008
  - name: https
    port: 16443
    protocol: TCP
    targetPort: 16443
  - name: tls-spire
    port: 8081
    protocol: TCP
    targetPort: 8081
  - name: tls-otel
    port: 4317
    protocol: TCP
    targetPort: 4317
  - name: grpc-cacert
    port: 31338
    protocol: TCP
    targetPort: 31338
  - name: grpc-ew-bootstrap
    port: 31339
    protocol: TCP
    targetPort: 31339
  - name: tcp-istiod
    port: 15012
    protocol: TCP
    targetPort: 15012
  - name: tcp-webhook
    port: 15017
    protocol: TCP
    targetPort: 15017
  selector:
    app: istio-ingressgateway
    istio: eastwestgateway
  type: LoadBalancer
EOF
kubectl --context ${CLUSTER2} create ns istio-gateways

kubectl apply --context ${CLUSTER2} -f - <<EOF
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

kubectl apply --context ${CLUSTER2} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: eastwestgateway
  name: istio-eastwestgateway
  namespace: istio-gateways
spec:
  ports:
  - name: status-port
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: tls
    port: 15443
    protocol: TCP
    targetPort: 15443
  - name: hbone
    port: 15008
    protocol: TCP
    targetPort: 15008
  - name: https
    port: 16443
    protocol: TCP
    targetPort: 16443
  - name: tls-spire
    port: 8081
    protocol: TCP
    targetPort: 8081
  - name: tls-otel
    port: 4317
    protocol: TCP
    targetPort: 4317
  - name: grpc-cacert
    port: 31338
    protocol: TCP
    targetPort: 31338
  - name: grpc-ew-bootstrap
    port: 31339
    protocol: TCP
    targetPort: 31339
  - name: tcp-istiod
    port: 15012
    protocol: TCP
    targetPort: 15012
  - name: tcp-webhook
    port: 15017
    protocol: TCP
    targetPort: 15017
  selector:
    app: istio-ingressgateway
    istio: eastwestgateway
  type: LoadBalancer
EOF
```

Let's deploy Istio using Helm in cluster1. We'll install the base Istio components, the Istiod control plane, the Istio CNI, the ztunnel, and the ingress/eastwest gateways.


```bash
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
EOF

helm upgrade --install istiod-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.23.1-solo
  multiCluster:
    clusterName: cluster1
profile: ambient
istio_cni:
  enabled: true
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: cluster.local
pilot:
  enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
  podLabels:
    hack: eastwest
  platforms:
    peering:
      enabled: true
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER1} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.23.1-solo
profile: ambient
cni:
  ambient:
    dnsCapture: true
  excludeNamespaces:
  - istio-system
  - kube-system
EOF

helm upgrade --install ztunnel oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/ztunnel \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
  NETWORK: cluster1
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster1
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.23.1-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
service:
  type: None
EOF

helm upgrade --install istio-eastwestgateway-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
imagePullPolicy: IfNotPresent
env:
  ISTIO_META_REQUESTED_NETWORK_VIEW: cluster1
  ISTIO_META_ROUTER_MODE: sni-dnat
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  topology.istio.io/network: cluster1
service:
  type: None
EOF
```
The Gateway APIs do not come installed by default on most Kubernetes clusters. Install the Gateway API CRDs if they are not present:
```bash
kubectl --context ${CLUSTER1} get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl --context ${CLUSTER1} apply -f -; }
kubectl --context ${CLUSTER2} get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl --context ${CLUSTER2} apply -f -; }
```
  
Let's deploy Istio using Helm in cluster2. We'll install the base Istio components, the Istiod control plane, the Istio CNI, the ztunnel, and the ingress/eastwest gateways.


```bash
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
EOF

helm upgrade --install istiod-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.23.1-solo
  multiCluster:
    clusterName: cluster2
profile: ambient
istio_cni:
  enabled: true
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: cluster.local
pilot:
  enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
  podLabels:
    hack: eastwest
  platforms:
    peering:
      enabled: true
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER2} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.23.1-solo
profile: ambient
cni:
  ambient:
    dnsCapture: true
  excludeNamespaces:
  - istio-system
  - kube-system
EOF

helm upgrade --install ztunnel oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/ztunnel \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
  NETWORK: cluster2
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster2
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.23.1-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER2} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
service:
  type: None
EOF

helm upgrade --install istio-eastwestgateway-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER2} \
--version 1.23.1-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
imagePullPolicy: IfNotPresent
env:
  ISTIO_META_REQUESTED_NETWORK_VIEW: cluster2
  ISTIO_META_ROUTER_MODE: sni-dnat
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  topology.istio.io/network: cluster2
service:
  type: None
EOF
```
The Gateway APIs do not come installed by default on most Kubernetes clusters. Install the Gateway API CRDs if they are not present:
```bash
kubectl --context ${CLUSTER1} get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl --context ${CLUSTER1} apply -f -; }
kubectl --context ${CLUSTER2} get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl --context ${CLUSTER2} apply -f -; }
```

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
  it('gateway pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-gateways", labels: "app=istio-ingressgateway", instances: 2 }));
  it('istiod pods are ready in cluster ' + process.env.CLUSTER2, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER2, namespace: "istio-system", labels: "app=istiod", instances: 1 }));
  it('gateway pods are ready in cluster ' + process.env.CLUSTER2, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER2, namespace: "istio-gateways", labels: "app=istio-ingressgateway", instances: 2 }));
  it("Gateways have an ip attached in cluster " + process.env.CLUSTER1, () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get svc -l app=istio-ingressgateway -o jsonpath='{.items}'");
    cli.stderr.should.be.empty;
    let deployments = JSON.parse(cli.stdout.slice(1,-1));
    expect(deployments).to.have.lengthOf(2);
    deployments.forEach((deployment) => {
      expect(deployment.status.loadBalancer).to.have.property("ingress");
    });
  });
  it("Gateways have an ip attached in cluster " + process.env.CLUSTER2, () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER2 + " -n istio-gateways get svc -l app=istio-ingressgateway -o jsonpath='{.items}'");
    cli.stderr.should.be.empty;
    let deployments = JSON.parse(cli.stdout.slice(1,-1));
    expect(deployments).to.have.lengthOf(2);
    deployments.forEach((deployment) => {
      expect(deployment.status.loadBalancer).to.have.property("ingress");
    });
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-helm/tests/istio-ready.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->
<!--bash
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o json | jq '.items[0].status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

```bash
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
export HOST_GW_CLUSTER2="$(kubectl --context ${CLUSTER2} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
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
echo "executing test ./default/tests/can-resolve.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const dns = require('dns');
const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const { waitOnFailedTest } = require('./tests/utils');

afterEach(function(done) { waitOnFailedTest(done, this.currentTest.currentRetry())});

describe("Address '" + process.env.HOST_GW_CLUSTER2 + "' can be resolved in DNS", () => {
    it(process.env.HOST_GW_CLUSTER2 + ' can be resolved', (done) => {
        return dns.lookup(process.env.HOST_GW_CLUSTER2, (err, address, family) => {
            expect(address).to.be.an.ip;
            done();
        });
    });
});
EOF
echo "executing test ./default/tests/can-resolve.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 5 - Deploy the httpbin demo app <a name="lab-5---deploy-the-httpbin-demo-app-"></a>
[<img src="https://img.youtube.com/vi/w1xB-o_gHs0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/w1xB-o_gHs0 "Video Link")


We're going to deploy the httpbin application to demonstrate several features of Gloo Mesh on cluster CLUSTER1.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app on `cluster1`. The deployment will be called `not-in-mesh` and won't have the sidecar injected, because of the annotation `sidecar.istio.io/inject: "false"` and its traffic won't be redirected to ztunnel because of the annotation `istio.io/dataplane-mode: none`.

```bash
kubectl --context ${CLUSTER1} create ns httpbin
kubectl --context ${CLUSTER1} label namespace httpbin istio.io/dataplane-mode=ambient
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
        istio.io/dataplane-mode: none
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: not-in-mesh
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
```

Then, we deploy a second version, which will be called `in-mesh` and will be part of the mesh.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: in-mesh
  namespace: httpbin
  labels:
    app: in-mesh
    service: in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: in-mesh
        version: v1
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-mesh
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
```


<!--bash
echo -n Waiting for httpbin pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n httpbin get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->
Add another HTTPBin service which is deployed in Ambient.
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-ambient
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: in-ambient
  namespace: httpbin
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
  namespace: httpbin
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
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-ambient
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
```
You can follow the progress using the following command:

```bash
kubectl --context ${CLUSTER1} -n httpbin get pods
```

```,nocopy
NAME                           READY   STATUS    RESTARTS   AGE
in-mesh-5d9d9549b5-qrdgd       2/2     Running   0          11s
in-ambient-5c64bb49cd-m9kwm    1/1     Running   0          4s
not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("httpbin app", () => {
  let cluster = process.env.CLUSTER1
  
  let deployments = ["not-in-mesh", "in-mesh"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->



## Lab 6 - Deploy the httpbin demo app <a name="lab-6---deploy-the-httpbin-demo-app-"></a>
[<img src="https://img.youtube.com/vi/w1xB-o_gHs0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/w1xB-o_gHs0 "Video Link")


We're going to deploy the httpbin application to demonstrate several features of Gloo Mesh on cluster CLUSTER2.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app on `cluster1`. The deployment will be called `not-in-mesh` and won't have the sidecar injected, because of the annotation `sidecar.istio.io/inject: "false"` and its traffic won't be redirected to ztunnel because of the annotation `istio.io/dataplane-mode: none`.

```bash
kubectl --context ${CLUSTER2} create ns httpbin
kubectl --context ${CLUSTER2} label namespace httpbin istio.io/dataplane-mode=ambient
kubectl apply --context ${CLUSTER2} -f - <<EOF

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
        istio.io/dataplane-mode: none
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: not-in-mesh
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
```

Then, we deploy a second version, which will be called `in-mesh` and will be part of the mesh.

```bash
kubectl apply --context ${CLUSTER2} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: in-mesh
  namespace: httpbin
  labels:
    app: in-mesh
    service: in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: in-mesh
        version: v1
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-mesh
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
```


<!--bash
echo -n Waiting for httpbin pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER2} -n httpbin get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->
Add another HTTPBin service which is deployed in Ambient.
```bash
kubectl apply --context ${CLUSTER2} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-ambient
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: in-ambient
  namespace: httpbin
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
  namespace: httpbin
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
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-ambient
        ports:
        - name: http
          containerPort: 80
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http

EOF
```
You can follow the progress using the following command:

```bash
kubectl --context ${CLUSTER2} -n httpbin get pods
```

```,nocopy
NAME                           READY   STATUS    RESTARTS   AGE
in-mesh-5d9d9549b5-qrdgd       2/2     Running   0          11s
in-ambient-5c64bb49cd-m9kwm    1/1     Running   0          4s
not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("httpbin app", () => {
  let cluster = process.env.CLUSTER1
  
  let deployments = ["not-in-mesh", "in-mesh"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->



## Lab 7 - Deploy the clients to make requests to other services <a name="lab-7---deploy-the-clients-to-make-requests-to-other-services-"></a>

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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->



## Lab 8 - Link Clusters <a name="lab-8---link-clusters-"></a>

Install the Kubernetes Gateway API in both clusters:
```
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl --context $CLUSTER2 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Configure the network topology for each cluster in the `istio-system` namespace:

```bash
kubectl --context $CLUSTER1 label namespace istio-system topology.istio.io/network=$CLUSTER1
kubectl --context $CLUSTER2 label namespace istio-system topology.istio.io/network=$CLUSTER2
```

Create a Gateway for each cluster:

```bash
  cat <<EOF | kubectl --context $CLUSTER1 apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eastwest
  namespace: istio-system
  labels:
    topology.istio.io/network: $CLUSTER1
    istio.io/expose-istiod: "15012"
spec:
  gatewayClassName: istio-eastwest
  listeners:
  - name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
EOF

  cat <<EOF | kubectl --context $CLUSTER2 apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eastwest
  namespace: istio-system
  labels:
    topology.istio.io/network: $CLUSTER2
    istio.io/expose-istiod: "15012"
spec:
  gatewayClassName: istio-eastwest
  listeners:
  - name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
EOF
```

Patch the eastwest gateways to admit xds traffic to the clusters:

```bash
kubectl --context $CLUSTER1 -n istio-system patch svc eastwest --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "grpc-xds", "port": 15010, "targetPort": "grpc-xds", "protocol": "TCP"}}]'
kubectl --context $CLUSTER2 -n istio-system patch svc eastwest --type='json' -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "grpc-xds", "port": 15010, "targetPort": "grpc-xds", "protocol": "TCP"}}]'
```

Link the first cluster to the second cluster:

```bash
CLUSTER_GW_IP="$(kubectl --context $CLUSTER2 -n istio-system get service eastwest -o jsonpath='{.status.loadBalancer.ingress[0].*}')"

cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    gateway.istio.io/service-account: eastwest
  labels:
    topology.istio.io/network: cluster2
  name: remote-cluster2
  namespace: istio-system
spec:
  addresses:
  - type: IPAddress
    value: "${CLUSTER_GW_IP}"
  gatewayClassName: istio-remote
  listeners:
  - name: cross-network
    port: 15008
    protocol: HBONE
EOF
```

Link the second cluster to the first cluster:

```bash
CLUSTER_GW_IP="$(kubectl --context $CLUSTER1 -n istio-system get service eastwest -o jsonpath='{.status.loadBalancer.ingress[0].*}')"

cat << EOF | kubectl --context ${CLUSTER2} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    gateway.istio.io/service-account: eastwest
  labels:
    topology.istio.io/network: cluster1
  name: remote-cluster1
  namespace: istio-system
spec:
  addresses:
  - type: IPAddress
    value: "${CLUSTER_GW_IP}"
  gatewayClassName: istio-remote
  listeners:
  - name: cross-network
    port: 15008
    protocol: HBONE
EOF
```

Let's validate that cross cluster traffic works. Let's annotate services that are globally accessible:

Next expose global service.

```bash
kubectl --context $CLUSTER1 -n httpbin annotate svc in-ambient istio.io/global-service=true
kubectl --context $CLUSTER2 -n httpbin annotate svc in-ambient istio.io/global-service=true
```

Validate that Service Entries are workload entries are created to route traffic to the gateway of the other cluster:

```shell
kubectl --context $CLUSTER1 -n httpbin get serviceentry
kubectl --context $CLUSTER2 -n httpbin get workloadentry
```

> [!IMPORTANT]
> Limitation:
>
> * Multi-Network traffic is currently not supported by Istio Gateways, Sidecars, and Waypoints.

Next, let's send some traffic across the clusters:

```shell
kubectl --context=$CLUSTER1 -n clients exec -it deploy/in-ambient -- curl -v in-ambient.httpbin.global:8000/get
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');


describe("ensure traffic goes to workloads in both clusters", () => {
  it('should have two origins', async () => {
    const origins = new Set();
    for (let i = 0; i < 10; i++) {
      const command = await helpers.curlInDeployment({
        curlCommand: 'curl in-ambient.httpbin.global:8000/get',
        deploymentName: 'in-ambient',
        namespace: 'clients',
        context: `${process.env.CLUSTER1}`
      });
      const origin = JSON.parse(command).origin;
      origins.add(origin);
    }
    expect(origins.size).to.equal(2);
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/link-clusters/tests/check-cross-cluster-traffic.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->



