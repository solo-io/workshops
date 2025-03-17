#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
source ./scripts/assert.sh
export MGMT=cluster1
export CLUSTER1=cluster1
export CLUSTER2=cluster2
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
bash ./data/steps/deploy-kind-clusters/deploy-cluster2.sh
./scripts/check.sh cluster1
./scripts/check.sh cluster2
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
export GLOO_MESH_VERSION=v2.7.0
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --set featureGates.insightsConfiguration=true \
  --version 2.7.0

helm upgrade --install gloo-platform-mgmt gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.7.0 \
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
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
  --version 2.7.0

helm upgrade --install gloo-platform-agent gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.7.0 \
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
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
gcloud auth configure-docker us-docker.pkg.dev --quiet
export GLOO_OPERATOR_VERSION=0.2.0-beta.0

kubectl --context "${CLUSTER1}" create ns gloo-mesh

helm upgrade --install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
  --kube-context ${CLUSTER1} \
  --version $GLOO_OPERATOR_VERSION \
  -n gloo-mesh --values - <<EOF
manager:
  env:
    POD_NAMESPACE: gloo-mesh
    SOLO_ISTIO_LICENSE_KEY: ${GLOO_MESH_LICENSE_KEY}
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
EOF
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
kubectl --context "${CLUSTER1}" apply -f - <<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: istio
  namespace: gloo-mesh
spec:
  version: 1.25.0
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
  version: 1.25.0
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
curl -L https://istio.io/downloadIstio | sh -

if [ -d "istio-"*/ ]; then
  cd istio-*/
  export PATH=$PWD/bin:$PATH
  cd ..
fi
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/clients/deploy-clients/tests/check-clients.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
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
kubectl --context ${CLUSTER1} -n httpbin get pods
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
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
kubectl --context ${CLUSTER1} create namespace keycloak
kubectl --context ${CLUSTER1} label namespace keycloak istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy/postgres

sleep 5
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "CREATE DATABASE keycloak;"
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "CREATE USER keycloak WITH PASSWORD 'password';"
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;"
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Postgres", () => {
  it('postgres pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "gloo-system", k8sObj: "postgres" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-keycloak/tests/postgres-available.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
KEYCLOAK_CLIENT=gloo-ext-auth
KEYCLOAK_SECRET=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri
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
kubectl --context ${CLUSTER1} -n keycloak rollout status deploy/keycloak
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Keycloak", () => {
  it('keycloak pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "keycloak", k8sObj: "keycloak" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n keycloak get svc keycloak -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
export ENDPOINT_KEYCLOAK=$(kubectl --context ${CLUSTER1} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):8080
export HOST_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK%:*})
export PORT_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK##*:})
export KEYCLOAK_URL=http://${ENDPOINT_KEYCLOAK}
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
echo "Waiting for Keycloak to be ready at $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token"
timeout 300 bash -c 'while [[ "$(curl -m 2 -s -o /dev/null -w ''%{http_code}'' $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token)" != "405" ]]; do printf '.';sleep 1; done' || false
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
kubectl --context $CLUSTER1 create namespace gloo-system
kubectl --context $CLUSTER1 label namespace gloo-system istio.io/dataplane-mode=ambient

helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update

helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.19.0-beta3 \
  --kube-context $CLUSTER1 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF

gloo:
  kubeGateway:
    enabled: true
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gateway:
    validation:
      allowWarnings: true
      alwaysAcceptResources: false
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
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER1 -n gloo-system rollout status deployment
kubectl --context $CLUSTER1 -n gloo-system get pods
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
kubectl --context ${CLUSTER1} create ns httpbin
kubectl --context ${CLUSTER1} label namespace httpbin istio.io/dataplane-mode=ambient
kubectl --context ${CLUSTER1} label namespace httpbin istio-injection=disabled
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
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
EOF
echo -n Waiting for httpbin pods to be ready...
kubectl --context ${CLUSTER1} -n httpbin rollout status deployment
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
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
export PROXY_IP=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
RETRY_COUNT=0
MAX_RETRIES=60
GLOO_PROXY_SVC=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -oname)
while [[ -z "$PROXY_IP" && $RETRY_COUNT -lt $MAX_RETRIES && $GLOO_PROXY_SVC ]]; do
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

./scripts/register-domain.sh httpbin.example.com ${PROXY_IP}

cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/expose-httpbin/tests/http.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
kubectl create --context ${CLUSTER1} -n gloo-system secret tls tls-secret --key tls.key \
   --cert tls.crt
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/expose-httpbin/tests/https.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/expose-httpbin/tests/redirect-http-to-https.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'201\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/201', retCode: 201 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/status-201.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
kubectl --context ${CLUSTER1} -n gloo-system delete httplisteneroption cache
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
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-gloo-waypoint
kubectl --context ${CLUSTER1} -n httpbin label svc httpbin2 istio.io/use-waypoint=gloo-waypoint
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
EOF
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl --context ${CLUSTER1} -n httpbin delete authorizationpolicy allow-get-only
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
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
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl delete --context ${CLUSTER1} -n httpbin ratelimitconfig limit-users
kubectl delete --context ${CLUSTER1} -n httpbin authconfig apikeys
kubectl delete --context ${CLUSTER1} -n gloo-system secret global-apikey
kubectl delete --context ${CLUSTER1} -n httpbin httproute httpbin2
kubectl delete --context ${CLUSTER1} -n httpbin httplisteneroption cache
kubectl --context $CLUSTER2 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
kubectl --context $CLUSTER2 create namespace gloo-system
kubectl --context $CLUSTER2 label namespace gloo-system istio.io/dataplane-mode=ambient

helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update

helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.19.0-beta3 \
  --kube-context $CLUSTER2 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF

gloo:
  kubeGateway:
    enabled: true
  gatewayProxies:
    gatewayProxy:
      disabled: false
  gateway:
    validation:
      allowWarnings: true
      alwaysAcceptResources: false
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
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER2 -n gloo-system rollout status deployment
kubectl --context $CLUSTER2 -n gloo-system get pods
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER2
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/waypoint-egress/tests/validate-egress-traffic.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 20000 --retries=60 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
kubectl --context ${CLUSTER1} delete authorizationpolicy httpbin -n egress
kubectl --context ${CLUSTER1} delete serviceentry httpbin.org -n egress
kubectl --context ${CLUSTER1} delete destinationrule httpbin.org-tls -n egress
kubectl --context ${CLUSTER1} delete httproute httpbin -n egress
kubectl --context ${CLUSTER1} delete networkpolicy restricted-namespace-policy -n clients
kubectl --context $CLUSTER1 create namespace istio-gateways
kubectl --context $CLUSTER2 create namespace istio-gateways
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
        curlCommand: 'curl in-ambient.httpbin.mesh.internal:8000/get',
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/link-clusters/tests/check-cross-cluster-traffic.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
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
cat << EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway-gloo
  namespace: httpbin
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - name: http
    hostname: "httpbin.gloo"
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-gloo
  namespace: httpbin
spec:
  parentRefs:
  - name: httpbin-gateway-gloo
  hostnames: ["httpbin.gloo"]
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
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
export GLOO_INGRESS=$(kubectl --context ${CLUSTER1} -n httpbin get svc gloo-proxy-httpbin-gateway-gloo -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
echo "Scenario 1: No waypoint"
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

describe("Tests all possible eastwest communication", () => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo ingress", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.GLOO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
echo "Scenario 1b: No waypoint with failover"
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=0
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=0
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
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

describe("Tests all possible eastwest communication", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress", () => {
  [].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo ingress", () => {
  [].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.GLOO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=1
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=1
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
echo "Scenario 2: Local Istio waypoints"
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
  name: global-in-ambient-gloo
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: in-ambient
    port: 8000
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
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: global-in-mesh-gloo
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: in-mesh
    port: 8000
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

describe("Tests all possible eastwest communication", () => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo ingress", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.GLOO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
echo "Scenario 2b: Local Istio waypoints with failover"
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=0
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=0
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
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

describe("Tests all possible eastwest communication", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress", () => {
  [].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo ingress", () => {
  [].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.GLOO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  [].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=1
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=1
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
echo "Scenario 3: Local Gloo waypoints"
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
export LOCAL_GLOO_WAYPOINT=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=gloo-waypoint -o jsonpath='{.items[0].metadata.name}')
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
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_GLOO_WAYPOINT);
}

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_GLOO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
echo "Scenario 3b: Local Gloo waypoints with failover"
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=0
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=0
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
kubectl --context ${CLUSTER1} -n httpbin delete httproute in-ambient
kubectl --context ${CLUSTER1} -n httpbin delete httproute in-mesh
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

describe("Tests all possible eastwest communication", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress", () => {
  [].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo ingress", () => {
  [].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.GLOO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_GLOO_WAYPOINT);
}

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  [].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_GLOO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-mesh --replicas=1
kubectl --context ${CLUSTER1} -n httpbin scale deploy/in-ambient --replicas=1
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-ambient
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
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=waypoint --overwrite
echo "Scenario 4: Local and remote Istio waypoints"
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
kubectl --context ${CLUSTER2} -n httpbin rollout status deploy waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=waypoint
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/ingress-use-waypoint=true
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
export REMOTE_ISTIO_WAYPOINT=$(kubectl --context ${CLUSTER2} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=waypoint -o jsonpath='{.items[0].metadata.name}')
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
  name: remote-in-ambient-gloo
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: remote-in-ambient
    port: 8000
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
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: remote-in-mesh-gloo
  namespace: httpbin
spec:
  parentRefs:
  - group: ""
    kind: Service
    name: remote-in-mesh
    port: 8000
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

describe("Tests all possible eastwest communication", () => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from gloo ingress", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh","/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is available`, () => helpers.checkURL({ host: `http://${process.env.GLOO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.gloo'}], path: `${path}/get`, retCode: 200 }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_ISTIO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
echo "Scenario 5: Local and remote Gloo waypoints"
cat << EOF | kubectl --context ${CLUSTER2} apply -f -
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
kubectl --context ${CLUSTER2} -n httpbin rollout status deploy gloo-proxy-gloo-waypoint
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-mesh istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc in-ambient istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
export REMOTE_GLOO_WAYPOINT=$(kubectl --context ${CLUSTER2} -n httpbin get pods -l gateway.networking.k8s.io/gateway-name=gloo-waypoint -o jsonpath='{.items[0].metadata.name}')
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
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.LOCAL_GLOO_WAYPOINT);
}

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["in-mesh.httpbin.svc.cluster.local", "in-ambient.httpbin.svc.cluster.local","in-mesh.httpbin.mesh.internal", "in-ambient.httpbin.mesh.internal",].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_GLOO_WAYPOINT);
}

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/in-ambient", "/in-mesh","/global-in-ambient", "/global-in-mesh",].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.LOCAL_GLOO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_GLOO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
echo "Scenario 6: Remote only Istio waypoints"
kubectl --context ${CLUSTER1} -n httpbin delete gateway waypoint
kubectl --context ${CLUSTER1} -n httpbin delete gateway gloo-waypoint
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin label svc in-mesh istio.io/ingress-use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin label svc in-ambient istio.io/ingress-use-waypoint-
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
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

describe("Tests all possible eastwest communication", () => {
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-mesh", "client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_ISTIO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
echo "Scenario 7: Remote only Gloo waypoints"
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-mesh istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER2} -n httpbin label svc remote-in-ambient istio.io/use-waypoint=gloo-waypoint --overwrite
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy client-in-mesh
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy httpbin-gateway-istio-istio
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy gloo-proxy-httpbin-gateway-gloo
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-httpbin-gateway-gloo
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
  expect(output.headers["X-Istio-Workload"]).to.equal(process.env.REMOTE_GLOO_WAYPOINT);
}

describe("Tests all possible eastwest communication through waypoint", () => {
  ["client-in-ambient"].forEach(async (source) => {
    ["remote-in-mesh.httpbin.mesh.internal", "remote-in-ambient.httpbin.mesh.internal"].forEach(async (target) => {
      it(`${source} => ${target}`, async () => {
        
        await header_test(source, target);
        
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-all.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
var expect = chai.expect;
chai.use(chaiExec);
const helpers = require('./tests/chai-http');

describe("Tests all possible communication from istio ingress through waypoint", () => {
  ["/remote-in-ambient", "/remote-in-mesh"].forEach(async (path) => {
    
    it(`${path} is going through the right waypoint`, () => helpers.checkBody({ host: `http://${process.env.ISTIO_INGRESS}`, headers: [{key: 'Host', value: 'httpbin.istio'}], path: `${path}/get`, body: process.env.REMOTE_GLOO_WAYPOINT }));
    
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/ambient/multicluster-routing/tests/check-ingress.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
