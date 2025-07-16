
<!--bash
source ./scripts/assert.sh
-->



<center>
<img src="images/document-gloo-mesh.svg" style="height: 100px;"/>
</center>

# <center>Gloo Mesh Core (2.7.4) Ambient</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD Cluster(s)](#lab-1---deploy-kind-cluster(s)-)
* [Lab 2 - Deploy and register Gloo Mesh](#lab-2---deploy-and-register-gloo-mesh-)
* [Lab 3 - Configure common trust certificates in both clusters](#lab-3---configure-common-trust-certificates-in-both-clusters-)
* [Lab 4 - Deploy or upgrade Gloo Operator](#lab-4---deploy-or-upgrade-gloo-operator-)
* [Lab 5 - Deploy or upgrade Istio using Gloo Operator](#lab-5---deploy-or-upgrade-istio-using-gloo-operator-)
* [Lab 6 - Deploy the httpbin demo app](#lab-6---deploy-the-httpbin-demo-app-)
* [Lab 7 - Deploy the httpbin demo app](#lab-7---deploy-the-httpbin-demo-app-)
* [Lab 8 - Deploy the httpbin demo app](#lab-8---deploy-the-httpbin-demo-app-)
* [Lab 9 - Deploy the clients to make requests to other services](#lab-9---deploy-the-clients-to-make-requests-to-other-services-)
* [Lab 10 - Deploy the clients to make requests to other services](#lab-10---deploy-the-clients-to-make-requests-to-other-services-)
* [Lab 11 - Deploy Keycloak](#lab-11---deploy-keycloak-)
* [Lab 12 - Deploy Gloo Gateway Enterprise](#lab-12---deploy-gloo-gateway-enterprise-)
* [Lab 13 - Deploy the httpbin demo app](#lab-13---deploy-the-httpbin-demo-app-)
* [Lab 14 - Expose the httpbin application through the gateway](#lab-14---expose-the-httpbin-application-through-the-gateway-)
* [Lab 15 - Delegate with control](#lab-15---delegate-with-control-)
* [Lab 16 - Use the `cache-control` response header to cache responses](#lab-16---use-the-`cache-control`-response-header-to-cache-responses-)
* [Lab 17 - Deploy and use waypoint](#lab-17---deploy-and-use-waypoint-)
* [Lab 18 - Deploy Gloo Gateway Enterprise](#lab-18---deploy-gloo-gateway-enterprise-)
* [Lab 19 - Ambient Egress Traffic with Waypoint](#lab-19---ambient-egress-traffic-with-waypoint-)
* [Lab 20 - Ambient Egress Traffic with Waypoint](#lab-20---ambient-egress-traffic-with-waypoint-)
* [Lab 21 - Link Clusters](#lab-21---link-clusters-)
* [Lab 22 - Ambient multicluster routing](#lab-22---ambient-multicluster-routing-)



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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
-->




## Lab 2 - Deploy and register Gloo Mesh <a name="lab-2---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


Before we get started, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.7.4
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->

Run the following commands to deploy the Gloo Mesh management plane:

```bash
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --set featureGates.insightsConfiguration=true \
  --set installEnterpriseCrds=false \
  --version 2.7.4

helm upgrade --install gloo-platform-mgmt gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.7.4 \
  -f -<<EOF
licensing:
  glooTrialLicenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: cluster1
experimental:
  ambientEnabled: true
glooInsightsEngine:
  enabled: true
glooAgent:
  enabled: true
  relay:
    serverAddress: gloo-mesh-mgmt-server:9900
    authority: gloo-mesh-mgmt-server.gloo-mesh
glooMgmtServer:
  enabled: true
  policyApis:
    enabled: false
  ports:
    healthcheck: 8091
  registerCluster: true
redis:
  deployment:
    enabled: true
telemetryGateway:
  enabled: true
  service:
    type: LoadBalancer
prometheus:
  enabled: true
glooUi:
  enabled: true
  serviceType: LoadBalancer
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: gloo-telemetry-gateway:4317
featureGates:
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/check-deployment.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/get-gloo-mesh-mgmt-server-ip.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->

```bash
export ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):9900
export HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH%:*})
export ENDPOINT_TELEMETRY_GATEWAY=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-telemetry-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):4317
export ENDPOINT_GLOO_MESH_UI=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-ui -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):8090
```

Check that the variables have correct values:

```bash,norun-workshop
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
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->
Finally, you need to register the cluster(s).

The first cluster was automatically registered when you deployed the management plane.
Here is how you register the second one:

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
  --set installEnterpriseCrds=false \
  --kube-context ${CLUSTER2} \
  --version 2.7.4

helm upgrade --install gloo-platform-agent gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.7.4 \
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


You can check the cluster(s) have been registered correctly in the Gloo UI or by using the following commands:

```bash,norun-workshop
meshctl --kubecontext ${MGMT} check
```

Alternatively, check for `relay_push_clients_connected` metrics:

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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->




## Lab 3 - Configure common trust certificates in both clusters <a name="lab-3---configure-common-trust-certificates-in-both-clusters-"></a>

We'll be implementing multi-cluster traffic distribution in this workshop.
For multi-cluster traffic to be trusted in both clusters, each cluster in the mesh must have a shared root of trust.
This can be achieved by providing a root certificate signed by a corporate CA, or a custom root certificate created for this purpose.
That certificate signs a unique intermediate CA certificate for each cluster.

<!--bash
echo "Generating new certificates"
if ! [ -x "$(command -v step)" ]; then
  echo 'Error: Install the smallstep cli (https://github.com/smallstep/cli)'
  exit 1
fi
-->

Create the root certificate:

```bash
mkdir -p certs/${CLUSTER1} certs/${CLUSTER2}

step certificate create root.istio.ca \
  certs/root-cert.pem \
  certs/root-ca.key \
  --profile root-ca \
  --no-password \
  --insecure \
  --san root.istio.ca \
  --not-after 87600h \
  --kty RSA
```

Next, create an intermediate certificate and apply it to `cluster1`:

```bash
step certificate create ${CLUSTER1} \
  certs/${CLUSTER1}/ca-cert.pem \
  certs/${CLUSTER1}/ca-key.pem \
  --ca certs/root-cert.pem \
  --ca-key certs/root-ca.key \
  --profile intermediate-ca \
  --not-after 87600h \
  --no-password \
  --san ${CLUSTER1} \
  --kty RSA \
  --insecure

kubectl --context ${CLUSTER1} create ns istio-system 2>/dev/null || true
kubectl --context ${CLUSTER1} -n istio-system create secret generic cacerts \
  --from-file=certs/${CLUSTER1}/ca-cert.pem \
  --from-file=certs/${CLUSTER1}/ca-key.pem \
  --from-file=certs/root-cert.pem \
  --from-file=cert-chain.pem=certs/${CLUSTER1}/ca-cert.pem
```

Create another intermediate certificate from the same root certificate and apply it to `cluster2`:

```bash
step certificate create ${CLUSTER2} \
  certs/${CLUSTER2}/ca-cert.pem \
  certs/${CLUSTER2}/ca-key.pem \
  --ca certs/root-cert.pem \
  --ca-key certs/root-ca.key \
  --profile intermediate-ca \
  --not-after 87600h \
  --no-password \
  --san ${CLUSTER2} \
  --kty RSA \
  --insecure

kubectl --context ${CLUSTER2} create ns istio-system 2>/dev/null || true
kubectl --context ${CLUSTER2} -n istio-system create secret generic cacerts \
  --from-file=certs/${CLUSTER2}/ca-cert.pem \
  --from-file=certs/${CLUSTER2}/ca-key.pem \
  --from-file=certs/root-cert.pem \
  --from-file=cert-chain.pem=certs/${CLUSTER2}/ca-cert.pem
```

Now the mesh workloads in each cluster will trust the certificates from the other cluster.



## Lab 4 - Deploy or upgrade Gloo Operator <a name="lab-4---deploy-or-upgrade-gloo-operator-"></a>

In this section, we will install Gloo Operator, which will handle the lifecycle of Istio control planes and Gloo Gateway Enterprise.

### Install or Upgrade Gloo Operator

Gloo Operator is a Kubernetes operator that manages the lifecycle of Istio Control Planes. Let's install or upgrade it.

```bash
gcloud auth configure-docker us-docker.pkg.dev --quiet
export GLOO_OPERATOR_VERSION=0.2.5

kubectl --context "${CLUSTER1}" create ns gloo-mesh

helm upgrade --install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
  --kube-context ${CLUSTER1} \
  --version $GLOO_OPERATOR_VERSION \
  -n gloo-mesh --values - <<EOF
manager:
  env:
    POD_NAMESPACE: gloo-mesh
    SOLO_ISTIO_LICENSE_KEY: ${GLOO_MESH_LICENSE_KEY}
    GLOO_GATEWAY_LICENSE_KEY: ${LICENSE_KEY}
EOF
kubectl --context "${CLUSTER2}" create ns gloo-mesh

helm upgrade --install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
  --kube-context ${CLUSTER2} \
  --version $GLOO_OPERATOR_VERSION \
  -n gloo-mesh --values - <<EOF
manager:
  env:
    POD_NAMESPACE: gloo-mesh
    SOLO_ISTIO_LICENSE_KEY: ${GLOO_MESH_LICENSE_KEY}
    GLOO_GATEWAY_LICENSE_KEY: ${LICENSE_KEY}
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Operator", () => {
  let cluster1 = process.env.CLUSTER1;
  let cluster2 = process.env.CLUSTER2;
  let operatorVersion = process.env.GLOO_OPERATOR_VERSION;

  it(`pod should be running in cluster ${cluster1}`, () => helpers.checkDeploymentHasPod({ context: cluster1, namespace: "gloo-mesh", deployment: 'gloo-operator' }));
  it(`operator in cluster ${cluster1} should be version ${operatorVersion}`, () => helpers.genericCommand({
      command: `kubectl --context ${cluster1} -n gloo-mesh get pods -l app.kubernetes.io/name=gloo-operator -o jsonpath='{.items[0].spec.containers[0].image}'`,
      responseContains: operatorVersion
    }));
  it(`pod should be running in cluster ${cluster2}`, () => helpers.checkDeploymentHasPod({ context: cluster2, namespace: "gloo-mesh", deployment: 'gloo-operator' }));
  it(`operator in cluster ${cluster2} should be version ${operatorVersion}`, () => helpers.genericCommand({
      command: `kubectl --context ${cluster2} -n gloo-mesh get pods -l app.kubernetes.io/name=gloo-operator -o jsonpath='{.items[0].spec.containers[0].image}'`,
      responseContains: operatorVersion
    }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-gloo-operator/tests/gloo-operator-ready.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
-->



## Lab 5 - Deploy or upgrade Istio using Gloo Operator <a name="lab-5---deploy-or-upgrade-istio-using-gloo-operator-"></a>

## Install Istio

In this section, we will use Gloo Operator to install Istio control planes.




### Install Istio

Install the Istio control plane using the ServiceMeshController:

```bash
kubectl --context "${CLUSTER1}" apply -f - <<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: istio
  namespace: gloo-mesh
spec:
  version: 1.25.3
  installNamespace: istio-system
  cluster: cluster1
  network: cluster1
  dataplaneMode: Ambient
  trustDomain: cluster1
  repository:
    url: oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>
  image:
    repository: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
EOF
kubectl --context "${CLUSTER2}" apply -f - <<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: istio
  namespace: gloo-mesh
spec:
  version: 1.25.3
  installNamespace: istio-system
  cluster: cluster2
  network: cluster2
  dataplaneMode: Ambient
  trustDomain: cluster2
  repository:
    url: oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>
  image:
    repository: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
EOF

kubectl --context "${CLUSTER1}" -n gloo-mesh rollout status deploy gloo-operator
timeout "3m" kubectl --context "${CLUSTER1}" -n istio-system rollout status deploy
kubectl --context "${CLUSTER2}" -n gloo-mesh rollout status deploy gloo-operator
timeout "3m" kubectl --context "${CLUSTER2}" -n istio-system rollout status deploy
```


<details>
  <summary>Install <code>istioctl</code></summary>

Install `istioctl` if not already installed as it will be useful when interfacing with Istio's components.

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
const helpers = require('./tests/chai-exec');
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);

describe("Istio is healthy", () => {
  let cluster1 = process.env.CLUSTER1;
  let cluster2 = process.env.CLUSTER2;

  function checkCluster(cluster) {
    it(`pod should be running in cluster ${cluster}`, () => helpers.checkDeploymentHasPod({ context: cluster, namespace: "istio-system", deployment: 'istiod-gloo' }));

    it(`mutating webhook configuration should be present in cluster ${cluster}`, () => {
      helpers.k8sObjectIsPresent({ context: cluster, namespace: "", k8sType: "mutatingwebhookconfigurations", k8sObj: "istio-sidecar-injector-gloo" });
    });
  }

  checkCluster(cluster1);
  checkCluster(cluster2);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-with-gloo-operator/tests/istio-ready.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->



## Lab 6 - Deploy the httpbin demo app <a name="lab-6---deploy-the-httpbin-demo-app-"></a>
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

```bash,norun-workshop
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
-->



## Lab 7 - Deploy the httpbin demo app <a name="lab-7---deploy-the-httpbin-demo-app-"></a>
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

```bash,norun-workshop
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
  let cluster = process.env.CLUSTER2
  
  let deployments = ["not-in-mesh", "in-mesh"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->



## Lab 8 - Deploy the httpbin demo app <a name="lab-8---deploy-the-httpbin-demo-app-"></a>
[<img src="https://img.youtube.com/vi/w1xB-o_gHs0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/w1xB-o_gHs0 "Video Link")


We're going to deploy the httpbin application to demonstrate several features of Gloo Mesh on cluster CLUSTER2.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app on `cluster1`. The deployment will be called `remote-not-in-mesh` and won't have the sidecar injected, because of the annotation `sidecar.istio.io/inject: "false"` and its traffic won't be redirected to ztunnel because of the annotation `istio.io/dataplane-mode: none`.

```bash
kubectl --context ${CLUSTER2} create ns httpbin
kubectl --context ${CLUSTER2} label namespace httpbin istio.io/dataplane-mode=ambient
kubectl apply --context ${CLUSTER2} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: remote-not-in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: remote-not-in-mesh
  namespace: httpbin
  labels:
    app: remote-not-in-mesh
    service: remote-not-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: remote-not-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: remote-not-in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: remote-not-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: remote-not-in-mesh
        version: v1
        istio.io/dataplane-mode: none
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: remote-not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: remote-not-in-mesh
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

Then, we deploy a second version, which will be called `remote-in-mesh` and will be part of the mesh.

```bash
kubectl apply --context ${CLUSTER2} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: remote-in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: remote-in-mesh
  namespace: httpbin
  labels:
    app: remote-in-mesh
    service: remote-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: remote-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: remote-in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: remote-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: remote-in-mesh
        version: v1
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: remote-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: remote-in-mesh
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

Add another HTTPBin service which is deployed in Ambient.
```bash
kubectl apply --context ${CLUSTER2} -f - <<EOF

apiVersion: v1
kind: ServiceAccount
metadata:
  name: remote-in-ambient
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: remote-in-ambient
  namespace: httpbin
  labels:
    app: remote-in-ambient
    service: remote-in-ambient
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: remote-in-ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: remote-in-ambient
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: remote-in-ambient
      version: v1
  template:
    metadata:
      labels:
        app: remote-in-ambient
        version: v1
        istio.io/dataplane-mode: ambient
        sidecar.istio.io/inject: "false"
        istio-injection: disabled
    spec:
      serviceAccountName: remote-in-ambient
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: remote-in-ambient
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

```bash,norun-workshop
kubectl --context ${CLUSTER2} -n httpbin get pods
```

```,nocopy
NAME                           READY   STATUS    RESTARTS   AGE
remote-in-mesh-5d9d9549b5-qrdgd       2/2     Running   0          11s
remote-in-ambient-5c64bb49cd-m9kwm    1/1     Running   0          4s
remote-not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("httpbin app", () => {
  let cluster = process.env.CLUSTER2
  
  let deployments = ["remote-not-in-mesh", "remote-in-mesh"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
-->



## Lab 9 - Deploy the clients to make requests to other services <a name="lab-9---deploy-the-clients-to-make-requests-to-other-services-"></a>

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
Then, we deploy a second version, which will be called `in-mesh` and will have the sidecar injected (because of the label `istio-injection` in the Pod template)

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: in-mesh
  namespace: clients
---
apiVersion: v1
kind: Service
metadata:
  name: in-mesh
  namespace: clients
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
  namespace: clients
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
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
```
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
  
  let deployments = ["not-in-mesh", "in-mesh", "in-ambient"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "clients", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/clients/deploy-clients/tests/check-clients.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
-->



## Lab 10 - Deploy the clients to make requests to other services <a name="lab-10---deploy-the-clients-to-make-requests-to-other-services-"></a>

We're going to deploy services that we'll use as clients to demonstrate several features of Gloo Mesh.

Run the following commands to deploy the client on `cluster1`. The deployment will be called `client-not-in-mesh` and won't have the sidecar injected, because of the annotation `sidecar.istio.io/inject: "false"` and its traffic won't be redirected to ztunnel because of the annotation `istio.io/dataplane-mode: none`.

```bash
kubectl --context ${CLUSTER1} create ns httpbin

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: client-not-in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: client-not-in-mesh
  namespace: httpbin
  labels:
    app: client-not-in-mesh
    service: client-not-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: client-not-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-not-in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client-not-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: client-not-in-mesh
        version: v1
        istio.io/dataplane-mode: none
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: client-not-in-mesh
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
```
Then, we deploy a second version, which will be called `client-in-mesh` and will have the sidecar injected (because of the label `istio-injection` in the Pod template)

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: client-in-mesh
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: client-in-mesh
  namespace: httpbin
  labels:
    app: client-in-mesh
    service: client-in-mesh
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: client-in-mesh
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-in-mesh
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client-in-mesh
      version: v1
  template:
    metadata:
      labels:
        app: client-in-mesh
        version: v1
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: client-in-mesh
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
EOF
```
Add another client service which is deployed in Ambient.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: client-in-ambient
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: client-in-ambient
  namespace: httpbin
  labels:
    app: client-in-ambient
    service: client-in-ambient
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: client-in-ambient
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-in-ambient
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client-in-ambient
      version: v1
  template:
    metadata:
      labels:
        app: client-in-ambient
        version: v1
        istio.io/dataplane-mode: ambient
        sidecar.istio.io/inject: "false"
        istio-injection: disabled
    spec:
      serviceAccountName: client-in-ambient
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
kubectl --context ${CLUSTER1} -n httpbin get pods
```

```,nocopy
NAME                           READY   STATUS    RESTARTS   AGE
client-in-ambient-5c64bb49cd-w3dmw    1/1     Running   0          4s
client-in-mesh-5d9d9549b5-qrdgd       2/2     Running   0          11s
client-not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("client apps", () => {
  let cluster = process.env.CLUSTER1
  
  let deployments = ["client-not-in-mesh", "client-in-mesh", "client-in-ambient"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/clients/deploy-clients/tests/check-clients.test.js.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
-->



## Lab 11 - Deploy Keycloak <a name="lab-11---deploy-keycloak-"></a>

In many use cases, you need to restrict the access to your applications to authenticated users.

OpenID Connect (OIDC) is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal, if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-Based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

In this lab, we're going to install Keycloak. It will allow us to set up OIDC workflows later.

But, first of all, we're going to deploy Keycloak to persist the data if Keycloak restarts.

```bash
kubectl --context ${CLUSTER1} create namespace gloo-system
kubectl --context ${CLUSTER1} label namespace gloo-system istio.io/dataplane-mode=ambient
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: postgres
  namespace: gloo-system
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: gloo-system
type: Opaque
data:
  POSTGRES_DB: ZGI=
  POSTGRES_USER: YWRtaW4=
  POSTGRES_PASSWORD: YWRtaW4=
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: gloo-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: gloo-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      serviceAccountName: postgres
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
      containers:
        - name: postgres
          image: postgres:13.2-alpine
          imagePullPolicy: 'IfNotPresent'
          ports:
            - containerPort: 5432
          envFrom:
            - secretRef:
                name: postgres-secrets
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
              subPath: postgres
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: gloo-system
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
EOF
```
Let's create the `keycloak` namespace and label it to be part of the mesh:

```bash
kubectl --context ${CLUSTER1} create namespace keycloak
kubectl --context ${CLUSTER1} label namespace keycloak istio.io/dataplane-mode=ambient
```

Wait while Postgres finishes rolling out:

```bash
kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy/postgres

sleep 5
```

Create the database and user for Keycloak:

```bash
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "CREATE DATABASE keycloak;"
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "CREATE USER keycloak WITH PASSWORD 'password';"
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;"
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Postgres", () => {
  it('postgres pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "gloo-system", k8sObj: "postgres" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-keycloak/tests/postgres-available.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
-->

First, we need to define an ID and secret for a "client", which will be the service that delegates to Keycloak for authorization:

```bash
KEYCLOAK_CLIENT=gloo-ext-auth
KEYCLOAK_SECRET=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri
```

We need to store these in a secret accessible by the ext auth service:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-system
type: extauth.solo.io/oauth
stringData:
  client-id: ${KEYCLOAK_CLIENT}
  client-secret: ${KEYCLOAK_SECRET}
EOF
```

We need to supply the initial configuration of the realm we'll use for these labs.
This will include the client with the ID and secret we defined above, as well as two users that we can use later:

- User1 credentials: `user1/password`
  Email: user1@example.com

- User2 credentials: `user2/password`
  Email: user2@solo.io

Create this configuration in a `ConfigMap`:

```bash
kubectl --context ${CLUSTER1} create namespace keycloak

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
data:
  workshop-realm.json: |-
    {
      "realm": "workshop",
      "enabled": true,
      "displayName": "solo.io",
      "accessTokenLifespan": 1800,
      "sslRequired": "none",
      "users": [
        {
          "username": "user1",
          "enabled": true,
          "email": "user1@example.com",
          "attributes": {
            "group": [
              "users"
            ],
            "subscription": [
              "enterprise"
            ]
          },
          "credentials": [
            {
              "type": "password",
              "secretData": "{\"value\":\"JsfNbCOIdZUbyBJ+BT+VoGI91Ec2rWLOvkLPDaX8e9k=\",\"salt\":\"P5rtFkGtPfoaryJ6PizUJw==\",\"additionalParameters\":{}}",
              "credentialData": "{\"hashIterations\":27500,\"algorithm\":\"pbkdf2-sha256\",\"additionalParameters\":{}}"
            }
          ]
        },
        {
          "username": "user2",
          "enabled": true,
          "email": "user2@solo.io",
          "attributes": {
            "group": [
              "users"
            ],
            "subscription": [
              "free"
            ],
            "show_personal_data": [
              "false"
            ]
          },
          "credentials": [
            {
              "type": "password",
              "secretData": "{\"value\":\"RITBVPdh5pvXOa4JzJ5pZTE0rG96zhnQNmSsKCf83aU=\",\"salt\":\"drB9e5Smf3cbfUfF3FUerw==\",\"additionalParameters\":{}}",
              "credentialData": "{\"hashIterations\":27500,\"algorithm\":\"pbkdf2-sha256\",\"additionalParameters\":{}}"
            }
          ]
        },
        {
          "username": "admin1",
          "enabled": true,
          "email": "admin1@solo.io",
          "attributes": {
            "group": [
              "admin"
            ],
            "show_personal_data": [
              "false"
            ]
          },
          "credentials": [
            {
              "type": "password",
              "secretData" : "{\"value\":\"BruFLfFkjH/8erZ26NnrbkOrWiZuQyDRCHD9o0R6Scg=\",\"salt\":\"Cf9AYCE5pAbb4CKEF0GUTA==\",\"additionalParameters\":{}}",
              "credentialData" : "{\"hashIterations\":5,\"algorithm\":\"argon2\",\"additionalParameters\":{\"hashLength\":[\"32\"],\"memory\":[\"7168\"],\"type\":[\"id\"],\"version\":[\"1.3\"],\"parallelism\":[\"1\"]}}"
            }
          ]
        }
      ],
      "clients": [
        {
          "clientId": "${KEYCLOAK_CLIENT}",
          "secret": "${KEYCLOAK_SECRET}",
          "redirectUris": [
            "*"
          ],
          "webOrigins": [
            "+"
          ],
          "authorizationServicesEnabled": true,
          "directAccessGrantsEnabled": true,
          "serviceAccountsEnabled": true,
          "protocolMappers": [
            {
              "name": "group",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "claim.name": "group",
                "user.attribute": "group",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            },
            {
              "name": "show_personal_data",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "claim.name": "show_personal_data",
                "user.attribute": "show_personal_data",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            },
            {
              "name": "subscription",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "claim.name": "subscription",
                "user.attribute": "subscription",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            },
            {
              "name": "name",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-property-mapper",
              "config": {
                "claim.name": "name",
                "user.attribute": "username",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            }
          ]
        }
      ],
      "components": {
        "org.keycloak.userprofile.UserProfileProvider": [
          {
            "providerId": "declarative-user-profile",
            "config": {
              "kc.user.profile.config": [
                "{\"attributes\":[{\"name\":\"username\"},{\"name\":\"email\"}],\"unmanagedAttributePolicy\":\"ENABLED\"}"
              ]
            }
          }
        ]
      }
    }
  portal-realm.json: |
    {
      "realm": "portal-mgmt",
      "enabled": true,
      "sslRequired": "none",
      "roles": {
        "client": {
          "gloo-portal-idp": [
            {
              "name": "uma_protection",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ]
        },
        "realm": [
          {
            "name": "default-roles-portal-mgmt",
            "description": "${role_default-roles}",
            "composite": true,
            "composites": {
              "realm": [
                "offline_access",
                "uma_authorization"
              ],
              "client": {
                "account": [
                  "manage-account",
                  "view-profile"
                ]
              }
            },
            "clientRole": false,
            "attributes": {}
          },
          {
            "name": "uma_authorization",
            "description": "${role_uma_authorization}",
            "composite": false,
            "clientRole": false
          }
        ]
      },
      "users": [
        {
          "username": "service-account-gloo-portal-idp",
          "createdTimestamp": 1727724261768,
          "emailVerified": false,
          "enabled": true,
          "totp": false,
          "serviceAccountClientId": "gloo-portal-idp",
          "disableableCredentialTypes": [],
          "requiredActions": [],
          "realmRoles": [
            "default-roles-portal-mgmt"
          ],
          "clientRoles": {
            "realm-management": [
              "manage-clients"
            ],
            "gloo-portal-idp": [
              "uma_protection"
            ]
          },
          "notBefore": 0,
          "groups": []
        }
      ],
      "clients": [
        {
          "clientId": "gloo-portal-idp",
          "enabled": true,
          "name": "Solo.io Gloo Portal Resource Server",
          "clientAuthenticatorType": "client-secret",
          "secret": "gloo-portal-idp-secret",
          "serviceAccountsEnabled": true,
          "authorizationServicesEnabled": true,
          "authorizationSettings": {
            "allowRemoteResourceManagement": true,
            "policyEnforcementMode": "ENFORCING",
            "resources": [
              {
                "name": "Default Resource",
                "type": "urn:gloo-portal-idp:resources:default",
                "ownerManagedAccess": false,
                "attributes": {},
                "uris": [
                  "/*"
                ]
              }
            ],
            "policies": [
              {
                "name": "Default Policy",
                "description": "A policy that grants access only for users within this realm",
                "type": "regex",
                "logic": "POSITIVE",
                "decisionStrategy": "AFFIRMATIVE",
                "config": {
                  "targetContextAttributes" : "false",
                  "pattern" : ".*",
                  "targetClaim" : "sub"
                }
              },
              {
                "name": "Default Permission",
                "description": "A permission that applies to the default resource type",
                "type": "resource",
                "logic": "POSITIVE",
                "decisionStrategy": "UNANIMOUS",
                "config": {
                  "defaultResourceType": "urn:gloo-portal-idp:resources:default",
                  "applyPolicies": "[\"Default Policy\"]"
                }
              }
            ],
            "scopes": [],
            "decisionStrategy": "UNANIMOUS"
          }
        }
      ]
    }
kind: ConfigMap
metadata:
  name: realms
  namespace: keycloak
EOF
```

Now let's install Keycloak:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
        image: quay.io/keycloak/keycloak:25.0.5
        args:
        - start-dev
        - --import-realm
        - --proxy-headers=xforwarded
        - --features=hostname:v1
        - --hostname-strict=false
        - --hostname-strict-https=false
        env:
        - name: KEYCLOAK_ADMIN
          value: admin
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: admin
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://postgres.gloo-system.svc.cluster.local:5432/keycloak
        - name: KC_DB_USERNAME
          value: keycloak
        - name: KC_DB_PASSWORD
          value: password
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /realms/workshop
            port: 8080
        volumeMounts:
        - name: realms
          mountPath: /opt/keycloak/data/import
      volumes:
      - name: realms
        configMap:
          name: realms
EOF
```

Wait while Keycloak finishes rolling out:

```bash
kubectl --context ${CLUSTER1} -n keycloak rollout status deploy/keycloak
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Keycloak", () => {
  it('keycloak pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "keycloak", k8sObj: "keycloak" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
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
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-keycloak/tests/keycloak-ip-is-attached.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
-->
<!--bash
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n keycloak get svc keycloak -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

Let's set the environment variables we need:

```bash
export ENDPOINT_KEYCLOAK=$(kubectl --context ${CLUSTER1} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):8080
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
-->
<!--bash
echo "Waiting for Keycloak to be ready at $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token"
timeout 300 bash -c 'while [[ "$(curl -m 2 -s -o /dev/null -w ''%{http_code}'' $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token)" != "405" ]]; do printf '.';sleep 1; done' || false
-->



## Lab 12 - Deploy Gloo Gateway Enterprise <a name="lab-12---deploy-gloo-gateway-enterprise-"></a>


You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
```
Let's create the `gloo-system` namespace and label it to be part of the mesh:

```bash
kubectl --context $CLUSTER1 create namespace gloo-system
kubectl --context $CLUSTER1 label namespace gloo-system istio.io/dataplane-mode=ambient
```


Next install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash
helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.19.0 \
  --kube-context $CLUSTER1 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF
gloo:
  kubeGateway:
    enabled: true
    gatewayParameters:
      glooGateway:
        podTemplate:
          gracefulShutdown:
            enabled: true
          livenessProbeEnabled: true
          probes: true
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gateway:
    validation:
      allowWarnings: true
      alwaysAcceptResources: false
      livenessProbeEnabled: true
  gloo:
    logLevel: info
    deployment:
      customEnv:
        - name: ENABLE_WAYPOINTS
          value: "true"
        - name: GG_AMBIENT_MULTINETWORK
          value: "true"
      livenessProbeEnabled: true
  discovery:
    enabled: false
observability:
  enabled: false
prometheus:
  enabled: false
grafana:
  defaultInstallationEnabled: false
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
global:
  extensions:
    caching:
      enabled: true
ambient:
  waypoint:
    enabled: true
EOF
kubectl --context $CLUSTER1 patch settings default -n gloo-system --type json \
  -p '[{ "op": "remove", "path": "/spec/cachingServer" }]'
```




We've deployed Ambient and Gloo Gateway is part of the mesh. Ingress capture can be disabled. This is done by setting the `ambient.istio.io/bypass-inbound-capture": "true"` annotation on the proxy pods.

```bash
kubectl --context $CLUSTER1 patch gatewayparameters gloo-gateway -n gloo-system --type merge -p '{
  "spec": {
    "kube": {
      "podTemplate": {
        "extraAnnotations": {
          "ambient.istio.io/bypass-inbound-capture": "true"
        }
      }
    }
  }
}'
```


Run the following command to check that the Gloo Gateway pods are running:

<!--bash
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER1 -n gloo-system rollout status deployment
-->
```bash
kubectl --context $CLUSTER1 -n gloo-system get pods
```

Here is the expected output:

```,nocopy
NAME                                         READY   STATUS      RESTARTS   AGE
caching-service-79cf55ccbb-dcvgp             1/1     Running     0          69s
extauth-58f68c5cd5-gxgxc                     1/1     Running     0          69s
gateway-portal-web-server-5c5d58d8d5-7lzwg   1/1     Running     0          69s
gloo-7d8994697-lfg5x                         1/1     Running     0          69s
gloo-resource-rollout-check-x8b77            0/1     Completed   0          69s
gloo-resource-rollout-cjtgh                  0/1     Completed   0          69s
rate-limit-6db9c67794-vf7h2                  1/1     Running     0          69s
redis-6c7c489d8c-g2dhc                       1/1     Running     0          69s
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER1;
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
-->



## Lab 13 - Deploy the httpbin demo app <a name="lab-13---deploy-the-httpbin-demo-app-"></a>


We're going to deploy the httpbin application to demonstrate several features of Gloo Gateway.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app twice (`httpbin1` and `httpbin2`).

```bash
kubectl --context ${CLUSTER1} create ns httpbin
kubectl --context ${CLUSTER1} label namespace httpbin istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} apply -f data/steps/gloo-gateway/deploy-httpbin/app-httpbin1.yaml
kubectl --context ${CLUSTER1} apply -f data/steps/gloo-gateway/deploy-httpbin/app-httpbin2.yaml
```

<details>
  <summary>Show yaml files</summary>

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: httpbin1
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin1
  namespace: httpbin
  labels:
    app: httpbin1
    service: httpbin1
spec:
  ports:
  - name: http
    port: 8000
    targetPort: http
    protocol: TCP
    appProtocol: http
  selector:
    app: httpbin1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin1
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin1
      version: v1
  template:
    metadata:
      labels:
        app: httpbin1
        version: v1
    spec:
      serviceAccountName: httpbin1
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.14.0
        command: [ go-httpbin ]
        args:
          - "-max-duration"
          - "600s" # override default 10s
          - -use-real-hostname
        ports:
          - name: http
            containerPort: 8080
            protocol: TCP
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http
        env:
        - name: K8S_MEM_LIMIT
          valueFrom:
            resourceFieldRef:
              divisor: "1"
              resource: limits.memory
        - name: GOMAXPROCS
          valueFrom:
            resourceFieldRef:
              divisor: "1"
              resource: limits.cpu
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: httpbin2
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin2
  namespace: httpbin
  labels:
    app: httpbin2
    service: httpbin2
spec:
  ports:
  - name: http
    port: 8000
    targetPort: http
    protocol: TCP
    appProtocol: http
  selector:
    app: httpbin2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin2
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin2
      version: v1
  template:
    metadata:
      labels:
        app: httpbin2
        version: v1
    spec:
      serviceAccountName: httpbin2
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.14.0
        command: [ go-httpbin ]
        args:
          - "-max-duration"
          - "600s" # override default 10s
          - -use-real-hostname
        ports:
          - name: http
            containerPort: 8080
            protocol: TCP
        livenessProbe:
          httpGet:
            path: /status/200
            port: http
        readinessProbe:
          httpGet:
            path: /status/200
            port: http
        env:
        - name: K8S_MEM_LIMIT
          valueFrom:
            resourceFieldRef:
              divisor: "1"
              resource: limits.memory
        - name: GOMAXPROCS
          valueFrom:
            resourceFieldRef:
              divisor: "1"
              resource: limits.cpu
```
</details>

You can follow the progress using the following command:

<!--bash
echo -n Waiting for httpbin pods to be ready...
kubectl --context ${CLUSTER1} -n httpbin rollout status deployment
-->
```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin get pods
```

Here is the expected output when both Pods are ready:

```,nocopy
NAME                        READY   STATUS    RESTARTS   AGE
httpbin1-7fdbf6498-ms7qt    1/1     Running   0          94s
httpbin2-655777b846-6nrms   1/1     Running   0          93s
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("httpbin app", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["httpbin1", "httpbin2"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
-->




## Lab 14 - Expose the httpbin application through the gateway <a name="lab-14---expose-the-httpbin-application-through-the-gateway-"></a>




The team in charge of the gateway can create a `Gateway` resource and configure an HTTP listener.




```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
  namespace: gloo-system
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 80
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF
```

Note that application teams can create and attach their `HTTPRoute` to this gateway.

An application team can create an `HTTPRoute` resource to expose the `httpbin` app on the gateway.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: http
  hostnames:
    - "httpbin.example.com"
  rules:
    - backendRefs:
        - name: httpbin1
          port: 8000
EOF
```




Set the environment variable for the service corresponding to the gateway:

```bash
export PROXY_IP=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
```

<!--bash
RETRY_COUNT=0
MAX_RETRIES=60
while true; do
  GLOO_PROXY_SVC=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -oname 2>/dev/null || echo "")
  if [[ -n "$GLOO_PROXY_SVC" ]]; then
    echo "Service gloo-proxy-http has been created."
    break
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ $RETRY_COUNT -ge $MAX_RETRIES ]]; then
    echo "Warning: Maximum retries reached. Service gloo-proxy-http could not be found."
    break
  fi

  echo "Waiting for service gloo-proxy-http to be created... Attempt $RETRY_COUNT/$MAX_RETRIES"
  sleep 1
done

# Then, wait for the IP to be assigned
RETRY_COUNT=0
MAX_RETRIES=60
while [[ -z "$PROXY_IP" && $RETRY_COUNT -lt $MAX_RETRIES && -n "$GLOO_PROXY_SVC" ]]; do
  echo "Waiting for PROXY_IP to be assigned... Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
  PROXY_IP=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
  RETRY_COUNT=$((RETRY_COUNT + 1))
  sleep 5
done

# if PROXY_IP is a hostname, resolve it to an IP address
if [[ -n "$PROXY_IP" && $PROXY_IP =~ [a-zA-Z] ]]; then
  while [[ -z "$IP" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    echo "Waiting for PROXY_IP to be propagated in DNS... Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
    IP=$(dig +short A "$PROXY_IP" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print; exit}')
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 5
  done
else
  IP="$PROXY_IP"
fi

if [[ -z "$PROXY_IP" ]]; then
  echo "WARNING: Maximum number of retries reached. PROXY_IP could not be assigned."
else
  export PROXY_IP
  export IP
  echo "PROXY_IP has been assigned: $PROXY_IP"
  echo "IP has been resolved to: $IP"
fi
-->
Configure your hosts file to resolve httpbin.example.com with the IP address of the proxy by executing the following command:


```bash
./scripts/register-domain.sh httpbin.example.com ${IP}
```



Try to access the application through HTTP:

```bash,norun-workshop
curl http://httpbin.example.com/get
```

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Host": [
      "httpbin.example.com"
    ],
    "User-Agent": [
      "curl/8.5.0"
    ],
    "X-Forwarded-Proto": [
      "http"
    ],
    "X-Request-Id": [
      "d0998a48-7532-4eeb-ab69-23cef22185cf"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:38917",
  "url": "http://httpbin.example.com/get"
}
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/expose-httpbin/tests/http.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
-->

Now, let's secure the access through TLS.
Let's first create a private key and a self-signed certificate:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

Then, you have to store it in a Kubernetes secret running the following command:

```bash
kubectl create --context ${CLUSTER1} -n gloo-system secret tls tls-secret --key tls.key \
   --cert tls.crt
```
Update the `Gateway` resource to add HTTPS listeners.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
  namespace: gloo-system
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTPS
    port: 443
    name: https-httpbin
    hostname: httpbin.example.com
    tls:
      mode: Terminate
      certificateRefs:
        - name: tls-secret
          kind: Secret
    allowedRoutes:
      namespaces:
        from: All
  - protocol: HTTPS
    port: 443
    name: https
    tls:
      mode: Terminate
      certificateRefs:
        - name: tls-secret
          kind: Secret
    allowedRoutes:
      namespaces:
        from: All
  - protocol: HTTP
    port: 80
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF
```

As you can see, we've added 2 new listeners. One for the `httpbin.example.com` hostname and one for all the other hostnames.

We used the same secret to keep things simple, but the goal is to demonstrate we can have different HTTPS listeners.

Update the `HTTPRoute` resource to expose the `httpbin` app through HTTPS.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https-httpbin
  hostnames:
    - "httpbin.example.com"
  rules:
    - backendRefs:
        - name: httpbin1
          port: 8000
EOF
kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy gloo-proxy-http
```


Try to access the application through HTTPS (might take a few seconds to be ready):

<!--bash
echo -n Wait for up to 2 minutes until the url is ready...
RETRY_COUNT=0
MAX_RETRIES=30
while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  echo "Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
  ret=`curl -k -s -o /dev/null -w %{http_code} https://httpbin.example.com/get`
  if [ "$ret" -eq "200" ]; then
    break
  else
    echo "Response was: $ret"
    echo "Retrying in 4 seconds..."
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  sleep 4
done
-->

```bash,norun-workshop
curl -k https://httpbin.example.com/get
```

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Host": [
      "httpbin.example.com"
    ],
    "User-Agent": [
      "curl/8.5.0"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "8e61c480-6373-4c38-824b-2bfe89e79d0c"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:52655",
  "url": "https://httpbin.example.com/get"
}
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/expose-httpbin/tests/https.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
-->


The team in charge of the gateway can create an `HTTPRoute` to automatically redirect HTTP to HTTPS:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: redirect-http-to-https
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: http
  hostnames:
    - "httpbin.example.com"
  rules:
    - filters:
      - type: RequestRedirect
        requestRedirect:
          scheme: https
EOF
```

Try to access the application through HTTP:

```bash,norun-workshop
curl -k http://httpbin.example.com/get -L
```

The `-L` option instructs curl to follow the redirect. Without it, you would get a `302` response with the `location` header set to the HTTPS url.

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Host": [
      "httpbin.example.com"
    ],
    "User-Agent": [
      "curl/8.5.0"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "2c7454cb-c2f8-428c-9c3b-f51822475327"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:52655",
  "url": "https://httpbin.example.com/get"
}
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/expose-httpbin/tests/redirect-http-to-https.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
-->






## Lab 15 - Delegate with control <a name="lab-15---delegate-with-control-"></a>

The team in charge of the gateway can create a parent `HTTPRoute` to delegate the routing of a domain or a path prefix (for example) to an application team.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https-httpbin
  hostnames:
    - "httpbin.example.com"
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF
```

The team in charge of the httpbin application can now create a child `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

Check you can still access the application through HTTPS:

```bash,norun-workshop
curl -k https://httpbin.example.com/get
```

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Host": [
      "httpbin.example.com"
    ],
    "User-Agent": [
      "curl/8.5.0"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "11037632-92c8-43c7-b919-7d7c7217c564"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:51121",
  "url": "https://httpbin.example.com/get"
}
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

In the previous example, we've used a simple `/` prefix matcher for both the parent and the child `HTTPRoute`.

But we'll often use the delegation capability to delegate a specific path to an application team.

For example, let's say the team in charge of the gateway wants to delegate the `/status` prefix to the team in charge of the httpbin application.

Let's update the parent `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https-httpbin
  hostnames:
    - "httpbin.example.com"
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /status
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF
```

Now, we can update the child `HTTPRoute` to match requests with the `/status/200` path:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: Exact
          value: /status/200
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

Check you can access the `/status/200` path:

```bash,norun-workshop
curl -k https://httpbin.example.com/status/200 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
200
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

In the child `HTTPRoute` we've indicated the absolute path (which includes the parent path), but instead we can inherite the parent matcher and use a relative path:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  annotations:
    delegation.gateway.solo.io/inherit-parent-matcher: "true"
spec:
  rules:
    - matches:
      - path:
          type: Exact
          value: /200
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

Check you can still access the `/status/200` path:

```bash,norun-workshop
curl -k https://httpbin.example.com/status/200 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
200
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

The team in charge of the httpbin application can also take advantage of the `parentRefs` option to indicate which parent `HTTPRoute` can delegate to its own `HTTPRoute`.

That's why you don't need to use `ReferenceGrant` objects when using delegation.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  annotations:
    delegation.gateway.solo.io/inherit-parent-matcher: "true"
spec:
  parentRefs:
    - name: httpbin
      namespace: gloo-system
      group: gateway.networking.k8s.io
      kind: HTTPRoute
  rules:
    - matches:
      - path:
          type: Exact
          value: /200
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

Check you can still access the `/status/200` path:

```bash,norun-workshop
curl -k https://httpbin.example.com/status/200 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
200
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

Delegation offers another very nice feature. It automatically reorders all the matchers to avoid any short-circuiting.

Let's add a second child `HTTPRoute` which is matching for any request starting with the path `/status`, but sends the requests to the second httpbin service.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-status
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /status
      backendRefs:
        - name: httpbin2
          port: 8000
EOF
```

If the matcher for `/status` is positioned before the matcher for `/status/200`, the latter would be ignored. So, all the requests would be sent to the second httpbin service.

Check you can still access the `/status/200` path:

```bash,norun-workshop
curl -k https://httpbin.example.com/status/200 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
200
```

You can use the following command to validate the request has still been handled by the first httpbin application.

```bash,norun-workshop
kubectl logs --context ${CLUSTER1} -n httpbin -l app=httpbin1 | grep curl | grep 200
```

You should get an output similar to:

```log,nocopy
time="2024-07-22T16:02:51.9508" status=200 method="GET" uri="/status/200" size_bytes=0 duration_ms=0.03 user_agent="curl/7.81.0" client_ip=10.101.0.13:58114
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

Check you can now also access the status `/status/201` path:

```bash,norun-workshop
curl -k https://httpbin.example.com/status/201 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
201
```

You can use the following command to validate this request has been handled by the second httpbin application.

```bash,norun-workshop
kubectl logs --context ${CLUSTER1} -n httpbin -l app=httpbin2 | grep curl | grep 201
```

You should get an output similar to:

```log,nocopy
time="2024-07-22T16:04:53.3189" status=201 method="GET" uri="/status/201" size_bytes=0 duration_ms=0.02 user_agent="curl/7.81.0" client_ip=10.101.0.13:52424
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'201\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/201', retCode: 201 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-201.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

Let's delete the latest `HTTPRoute` and apply the original ones:

```bash
kubectl delete --context ${CLUSTER1} -n httpbin httproute httpbin-status

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https-httpbin
  hostnames:
    - "httpbin.example.com"
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->



## Lab 16 - Use the `cache-control` response header to cache responses <a name="lab-16---use-the-`cache-control`-response-header-to-cache-responses-"></a>

An HTTP or HTTPS listener on your gateway can be configured to cache responses for upstream services.
When the listener routes a request to an upstream service, the response from the upstream is automatically cached by the caching server if it contains a `cache-control` response header.
All subsequent requests receive the cached response until the cache entry expires.

Check that we have a caching service running in the Gloo Gateway installation:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n gloo-system get deploy caching-service
```

You should see a healthy deployment of the caching service:

```,nocopy
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
caching-service   1/1     1            1           166m
```

This service is responsible for creating the cached responses in the backing Redis datastore when an eligible response is being processed.

The **httpbin** application has some utility endpoints we can use to test that caching is applied.
First of all, let's make sure that caching is *not* being applied by making a request to the `/cache` endpoint, passing a cache time-to-live (TTL) value of 10 seconds that we want the service to use in the response `cache-control` header:

```bash,norun-workshop
curl -ksSD - -o /dev/null https://httpbin.example.com/cache/10
```

We'll get a response like this back, which includes the `cache-control` header set by the application with a value `max-age=10`:

```http,nocopy
HTTP/2 200
access-control-allow-credentials: true
access-control-allow-origin: *
cache-control: public, max-age=10
content-type: application/json; charset=utf-8
date: Mon, 29 Jul 2024 14:10:48 GMT
content-length: 513
x-envoy-upstream-service-time: 0
server: envoy
```

Send a second request within that cache TTL of 10 seconds and look at the response:

```bash,norun-workshop
curl -ksSD - -o /dev/null https://httpbin.example.com/cache/10
```

```http,nocopy
HTTP/2 200
access-control-allow-credentials: true
access-control-allow-origin: *
cache-control: public, max-age=10
content-type: application/json; charset=utf-8
date: Mon, 29 Jul 2024 14:10:53 GMT
content-length: 513
x-envoy-upstream-service-time: 0
server: envoy
```

See that the timestamp in the `date` headers of the two responses are different, meaning that we got a fresh response back from the **httpbin** application each time.



In this example we'll configure caching on all routes processed by the `Gateway` that we have already set up.
We do this by defining a `HttpListenerOption` resource that includes a reference to the caching server:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: HttpListenerOption
metadata:
  name: cache
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    caching:
      cachingServiceRef:
        name: caching-service
        namespace: gloo-system
EOF
```

Note that this refers to the `Gateway` resource as a whole, so it will apply to all listeners on that gateway.
We can also restrict it to a particular listener by including a value for `sectionName` corresponding to the `name` of a given listener.

Let's test this configuration by making three requests to the `/cache` endpoint with a 10s cache TTL value, waiting 6 seconds between requests:

```bash,norun-workshop
curl -ksSD - -o /dev/null https://httpbin.example.com/cache/10
sleep 6
curl -ksSD - -o /dev/null https://httpbin.example.com/cache/10
sleep 6
curl -ksSD - -o /dev/null https://httpbin.example.com/cache/10
```

Check the responses:

```http,nocopy
HTTP/2 200
access-control-allow-credentials: true
access-control-allow-origin: *
cache-control: public, max-age=10
content-type: application/json; charset=utf-8
date: Mon, 29 Jul 2024 14:25:05 GMT
content-length: 513
x-envoy-upstream-service-time: 0
server: envoy

HTTP/2 200
access-control-allow-credentials: true
cache-control: public, max-age=10
x-envoy-upstream-service-time: 0
access-control-allow-origin: *
date: Mon, 29 Jul 2024 14:25:05 GMT
content-type: application/json; charset=utf-8
content-length: 513
age: 6
server: envoy

HTTP/2 200
access-control-allow-credentials: true
access-control-allow-origin: *
cache-control: public, max-age=10
content-type: application/json; charset=utf-8
date: Mon, 29 Jul 2024 14:25:17 GMT
content-length: 513
x-envoy-upstream-service-time: 0
server: envoy
```



Notice that the first two responses have the same `date` header showing that the response for the first request was also returned as the response for the second request.
The second response also has a new `age` header, corresponding to how long the response has been cached for.

The third response has a different `date` timestamp and no `age` header:
this request was made 12 seconds after the first, but the cache entry had expired 10 seconds after the original request, so the third request did not receive a cached response.

Let's delete the `HttpListenerOption` we created:

```bash
kubectl --context ${CLUSTER1} -n gloo-system delete httplisteneroption cache
```



## Lab 17 - Deploy and use waypoint <a name="lab-17---deploy-and-use-waypoint-"></a>



Istio Ambient Mesh is using a proxy called [Waypoint](https://ambientmesh.io/docs/about/architecture/#gateways-and-waypoints) (based on Envoy) to provide L7 capabilities.

You can use Gloo Gateway as a Waypoint to get even more L7 features available.

To demonstrate it, let's deploy a Waypoint proxy in the `httpbin` namespace.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gloo-waypoint
  namespace: httpbin
spec:
  gatewayClassName: gloo-waypoint
  listeners:
  - name: proxy
    port: 15088
    protocol: istio.io/PROXY
  - name: hbone
    port: 15008
    protocol: istio.io/HBONE
EOF
```

Run the following command to check the Waypoint has been deployed correctly:

```bash
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-gloo-waypoint
```

You should get this output:

```,nocopy
deployment "gloo-proxy-gloo-waypoint" successfully rolled out
```

Then, let's label the `httpbin2` service to use this Waypoint proxy.

```bash
kubectl --context ${CLUSTER1} label namespace httpbin istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} -n httpbin label svc httpbin2 istio.io/use-waypoint=gloo-waypoint
```

We need a client to send request to the `httpbin2` service:

```bash
kubectl --context ${CLUSTER1} apply -f data/steps/gloo-gateway/waypoint/netshoot.yaml
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client
```

<details>
  <summary>Show yaml files</summary>

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: client
  namespace: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: client
  namespace: httpbin
  labels:
    app: client
    service: client
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: client
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
      version: v1
  template:
    metadata:
      labels:
        app: client
        version: v1
    spec:
      serviceAccountName: client
      containers:
      - image: nicolaka/netshoot:latest
        imagePullPolicy: IfNotPresent
        name: netshoot
        command: ["/bin/bash"]
        args: ["-c", "while true; do ping localhost; sleep 60;done"]
```
</details>

Now, let's demonstrate how to leverage the Waypoint proxy.

First of all, you can use the standard features provided by a standard waypoint.

Let's start with L7 Authorization.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: httpbin2
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client
    to:
    - operation:
        methods: ["GET"]
EOF
```

This policy means that only the client can send requests to `httpbin2`, and only GET requests.

Try to send a POST request:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s -X POST http://httpbin2:8000/post
```

You'll get an `RBAC: access denied` response.
Try to send a GET request:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get
```

This time it works !

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

describe("AuthorizationPolicy is working properly", function() {
  it("The client isn't allowed to send POST requests", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -m 2 --max-time 2 -s -X POST -o /dev/null -w "%{http_code}" "http://httpbin2:8000/post"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('403');
  });
  it("The client is allowed to send GET requests", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -m 2 --max-time 2 -s -o /dev/null -w "%{http_code}" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('200');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/waypoint/tests/authorization.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

Let's delete the policy:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete authorizationpolicy allow-get-only
```


The Kubernetes Gateway API provides different options to add/update/remove request and response headers.

Let's try with request headers.

Update the `HTTPRoute` resource to do the following:
- add a new header `Foo` with the value `bar`
- update the value of the header `User-Agent` to `custom`
- remove the `To-Remove` header

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin2
  namespace: httpbin
spec:
  parentRefs:
  - name: gloo-waypoint
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin2
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: Foo
                value: bar
            set:
              - name: User-Agent
                value: custom
            remove:
              - To-Remove
EOF
```

Try to access the application (with the `To-Remove` request header added):

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get -H 'To-Remove: whatever'
```

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
    ...
    "Foo": [
      "bar"
    ],
    ...
    "User-Agent": [
      "custom"
    ],
    ...
  },
  ...
}
```

The transformations have been applied as expected.

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

describe("request transformations applied", function() {
  it('Checking text \'bar\'', () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('bar');
  });
  it('Checking text \'custom\'', () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('custom');
  });
  it('Checking text \'To-Remove\'', () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.not.to.contain('To-Remove');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/waypoint/tests/request-headers.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

Gloo Gateway provides some [extensions](https://docs.solo.io/gateway/latest/traffic-management/transformations/) to manipulate requests and responses in a more advanced way.

Let's extract the product name from the `User-Agent` header (getting rid of the product version and comments).

For example, if a request comes in with a User-Agent header like `curl/8.5.0 (x86_64-pc-linux-gnu) OpenSSL`, we want to extract just the product name `curl` and store it in a new header called `X-Client`.

To do this, we'll use a regular expression with a capture group to extract just the product name before any version numbers or additional information:
- The regex pattern `^([^/\s]+).*` matches:
  - `^` - start of string
  - `([^/\s]+)` - capture group containing one or more characters that are not forward slashes or whitespace
  - `.*` - followed by any remaining characters
- The captured value from group 1 will be stored in the `client` variable
- This variable is then used to set the `X-Client` header

To do that we need to create a Gloo Gateway `RouteOption` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin2
  options:
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            transformationTemplate:
              extractors:
                client:
                  header: 'User-Agent'
                  regex: '^([^/\s]+).*'
                  subgroup: 1
              headers:
                x-client:
                  text: "{{ client }}"
EOF
```

Try to access the application:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get
```

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
...
    ],
    "User-Agent": [
      "custom"
    ],
    "X-Client": [
      "curl"
    ],
...
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
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("request transformations applied", function() {
  it('Checking text \'X-Client\'', () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s -H "User-agent: curl/8.5.0" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('X-Client');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/waypoint/tests/x-client-request-header.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

As you can see, we've created a new header called `X-Client` by extracting some data from the `User-Agent` header using a regular expression.

And we've targetted the `HTTPRoute` using the `targetRefs` of the `RouteOption` object. With this approach, it applies to all its rules.

We can also use the [extauth capabilities](https://docs.solo.io/gateway/latest/security/extauth/basic-auth/) of Gloo Gateway. Let's secure the access to the `httpbin2` service using Api keys.

First, we need to create an `AuthConfig`, which is a CRD that contains authentication information. We will create a secret with the apikey as well:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
type: extauth.solo.io/apikey
metadata:
  labels:
    team: product-excellence
  name: global-apikey
  namespace: gloo-system
stringData:
  api-key: apikey1
  organization: solo.io
---
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apikeys
  namespace: httpbin
spec:
  configs:
  - apiKeyAuth:
      headerName: api-key
      labelSelector:
        team: product-excellence
      headersFromMetadataEntry:
        X-Organization:
          name: organization
EOF
```

After that, you need to update the `RouteOption`, to reference the `AuthConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin2
  options:
    extauth:
      configRef:
        name: apikeys
        namespace: httpbin
EOF
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

describe("Authentication with apikeys is working properly", function() {
  it("The httpbin2 service isn't accessible without authenticating", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s -o /dev/null -w "%{http_code}" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('401');
  });
  it("The httpbin2 service is accessible after authenticating", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s -o /dev/null -w "%{http_code}" -H "api-key: apikey1" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('200');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/waypoint/tests/authentication.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

After you've completed these steps, you should be able to access the `httpbin2` service using the api key. You can test this by running the following command:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get -H "api-key: apikey1"
```

You can see the `X-Organization` header added with the value gathered from the secret.

We can also use the [rate limiting capabilities](https://docs.solo.io/gateway/latest/security/ratelimit/) of Gloo Gateway. Ideally we want to use information that is produced by the gateway, so it can't be manipulated by the client easily. The header `X-Organization` is a good candidate for this.


We're going to apply rate limiting to the Gateway to only allow 3 requests per minute for the users of the `solo.io` organization.



First, we need to create a `RateLimitConfig` object to define the limits:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: limit-users
  namespace: httpbin
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: organization
            value: solo.io
        rateLimit:
          requestsPerUnit: 3
          unit: MINUTE
    rateLimits:
    - setActions:
      - requestHeaders:
          descriptorKey: organization
          headerName: X-Organization
EOF
```

Finally, you need to update the `RouteOption` to use this `RateLimitConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin2
  options:
    extauth:
      configRef:
        name: apikeys
        namespace: httpbin
    rateLimitConfigs:
      refs:
      - name: limit-users
        namespace: httpbin
EOF
```

Run the following command several times:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get -H "api-key: apikey1" -I
```

You should get a `200` response code the first 3 times and a `429` response code after.

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

describe("Rate limiting is working properly", function() {
  it("The httpbin2 service should be rate limited", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s -o /dev/null -w "%{http_code}" -H "api-key: apikey1" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('429');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/waypoint/tests/rate-limited.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

Let's delete the `RouteOption`:

```bash
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
```

We can also configure caching on all routes processed by the Waypoint that we have already set up.

We do this by defining a `HttpListenerOption` resource that includes a reference to the caching server:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: HttpListenerOption
metadata:
  name: cache
  namespace: httpbin
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: gloo-waypoint
  options:
    caching:
      cachingServiceRef:
        name: caching-service
        namespace: gloo-system
EOF
```

Let's test this configuration by making three requests to the `/cache` endpoint with a 10s cache TTL value, waiting 6 seconds between requests:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -ksSD - -o /dev/null http://httpbin2:8000/cache/10
sleep 6
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -ksSD - -o /dev/null http://httpbin2:8000/cache/10
sleep 6
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -ksSD - -o /dev/null http://httpbin2:8000/cache/10
```

Check the responses:

```http,nocopy
HTTP/1.1 200 OK
access-control-allow-credentials: true
access-control-allow-origin: *
cache-control: public, max-age=10
content-type: application/json; charset=utf-8
date: Tue, 29 Oct 2024 17:00:18 GMT
content-length: 508
x-envoy-upstream-service-time: 0
server: envoy

HTTP/1.1 200 OK
cache-control: public, max-age=10
access-control-allow-origin: *
content-type: application/json; charset=utf-8
content-length: 508
date: Tue, 29 Oct 2024 17:00:18 GMT
x-envoy-upstream-service-time: 0
access-control-allow-credentials: true
age: 6
server: envoy

HTTP/1.1 200 OK
access-control-allow-credentials: true
access-control-allow-origin: *
cache-control: public, max-age=10
content-type: application/json; charset=utf-8
date: Tue, 29 Oct 2024 17:00:30 GMT
content-length: 508
x-envoy-upstream-service-time: 0
server: envoy
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

describe("Caching", function() {
  it("returns a cached response within cache TTL", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -ksSD - -o /dev/null "http://httpbin2:8000/cache/10"`;
    let cli = chaiExec(command);
    expect(cli).output.to.contain('age:');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/waypoint/tests/caching-applies.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

Notice that the first two responses have the same `date` header showing that the response for the first request was also returned as the response for the second request.
The second response also has a new `age` header, corresponding to how long the response has been cached for.

The third response has a different `date` timestamp and no `age` header:
this request was made 12 seconds after the first, but the cache entry had expired 10 seconds after the original request, so the third request did not receive a cached response.

Let's delete the resources we've created:

```bash
kubectl delete --context ${CLUSTER1} -n httpbin ratelimitconfig limit-users
kubectl delete --context ${CLUSTER1} -n httpbin authconfig apikeys
kubectl delete --context ${CLUSTER1} -n gloo-system secret global-apikey
kubectl delete --context ${CLUSTER1} -n httpbin httproute httpbin2
kubectl delete --context ${CLUSTER1} -n httpbin httplisteneroption cache
```



## Lab 18 - Deploy Gloo Gateway Enterprise <a name="lab-18---deploy-gloo-gateway-enterprise-"></a>


You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER2 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
```
Let's create the `gloo-system` namespace and label it to be part of the mesh:

```bash
kubectl --context $CLUSTER2 create namespace gloo-system
kubectl --context $CLUSTER2 label namespace gloo-system istio.io/dataplane-mode=ambient
```


Next install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash
helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.19.0 \
  --kube-context $CLUSTER2 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF
gloo:
  kubeGateway:
    enabled: true
    gatewayParameters:
      glooGateway:
        podTemplate:
          gracefulShutdown:
            enabled: true
          livenessProbeEnabled: true
          probes: true
  gatewayProxies:
    gatewayProxy:
      disabled: false
      podTemplate:
        gracefulShutdown:
          enabled: true
        livenessProbeEnabled: true
        probes: true
  gateway:
    validation:
      allowWarnings: true
      alwaysAcceptResources: false
      livenessProbeEnabled: true
  gloo:
    logLevel: info
    deployment:
      customEnv:
        - name: ENABLE_WAYPOINTS
          value: "true"
        - name: GG_AMBIENT_MULTINETWORK
          value: "true"
      livenessProbeEnabled: true
  discovery:
    enabled: false
observability:
  enabled: false
prometheus:
  enabled: false
grafana:
  defaultInstallationEnabled: false
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
global:
  extensions:
    caching:
      enabled: true
ambient:
  waypoint:
    enabled: true
EOF
kubectl --context $CLUSTER2 patch settings default -n gloo-system --type json \
  -p '[{ "op": "remove", "path": "/spec/cachingServer" }]'
```




We've deployed Ambient and Gloo Gateway is part of the mesh. Ingress capture can be disabled. This is done by setting the `ambient.istio.io/bypass-inbound-capture": "true"` annotation on the proxy pods.

```bash
kubectl --context $CLUSTER2 patch gatewayparameters gloo-gateway -n gloo-system --type merge -p '{
  "spec": {
    "kube": {
      "podTemplate": {
        "extraAnnotations": {
          "ambient.istio.io/bypass-inbound-capture": "true"
        }
      }
    }
  }
}'
```


Run the following command to check that the Gloo Gateway pods are running:

<!--bash
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER2 -n gloo-system rollout status deployment
-->
```bash
kubectl --context $CLUSTER2 -n gloo-system get pods
```

Here is the expected output:

```,nocopy
NAME                                         READY   STATUS      RESTARTS   AGE
caching-service-79cf55ccbb-dcvgp             1/1     Running     0          69s
extauth-58f68c5cd5-gxgxc                     1/1     Running     0          69s
gateway-portal-web-server-5c5d58d8d5-7lzwg   1/1     Running     0          69s
gloo-7d8994697-lfg5x                         1/1     Running     0          69s
gloo-resource-rollout-check-x8b77            0/1     Completed   0          69s
gloo-resource-rollout-cjtgh                  0/1     Completed   0          69s
rate-limit-6db9c67794-vf7h2                  1/1     Running     0          69s
redis-6c7c489d8c-g2dhc                       1/1     Running     0          69s
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER2;
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
-->



## Lab 19 - Ambient Egress Traffic with Waypoint <a name="lab-19---ambient-egress-traffic-with-waypoint-"></a>

In this lab, we'll explore how to control and secure outbound traffic from your Ambient Mesh using Waypoints. We'll start by restricting all outgoing traffic from a specific namespace, then set up a shared Waypoint to manage egress traffic centrally. This approach allows for consistent policy enforcement across multiple services and namespaces.

### Restricting Egress Traffic

We'll begin by implementing a NetworkPolicy to prohibit all outgoing traffic from the `clients` namespace. This step simulates a secure environment where external access is tightly controlled.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restricted-namespace-policy
  namespace: clients
spec:
  podSelector: {}  # This applies to all pods in the namespace
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}  # Allow all ingress traffic
  egress:
  - to:
    - namespaceSelector: {}  # Allow egress to all namespaces
    - podSelector: {}  # Allow egress to all pods within the cluster
EOF
```

After applying this policy, verify that outbound traffic is indeed restricted by attempting to access an external service. You should observe that the connection fails.
```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -I httpbin.org/get
```

### Establishing a Shared Waypoint for Egress

Next, we'll create a dedicated `egress` namespace and deploy a shared Waypoint. This Waypoint will serve as a centralized control point for outbound traffic from various namespaces.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/dataplane-mode: ambient
    istio.io/use-waypoint: gloo-waypoint
  name: egress
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gloo-waypoint
  namespace: egress
spec:
  gatewayClassName: gloo-waypoint
  listeners:
  - name: proxy
    port: 15088
    protocol: istio.io/PROXY
EOF
```

Wait for the Waypoint deployment to be fully operational before proceeding.

```bash
kubectl --context ${CLUSTER1} -n egress rollout status deployment/gloo-proxy-gloo-waypoint
```

### Configuring External Service Access

Next, create a Service Entry to represent the external service 'httpbin.org' and by setting the labels `istio.io/use-waypoint` and `istio.io/use-waypoint-namespace` we configure traffic targeted at this service entry to be routed through the shared egress waypoint.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: httpbin.org
  namespace: egress
spec:
  hosts:
  - httpbin.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  resolution: DNS
EOF
```

To confirm that traffic is correctly flowing through the Waypoint, send a request to the external service and look for Envoy-specific headers in the response. These headers indicate that the traffic has been processed by the Waypoint.

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -sI httpbin.org/get | grep envoy
```

```http,nocopy
server: istio-envoy
x-envoy-decorator-operation: :80/*
```

The presence of Envoy headers in the response confirms that our traffic is being routed through the Waypoint as intended.

### Transforming Traffic in Egress Waypoint

To demonstrate the traffic management capabilities of our Waypoint, we'll apply a HTTPRoute that adds a custom header to outbound requests. This illustrates how you can modify and control egress traffic at the Waypoint level.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: egress
spec:
  parentRefs:
  - group: "networking.istio.io"
    kind: ServiceEntry
    name: httpbin.org
  rules:
  - backendRefs:
    - kind: Upstream
      group: gloo.solo.io
      name: httpbin-static
      namespace: egress
    filters:
      - type: RequestHeaderModifier
        requestHeaderModifier:
          add:
            - name: x-istio-workload
              value: "%ENVIRONMENT(HOSTNAME)%"
EOF
```

Verify that the new header is present in your requests to the external service.

```bash,norun-workshop
kubectl  --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get | grep -i X-Istio-Workload
```

Expected output:

```http,nocopy
    "X-Istio-Workload": "waypoint-94f49bb5b-b96k7",
```

### Securing Egress Traffic with Encryption

To enhance security, we'll now configure TLS encryption for our egress traffic. This involves updating the ServiceEntry to redirect traffic to a secure port and creating a DestinationRule to enable TLS.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: httpbin-static
  namespace: egress
spec:
  static:
    hosts:
      - addr: httpbin.org
        port: 443
EOF
```

Confirm that your traffic is now encrypted by checking the URL scheme in the response.

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get | jq .url
```

Expected output:

```,nocopy
"https://httpbin.org/get"
```

### Implementing Egress Authorization Policies

Finally, we'll apply an authorization policy to our Waypoint. This policy will allow only specific types of requests (in this case, GET requests to a particular path) and block all others, providing fine-grained control over outbound traffic.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: egress
spec:
  targetRefs:
  - kind: Gateway
    name: gloo-waypoint
    group: gateway.networking.k8s.io
  action: ALLOW
  rules:
  - to:
    - operation:
        hosts: ["httpbin.org"]
        methods: ["GET"]
        paths: ["/get"]
EOF
```

Confirm that the authorization policy is correctly enforced by attempting to access a different path on the external service. You should observe that the request is blocked.

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -s -X POST httpbin.org/post
```

Expected output:
```http,nocopy
RBAC: access denied
```

By setting up a Waypoint in the egress namespace and restricting direct outbound traffic, we've created a centralized point of control for all egress traffic. This setup allows for consistent policy enforcement, traffic management, and security measures across your entire mesh. Such an approach is crucial for maintaining compliance and security in enterprise environments.

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

describe("egress traffic", function() {
  const cluster = process.env.CLUSTER1

  it(`httproute should add customer header`, function() {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get`;
    let cli = chaiExec(command);
    expect(cli.output.toLowerCase()).to.contain('x-istio-workload');
  });

  it(`destination rule should route to https`, function() {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get`;
    let cli = chaiExec(command);
    expect(cli.output.toLowerCase()).to.contain('https://httpbin.org/get');
  });

  it(`other types of traffic (HTTP methods) should be rejected`, function() {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -s -X POST httpbin.org/post`;
    let cli = chaiExec(command);
    expect(cli.output).to.contain('RBAC: access denied');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-egress/tests/validate-egress-traffic.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
-->

Let's cleanup the resources:

```bash
kubectl --context ${CLUSTER1} delete authorizationpolicy httpbin -n egress
kubectl --context ${CLUSTER1} delete httproute httpbin -n egress
kubectl --context ${CLUSTER1} delete networkpolicy restricted-namespace-policy -n clients
kubectl --context ${CLUSTER1} delete upstream httpbin-static -n egress
```



## Lab 20 - Ambient Egress Traffic with Waypoint <a name="lab-20---ambient-egress-traffic-with-waypoint-"></a>

In this lab, we'll explore how to control and secure outbound traffic from your Ambient Mesh using Waypoints. We'll start by restricting all outgoing traffic from a specific namespace, then set up a shared Waypoint to manage egress traffic centrally. This approach allows for consistent policy enforcement across multiple services and namespaces.

### Restricting Egress Traffic

We'll begin by implementing a NetworkPolicy to prohibit all outgoing traffic from the `clients` namespace. This step simulates a secure environment where external access is tightly controlled.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restricted-namespace-policy
  namespace: clients
spec:
  podSelector: {}  # This applies to all pods in the namespace
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}  # Allow all ingress traffic
  egress:
  - to:
    - namespaceSelector: {}  # Allow egress to all namespaces
    - podSelector: {}  # Allow egress to all pods within the cluster
EOF
```

After applying this policy, verify that outbound traffic is indeed restricted by attempting to access an external service. You should observe that the connection fails.
```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -I httpbin.org/get
```

### Establishing a Shared Waypoint for Egress

Next, we'll create a dedicated `egress` namespace and deploy a shared Waypoint. This Waypoint will serve as a centralized control point for outbound traffic from various namespaces.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio.io/dataplane-mode: ambient
    istio.io/use-waypoint: waypoint
  name: egress
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: egress
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    allowedRoutes:
      namespaces:
        from: All
EOF
```

Wait for the Waypoint deployment to be fully operational before proceeding.

```bash
kubectl --context ${CLUSTER1} -n egress rollout status deployment/waypoint
```

### Configuring External Service Access

Next, create a Service Entry to represent the external service 'httpbin.org' and by setting the labels `istio.io/use-waypoint` and `istio.io/use-waypoint-namespace` we configure traffic targeted at this service entry to be routed through the shared egress waypoint.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: httpbin.org
  namespace: egress
spec:
  hosts:
  - httpbin.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  resolution: DNS
EOF
```

To confirm that traffic is correctly flowing through the Waypoint, send a request to the external service and look for Envoy-specific headers in the response. These headers indicate that the traffic has been processed by the Waypoint.

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -sI httpbin.org/get | grep envoy
```

```http,nocopy
server: istio-envoy
x-envoy-decorator-operation: :80/*
```

The presence of Envoy headers in the response confirms that our traffic is being routed through the Waypoint as intended.

### Transforming Traffic in Egress Waypoint

To demonstrate the traffic management capabilities of our Waypoint, we'll apply a HTTPRoute that adds a custom header to outbound requests. This illustrates how you can modify and control egress traffic at the Waypoint level.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: egress
spec:
  parentRefs:
  - group: "networking.istio.io"
    kind: ServiceEntry
    name: httpbin.org
  rules:
  - backendRefs:
    - kind: Hostname
      group: networking.istio.io
      name: httpbin.org
      port: 80
    filters:
      - type: RequestHeaderModifier
        requestHeaderModifier:
          add:
            - name: x-istio-workload
              value: "%ENVIRONMENT(HOSTNAME)%"
EOF
```

Verify that the new header is present in your requests to the external service.

```bash,norun-workshop
kubectl  --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get | grep -i X-Istio-Workload
```

Expected output:

```http,nocopy
    "X-Istio-Workload": "waypoint-94f49bb5b-b96k7",
```

### Securing Egress Traffic with Encryption

To enhance security, we'll now configure TLS encryption for our egress traffic. This involves updating the ServiceEntry to redirect traffic to a secure port and creating a DestinationRule to enable TLS.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: httpbin.org
  namespace: egress
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
    targetPort: 443 # New: send traffic originally for port 80 to port 443
  resolution: DNS
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpbin.org-tls
  namespace: egress
spec:
  host: httpbin.org
  trafficPolicy:
    tls:
      mode: SIMPLE
EOF
```

Confirm that your traffic is now encrypted by checking the URL scheme in the response.

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get | jq .url
```

Expected output:

```,nocopy
"https://httpbin.org/get"
```

### Implementing Egress Authorization Policies

Finally, we'll apply an authorization policy to our Waypoint. This policy will allow only specific types of requests (in this case, GET requests to a particular path) and block all others, providing fine-grained control over outbound traffic.

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: egress
spec:
  targetRefs:
  - kind: Gateway
    name: waypoint
    group: gateway.networking.k8s.io
  action: ALLOW
  rules:
  - to:
    - operation:
        hosts: ["httpbin.org"]
        methods: ["GET"]
        paths: ["/get"]
EOF
```

Confirm that the authorization policy is correctly enforced by attempting to access a different path on the external service. You should observe that the request is blocked.

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n clients exec deploy/in-ambient -- curl -s -X POST httpbin.org/post
```

Expected output:
```http,nocopy
RBAC: access denied
```

By setting up a Waypoint in the egress namespace and restricting direct outbound traffic, we've created a centralized point of control for all egress traffic. This setup allows for consistent policy enforcement, traffic management, and security measures across your entire mesh. Such an approach is crucial for maintaining compliance and security in enterprise environments.

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

describe("egress traffic", function() {
  const cluster = process.env.CLUSTER1

  it(`httproute should add customer header`, function() {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get`;
    let cli = chaiExec(command);
    expect(cli.output.toLowerCase()).to.contain('x-istio-workload');
  });

  it(`destination rule should route to https`, function() {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -s httpbin.org/get`;
    let cli = chaiExec(command);
    expect(cli.output.toLowerCase()).to.contain('https://httpbin.org/get');
  });

  it(`other types of traffic (HTTP methods) should be rejected`, function() {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -s -X POST httpbin.org/post`;
    let cli = chaiExec(command);
    expect(cli.output).to.contain('RBAC: access denied');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-egress/tests/validate-egress-traffic.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
-->

Let's cleanup the resources:

```bash
kubectl --context ${CLUSTER1} delete authorizationpolicy httpbin -n egress
kubectl --context ${CLUSTER1} delete httproute httpbin -n egress
kubectl --context ${CLUSTER1} delete networkpolicy restricted-namespace-policy -n clients
kubectl --context ${CLUSTER1} delete serviceentry httpbin.org -n egress
kubectl --context ${CLUSTER1} delete destinationrule httpbin.org-tls -n egress
```



## Lab 21 - Link Clusters <a name="lab-21---link-clusters-"></a>

Create the `istio-gateways` namespaces:

```bash
kubectl --context $CLUSTER1 create namespace istio-gateways
kubectl --context $CLUSTER2 create namespace istio-gateways
```

Create a Gateway for each cluster:

```bash
cat <<EOF | kubectl --context $CLUSTER1 apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: istio-eastwest
  namespace: istio-gateways
  labels:
    topology.istio.io/network: $CLUSTER1
    istio.io/expose-istiod: "15012"
spec:
  gatewayClassName: istio-eastwest
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
  - allowedRoutes:
      namespaces:
        from: Same
    name: xds-tls
    port: 15012
    protocol: TLS
    tls:
      mode: Passthrough
EOF

cat <<EOF | kubectl --context $CLUSTER2 apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: istio-eastwest
  namespace: istio-gateways
  labels:
    topology.istio.io/network: $CLUSTER2
    istio.io/expose-istiod: "15012"
spec:
  gatewayClassName: istio-eastwest
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
  - allowedRoutes:
      namespaces:
        from: Same
    name: xds-tls
    port: 15012
    protocol: TLS
    tls:
      mode: Passthrough
EOF
```

Link the first cluster to the second cluster:

```bash
while [ -z "$CLUSTER_GW_IP" ]; do
    CLUSTER_GW_IP="$(kubectl --context $CLUSTER2 -n istio-gateways get service istio-eastwest -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')"
    if [ -z "$CLUSTER_GW_IP" ]; then
        echo "Waiting for Gateway IP..."
        sleep 5
    fi
done

cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    gateway.istio.io/service-account: istio-eastwest
    gateway.istio.io/trust-domain: cluster2
  labels:
    topology.istio.io/network: cluster2
  name: istio-remote-peer-cluster2
  namespace: istio-gateways
spec:
  addresses:
  - type: IPAddress
    value: "${CLUSTER_GW_IP}"
  gatewayClassName: istio-remote
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
  - allowedRoutes:
      namespaces:
        from: Same
    name: xds-tls
    port: 15012
    protocol: TLS
    tls:
      mode: Passthrough
EOF
```

Link the second cluster to the first cluster:

```bash
unset CLUSTER_GW_IP
while [ -z "$CLUSTER_GW_IP" ]; do
    CLUSTER_GW_IP="$(kubectl --context $CLUSTER1 -n istio-gateways get service istio-eastwest -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')"
    if [ -z "$CLUSTER_GW_IP" ]; then
        echo "Waiting for Gateway IP..."
        sleep 5
    fi
done

cat << EOF | kubectl --context ${CLUSTER2} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    gateway.istio.io/service-account: istio-eastwest
    gateway.istio.io/trust-domain: cluster1
  labels:
    topology.istio.io/network: cluster1
  name: istio-remote-peer-cluster1
  namespace: istio-gateways
spec:
  addresses:
  - type: IPAddress
    value: "${CLUSTER_GW_IP}"
  gatewayClassName: istio-remote
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: cross-network
    port: 15008
    protocol: HBONE
    tls:
      mode: Passthrough
  - allowedRoutes:
      namespaces:
        from: Same
    name: xds-tls
    port: 15012
    protocol: TLS
    tls:
      mode: Passthrough
EOF
```

Let's validate that cross cluster traffic works. Let's annotate services that are globally accessible:

Next expose global service.

```bash
kubectl --context $CLUSTER1 -n httpbin label svc in-ambient solo.io/service-scope=global
kubectl --context $CLUSTER1 -n httpbin annotate svc in-ambient networking.istio.io/traffic-distribution=Any
kubectl --context $CLUSTER1 -n httpbin label svc in-mesh solo.io/service-scope=global
kubectl --context $CLUSTER1 -n httpbin annotate svc in-mesh networking.istio.io/traffic-distribution=Any
kubectl --context $CLUSTER2 -n httpbin label svc in-ambient solo.io/service-scope=global
kubectl --context $CLUSTER2 -n httpbin annotate svc in-ambient networking.istio.io/traffic-distribution=Any
kubectl --context $CLUSTER2 -n httpbin label svc in-mesh solo.io/service-scope=global
kubectl --context $CLUSTER2 -n httpbin annotate svc in-mesh networking.istio.io/traffic-distribution=Any
kubectl --context $CLUSTER2 -n httpbin label svc remote-in-ambient solo.io/service-scope=global
kubectl --context $CLUSTER2 -n httpbin label svc remote-in-mesh solo.io/service-scope=global
```

Note that the default value of the traffic distribution is `PreferClose` which would only send the traffic to the local service if it's available.

Validate that Service Entries are workload entries are created to route traffic to the gateway of the other cluster:

```bash,norun-workshop
kubectl --context $CLUSTER1 -n httpbin get serviceentry
kubectl --context $CLUSTER2 -n httpbin get workloadentry
```

Next, let's send some traffic across the clusters:

```bash,norun-workshop
kubectl --context=$CLUSTER1 -n httpbin exec -it deploy/client-in-ambient -- curl -v in-ambient.httpbin.mesh.internal:8000/get
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
        curlCommand: 'curl -s in-ambient.httpbin.mesh.internal:8000/get',
        deploymentName: 'client-in-ambient',
        namespace: 'httpbin',
        context: `${process.env.CLUSTER1}`
      });
      const origin = JSON.parse(command).origin;
      origins.add(origin);
    }
    expect(origins.size).to.equal(2);
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/link-clusters/tests/check-cross-cluster-traffic.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 120000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
-->




## Lab 22 - Ambient multicluster routing <a name="lab-22---ambient-multicluster-routing-"></a>

Let's configure the Istio Ingress Gateway:

```bash
cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway-istio
  namespace: httpbin
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    hostname: "httpbin.istio"
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-istio
  namespace: httpbin
spec:
  parentRefs:
  - name: httpbin-gateway-istio
  hostnames: ["httpbin.istio"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /in-ambient
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: in-ambient
      port: 8000
  - matches:
    - path:
        type: PathPrefix
        value: /in-mesh
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: in-mesh
      port: 8000
  - matches:
    - path:
        type: PathPrefix
        value: /global-in-ambient
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: in-ambient.httpbin.mesh.internal
      kind: Hostname
      group: networking.istio.io
      port: 8000
  - matches:
    - path:
        type: PathPrefix
        value: /global-in-mesh
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: in-mesh.httpbin.mesh.internal
      kind: Hostname
      group: networking.istio.io
      port: 8000
  - matches:
    - path:
        type: PathPrefix
        value: /remote-in-ambient
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: remote-in-ambient.httpbin.mesh.internal
      kind: Hostname
      group: networking.istio.io
      port: 8000
  - matches:
    - path:
        type: PathPrefix
        value: /remote-in-mesh
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: remote-in-mesh.httpbin.mesh.internal
      kind: Hostname
      group: networking.istio.io
      port: 8000
EOF
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
export ISTIO_INGRESS=$(kubectl --context ${CLUSTER1} -n httpbin get svc httpbin-gateway-istio-istio -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
```


Let's configure the Gloo Gateway Ingress Gateway:

```bash
cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway-gloo-gateway
  namespace: httpbin
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - name: http
    hostname: "httpbin.gloo-gateway"
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-gloo-gateway
  namespace: httpbin
spec:
  parentRefs:
  - name: httpbin-gateway-gloo-gateway
  hostnames: ["httpbin.gloo-gateway"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /in-ambient
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: in-ambient
      namespace: httpbin
      group: gloo.solo.io
      kind: Upstream
  - matches:
    - path:
        type: PathPrefix
        value: /in-mesh
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: in-mesh
      namespace: httpbin
      group: gloo.solo.io
      kind: Upstream
  - matches:
    - path:
        type: PathPrefix
        value: /global-in-ambient
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: global-in-ambient
      namespace: httpbin
      group: gloo.solo.io
      kind: Upstream
  - matches:
    - path:
        type: PathPrefix
        value: /global-in-mesh
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: global-in-mesh
      namespace: httpbin
      group: gloo.solo.io
      kind: Upstream
  - matches:
    - path:
        type: PathPrefix
        value: /remote-in-ambient
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: remote-in-ambient
      namespace: httpbin
      group: gloo.solo.io
      kind: Upstream
  - matches:
    - path:
        type: PathPrefix
        value: /remote-in-mesh
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: remote-in-mesh
      namespace: httpbin
      group: gloo.solo.io
      kind: Upstream
# Upstreams are needed in Gloo Gateway 1.19 to use waypoints
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: in-ambient
  namespace: httpbin
spec:
  static:
    hosts:
      - addr: in-ambient.httpbin.svc.cluster.local
        port: 8000
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: in-mesh
  namespace: httpbin
spec:
  static:
    hosts:
      - addr: in-mesh.httpbin.svc.cluster.local
        port: 8000
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: global-in-ambient
  namespace: httpbin
spec:
  static:
    hosts:
      - addr: in-ambient.httpbin.mesh.internal
        port: 8000
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: global-in-mesh
  namespace: httpbin
spec:
  static:
    hosts:
      - addr: in-mesh.httpbin.mesh.internal
        port: 8000
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: remote-in-ambient
  namespace: httpbin
spec:
  static:
    hosts:
      - addr: remote-in-ambient.httpbin.mesh.internal
        port: 8000
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: remote-in-mesh
  namespace: httpbin
spec:
  static:
    hosts:
      - addr: remote-in-mesh.httpbin.mesh.internal
        port: 8000
EOF
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway-gateway
export SOLO_INGRESS=$(kubectl --context ${CLUSTER1} -n httpbin get svc gloo-proxy-httpbin-gateway-gloo-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
```


### Scenario 1: No waypoint


<!--bash
echo "Scenario 1: No waypoint"
-->



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Expected output: `200`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Expected output: `200`



<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal","remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 1b: No waypoint with failover


<!--bash
echo "Scenario 1b: No waypoint with failover"
-->

Let's scale down the local services:

```bash
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=0
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=0
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
```



#### From client-in-mesh




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`







#### From client-in-ambient




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal","remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

Let's scale up the local services:

```bash
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=1
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=1
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
```

### Scenario 2: Local Istio waypoints


<!--bash
echo "Scenario 2: Local Istio waypoints"
-->

Let's add local waypoint:

```bash
cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/waypoint-for: service
  name: waypoint
  namespace: httpbin
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
EOF
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy waypoint
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/ingress-use-waypoint=true
export LOCAL_ISTIO_WAYPOINT=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=waypoint -o jsonpath='{.items[0].metadata.name}')
```

Let's configure the `HTTPRoutes`

```bash
cat << 'EOF' | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: in-ambient
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: in-ambient
    port: 8000
  rules:
    - backendRefs:
        - name: in-ambient
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: in-mesh
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: in-mesh
    port: 8000
  rules:
    - backendRefs:
        - name: in-mesh
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: global-in-ambient
  namespace: httpbin
spec:
  parentRefs:
  - group: "networking.istio.io"
    kind: ServiceEntry
    name: autogen.httpbin.in-ambient
    sectionName: "8000"
  rules:
    - backendRefs:
        - name: in-ambient.httpbin.mesh.internal
          kind: Hostname
          group: networking.istio.io
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: global-in-mesh
  namespace: httpbin
spec:
  parentRefs:
  - group: "networking.istio.io"
    kind: ServiceEntry
    name: autogen.httpbin.in-mesh
    sectionName: "8000"
  rules:
    - backendRefs:
        - name: in-mesh.httpbin.mesh.internal
          kind: Hostname
          group: networking.istio.io
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
EOF
```



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`







#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`






#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`







#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 2b: Local Istio waypoints with failover


<!--bash
echo "Scenario 2b: Local Istio waypoints with failover"
-->

Let's scale down the local services:

```bash
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=0
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=0
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
```



#### From client-in-mesh




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`







#### From client-in-ambient




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`






#### From client-in-mesh




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`







#### From client-in-ambient




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  [].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  [].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=true, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

Let's scale up the local services:

```bash
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=1
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=1
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
```

### Scenario 2c: Local Istio waypoints with AuthorizationPolicy


<!--bash
echo "Scenario 2c: Local Istio waypoints with AuthorizationPolicy"
-->

Let's configure the `AuthorizationPolicies`

```bash
cat << 'EOF' | kubectl --context ${CLUSTER1} apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: in-ambient-allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: ServiceEntry
    group: "networking.istio.io"
    name: autogen.httpbin.in-ambient
  - kind: Service
    group: ""
    name: in-ambient
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/httpbin-gateway-istio-istio
    - source:
        principals:
        - cluster1/ns/httpbin/sa/gloo-proxy-httpbin-gateway-gloo-gateway
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-ambient
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-mesh
    to:
    - operation:
        methods: ["GET", "HEAD"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: in-mesh-allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: ServiceEntry
    group: "networking.istio.io"
    name: autogen.httpbin.in-mesh
  - kind: Service
    group: ""
    name: in-mesh
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/httpbin-gateway-istio-istio
    - source:
        principals:
        - cluster1/ns/httpbin/sa/gloo-proxy-httpbin-gateway-gloo-gateway
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-ambient
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-mesh
    to:
    - operation:
        methods: ["GET", "HEAD"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: remote-in-ambient-allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: ServiceEntry
    group: "networking.istio.io"
    name: autogen.httpbin.remote-in-ambient
  - kind: Service
    group: ""
    name: remote-in-ambient
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/httpbin-gateway-istio-istio
    - source:
        principals:
        - cluster1/ns/httpbin/sa/gloo-proxy-httpbin-gateway-gloo-gateway
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-ambient
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-mesh
    to:
    - operation:
        methods: ["GET", "HEAD"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: remote-in-mesh-allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: ServiceEntry
    group: "networking.istio.io"
    name: autogen.httpbin.remote-in-mesh
  - kind: Service
    group: ""
    name: remote-in-mesh
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/httpbin-gateway-istio-istio
    - source:
        principals:
        - cluster1/ns/httpbin/sa/gloo-proxy-httpbin-gateway-gloo-gateway
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-ambient
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-mesh
    to:
    - operation:
        methods: ["GET", "HEAD"]
EOF
```

POST requests should be denied. For example:

```bash,norun-workshop
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -X POST in-ambient.httpbin.svc.cluster.local:8000/post
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("AuthorizationPolicy is working properly (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} isn't allowed to send POST requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -X POST -o /dev/null -w "%{http_code}" "http://${target}:8000/post"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('403');
      });
      it(`${source} is allowed to send GET requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -o /dev/null -w "%{http_code}" "http://${target}:8000/get"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    });
    ["global-in-mesh", "global-in-ambient",].forEach(async (target) => {
      it(`Istio ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/post`, retCode: 403 }));
      it(`Istio ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/get`, retCode: 200 }));

      it(`gloo-gateway ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/post`, retCode: 403 }));
      it(`gloo-gateway ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/get`, retCode: 200 }));
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-authorization.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 3: Local gloo-gateway waypoints


<!--bash
echo "Scenario 3: Local gloo-gateway waypoints"
-->

Let's use Solo Waypoint:

```bash

cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gloo-gateway-waypoint
  namespace: httpbin
spec:
  gatewayClassName: gloo-waypoint
  listeners:
  - name: proxy
    port: 15088
    protocol: istio.io/PROXY
  - name: hbone
    port: 15008
    protocol: istio.io/HBONE
EOF

kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway
export LOCAL_SOLO_WAYPOINT=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=gloo-gateway-waypoint -o jsonpath='{.items[0].metadata.name}')
```



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`







#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`






#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`







#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
### Scenario 3b: Local gloo-gateway waypoints with failover


<!--bash
echo "Scenario 3b: Local gloo-gateway waypoints with failover"
-->

Let's scale down the local services:

```bash
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=0
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=0
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
```

Remove the local HTTPRoutes:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete httproute in-ambient
kubectl --context ${CLUSTER1} -n httpbin delete httproute in-mesh
```



#### From client-in-mesh




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`







#### From client-in-ambient




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`






#### From client-in-mesh




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`







#### From client-in-ambient




1. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



2. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)




1. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



2. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=true, Authorization Policy=)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=true, Authorization Policy=)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=true, Authorization Policy=)", () => {
  [].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=true, Authorization Policy=)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=true, Authorization Policy=)", () => {
  [].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=true, Authorization Policy=)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

Let's scale up the local services:

```bash
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=1
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=1
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
```

### Scenario 3c: Local gloo-gateway waypoints with AuthorizationPolicy


<!--bash
echo "Scenario 3c: Local gloo-gateway waypoints with AuthorizationPolicy"
-->

POST requests should be denied. For example:

```bash,norun-workshop
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -X POST in-ambient.httpbin.svc.cluster.local:8000/post
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("AuthorizationPolicy is working properly (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} isn't allowed to send POST requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -X POST -o /dev/null -w "%{http_code}" "http://${target}:8000/post"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('403');
      });
      it(`${source} is allowed to send GET requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -o /dev/null -w "%{http_code}" "http://${target}:8000/get"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    });
    ["global-in-mesh", "global-in-ambient",].forEach(async (target) => {
      it(`Istio ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/post`, retCode: 403 }));
      it(`Istio ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/get`, retCode: 200 }));

      it(`gloo-gateway ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/post`, retCode: 403 }));
      it(`gloo-gateway ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/get`, retCode: 200 }));
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-authorization.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=None, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

Add the local HTTPRoutes:

```bash
cat << 'EOF' | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: in-ambient
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: in-ambient
    port: 8000
  rules:
    - backendRefs:
        - name: in-ambient
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: in-mesh
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: in-mesh
    port: 8000
  rules:
    - backendRefs:
        - name: in-mesh
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
EOF
```

### Scenario 4: Local and remote Istio waypoints


<!--bash
echo "Scenario 4: Local and remote Istio waypoints"
-->

Let's use Istio Waypoint:

```bash
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint --overwrite
```

And add remote waypoint:

```bash
cat << EOF | kubectl --context ${CLUSTER2} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/waypoint-for: service
  name: waypoint
  namespace: httpbin
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
EOF
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy waypoint
cat << EOF | kubectl --context ${CLUSTER2} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gloo-gateway-waypoint
  namespace: httpbin
spec:
  gatewayClassName: gloo-waypoint
  listeners:
  - name: proxy
    port: 15088
    protocol: istio.io/PROXY
  - name: hbone
    port: 15008
    protocol: istio.io/HBONE
EOF
kubectl --context ${CLUSTER2} -n httpbin rollout status deploy waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway
export REMOTE_ISTIO_WAYPOINT=$(kubectl --context ${CLUSTER2} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=waypoint -o jsonpath='{.items[0].metadata.name}')
```

Let's configure the `HTTPRoutes`
```bash
cat << 'EOF' | kubectl --context ${CLUSTER2} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: remote-in-ambient
  namespace: httpbin
spec:
  parentRefs:
  - group: "networking.istio.io"
    kind: ServiceEntry
    name: autogen.httpbin.remote-in-ambient
    sectionName: "8000"
  rules:
    - backendRefs:
        - name: remote-in-ambient.httpbin.mesh.internal
          kind: Hostname
          group: networking.istio.io
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: remote-in-mesh
  namespace: httpbin
spec:
  parentRefs:
  - group: "networking.istio.io"
    kind: ServiceEntry
    name: autogen.httpbin.remote-in-mesh
    sectionName: "8000"
  rules:
    - backendRefs:
        - name: remote-in-mesh.httpbin.mesh.internal
          kind: Hostname
          group: networking.istio.io
          port: 8000
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: x-istio-workload
                value: "%ENVIRONMENT(HOSTNAME)%"
EOF
```



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Expected output: `200`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Expected output: `200`




#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`







#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_ISTIO_WAYPOINT`






#### From client-in-mesh






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`





#### From client-in-ambient






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_ISTIO_WAYPOINT}`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=Istio, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => REMOTE_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=Istio, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=Istio, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 5: Local and remote gloo-gateway waypoints

<!--bash
echo "Scenario 5: Local and remote gloo-gateway waypoints"
-->

Let's use Solo Waypoint:

```bash
cat << EOF | kubectl --context ${CLUSTER2} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gloo-gateway-waypoint
  namespace: httpbin
spec:
  gatewayClassName: gloo-waypoint
  listeners:
  - name: proxy
    port: 15088
    protocol: istio.io/PROXY
  - name: hbone
    port: 15008
    protocol: istio.io/HBONE
EOF
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway
export REMOTE_SOLO_WAYPOINT=$(kubectl --context ${CLUSTER2} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=gloo-gateway-waypoint -o jsonpath='{.items[0].metadata.name}')
```



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Expected output: `200`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Expected output: `200`



2. Test connectivity to in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service via ingress:
```
curl -s -o /dev/null -w "%{http_code}" -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Expected output: `200`




#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`







#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.svc.cluster.local:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $LOCAL_SOLO_WAYPOINT`






#### From client-in-mesh






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`





#### From client-in-ambient






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





#### Testing Ingress Connectivity (istio ISTIO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)


1. Test connectivity to in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



2. Test connectivity to in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





3. Test connectivity to global in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-mesh/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`



4. Test connectivity to global in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/global-in-ambient/get
```

Check that the response body contains `${process.env.LOCAL_SOLO_WAYPOINT}`





#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => LOCAL_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=gloo-gateway, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => REMOTE_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => LOCAL_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.LOCAL_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=gloo-gateway, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=gloo-gateway, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.REMOTE_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

Let's use Istio Waypoint:

```bash
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway
```

### Scenario 6: Remote only Istio waypoints


<!--bash
echo "Scenario 6: Remote only Istio waypoints"
-->

Let's delete the local waypoints:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete gateway waypoint
kubectl --context ${CLUSTER1} -n httpbin delete gateway gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/ingress-use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/ingress-use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway
```



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`




#### From client-in-mesh






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`





#### From client-in-ambient






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_ISTIO_WAYPOINT`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_ISTIO_WAYPOINT}`



<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => REMOTE_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 6b: Remote only Istio waypoints with AuthorizationPolicy

<!--bash
echo "Scenario 6b: Remote only Istio waypoints with AuthorizationPolicy"
-->

Let's configure the `AuthorizationPolicies`

```bash
cat << 'EOF' | kubectl --context ${CLUSTER2} apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: remote-in-ambient-allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: ServiceEntry
    group: "networking.istio.io"
    name: autogen.httpbin.remote-in-ambient
  - kind: Service
    group: ""
    name: remote-in-ambient
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/httpbin-gateway-istio-istio
    - source:
        principals:
        - cluster1/ns/httpbin/sa/gloo-proxy-httpbin-gateway-gloo-gateway
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-ambient
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-mesh
    to:
    - operation:
        methods: ["GET", "HEAD"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: remote-in-mesh-allow-get-only
  namespace: httpbin
spec:
  targetRefs:
  - kind: ServiceEntry
    group: "networking.istio.io"
    name: autogen.httpbin.remote-in-mesh
  - kind: Service
    group: ""
    name: remote-in-mesh
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster1/ns/httpbin/sa/httpbin-gateway-istio-istio
    - source:
        principals:
        - cluster1/ns/httpbin/sa/gloo-proxy-httpbin-gateway-gloo-gateway
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-ambient
    - source:
        principals:
        - cluster1/ns/httpbin/sa/client-in-mesh
    to:
    - operation:
        methods: ["GET", "HEAD"]
EOF
```

POST requests should be denied. For example:

```bash,norun-workshop
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -X POST remote-in-ambient.httpbin.svc.cluster.local:8000/post
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("AuthorizationPolicy is working properly (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      it(`${source} isn't allowed to send POST requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -X POST -o /dev/null -w "%{http_code}" "http://${target}:8000/post"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('403');
      });
      it(`${source} is allowed to send GET requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -o /dev/null -w "%{http_code}" "http://${target}:8000/get"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    });
    ["remote-in-mesh", "remote-in-ambient"].forEach(async (target) => {
      it(`Istio ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/post`, retCode: 403 }));
      it(`Istio ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/get`, retCode: 200 }));

      it(`gloo-gateway ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/post`, retCode: 403 }));
      it(`gloo-gateway ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/get`, retCode: 200 }));
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-authorization.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => REMOTE_ISTIO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=Istio, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_ISTIO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 7: Remote only gloo-gateway waypoints


<!--bash
echo "Scenario 7: Remote only gloo-gateway waypoints"
-->

Let's use Solo Waypoint:

```bash
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=gloo-gateway-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo-gateway
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo-gateway
```



#### From client-in-mesh


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





#### From client-in-ambient


1. Test connectivity to in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`



2. Test connectivity to in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.svc.cluster.local:8000/get
```

Expected output: `200`





3. Test connectivity to global in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



4. Test connectivity to global in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`





5. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-mesh.httpbin.mesh.internal:8000/get
```

Expected output: `200`



6. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -o /dev/null -w "%{http_code}" remote-in-ambient.httpbin.mesh.internal:8000/get
```

Expected output: `200`




#### From client-in-mesh






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-mesh -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`





#### From client-in-ambient






1. Test connectivity to remote in-mesh service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-mesh.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`



2. Test connectivity to remote in-ambient service:
```
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s  remote-in-ambient.httpbin.mesh.internal:8000/get
```

Check that the response headers include `X-Istio-Workload: $REMOTE_SOLO_WAYPOINT`



#### Testing Ingress Connectivity (istio ISTIO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.istio" http://${ISTIO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



#### Testing Ingress Connectivity (gloo-gateway SOLO_INGRESS)






1. Test connectivity to remote in-mesh service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-mesh/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



2. Test connectivity to remote in-ambient service via ingress:
```
curl -s  -H "Host: httpbin.gloo-gateway" http://${SOLO_INGRESS}/remote-in-ambient/get
```

Check that the response body contains `${process.env.REMOTE_SOLO_WAYPOINT}`



<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => REMOTE_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=false)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.REMOTE_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

### Scenario 7b: Remote only gloo-gateway waypoints with AuthorizationPolicy


<!--bash
echo "Scenario 7b: Remote only gloo-gateway waypoints with AuthorizationPolicy"
-->

POST requests should be denied. For example:

```bash,norun-workshop
kubectl --context ${CLUSTER1} exec -n httpbin $(kubectl --context ${CLUSTER1} get pod -l app=client-in-ambient -n httpbin -o jsonpath='{.items[0].metadata.name}') -- curl -s -X POST remote-in-ambient.httpbin.svc.cluster.local:8000/post
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("AuthorizationPolicy is working properly (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      it(`${source} isn't allowed to send POST requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -X POST -o /dev/null -w "%{http_code}" "http://${target}:8000/post"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('403');
      });
      it(`${source} is allowed to send GET requests to ${target}`, () => {
        let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/${source} -- curl -m 2 --max-time 2 -s -o /dev/null -w "%{http_code}" "http://${target}:8000/get"`;
        let cli = chaiExec(command);
        expect(cli).to.exit.with.code(0);
        expect(cli).output.to.contain('200');
      });
    });
    ["remote-in-mesh", "remote-in-ambient"].forEach(async (target) => {
      it(`Istio ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/post`, retCode: 403 }));
      it(`Istio ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.ISTIO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.istio'}], path: `/${target}/get`, retCode: 200 }));

      it(`gloo-gateway ingress isn't allowed to send POST requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "post", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/post`, retCode: 403 }));
      it(`gloo-gateway ingress is allowed to send GET requests to /${target}`, () => helpers.checkWithMethod({ host: `http://${process.env.SOLO_INGRESS}`, method: "get", headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `/${target}/get`, retCode: 200 }));
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-authorization.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_ISTIO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      
      it(`${source} => ${target}`, async () => {
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-exec');

async function status_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s -o /dev/null -w "%{http_code}" ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output).to.equal(200);
}

async function header_test(source, target) {
  const command = await helpers.curlInDeployment({
    context: `${process.env.CLUSTER1}`,
    namespace: 'httpbin',
    deploymentName: source,
    curlCommand: `curl -s ${target}:8000/get`
  });
  output = JSON.parse(command);
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_SOLO_WAYPOINT);
}

describe("Tests all possible eastwest communication (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      
      it(`${source} => REMOTE_SOLO_WAYPOINT => ${target}`, async () => {
        await header_test(source, target);
        await status_test(source, target);
      });
      
    });
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo-gateway ingress (Local Waypoint=None, Remote Waypoint=gloo-gateway, Failover=false, Authorization Policy=true)", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    it(`Ingress => ${path}`, () => helpers.checkURL({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, retCode: 200 }));
    
    it(`Ingress => REMOTE_SOLO_WAYPOINT => ${path}`, () => helpers.checkBody({ host: `http://${process.env.SOLO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo-gateway'}], path: `${path}/get`, body: process.env.REMOTE_SOLO_WAYPOINT }));
    
  });
});

const fs = require('fs');
const path = require('path');

const counterFilePath = path.join(__dirname, '.test-counter');

// Setup before all tests
before(function() {
  // Initialize counter file if it doesn't exist
  if (!fs.existsSync(counterFilePath)) {
    fs.writeFileSync(counterFilePath, '0');
  }
});

// Before each test
beforeEach(function() {
  // Read current counter value
  let counter = parseInt(fs.readFileSync(counterFilePath, 'utf8'));
  
  // Increment counter
  counter++;
  
  // Save incremented value
  fs.writeFileSync(counterFilePath, counter.toString());
  
  // Set environment variable
  process.env.TEST_COUNTER = counter.toString();
  
  console.log(`Running test #${process.env.TEST_COUNTER}`);
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->



