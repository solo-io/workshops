#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
source ./scripts/assert.sh
export MGMT=cluster1
export CLUSTER1=cluster1
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
./scripts/check.sh cluster1
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = ["cluster1"];

    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
export GLOO_MESH_VERSION=v2.7.0-beta1
curl -sL https://run.solo.io/meshctl/install | sh -
export PATH=$HOME/.gloo-mesh/bin:$PATH
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --set featureGates.insightsConfiguration=true \
  --version 2.7.0-beta1

helm upgrade --install gloo-platform-mgmt gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.7.0-beta1 \
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
export ENDPOINT_GLOO_MESH_UI=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-ui -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):8090
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
curl -L https://istio.io/downloadIstio | sh -

if [ -d "istio-"*/ ]; then
  cd istio-*/
  export PATH=$PWD/bin:$PATH
  cd ..
fi
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
    let version = "1.24.1-patch1";
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-helm/tests/istio-version.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
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
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.24.1-patch1-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
EOF

helm upgrade --install istiod-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.24.1-patch1-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.24.1-patch1-solo
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
  trustDomain: cluster1
pilot:
  enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER1} \
--version 1.24.1-patch1-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.24.1-patch1-solo
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
--version 1.24.1-patch1-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster1
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.24.1-patch1-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-23 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.24.1-patch1-solo \
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

kubectl --context ${CLUSTER1} get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.1.0" | kubectl --context ${CLUSTER1} apply -f -; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-helm/tests/istio-ready.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o json | jq '.items[0].status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
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
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 4 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
echo -n Waiting for clients to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n clients get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
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
kubectl --context ${CLUSTER1} -n clients get pods
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/clients/deploy-clients/tests/check-clients.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
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
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: bookinfo-backends
spec:
  {}
EOF
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
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
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l4-authn-interoperability/tests/validate-interoperability.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=disabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
# wait for all pods to be running

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l4-authn-interoperability/tests/validate-interoperability.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode-
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=enabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
# wait for all pods to be running

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/is-waypoint-created.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint=waypoint
for workload in not-in-mesh in-mesh-with-sidecar in-ambient; do
  echo "${workload} to reviews.bookinfo-backends"
  kubectl --context ${CLUSTER1} -n clients exec deploy/$workload -- curl -s -o /dev/null -w "%{http_code}" "http://reviews.bookinfo-backends:9080/reviews/0"
  echo
done
sleep 20
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=disabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
# wait for all pods to be ready

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-authz-interoperability/tests/validate-interoperability.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl --context ${CLUSTER1} delete authorizationpolicy reviews-admit-traffic -n bookinfo-backends
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode-
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=enabled --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout restart deploy
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint-
kubectl --context ${CLUSTER1} delete gateway waypoint -n bookinfo-backends
kubectl --context ${CLUSTER1} delete authorizationpolicies -A --all
kubectl --context ${CLUSTER1} delete peerauthentications -A --all
# wait for all pods to be running

timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get pods -n bookinfo-backends -o json  | jq -r '.items[] | select(.status.phase != \"Running\" or .metadata.deletionTimestamp != null) | .metadata.name' | wc -l) -eq 0 ]]; do sleep 1; done"
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
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint=waypoint
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-routing-interoperability/tests/validate-routing-interoperability.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-transforming-traffic-interoperability/tests/validate-traffic-transformation-interoperability.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=10 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
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
kubectl --context ${CLUSTER1} -n bookinfo-backends create deployment echo-service --image=ealen/echo-server
kubectl --context ${CLUSTER1} -n bookinfo-backends expose deployment echo-service --port=80 --target-port=80 --name=echo-service --type=ClusterIP
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout status deployment/echo-service
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-traffic-resiliency-interoperability/tests/validate-resiliency-interoperability.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=10 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
