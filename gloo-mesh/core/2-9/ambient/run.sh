#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
source ./scripts/assert.sh
export MGMT=mgmt
export CLUSTER1=cluster1
export CLUSTER2=cluster2
bash ./data/steps/deploy-kind-clusters/deploy-mgmt.sh
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
bash ./data/steps/deploy-kind-clusters/deploy-cluster2.sh
./scripts/check.sh mgmt
./scripts/check.sh cluster1
./scripts/check.sh cluster2
kubectl config use-context ${MGMT}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = ["mgmt", "cluster1", "cluster2"];

    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
export GLOO_MESH_VERSION=v2.9.1
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
    expect(process.env.CLUSTER2).not.to.be.empty
  });

  it("Gloo Mesh licence environment variables should not be empty", () => {
    expect(process.env.GLOO_MESH_LICENSE_KEY).not.to.be.empty
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --set featureGates.insightsConfiguration=true \
  --set installEnterpriseCrds=false \
  --version 2.9.1

helm upgrade --install gloo-platform gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.9.1 \
  -f -<<EOF
licensing:
  glooTrialLicenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: mgmt
experimental:
  ambientEnabled: true
glooInsightsEngine:
  enabled: true
glooMgmtServer:
  enabled: true
  policyApis:
    enabled: false
  ports:
    healthcheck: 8091
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
kubectl wait --context ${MGMT} --for=condition=Ready -n gloo-mesh --all pod
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
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
export ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):9900
export HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH%:*})
export ENDPOINT_TELEMETRY_GATEWAY=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-telemetry-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):4317
export ENDPOINT_GLOO_MESH_UI=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-ui -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):8090
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
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: cluster1
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF

kubectl --context ${CLUSTER1} create ns gloo-mesh

kubectl get secret relay-root-tls-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context ${CLUSTER1} --from-file ca.crt=ca.crt
rm ca.crt

kubectl get secret relay-identity-token-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.token}' | base64 -d > token
kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context ${CLUSTER1} --from-file token=token
rm token

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --set installEnterpriseCrds=false \
  --kube-context ${CLUSTER1} \
  --version 2.9.1

helm upgrade --install gloo-platform gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER1} \
  --version 2.9.1 \
  -f -<<EOF
common:
  cluster: cluster1
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

helm upgrade --install gloo-platform gloo-platform \
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
    let version = "1.25.3";
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
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
    revision: 1-25
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
    revision: 1-25
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
    revision: 1-25
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
    revision: 1-25
  type: LoadBalancer
EOF
kubectl --context ${CLUSTER1} create ns istio-system
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
revision: 1-25
EOF

helm upgrade --install istiod-1-25 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.25.3-solo
  multiCluster:
    clusterName: cluster1
  meshID: mesh1
profile: ambient
revision: 1-25
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: cluster1
pilot:
  enabled: true
  cni:
    enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER1} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.25.3-solo
profile: ambient
revision: 1-25
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
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
revision: 1-25
env:
  L7_ENABLED: "true"
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster1
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.25.3-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-25 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-25
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
  revision: 1-25
service:
  type: None
EOF

helm upgrade --install istio-eastwestgateway-1-25 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-25
imagePullPolicy: IfNotPresent
env:
  ISTIO_META_REQUESTED_NETWORK_VIEW: cluster1
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  revision: 1-25
  topology.istio.io/network: cluster1
service:
  type: None
EOF
kubectl --context ${CLUSTER1} apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
kubectl --context ${CLUSTER2} create ns istio-system
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
revision: 1-25
EOF

helm upgrade --install istiod-1-25 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.25.3-solo
  multiCluster:
    clusterName: cluster2
  meshID: mesh1
profile: ambient
revision: 1-25
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: cluster2
pilot:
  enabled: true
  cni:
    enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER2} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.25.3-solo
profile: ambient
revision: 1-25
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
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
revision: 1-25
env:
  L7_ENABLED: "true"
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster2
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.25.3-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-25 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER2} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-25
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
  revision: 1-25
service:
  type: None
EOF

helm upgrade --install istio-eastwestgateway-1-25 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER2} \
--version 1.25.3-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-25
imagePullPolicy: IfNotPresent
env:
  ISTIO_META_REQUESTED_NETWORK_VIEW: cluster2
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  revision: 1-25
  topology.istio.io/network: cluster2
service:
  type: None
EOF
kubectl --context ${CLUSTER2} apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-helm/tests/istio-ready.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o json | jq '.items[0].status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}{.items[0].status.loadBalancer.ingress[0].ip}')"
export HOST_GW_CLUSTER2="$(kubectl --context ${CLUSTER2} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}{.items[0].status.loadBalancer.ingress[0].ip}')"
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
kubectl --context ${CLUSTER1} create ns bookinfo-frontends
kubectl --context ${CLUSTER1} create ns bookinfo-backends
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio-injection=disabled
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio-injection=disabled
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio.io/rev=1-25 --overwrite
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/rev=1-25 --overwrite


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
kubectl --context ${CLUSTER2} create ns bookinfo-frontends
kubectl --context ${CLUSTER2} create ns bookinfo-backends
kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio-injection=disabled
kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio-injection=disabled
kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio.io/rev=1-25 --overwrite
kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio.io/rev=1-25 --overwrite


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

echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER2} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER2} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 5 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
kubectl --context ${CLUSTER2} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER2} -n bookinfo-backends get pods
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
kubectl --context ${CLUSTER1} create ns httpbin
kubectl --context ${CLUSTER1} label namespace httpbin istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace httpbin istio.io/rev=1-25
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
        istio.io/rev: 1-25
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
        istio.io/rev: 1-25
    spec:
      serviceAccountName: in-mesh
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
  
  let deployments = ["not-in-mesh", "in-mesh", "in-ambient"];
  
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "clients", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/clients/deploy-clients/tests/check-clients.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - cluster1-bookinfo.example.com
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  hosts:
  - cluster1-bookinfo.example.com
  gateways:
  - bookinfo
  http:
  - match:
    - uri:
        prefix: /productpage
    - uri:
        prefix: /static
    route:
    - destination:
        port:
          number: 9080
        host: productpage
EOF
./scripts/register-domain.sh cluster1-bookinfo.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster2-bookinfo.example.com ${HOST_GW_CLUSTER2}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("productpage is available (HTTP)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `http://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-istio/tests/productpage-available.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
kubectl --context ${CLUSTER1} -n istio-gateways create secret generic tls-secret \
--from-file=tls.key=tls.key \
--from-file=tls.crt=tls.crt

kubectl --context ${CLUSTER2} -n istio-gateways create secret generic tls-secret \
--from-file=tls.key=tls.key \
--from-file=tls.crt=tls.crt
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - cluster1-bookinfo.example.com
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: tls-secret
    hosts:
    - cluster1-bookinfo.example.com
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-istio/tests/productpage-available-secure.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-istio/tests/otel-metrics.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=150 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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

  it("should show ingress gateway and product page", async function () {
    await graphPage.navigateTo(`http://${process.env.ENDPOINT_GLOO_MESH_UI}/graph`);

    // Select the clusters and namespaces so that the graph shows
    await graphPage.selectClusters(['cluster1', 'cluster2']);
    await graphPage.selectNamespaces(['istio-gateways', 'bookinfo-backends', 'bookinfo-frontends']);
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
      ["istio-ingressgateway", "productpage-v1", "details-v1", "ratings-v1", "reviews-v1", "reviews-v2"],
      await graphPage.getCurrentGlooUISelectors());

    const flattenedRecognizedText = recognizedTexts.join(",").replace(/\n/g, '');
    console.log("Flattened recognized text:", flattenedRecognizedText);

    // Validate recognized texts
    expect(flattenedRecognizedText).to.include("reviews-v2");
    // New ReactFlow UI can truncate the istio-ingressgateway to istio-ingressgat...
    expect(flattenedRecognizedText).to.include.oneOf(["istio-ingressgateway","istio-ingressgat..."]);
    // For 2.7 the tessaract image processor is interpreting v1 as vl due to bold font. So cover all cases for v1 checks
    expect(flattenedRecognizedText).to.include.oneOf(["productpage-v1", "productpage-vl"]);
    expect(flattenedRecognizedText).to.include.oneOf(["details-v1", "details-vl"]);
    expect(flattenedRecognizedText).to.include.oneOf(["ratings-v1", "ratings-vl"]);
    expect(flattenedRecognizedText).to.include.oneOf(["reviews-v1", "reviews-vl"]);
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose-istio/tests/graph-shows-traffic.test.js.liquid from lab number 7"
timeout --signal=INT 7m mocha ./test.js --timeout 120000 --retries=3 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-backends/sa/*"
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));

  it('should reject traffic to bookinfo-backends details', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Error fetching product details',
      match: true
    })
  });

  it('should reject traffic to bookinfo-backends reviews', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Error fetching product reviews',
      match: true
    })
  });
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/authorization-policies/tests/bookinfo-backend-services-unavailable.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-frontends/sa/bookinfo-productpage"
        - "cluster1/ns/bookinfo-backends/sa/*"
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));

  it('should admit traffic to bookinfo-backends details', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Book Details',
      match: true
    })
  });

  it('should admit traffic to bookinfo-backends reviews', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Book Reviews',
      match: true
    })
  });
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/authorization-policies/tests/bookinfo-backend-services-available.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-frontends/sa/bookinfo-productpage"
        - "cluster1/ns/bookinfo-backends/sa/*"
    to:
    - operation:
        methods: ["GET"]
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));

  it('should reject traffic to bookinfo-backends details', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Error fetching product details',
      match: true
    })
  });

  it('should reject traffic to bookinfo-backends reviews', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Error fetching product reviews',
      match: true
    })
  });
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/authorization-policies/tests/bookinfo-backend-services-unavailable.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
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

kubectl --context ${CLUSTER1} -n bookinfo-backends label ns bookinfo-backends istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: policy
  namespace: bookinfo-backends
spec:
  targetRefs:
  - kind: Gateway
    group: gateway.networking.k8s.io
    name: waypoint
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster1/ns/bookinfo-frontends/sa/bookinfo-productpage"
        - "cluster1/ns/bookinfo-backends/sa/*"
    to:
    - operation:
        methods: ["GET"]
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));

  it('should admit traffic to bookinfo-backends details', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Book Details',
      match: true
    })
  });

  it('should admit traffic to bookinfo-backends reviews', () => {
    return helpers.checkBody({
      host: `https://cluster1-bookinfo.example.com`,
      path: '/productpage',
      retCode: 200,
      body: 'Book Reviews',
      match: true
    })
  });
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/authorization-policies/tests/bookinfo-backend-services-available.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 60000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl --context ${CLUSTER1} -n bookinfo-backends delete authorizationpolicy policy
for i in {1..20}; do  curl -k "http://cluster1-bookinfo.example.com/productpage" -I; done
kubectl --context ${CLUSTER1} debug -n istio-system "$pod" -it --image=curlimages/curl  -- curl http://localhost:15020/metrics | grep istio_request_
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

describe("L4 metrics available", function() {
  it("ztunnel contains L4 and l7 metrics", () => {
    let node = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].spec.nodeName}'`).stdout.replaceAll("'", "");
    let pods = JSON.parse(chaiExec(`kubectl --context ${process.env.CLUSTER1} -n istio-system get pods -l app=ztunnel -o json`).stdout).items;
    let pod = "";
    pods.forEach(item => {
      if(item.spec.nodeName == node) {
        pod = item.metadata.name;
      }
    });
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n istio-system debug ${pod} -it --image=curlimages/curl  -- curl http://localhost:15020/metrics`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain("istio_tcp_sent_bytes_total");
    expect(cli).output.to.contain("istio_requests_total");
    expect(cli).output.to.contain("istio_request_duration_milliseconds");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/l7-observability/tests/l4-l7-metrics-available.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context "${CLUSTER1}" -n istio-system logs ds/ztunnel
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');
const InsightsPage = require('./tests/pages/insights-page');
const constants = require('./tests/pages/constants');
const puppeteer = require('puppeteer');
var chai = require('chai');
var expect = chai.expect;
const { enhanceBrowser } = require('./tests/utils/enhance-browser');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Insights UI", function() {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let insightsPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  beforeEach(async function() {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 40,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    insightsPage = new InsightsPage(page);
  });

  // Use Mocha's 'after' hook to close Puppeteer
  afterEach(async function() {
    await browser.close();
  });

  it("should display BP0001 warning with text 'Globally scoped routing'", async () => {
    await insightsPage.navigateTo(`http://${process.env.ENDPOINT_GLOO_MESH_UI}/insights`);
    await insightsPage.selectClusters(['cluster1', 'cluster2']);
    await insightsPage.selectInsightTypes([constants.InsightType.BP]);
    const data = await insightsPage.getTableDataRows()
    expect(data.some(item => item.includes("Globally scoped routing"))).to.be.true;
  });

  it("should have quick resource state filters", async () => {
    await insightsPage.navigateTo(`http://${process.env.ENDPOINT_GLOO_MESH_UI}/insights`);
    const healthy = await insightsPage.getQuickFiltersResourcesCount("healthy");
    const warning = await insightsPage.getQuickFiltersResourcesCount("warning");
    const error = await insightsPage.getQuickFiltersResourcesCount("error");
    expect(warning).to.be.greaterThan(0);
    expect(error).to.be.a('number');
    expect(healthy).to.be.greaterThan(0);
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-intro/tests/insight-ui-BP0001.test.js.liquid from lab number 10"
timeout --signal=INT 5m mocha ./test.js --timeout 120000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

const deployments = [
  { name: "gloo-mesh-mgmt-server", arg: "--stats-port=9094" },
  { name: "gloo-mesh-ui", arg: "--insights-stats-port=9094" }
]

describe("Insight generation", () => {
  it("Insight BP0002 has been triggered in the source (MGMT)", () => {
    let insightsSvcName = '';
    for (let i=0; i<deployments.length; i++) {
      // Go through the deployments one at a time and get list of args for all the containers
      let listOfArgs = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get deploy ${deployments[i].name} -o jsonpath='{.spec.template.spec.containers[*].args[*]}}'`}).replaceAll("'", "");
      if (listOfArgs.includes(deployments[i].arg)) {
        // if the list of arguments contain arg '*stats-port=9090', that's the deployment to use to query for insight metrics. Return the associated service.
        insightsSvcName = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get svc --selector=app=${deployments[i].name} -o jsonpath='{range.items[]}{.metadata.name}'`}).replaceAll("'", "");
        break;
      };
    }
    expect(insightsSvcName).not.to.be.empty;

    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc ${insightsSvcName} -p '{"spec":{"ports": [{"port": 9094,"name":"http-insights"}]}}'` });
    helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh run debug --image=nginx:1.25.3 --context " + process.env.MGMT });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s http://" + insightsSvcName + ".gloo-mesh:9094/metrics" }).replaceAll("'", "");
    const regex = /gloo_mesh_insights{.*BP0002.*} 1/;
    const match = command.match(regex);
    expect(match).to.not.be.null;
  });

  it("Insight BP0002 has been triggered in PROMETHEUS", () => {
    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc prometheus-server -p '{"spec":{"ports": [{"port": 9090,"name":"http-metrics"}]}}'` });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s 'http://prometheus-server.gloo-mesh:9090/api/v1/query?query=gloo_mesh_insights'" }).replaceAll("'", "");
    let result = JSON.parse(command);
    let active = false;
    result.data.result.forEach(item => {
      if(item.metric.code == "BP0002" && item.value[1] > 0) {
        active = true
      }
    });
    expect(active).to.be.true;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-intro/tests/insight-metrics.test.js.liquid from lab number 10"
timeout --signal=INT 5m mocha ./test.js --timeout 120000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2alpha1
kind: InsightsConfig
metadata:
  name: insights-config
  namespace: gloo-mesh
spec:
  disabledInsights:
    - BP0002
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');
const InsightsPage = require('./tests/pages/insights-page');
const constants = require('./tests/pages/constants');
const puppeteer = require('puppeteer');
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Insights UI", function() {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let insightsPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  beforeEach(async function() {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 40,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    insightsPage = new InsightsPage(page);
  });

  // Use Mocha's 'after' hook to close Puppeteer
  afterEach(async function() {
    await browser.close();
  });

  it("should not display BP0002 in the UI", async () => {
    await insightsPage.navigateTo(`http://${process.env.ENDPOINT_GLOO_MESH_UI}/insights`);
    await insightsPage.selectClusters(['cluster1', 'cluster2']);
    await insightsPage.selectInsightTypes([constants.InsightType.BP]);
    const data = await insightsPage.getTableDataRows()
    expect(data.some(item => item.includes("is not namespaced"))).to.be.false;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-intro/tests/insight-not-ui-BP0002.test.js.liquid from lab number 10"
timeout --signal=INT 5m mocha ./test.js --timeout 120000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: bookinfo
  namespace: bookinfo-frontends
spec:
  hosts:
  - cluster1-bookinfo.example.com
  exportTo:
  - istio-gateways
  gateways:
  - bookinfo
  http:
  - match:
    - uri:
        prefix: /productpage
    - uri:
        prefix: /static
    route:
    - destination:
        port:
          number: 9080
        host: productpage
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');
const InsightsPage = require('./tests/pages/insights-page');
const constants = require('./tests/pages/constants');
const puppeteer = require('puppeteer');
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Insights UI", function() {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let insightsPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  beforeEach(async function() {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 40,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    insightsPage = new InsightsPage(page);
  });

  // Use Mocha's 'after' hook to close Puppeteer
  afterEach(async function() {
    await browser.close();
  });

  it("should not display BP0001 in the UI", async () => {
    await insightsPage.navigateTo(`http://${process.env.ENDPOINT_GLOO_MESH_UI}/insights`);
    await insightsPage.selectClusters(['cluster1', 'cluster2']);
    await insightsPage.selectInsightTypes([constants.InsightType.BP]);
    const data = await insightsPage.getTableDataRows()
    expect(data.some(item => item.includes("is not namespaced"))).to.be.false;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-intro/tests/insight-not-ui-BP0001.test.js.liquid from lab number 10"
timeout --signal=INT 5m mocha ./test.js --timeout 120000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
  - reviews
  exportTo:
  - bookinfo-frontends
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
EOF
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

const deployments = [
  { name: "gloo-mesh-mgmt-server", arg: "--stats-port=9094" },
  { name: "gloo-mesh-ui", arg: "--insights-stats-port=9094" }
]

describe("Insight generation", () => {
  it("Insight CFG0001 has been triggered in the source (MGMT)", () => {
    let insightsSvcName = '';
    for (let i=0; i<deployments.length; i++) {
      // Go through the deployments one at a time and get list of args for all the containers
      let listOfArgs = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get deploy ${deployments[i].name} -o jsonpath='{.spec.template.spec.containers[*].args[*]}}'`}).replaceAll("'", "");
      if (listOfArgs.includes(deployments[i].arg)) {
        // if the list of arguments contain arg '*stats-port=9090', that's the deployment to use to query for insight metrics. Return the associated service.
        insightsSvcName = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get svc --selector=app=${deployments[i].name} -o jsonpath='{range.items[]}{.metadata.name}'`}).replaceAll("'", "");
        break;
      };
    }
    expect(insightsSvcName).not.to.be.empty;

    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc ${insightsSvcName} -p '{"spec":{"ports": [{"port": 9094,"name":"http-insights"}]}}'` });
    helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh run debug --image=nginx: --context " + process.env.MGMT });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s http://" + insightsSvcName + ".gloo-mesh:9094/metrics" }).replaceAll("'", "");
    const regex = /gloo_mesh_insights{.*CFG0001.*} 1/;
    const match = command.match(regex);
    expect(match).to.not.be.null;
  });

  it("Insight CFG0001 has been triggered in PROMETHEUS", () => {
    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc prometheus-server -p '{"spec":{"ports": [{"port": 9090,"name":"http-metrics"}]}}'` });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s 'http://prometheus-server.gloo-mesh:9090/api/v1/query?query=gloo_mesh_insights'" }).replaceAll("'", "");
    let result = JSON.parse(command);
    let active = false;
    result.data.result.forEach(item => {
      if(item.metric.code == "CFG0001" && item.value[1] > 0) {
        active = true
      }
    });
    expect(active).to.be.true;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-config/../insights-intro/tests/insight-metrics.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 120000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  host: reviews.bookinfo-backends.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
EOF
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

const deployments = [
  { name: "gloo-mesh-mgmt-server", arg: "--stats-port=9094" },
  { name: "gloo-mesh-ui", arg: "--insights-stats-port=9094" }
]

describe("Insight generation", () => {
  it("Insight CFG0001 has not been triggered in the source (MGMT)", () => {
    let insightsSvcName = '';
    for (let i=0; i<deployments.length; i++) {
      // Go through the deployments one at a time and get list of args for all the containers
      let listOfArgs = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get deploy ${deployments[i].name} -o jsonpath='{.spec.template.spec.containers[*].args[*]}}'`}).replaceAll("'", "");
      if (listOfArgs.includes(deployments[i].arg)) {
        // if the list of arguments contain arg '*stats-port=9090', that's the deployment to use to query for insight metrics. Return the associated service.
        insightsSvcName = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get svc --selector=app=${deployments[i].name} -o jsonpath='{range.items[]}{.metadata.name}'`}).replaceAll("'", "");
        break;
      };
    }
    expect(insightsSvcName).not.to.be.empty;

    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc ${insightsSvcName} -p '{"spec":{"ports": [{"port": 9094,"name":"http-insights"}]}}'` });
    helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh run debug --image=nginx: --context " + process.env.MGMT });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s http://" + insightsSvcName + ".gloo-mesh:9094/metrics" }).replaceAll("'", "");
    const regex = /gloo_mesh_insights{.*CFG0001.*} 1/;
    const match = command.match(regex);
    expect(match).to.be.null;
  });

  it("Insight CFG0001 has not been triggered in PROMETHEUS", () => {
    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc prometheus-server -p '{"spec":{"ports": [{"port": 9090,"name":"http-metrics"}]}}'` });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s 'http://prometheus-server.gloo-mesh:9090/api/v1/query?query=gloo_mesh_insights'" }).replaceAll("'", "");
    let result = JSON.parse(command);
    let active = false;
    result.data.result.forEach(item => {
      if(item.metric.code == "CFG0001" && item.value[1] > 0) {
        active = true
      }
    });
    expect(active).to.be.false;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-config/../insights-intro/tests/insight-metrics.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 120000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
kubectl --context ${CLUSTER1} -n bookinfo-backends delete virtualservice reviews
kubectl --context ${CLUSTER1} -n bookinfo-backends delete destinationrule reviews
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  action: DENY
  selector:
    matchLabels:
      app: reviews
  rules:
  - from:
    - source:
        namespaces: ["httpbin"]
EOF
pod=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l app=in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n httpbin debug -q -i ${pod} --image=curlimages/curl -- curl -s http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0 
pod=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l app=not-in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n httpbin debug -q -i ${pod} --image=curlimages/curl -- curl -s http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0 
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

const deployments = [
  { name: "gloo-mesh-mgmt-server", arg: "--stats-port=9094" },
  { name: "gloo-mesh-ui", arg: "--insights-stats-port=9094" }
]

describe("Insight generation", () => {
  it("Insight SEC0008 has been triggered in the source (MGMT)", () => {
    let insightsSvcName = '';
    for (let i=0; i<deployments.length; i++) {
      // Go through the deployments one at a time and get list of args for all the containers
      let listOfArgs = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get deploy ${deployments[i].name} -o jsonpath='{.spec.template.spec.containers[*].args[*]}}'`}).replaceAll("'", "");
      if (listOfArgs.includes(deployments[i].arg)) {
        // if the list of arguments contain arg '*stats-port=9090', that's the deployment to use to query for insight metrics. Return the associated service.
        insightsSvcName = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get svc --selector=app=${deployments[i].name} -o jsonpath='{range.items[]}{.metadata.name}'`}).replaceAll("'", "");
        break;
      };
    }
    expect(insightsSvcName).not.to.be.empty;

    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc ${insightsSvcName} -p '{"spec":{"ports": [{"port": 9094,"name":"http-insights"}]}}'` });
    helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh run debug --image=nginx: --context " + process.env.MGMT });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s http://" + insightsSvcName + ".gloo-mesh:9094/metrics" }).replaceAll("'", "");
    const regex = /gloo_mesh_insights{.*SEC0008.*} 1/;
    const match = command.match(regex);
    expect(match).to.not.be.null;
  });

  it("Insight SEC0008 has been triggered in PROMETHEUS", () => {
    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc prometheus-server -p '{"spec":{"ports": [{"port": 9090,"name":"http-metrics"}]}}'` });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s 'http://prometheus-server.gloo-mesh:9090/api/v1/query?query=gloo_mesh_insights'" }).replaceAll("'", "");
    let result = JSON.parse(command);
    let active = false;
    result.data.result.forEach(item => {
      if(item.metric.code == "SEC0008" && item.value[1] > 0) {
        active = true
      }
    });
    expect(active).to.be.true;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-security/../insights-intro/tests/insight-metrics.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

const deployments = [
  { name: "gloo-mesh-mgmt-server", arg: "--stats-port=9094" },
  { name: "gloo-mesh-ui", arg: "--insights-stats-port=9094" }
]

describe("Insight generation", () => {
  it("Insight SEC0008 has not been triggered in the source (MGMT)", () => {
    let insightsSvcName = '';
    for (let i=0; i<deployments.length; i++) {
      // Go through the deployments one at a time and get list of args for all the containers
      let listOfArgs = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get deploy ${deployments[i].name} -o jsonpath='{.spec.template.spec.containers[*].args[*]}}'`}).replaceAll("'", "");
      if (listOfArgs.includes(deployments[i].arg)) {
        // if the list of arguments contain arg '*stats-port=9090', that's the deployment to use to query for insight metrics. Return the associated service.
        insightsSvcName = helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh get svc --selector=app=${deployments[i].name} -o jsonpath='{range.items[]}{.metadata.name}'`}).replaceAll("'", "");
        break;
      };
    }
    expect(insightsSvcName).not.to.be.empty;

    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc ${insightsSvcName} -p '{"spec":{"ports": [{"port": 9094,"name":"http-insights"}]}}'` });
    helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh run debug --image=nginx: --context " + process.env.MGMT });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s http://" + insightsSvcName + ".gloo-mesh:9094/metrics" }).replaceAll("'", "");
    const regex = /gloo_mesh_insights{.*SEC0008.*} 1/;
    const match = command.match(regex);
    expect(match).to.be.null;
  });

  it("Insight SEC0008 has not been triggered in PROMETHEUS", () => {
    helpers.getOutputForCommand({ command: `kubectl --context ${process.env.MGMT} -n gloo-mesh patch svc prometheus-server -p '{"spec":{"ports": [{"port": 9090,"name":"http-metrics"}]}}'` });
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh exec debug -- curl -s 'http://prometheus-server.gloo-mesh:9090/api/v1/query?query=gloo_mesh_insights'" }).replaceAll("'", "");
    let result = JSON.parse(command);
    let active = false;
    result.data.result.forEach(item => {
      if(item.metric.code == "SEC0008" && item.value[1] > 0) {
        active = true
      }
    });
    expect(active).to.be.false;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/insights-security/../insights-intro/tests/insight-metrics.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
kubectl --context ${CLUSTER1} -n bookinfo-backends delete authorizationpolicy reviews
kubectl --context ${CLUSTER1} -n istio-system delete peerauthentication default
kubectl --context ${CLUSTER1} create ns istio-system
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
revision: 1-26
EOF

helm upgrade --install istiod-1-26 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER1} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.26.2-solo
  multiCluster:
    clusterName: cluster1
  meshID: mesh1
profile: ambient
revision: 1-26
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: cluster1
pilot:
  enabled: true
  cni:
    enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER1} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.26.2-solo
profile: ambient
revision: 1-26
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
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
revision: 1-26
env:
  L7_ENABLED: "true"
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster1
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.26.2-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-26 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-26
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
  revision: 1-26
service:
  type: None
EOF

helm upgrade --install istio-eastwestgateway-1-26 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER1} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-26
imagePullPolicy: IfNotPresent
env:
  ISTIO_META_REQUESTED_NETWORK_VIEW: cluster1
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  revision: 1-26
  topology.istio.io/network: cluster1
service:
  type: None
EOF
kubectl --context ${CLUSTER2} create ns istio-system
helm upgrade --install istio-base oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
defaultRevision: ""
profile: ambient
revision: 1-26
EOF

helm upgrade --install istiod-1-26 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
--namespace istio-system \
--kube-context=${CLUSTER2} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy:
    clusterDomain: cluster.local
  tag: 1.26.2-solo
  multiCluster:
    clusterName: cluster2
  meshID: mesh1
profile: ambient
revision: 1-26
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
  trustDomain: cluster2
pilot:
  enabled: true
  cni:
    enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
EOF

helm upgrade --install istio-cni oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
--namespace kube-system \
--kube-context=${CLUSTER2} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
global:
  hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
  proxy: 1.26.2-solo
profile: ambient
revision: 1-26
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
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
configValidation: true
enabled: true
revision: 1-26
env:
  L7_ENABLED: "true"
  SKIP_VALIDATE_TRUST_DOMAIN: "true"
hub: us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo>
istioNamespace: istio-system
multiCluster:
  clusterName: cluster2
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: 1.26.2-solo
terminationGracePeriodSeconds: 29
variant: distroless
EOF

helm upgrade --install istio-ingressgateway-1-26 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER2} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-26
imagePullPolicy: IfNotPresent
labels:
  app: istio-ingressgateway
  istio: ingressgateway
  revision: 1-26
service:
  type: None
EOF

helm upgrade --install istio-eastwestgateway-1-26 oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/gateway \
--namespace istio-gateways \
--kube-context=${CLUSTER2} \
--version 1.26.2-solo \
--create-namespace \
-f - <<EOF
autoscaling:
  enabled: false
profile: ambient
revision: 1-26
imagePullPolicy: IfNotPresent
env:
  ISTIO_META_REQUESTED_NETWORK_VIEW: cluster2
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  revision: 1-26
  topology.istio.io/network: cluster2
service:
  type: None
EOF
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
  it('istiod pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-system", labels: "app=istiod", instances: 2 }));
  it('gateway pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-gateways", labels: "app=istio-ingressgateway", instances: 4 }));
  it('istiod pods are ready in cluster ' + process.env.CLUSTER2, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER2, namespace: "istio-system", labels: "app=istiod", instances: 2 }));
  it('gateway pods are ready in cluster ' + process.env.CLUSTER2, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER2, namespace: "istio-gateways", labels: "app=istio-ingressgateway", instances: 4 }));
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-istio-helm/tests/istio-ready.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl --context ${CLUSTER1} get ns -l istio.io/rev=1-25 -o json | jq -r '.items[].metadata.name' | while read ns; do
  kubectl --context ${CLUSTER1} label ns ${ns} istio.io/rev=1-26 --overwrite
done
kubectl --context ${CLUSTER2} get ns -l istio.io/rev=1-25 -o json | jq -r '.items[].metadata.name' | while read ns; do
  kubectl --context ${CLUSTER2} label ns ${ns} istio.io/rev=1-26 --overwrite
done

if kubectl --context ${CLUSTER1} -n httpbin get deploy in-mesh -o json | jq -e '.spec.template.metadata.labels."istio.io/rev"' >/dev/null; then
  kubectl --context ${CLUSTER1} -n httpbin patch deploy in-mesh --patch "{\"spec\": {\"template\": {\"metadata\": {\"labels\": {\"istio.io/rev\": \"1-26\" }}}}}"
  kubectl --context ${CLUSTER1} -n httpbin rollout status deploy in-mesh
fi
if kubectl --context ${CLUSTER1} -n clients get deploy in-mesh-with-sidecar -o json | jq -e '.spec.template.metadata.labels."istio.io/rev"' >/dev/null; then
  kubectl --context ${CLUSTER1} -n clients patch deploy in-mesh-with-sidecar --patch "{\"spec\": {\"template\": {\"metadata\": {\"labels\": {\"istio.io/rev\": \"1-26\" }}}}}"
  kubectl --context ${CLUSTER1} -n clients rollout status deploy in-mesh-with-sidecar
fi
curl -k "https:///productpage" -I
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("productpage is accessible", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/helm-migrate-workloads-to-revision/../deploy-istio-helm/tests/productpage-available.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
kubectl --context ${CLUSTER1} -n istio-gateways patch svc istio-ingressgateway --type=json --patch '[{"op": "remove", "path": "/spec/selector/revision"}]'
kubectl --context ${CLUSTER1} -n istio-gateways patch svc istio-eastwestgateway --type=json --patch '[{"op": "remove", "path": "/spec/selector/revision"}]'
kubectl --context ${CLUSTER2} -n istio-gateways patch svc istio-ingressgateway --type=json --patch '[{"op": "remove", "path": "/spec/selector/revision"}]'
kubectl --context ${CLUSTER2} -n istio-gateways patch svc istio-eastwestgateway --type=json --patch '[{"op": "remove", "path": "/spec/selector/revision"}]'
curl -k "https:///productpage" -I
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("productpage is accessible", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/helm-migrate-workloads-to-revision/../deploy-istio-helm/tests/productpage-available.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("productpage is accessible", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/helm-migrate-workloads-to-revision/../deploy-istio-helm/tests/productpage-available.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const chai = require("chai");
var expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("istio in place upgrades", function() {
  const cluster1 = process.env.CLUSTER1;
  it("should upgrade waypoints", () => {
    let cli = chaiExec(`sh -c "istioctl --context ${cluster1} ps | grep waypoint"`);
    expect(cli.stdout).to.contain("1.26.2");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/helm-migrate-workloads-to-revision/tests/waypoint-upgraded.test.js.liquid from lab number 14"
timeout --signal=INT 1m mocha ./test.js --timeout 10000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
helm uninstall istio-ingressgateway-1-25 \
--namespace istio-gateways \
--kube-context=${CLUSTER1}

helm uninstall istio-eastwestgateway-1-25 \
--namespace istio-gateways \
--kube-context=${CLUSTER1}

helm uninstall istio-ingressgateway-1-25 \
--namespace istio-gateways \
--kube-context=${CLUSTER2}

helm uninstall istio-eastwestgateway-1-25 \
--namespace istio-gateways \
--kube-context=${CLUSTER2}
kubectl --context ${CLUSTER1} -n istio-system get pods
kubectl --context ${CLUSTER2} -n istio-system get pods
kubectl --context ${CLUSTER1} -n istio-gateways get pods
kubectl --context ${CLUSTER2} -n istio-gateways get pods
ATTEMPTS=1
until [[ $(kubectl --context ${CLUSTER1} -n istio-gateways get pods -l "istio.io/rev=1-25" -o json | jq '.items | length') -eq 0 ]] || [ $ATTEMPTS -gt 120 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
[ $ATTEMPTS -le 120 ] || kubectl --context ${CLUSTER1} -n istio-gateways get pods -l "istio.io/rev=1-25"

ATTEMPTS=1
until [[ $(kubectl --context ${CLUSTER2} -n istio-gateways get pods -l "istio.io/rev=1-25" -o json | jq '.items | length') -eq 0 ]] || [ $ATTEMPTS -gt 60 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
[ $ATTEMPTS -le 60 ] || kubectl --context ${CLUSTER2} -n istio-gateways get pods -l "istio.io/rev=1-25"
helm uninstall istiod-1-25 \
--namespace istio-system \
--kube-context=${CLUSTER1}

helm uninstall istiod-1-25 \
--namespace istio-system \
--kube-context=${CLUSTER2}
ATTEMPTS=1
until [[ $(kubectl --context ${CLUSTER1} -n istio-system get pods -l "istio.io/rev=1-25" -o json | jq '.items | length') -eq 0 ]] || [ $ATTEMPTS -gt 120 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
[ $ATTEMPTS -le 120 ] || kubectl --context ${CLUSTER1} -n istio-system get pods -l "istio.io/rev=1-25"
ATTEMPTS=1
until [[ $(kubectl --context ${CLUSTER2} -n istio-system get pods -l "istio.io/rev=1-25" -o json | jq '.items | length') -eq 0 ]] || [ $ATTEMPTS -gt 60 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
[ $ATTEMPTS -le 60 ] || kubectl --context ${CLUSTER2} -n istio-system get pods -l "istio.io/rev=1-25"
kubectl --context ${CLUSTER1} -n istio-system get pods && kubectl --context ${CLUSTER1} -n istio-gateways get pods
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
describe("Old Istio version should be uninstalled", () => {
  it("Pods aren't running anymore in CLUSTER1, namespace istio-system", () => {
    let cli = chaiExec('kubectl --context ' + process.env.CLUSTER1 + ' -n istio-system get pods -l "istio.io/rev=' + process.env.OLD_REVISION +'" -o json');
    expect(cli).to.exit.with.code(0);
    expect(JSON.parse(cli.stdout).items).to.have.lengthOf(0);
  });
  it("Pods aren't running anymore in CLUSTER1, namespace istio-gateways", () => {
    let cli = chaiExec('kubectl --context ' + process.env.CLUSTER1 + ' -n istio-gateways get pods -l "istio.io/rev=' + process.env.OLD_REVISION +'" -o json');
    expect(cli).to.exit.with.code(0);
    expect(JSON.parse(cli.stdout).items).to.have.lengthOf(0);
  });
  it("Pods aren't running anymore in CLUSTER2, namespace istio-system", () => {
    let cli = chaiExec('kubectl --context ' + process.env.CLUSTER2 + ' -n istio-system get pods -l "istio.io/rev=' + process.env.OLD_REVISION +'" -o json');
    expect(cli).to.exit.with.code(0);
    expect(JSON.parse(cli.stdout).items).to.have.lengthOf(0);
  });
  it("Pods aren't running anymore in CLUSTER2, namespace istio-gateways", () => {
    let cli = chaiExec('kubectl --context ' + process.env.CLUSTER2 + ' -n istio-gateways get pods -l "istio.io/rev=' + process.env.OLD_REVISION +'" -o json');
    expect(cli).to.exit.with.code(0);
    expect(JSON.parse(cli.stdout).items).to.have.lengthOf(0);
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/helm-cleanup-revision/tests/previous-version-uninstalled.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
kubectl --context ${CLUSTER1} -n egress rollout status deployment/waypoint
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-egress/tests/validate-egress-traffic.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=60 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
kubectl --context ${CLUSTER1} delete authorizationpolicy httpbin -n egress
kubectl --context ${CLUSTER1} delete httproute httpbin -n egress
kubectl --context ${CLUSTER1} delete networkpolicy restricted-namespace-policy -n clients
kubectl --context ${CLUSTER1} delete serviceentry httpbin.org -n egress
kubectl --context ${CLUSTER1} delete destinationrule httpbin.org-tls -n egress
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/waypoint-for: service
  name: waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
EOF
kubectl --context ${CLUSTER1} label ns bookinfo-backends istio.io/use-waypoint=waypoint --overwrite
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

describe("waypoint for service when ns is labeled", function() {
  const cluster = process.env.CLUSTER1

  it(`should redirect traffic for all services to the waypoint`, () => {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -v "http://ratings.bookinfo-backends:9080/ratings/0"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('istio-envoy');

    command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -v "http://reviews.bookinfo-backends:9080/reviews/0"`;
    cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('istio-envoy');
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-deployment-options/tests/validate-waypoint-for-service-ns.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/waypoint-for: service
  name: ratings-waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-traffic-from-clients-ns
  namespace: bookinfo-backends
spec:
  targetRefs:
  - kind: Gateway
    name: ratings-waypoint
    group: gateway.networking.k8s.io
  action: DENY
  rules:
  - from:
    - source:
        namespaces: ["clients"]
    to:
    - operation:
        methods: ["GET"]
EOF
kubectl --context ${CLUSTER1} label svc ratings -n bookinfo-backends istio.io/use-waypoint=ratings-waypoint
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

describe("service labeling to use a waypoint takes precedence over namespace labeling", function() {
  const cluster = process.env.CLUSTER1

  it(`should redirect traffic of labeled service through the waypoint and enforce the policy`, () => {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -v "http://ratings.bookinfo-backends:9080/ratings/0"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('Forbidden');
  });

  it(`should NOT redirect traffic of NON labeled services, which are redirected to the waypoint the namespace is configured for`, () => {
    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -v "http://reviews.bookinfo-backends:9080/reviews/0"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('istio-envoy');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-deployment-options/tests/validate-waypoint-for-specific-service.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 120000 --retries=40 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/waypoint-for: workload
  name: ratings-workload-waypoint
  namespace: bookinfo-backends
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
EOF
kubectl --context ${CLUSTER1} -n bookinfo-backends label pod -l app=ratings istio.io/use-waypoint=ratings-workload-waypoint
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

describe("waypoint for workloads when pod is labeled", function() {
  const cluster = process.env.CLUSTER1

  it(`should redirect traffic to waypoint`, () => {
    let commandGetIP = `kubectl --context ${cluster} -n bookinfo-backends get pod -l app=ratings -o jsonpath='{.items[0].status.podIP}'`;
    let cli = chaiExec(commandGetIP);
    let podIP = cli.output.replace(/'/g, '');

    let command = `kubectl --context ${cluster} -n clients exec deploy/in-ambient -- curl -v "http://${podIP}:9080/ratings/0"`;
    cli = chaiExec(command);

    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('istio-envoy');
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-deployment-options/tests/validate-waypoint-for-workload.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=30 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl --context ${CLUSTER1} -n bookinfo-backends label pod -l app=ratings istio.io/use-waypoint-
kubectl --context ${CLUSTER1} -n bookinfo-backends label svc ratings istio.io/use-waypoint=ratings-waypoint
kubectl --context ${CLUSTER1} -n bookinfo-backends delete authorizationpolicy deny-traffic-from-clients-ns
kubectl --context ${CLUSTER1} -n bookinfo-backends delete gateway waypoint ratings-waypoint ratings-workload-waypoint
