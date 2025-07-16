
<!--bash
source ./scripts/assert.sh
-->



<center>
<img src="images/document-gloo-mesh.svg" style="height: 100px;"/>
</center>

# <center>Istio Ambient Lightswitch (Multi-Cluster, Gloo Mesh 2.9.1)</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD Cluster(s)](#lab-1---deploy-kind-cluster(s)-)
* [Lab 2 - Deploy and register Gloo Mesh](#lab-2---deploy-and-register-gloo-mesh-)
* [Lab 3 - Deploy the Bookinfo demo app](#lab-3---deploy-the-bookinfo-demo-app-)
* [Lab 4 - Configure common trust certificates in both clusters](#lab-4---configure-common-trust-certificates-in-both-clusters-)
* [Lab 5 - Install the Istio CLI tool](#lab-5---install-the-istio-cli-tool-)
* [Lab 6 - Deploy Istio](#lab-6---deploy-istio-)
* [Lab 7 - Expose Bookinfo's productpage](#lab-7---expose-bookinfo's-productpage-)
* [Lab 8 - Add Bookinfo to the mesh](#lab-8---add-bookinfo-to-the-mesh-)
* [Lab 9 - Link clusters](#lab-9---link-clusters-)
* [Lab 10 - Declare productpage to be a global service for multi-cluster access](#lab-10---declare-productpage-to-be-a-global-service-for-multi-cluster-access-)



## Introduction <a name="introduction"></a>

<a href="https://www.solo.io/products/gloo-mesh/">Gloo Mesh</a> is a management plane that makes it easy to operate <a href="https://istio.io">Istio</a> and adds additional features to Ambient.

Gloo Mesh works with community [Istio](https://istio.io/) out of the box.
You get instant insights into your Istio environment through a custom dashboard.
Observability pipelines let you analyze many data sources that you already have.
You can even automate installing and upgrading Istio with the Gloo lifecycle manager, on one or many Kubernetes clusters deployed anywhere.

But Gloo Mesh includes more than tooling to complement an existing Istio installation.
You can also replace community Istio with Solo's hardened Istio images. These images unlock enterprise-level support.
Later, you might choose to include Gloo Gateway for a full-stack service mesh and API gateway solution.
This approach lets you scale as you need more advanced routing and security features.

### Istio and Ambient support

The Gloo Mesh subscription includes end-to-end Istio support:

* Upstream feature development
* CI/CD-ready automated installation and upgrade
* End-to-end Istio support and CVE security patching
* Long-term n-4 version support with Solo images
* Special image builds for distroless and FIPS compliance
* 24x7 production support and one-hour Severity 1 SLA
* Ambient support for Istio
* L7 Telemetry support in Ztunnel

### Gloo Mesh overview

Gloo Mesh provides many unique features, including:

* Single pane of glass for operational management of Istio, including global observability
* Insights based on environment checks with corrective actions and best practices
* Seamless migration to full-stack service mesh

### Want to learn more about Gloo Mesh?

You can find more information about Gloo Mesh in the official documentation: <https://docs.solo.io/gloo-mesh-core>




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
export GLOO_MESH_VERSION=v2.9.1
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
  --version 2.9.1

helm upgrade --install gloo-platform-mgmt gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.9.1 \
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
  --version 2.9.1

helm upgrade --install gloo-platform-agent gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.9.1 \
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




## Lab 3 - Deploy the Bookinfo demo app <a name="lab-3---deploy-the-bookinfo-demo-app-"></a>
[<img src="https://img.youtube.com/vi/nzYcrjalY5A/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/nzYcrjalY5A "Video Link")

We're going to deploy the bookinfo application to demonstrate several features of Gloo Mesh.
You can find more information about this application [here](https://istio.io/latest/docs/examples/bookinfo/).

Run the following commands to deploy the bookinfo application on `cluster1`:

```bash
kubectl --context ${CLUSTER1} create ns bookinfo-frontends
kubectl --context ${CLUSTER1} create ns bookinfo-backends
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio-injection=disabled
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=disabled


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

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
```

Note that we deployed the `productpage` service in the `bookinfo-frontends` namespace and the other services in the `bookinfo-backends` namespace.
And we deployed the `v1` and `v2` versions of the `reviews` microservice, not the `v3` version.

Now, run the following commands to deploy the bookinfo application on `cluster2`:

```bash
kubectl --context ${CLUSTER2} create ns bookinfo-frontends
kubectl --context ${CLUSTER2} create ns bookinfo-backends
kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio-injection=disabled
kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio-injection=disabled


# Deploy the frontend bookinfo service in the bookinfo-frontends namespace
kubectl --context ${CLUSTER2} -n bookinfo-frontends apply -f data/steps/deploy-bookinfo/productpage-v1.yaml

# Deploy the backend bookinfo services in the bookinfo-backends namespace for all versions
kubectl --context ${CLUSTER2} -n bookinfo-backends apply \
  -f data/steps/deploy-bookinfo/details-v1.yaml \
  -f data/steps/deploy-bookinfo/ratings-v1.yaml \
  -f data/steps/deploy-bookinfo/reviews-v1-v2.yaml \
  -f data/steps/deploy-bookinfo/reviews-v3.yaml

# Update the reviews service to display where it is coming from
kubectl --context ${CLUSTER2} -n bookinfo-backends set env deploy/reviews-v1 CLUSTER_NAME=${CLUSTER2}
kubectl --context ${CLUSTER2} -n bookinfo-backends set env deploy/reviews-v2 CLUSTER_NAME=${CLUSTER2}
kubectl --context ${CLUSTER2} -n bookinfo-backends set env deploy/reviews-v3 CLUSTER_NAME=${CLUSTER2}

```

<!--bash
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER2} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER2} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 5 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->

Confirm that `v1`, `v2` and `v3` of the `reviews` service are now running in the second cluster:

```bash
kubectl --context ${CLUSTER2} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER2} -n bookinfo-backends get pods
```

As you can see, we deployed all three versions of the `reviews` microservice on this cluster.

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
  cluster = process.env.CLUSTER2
  deployments = ["productpage-v1"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo-frontends", k8sObj: deploy }));
  });
  deployments = ["ratings-v1", "details-v1", "reviews-v1", "reviews-v2", "reviews-v3"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo-backends", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
-->



## Lab 4 - Configure common trust certificates in both clusters <a name="lab-4---configure-common-trust-certificates-in-both-clusters-"></a>

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



## Lab 5 - Install the Istio CLI tool <a name="lab-5---install-the-istio-cli-tool-"></a>

Download the Istio CLI and add it to your `$PATH`:

```bash
OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')

mkdir -p ~/.istioctl/bin
curl -sSL https://storage.googleapis.com/soloio-istio-binaries/release/1.25.3-solo/istioctl-1.25.3-solo-${OS}-${ARCH}.tar.gz | tar xzf - -C ~/.istioctl/bin
chmod +x ~/.istioctl/bin/istioctl

export PATH=${HOME}/.istioctl/bin:${PATH}
```



## Lab 6 - Deploy Istio <a name="lab-6---deploy-istio-"></a>

Install the Kubernetes Gateway API custom resource definitions in `cluster1` if they're not already present:

```bash
kubectl --context ${CLUSTER1} get crd gateways.gateway.networking.k8s.io &>/dev/null || \
  { kubectl --context ${CLUSTER1} apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml; }
```

Install Istio Ambient mode in `cluster1`:

```bash
istioctl --context ${CLUSTER1} install \
  --set profile=ambient \
  --set values.global.hub=us-docker.pkg.dev/soloio-img/istio \
  --set values.license.value=${GLOO_MESH_LICENSE_KEY} \
  --set meshConfig.trustDomain=${CLUSTER1} \
  --set values.global.multiCluster.clusterName=${CLUSTER1} \
  --set values.global.network=${CLUSTER1} \
  --set values.platforms.peering.enabled=true \
  --set values.pilot.env.PILOT_SKIP_VALIDATE_TRUST_DOMAIN="true" \
  --set values.ztunnel.env.SKIP_VALIDATE_TRUST_DOMAIN="true" \
  --skip-confirmation
```

Check that the Istio pods are running:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n istio-system get pods
```

Here is the expected output:

```,nocopy
NAME                      READY   STATUS    RESTARTS   AGE
istio-cni-node-75ds2      1/1     Running   0          86s
istiod-7758df6879-pcvjt   1/1     Running   0          45s
ztunnel-zgf7b             1/1     Running   0          13s
```

Make sure the `istio-system` namespace is labelled with the network:

```bash
kubectl --context ${CLUSTER1} label ns istio-system topology.istio.io/network=${CLUSTER1}
```

Now install Istio the same way on `cluster2`:

```bash
kubectl --context ${CLUSTER2} get crd gateways.gateway.networking.k8s.io &>/dev/null || \
  { kubectl --context ${CLUSTER2} apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml; }

istioctl --context ${CLUSTER2} install \
  --set profile=ambient \
  --set values.global.hub=us-docker.pkg.dev/soloio-img/istio \
  --set values.license.value=${GLOO_MESH_LICENSE_KEY} \
  --set meshConfig.trustDomain=${CLUSTER2} \
  --set values.global.multiCluster.clusterName=${CLUSTER2} \
  --set values.global.network=${CLUSTER2} \
  --set values.platforms.peering.enabled=true \
  --set values.pilot.env.PILOT_SKIP_VALIDATE_TRUST_DOMAIN="true" \
  --set values.ztunnel.env.SKIP_VALIDATE_TRUST_DOMAIN="true" \
  --skip-confirmation

kubectl --context ${CLUSTER2} label ns istio-system topology.istio.io/network=${CLUSTER2}
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Istio", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["istiod"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "istio-system", k8sObj: deploy }));
  });
  let DaemonSets = ["istio-cni-node", "ztunnel"];
  DaemonSets.forEach(DaemonSet => {
    it(DaemonSet + ' pods are ready in ' + cluster, () => helpers.checkDaemonSet({ context: cluster, namespace: "istio-system", k8sObj: DaemonSet }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-istioctl/tests/check-istio.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Istio", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["istiod"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "istio-system", k8sObj: deploy }));
  });
  let DaemonSets = ["istio-cni-node", "ztunnel"];
  DaemonSets.forEach(DaemonSet => {
    it(DaemonSet + ' pods are ready in ' + cluster, () => helpers.checkDaemonSet({ context: cluster, namespace: "istio-system", k8sObj: DaemonSet }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-istioctl/tests/check-istio.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
-->



## Lab 7 - Expose Bookinfo's productpage <a name="lab-7---expose-bookinfo's-productpage-"></a>

The [Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) sample app is now installed.
We're going to expose its `productpage` service securely with Istio using Gateway API resources.

Let's first create a private key and a self-signed certificate:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

You need to store this in a Kubernetes secret by running the following commands:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends create secret generic tls-secret \
  --from-file=tls.key=tls.key \
  --from-file=tls.crt=tls.crt
```

Next, create a `Gateway` resource to configure Istio to listen to incoming requests:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: http
  namespace: bookinfo-frontends
spec:
  gatewayClassName: istio
  listeners:
  - hostname: cluster1-bookinfo.example.com
    name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: tls-secret
        kind: Secret
EOF
```

Finally, create an `HTTPRoute` to expose the `productpage` service through the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  parentRefs:
  - name: http
  rules:
  - matches:
    - path:
        type: Exact
        value: /productpage
    - path:
        value: /static
    backendRefs:
    - name: productpage
      port: 9080
EOF
```
Let's add the domains to our `/etc/hosts` file:

```bash
export BOOKINFO_PROXY_IP=$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get svc http-istio -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
./scripts/register-domain.sh cluster1-bookinfo.example.com ${BOOKINFO_PROXY_IP}
```

You should now be able to access the Bookinfo application through the browser:

<https://cluster1-bookinfo.example.com/productpage>

![Bookinfo product page](images/steps/gateway-expose-gatewayapi/bookinfo.png)

After refreshing the Bookinfo application several times, switch to the Gloo UI and open the "Graph" page under "Observability".
Select `cluster1` under the "Clusters" dropdown, and select the `bookinfo-frontends` and `bookinfo-backends` namespaces.
You should see encrypted traffic from `http-istio` to `productpage-v1`and from there on to the `details`, `reviews` and `ratings` services:

![Bookinfo traffic in Gloo UI](images/steps/gateway-expose-gatewayapi/bookinfo-traffic-mesh.png)


This is because the Bookinfo application is part of the service mesh,
so its traffic is automatically encrypted.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-gatewayapi/tests/productpage-available-secure.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Otel metrics", () => {
  it("cluster1 is sending metrics to telemetryGateway", () => {
    podName = helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh get pods -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' --context " + process.env.MGMT }).replaceAll("'", "");
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh debug -q -i " + podName + " --image=curlimages/curl -- curl -s http://localhost:9090/api/v1/query?query=istio_requests_total" }).replaceAll("'", "");
    expect(command).to.contain("cluster\":\"cluster1");
  });
});


EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-gatewayapi/tests/otel-metrics.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=150 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');
const puppeteer = require('puppeteer');
const chai = require('chai');
const expect = chai.expect;
const GraphPage = require('./tests/pages/gloo-ui/graph-page');
const { recognizeTextFromScreenshot } = require('./tests/utils/image-ocr-processor');
const { enhanceBrowser } = require('./tests/utils/enhance-browser');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("graph page", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let page;
  let graphPage;

  beforeEach(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 40,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    page = await browser.newPage();
    graphPage = new GraphPage(page);
    await Promise.all(Array.from({ length: 20 }, () =>
      helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 })));
  });

  afterEach(async function () {
    await browser.close();
  });

  it("should show gateway and product page", async function () {
    await graphPage.navigateTo(`http://${process.env.ENDPOINT_GLOO_MESH_UI}/graph`);

    // Select the clusters and namespaces so that the graph shows
    await graphPage.selectClusters(['cluster1', 'cluster2']);
    await graphPage.selectNamespaces(['bookinfo-backends', 'bookinfo-frontends']);
    await graphPage.checkViewGraphButton();
    // Disabling Cilium nodes due to this issue: https://github.com/solo-io/gloo-mesh-enterprise/issues/18623
    await graphPage.toggleLayoutSettings();
    await graphPage.disableCiliumNodes();
    await graphPage.toggleLayoutSettings();

    // Capture a screenshot of the canvas and run text recognition
    await graphPage.fullscreenGraph();
    await graphPage.centerGraph();
    const screenshotPath = 'ui-test-data/canvas.png';
    await graphPage.captureCanvasScreenshot(screenshotPath);

    const recognizedTexts = await recognizeTextFromScreenshot(
      screenshotPath,
      ["http-istio", "productpage-v1", "details-v1", "ratings-v1", "reviews-v1", "reviews-v2"],
      await graphPage.getCurrentGlooUISelectors());

    const flattenedRecognizedText = recognizedTexts.join(",").replace(/\n/g, '');
    console.log("Flattened recognized text:", flattenedRecognizedText);

    // Validate recognized texts
    expect(flattenedRecognizedText).to.include("reviews-v2");
    expect(flattenedRecognizedText).to.include("http-istio");
    // The tessaract image processor sometimes interprets v1 as vl or vi. So cover all cases for v1 checks
    expect(flattenedRecognizedText).to.include.oneOf(["productpage-v1", "productpage-vl", "productpage-vi"]);
    expect(flattenedRecognizedText).to.include.oneOf(["details-v1", "details-vl", "details-vi"]);
    expect(flattenedRecognizedText).to.include.oneOf(["ratings-v1", "ratings-vl", "ratings-vi"]);
    expect(flattenedRecognizedText).to.include.oneOf(["reviews-v1", "reviews-vl", "reviews-vi"]);
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-gatewayapi/tests/graph-shows-traffic.test.js.liquid from lab number 7"
timeout --signal=INT 7m mocha ./test.js --timeout 120000 --retries=3 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->



## Lab 8 - Add Bookinfo to the mesh <a name="lab-8---add-bookinfo-to-the-mesh-"></a>

At the moment, the Bookinfo application is not part of the service mesh. Now we're going to add it to the service mesh.

Before we start, take a look at the UI Graph. You can see the gateway and the services that have been interacted with.
Because services are not part of the mesh yet, we can't see any traffic between them.

![UI-no-Mesh](images/steps/adding-services-to-mesh/ui-no-mesh.png)

We're using Istio Ambient mode, so onboarding to the service mesh is transparent to applications.
There is no need to restart them so that they can be injected with an Istio proxy sidecar.


1. To enable the automatic mesh injection,
   use the command below to add the necessary labels to the `bookinfo-frontends` namespace:

   ```bash
   kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
   kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
   ```

1. Validate that the namespace is annotated with the necessary labels:

   ```bash,norun-workshop
   kubectl --context ${CLUSTER1} get ns -L istio.io/dataplane-mode
   kubectl --context ${CLUSTER2} get ns -L istio.io/dataplane-mode
   ```

Now that you have a namespace with Ambient mode enabled, the services running in this namespace are automatically part of the mesh without any further action.

We can confirm this by checking pods for the annotation `ambient.istio.io/redirection: enabled`:

```bash,norun-workshop
kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods -ojson | jq -r '.items[] | select(.metadata.annotations["ambient.istio.io/redirection"] == "enabled") | .metadata.name'
kubectl --context ${CLUSTER2} -n bookinfo-frontends get pods -ojson | jq -r '.items[] | select(.metadata.annotations["ambient.istio.io/redirection"] == "enabled") | .metadata.name'
```

## Add more services to the Istio service mesh

Now that you have added the `productpage` service to the mesh, you can add the other services to the mesh as well.
The `details`, `reviews`, and `ratings` services are part of the `bookinfo-backends` namespace.

1. First, you need to annotate the `bookinfo-backends` namespace to enable automatic mesh injection:

   ```bash
   kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
   kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
   ```


1. Validate that all the pods in the `bookinfo-backends` namespace are part of the mesh:

   ```bash,norun-workshop
   kubectl --context ${CLUSTER1} -n bookinfo-backends get pods -ojson | jq -r '.items[] | select(.metadata.annotations["ambient.istio.io/redirection"] == "enabled") | .metadata.name'
   kubectl --context ${CLUSTER2} -n bookinfo-backends get pods -ojson | jq -r '.items[] | select(.metadata.annotations["ambient.istio.io/redirection"] == "enabled") | .metadata.name'
   ```

1. Make sure that you can continue to call the `productpage` service securely:

   <http://cluster1-bookinfo.example.com/productpage>

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/adding-services-to-mesh/tests/productpage-available-secure.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
-->

## What have you gained?

One of the values of using a service mesh is that you will gain immediate insight into the behaviour and interactions between your services.
Istio gives you access to important telemetry data, just by adding services to the mesh.
You also  get a lot of functionality for free, such as load balancing, circuit breaking, mutual TLS, and more.

Doing this with Istio Ambient mode, we did not need to restart our application pods to get them added to the mesh;
nor do we need to restart them in the future when we upgrade the Istio installation.

You can now see the services in the UI Graph, the traffic between them, and if they are healthy or not.

![UI-Mesh](images/steps/adding-services-to-mesh/ui-mesh.png)

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
  cluster = process.env.CLUSTER2
  deployments = ["productpage-v1"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo-frontends", k8sObj: deploy }));
  });
  deployments = ["ratings-v1", "details-v1", "reviews-v1", "reviews-v2", "reviews-v3"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo-backends", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/adding-services-to-mesh/../deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Bookinfo in " + process.env.CLUSTER1, () => {
  let cluster = process.env.CLUSTER1

  let apps = ["productpage"];
  apps.forEach(app => {
    it(app + " pods are in the service mesh", () =>
      helpers.checkPodForAnnotation({ context: cluster, namespace: "bookinfo-frontends", k8sLabel: "app=" + app, expectedAnnotationKey: "ambient.istio.io/redirection", expectedAnnotationValue: "enabled" })
    );
  });

  apps = ["ratings", "details", "reviews"];
  apps.forEach(app => {
    it(app + " pods are in the service mesh", () =>
      helpers.checkPodForAnnotation({ context: cluster, namespace: "bookinfo-backends", k8sLabel: "app=" + app, expectedAnnotationKey: "ambient.istio.io/redirection", expectedAnnotationValue: "enabled" })
    );
  });
});

describe("Bookinfo in " + process.env.CLUSTER2, () => {
  let cluster = process.env.CLUSTER2

  let apps = ["productpage"];
  apps.forEach(app => {
    it(app + " pods are in the service mesh", () =>
      helpers.checkPodForAnnotation({ context: cluster, namespace: "bookinfo-frontends", k8sLabel: "app=" + app, expectedAnnotationKey: "ambient.istio.io/redirection", expectedAnnotationValue: "enabled" })
    );
  });

  apps = ["ratings", "details", "reviews"];
  apps.forEach(app => {
    it(app + " pods are in the service mesh", () =>
      helpers.checkPodForAnnotation({ context: cluster, namespace: "bookinfo-backends", k8sLabel: "app=" + app, expectedAnnotationKey: "ambient.istio.io/redirection", expectedAnnotationValue: "enabled" })
    );
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/adding-services-to-mesh/tests/bookinfo-services-in-mesh.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
-->




## Lab 9 - Link clusters <a name="lab-9---link-clusters-"></a>

We'll now set up multi-cluster service discovery and routing using Istio Ambient.

Before clusters can be linked together, we need to deploy an east-west gateway in each cluster.
Do that with the following commands:

```bash
kubectl --context ${CLUSTER1} create namespace istio-gateways
istioctl --context ${CLUSTER1} multicluster expose --namespace istio-gateways

kubectl --context ${CLUSTER2} create namespace istio-gateways
istioctl --context ${CLUSTER2} multicluster expose --namespace istio-gateways
```

Wait for the gateways to be available:

```bash
kubectl --context ${CLUSTER1} -n istio-gateways wait --for=jsonpath='{.status.loadBalancer.ingress}' svc istio-eastwest --timeout 120s
kubectl --context ${CLUSTER2} -n istio-gateways wait --for=jsonpath='{.status.loadBalancer.ingress}' svc istio-eastwest --timeout 120s
```

Now, link the clusters together with a single command:

```bash
istioctl --context ${CLUSTER1} -n istio-gateways multicluster link --contexts ${CLUSTER1},${CLUSTER2}
```

The clusters are now ready to communicate to global services available in any cluster.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Istio east-west gateway", function() {
  it("exists and has an IP address in " + process.env.CLUSTER1, () => {
    const command = "kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get svc istio-eastwest -o jsonpath='{.status.loadBalancer}'";
    helpers.genericCommand({ command: command, responseContains: '"ingress"' });
  });

  it("exists and has an IP address in " + process.env.CLUSTER2, () => {
    const command = "kubectl --context " + process.env.CLUSTER2 + " -n istio-gateways get svc istio-eastwest -o jsonpath='{.status.loadBalancer}'";
    helpers.genericCommand({ command: command, responseContains: '"ingress"' });
  });
});

describe("Istio remote gateway", function() {
  it("exists for " + process.env.CLUSTER2 + " in " + process.env.CLUSTER1, () => {
    const command = "kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get gateway istio-remote-peer-" + process.env.CLUSTER2 + " -o jsonpath='{.status.conditions}'";
    helpers.genericCommand({ command: command, responseContains: '"Resource accepted"' });
  });

  it("exists for " + process.env.CLUSTER1 + " in " + process.env.CLUSTER2, () => {
    const command = "kubectl --context " + process.env.CLUSTER2 + " -n istio-gateways get gateway istio-remote-peer-" + process.env.CLUSTER1 + " -o jsonpath='{.status.conditions}'";
    helpers.genericCommand({ command: command, responseContains: '"Resource accepted"' });
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/link-clusters-istioctl/tests/check-gateways.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
-->



## Lab 10 - Declare productpage to be a global service for multi-cluster access <a name="lab-10---declare-productpage-to-be-a-global-service-for-multi-cluster-access-"></a>

To allow the `productpage` service to be accessed from other clusters, it needs to be declared as a global service.

Let's do that now, by adding the label `solo.io/service-scope=global` to the service we want to expose globally:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends label svc productpage solo.io/service-scope=global
kubectl --context ${CLUSTER2} -n bookinfo-frontends label svc productpage solo.io/service-scope=global
```

To make sure that traffic is load balanced across local and remote replicas of this service,
we'll also annotate it with `networking.istio.io/traffic-distribution=Any`:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate svc productpage networking.istio.io/traffic-distribution=Any
kubectl --context ${CLUSTER2} -n bookinfo-frontends annotate svc productpage networking.istio.io/traffic-distribution=Any
```
Finally, update the `HTTPRoute` that exposes the `productpage` service so that it references its global hostname,
`productpage.bookinfo-frontends.mesh.internal`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  parentRefs:
  - name: http
  rules:
  - matches:
    - path:
        type: Exact
        value: /productpage
    - path:
        value: /static
    backendRefs:
    - kind: Hostname
      group: networking.istio.io
      name: productpage.bookinfo-frontends.mesh.internal
      port: 9080
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/declare-global-service/../adding-services-to-mesh/tests/productpage-available-secure.test.js.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("productpage service", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://productpage.bookinfo-frontends.mesh.internal:9080/productpage'); print(r.text)\"";
  it('responds from cluster1', () => helpers.genericCommand({ command: command, responseContains: "cluster1" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/declare-global-service/tests/productpage-from-cluster1.test.js.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("productpage service", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://productpage.bookinfo-frontends.mesh.internal:9080/productpage'); print(r.text)\"";
  it('responds from cluster2', () => helpers.genericCommand({ command: command, responseContains: "cluster2" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/declare-global-service/tests/productpage-from-cluster2.test.js.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
-->

That's it! Check that you get reviews from services in both `cluster1` and `cluster2` when you refresh the Bookinfo application several times.

After refreshing the Bookinfo application several times, switch to the Gloo UI and open the "Graph" page under "Observability".
Select `cluster1` and `cluster2` under the "Clusters" dropdown, and select the `bookinfo-frontends` and `bookinfo-backends` namespaces.
You should see encrypted traffic from `http-istio` to both `productpage-v1` services in `cluster1` and `cluster2`,
and from there on to the local `details`, `reviews` and `ratings` services, including `reviews-v3`:

![Bookinfo traffic in Gloo UI](images/steps/declare-global-service/bookinfo-multicluster.png)



