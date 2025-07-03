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
export GITEA_HTTP=http://git.example.com:3180

helm upgrade --install gitea gitea \
  --repo https://dl.gitea.com/charts/ \
  --version 10.4.1 \
  --kube-context ${MGMT} \
  --namespace gitea \
  --create-namespace \
  --wait \
  -f -<<EOF
service:
  http:
    type: LoadBalancer
    port: 3180
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
redis-cluster:
  enabled: false
postgresql-ha:
  enabled: false
persistence:
  enabled: false
gitea:
  config:
    repository:
      ENABLE_PUSH_CREATE_USER: true
      DEFAULT_PUSH_CREATE_PRIVATE: false
    database:
      DB_TYPE: sqlite3
    session:
      PROVIDER: memory
    cache:
      ADAPTER: memory
    queue:
      TYPE: level
    server:
      ROOT_URL: ${GITEA_HTTP}
      OFFLINE_MODE: true
    webhook:
      ALLOWED_HOST_LIST: private
EOF

echo Waiting for Gitea LB to be ready...
kubectl --context ${MGMT} -n gitea wait svc gitea-http --for=jsonpath='{.status.loadBalancer.ingress[0]}' --timeout=300s
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

describe("Gitea load balancer IP address", () => {
  it("is assigned", () => {
    let cli = chaiExec("kubectl --context " + process.env.MGMT + " -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-hosted-git/tests/get-gitea-http-ip.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
RETRY_COUNT=0
MAX_RETRIES=60
while [[ -z "$GITEA_IP" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  echo "Waiting for GITEA_IP to be assigned... Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
  GITEA_IP=$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
  RETRY_COUNT=$((RETRY_COUNT + 1))
  sleep 5
done

# if GITEA_IP is a hostname, resolve it to an IP address
if [[ -n "$GITEA_IP" && $GITEA_IP =~ [a-zA-Z] ]]; then
  echo "GITEA_IP is a hostname. Resolving to IP address..."
  unset IP
  while [[ -z "$IP" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    echo "Waiting for GITEA_IP to be propagated in DNS... Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES"
    GITEA_IP=$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
    IP=$(dig +short A "$GITEA_IP" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print; exit}')
    echo "IP: $IP"
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 5
  done
  GITEA_IP=$IP
fi

if [[ -z "$GITEA_IP" ]]; then
  echo "WARNING: Maximum number of retries reached. GITEA_IP could not be assigned."
  exit 1
else
  export GITEA_IP
  echo "GITEA_IP has been assigned: $GITEA_IP"
fi
GITEA_IP=$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
./scripts/register-domain.sh git.example.com ${GITEA_IP}
GITEA_ADMIN_TOKEN=$(curl -Ss ${GITEA_HTTP}/api/v1/users/gitea_admin/tokens \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"admin-$RANDOM\", \"scopes\": [\"write:admin\", \"write:repository\"]}" \
  -u 'gitea_admin:r8sA8CPHD9!bt6d' \
  | jq -r .sha1)
echo export GITEA_ADMIN_TOKEN=${GITEA_ADMIN_TOKEN} >> ~/.env

curl -i ${GITEA_HTTP}/api/v1/admin/users \
  -H "accept: application/json" -H "Content-Type: application/json" \
  -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
  -d '{
    "username": "gloo-gitops",
    "password": "password",
    "email": "gloo-gitops@solo.io",
    "full_name": "Solo.io GitOps User",
    "must_change_password": false
  }'
ARGOCD_WEBHOOK_SECRET=$(shuf -ern32 {A..Z} {a..z} {0..9} | paste -sd "\0" -)

helm upgrade --install argo-cd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 7.5.2 \
  --kube-context ${MGMT} \
  --namespace argocd \
  --create-namespace \
  --wait \
  -f -<<EOF
server:
  service:
    type: LoadBalancer
    servicePortHttp: 3280
    servicePortHttps: 3243
configs:
  params:
    server.insecure: true
    server.disable.auth: true
  secret:
    gogsSecret: ${ARGOCD_WEBHOOK_SECRET}
  cm:
    timeout.reconciliation: 10s
  clusterCredentials:
    ${MGMT}:
      server: https://kubernetes.default.svc
      config:
        tlsClientConfig:
          insecure: false
EOF

kubectl --context ${MGMT} -n argocd wait svc argo-cd-argocd-server --for=jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}' --timeout=300s
mkdir -p ${HOME}/bin
curl -Lo ${HOME}/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.12.3/argocd-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/aarch/arm/' | sed 's/x86_/amd/')
chmod +x ${HOME}/bin/argocd
export PATH=$HOME/bin:$PATH
ARGOCD_HTTP_IP=$(kubectl --context ${MGMT} -n argocd get svc argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
ARGOCD_ADMIN_SECRET=$(kubectl --context ${MGMT} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd --kube-context ${MGMT} login ${ARGOCD_HTTP_IP}:3280 --username admin --password ${ARGOCD_ADMIN_SECRET} --plaintext
argocd cluster add ${CLUSTER1} --name ${CLUSTER1} -y --cluster-endpoint kube-public
argocd cluster add ${CLUSTER2} --name ${CLUSTER2} -y --cluster-endpoint kube-public
argocd cluster list
mkdir -p data/steps/gitops-repo
export GITOPS_REPO_LOCAL=$(realpath data/steps/gitops-repo)
export GITOPS_ARGOCD=${GITOPS_REPO_LOCAL}/argo-cd
mkdir -p ${GITOPS_ARGOCD} && touch ${GITOPS_ARGOCD}/.gitignore
git -C ${GITOPS_REPO_LOCAL} init -b main
git -C ${GITOPS_REPO_LOCAL} config user.email "gloo-gitops@solo.io"
git -C ${GITOPS_REPO_LOCAL} config user.name "Solo.io GitOps User"
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Initial commit of Gloo GitOps"

git -C ${GITOPS_REPO_LOCAL} config credential.helper '!f() { sleep 1; echo "username=gloo-gitops"; echo "password=password"; }; f'
git -C ${GITOPS_REPO_LOCAL} remote add origin ${GITEA_HTTP}/gloo-gitops/gitops-repo.git

git -C ${GITOPS_REPO_LOCAL} push -u origin main
cat <<EOF > ${GITOPS_ARGOCD}/argo-cd.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: argo-cd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-${MGMT}
  finalizers:
  - resources-finalizer.argocd.argoproj.io/background
spec:
  project: argo-cd
  sources:
  - repoURL: http://gitea-http.gitea:3180/gloo-gitops/gitops-repo.git
    targetRevision: HEAD
    path: argo-cd
  destination:
    name: ${MGMT}
    namespace: argocd
  syncPolicy:
    automated:
      allowEmpty: true
      prune: true
    syncOptions:
    - ApplyOutOfSyncOnly=true
EOF

kubectl --context ${MGMT} -n argocd create -f ${GITOPS_ARGOCD}/argo-cd.yaml
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Manage argo-cd config"
git -C ${GITOPS_REPO_LOCAL} push
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

describe("Argo CD config", () => {
  it("syncs to mgmt cluster", () => {
    let cli = chaiExec(process.env.HOME + "/bin/argocd --kube-context " + process.env.MGMT + " app get argocd-" + process.env.MGMT);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bServer:\\s+" + process.env.MGMT + "\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bRepo:\\s+.+/gloo-gitops/gitops-repo.git\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bPath:\\s+argo-cd\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bHealth Status:\\s+Healthy\\b"));
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-argo-cd/tests/argo-cd-sync-repo.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
curl -i ${GITEA_HTTP}/api/v1/repos/gloo-gitops/gitops-repo/hooks \
  -H "accept: application/json" -H "Content-Type: application/json" \
  -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
  -d '{
    "active": true,
    "type": "gitea",
    "branch_filter": "*",
    "config": {
      "content_type": "json",
      "url": "'http://${ARGOCD_HTTP_IP}:3280/api/webhook'",
      "secret": "'${ARGOCD_WEBHOOK_SECRET}'"
    },
    "events": [
      "push"
    ]
  }'
cat <<EOF > ${GITOPS_ARGOCD}/nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: default
spec:
  containers:
  - image: nginx:1.25.3
    name: nginx
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Add nginx"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n default get pod nginx 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n default wait --for=condition=ready pod/nginx --timeout=30s 2>/dev/null) ]]; do
  sleep 1
done"
if [[ ! $(kubectl --context ${MGMT} -n default wait --for=condition=ready pod/nginx --timeout=30s) ]]; then
  echo "nginx did not become ready"
  exit 1
fi
until kubectl --context ${MGMT} -n default wait --for=condition=ready pod/nginx --timeout=30s 2>/dev/null; do sleep 1; done
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD
git -C ${GITOPS_REPO_LOCAL} commit -m "Delete nginx"
git -C ${GITOPS_REPO_LOCAL} push

kubectl --context ${MGMT} -n default wait --for=delete pod/nginx --timeout=30s
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
export GITOPS_PLATFORM=${GITOPS_REPO_LOCAL}/platform
mkdir -p ${GITOPS_PLATFORM}/${MGMT}
cat <<EOF > ${GITOPS_ARGOCD}/platform.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform
spec:
  generators:
  - list:
      elements:
      - cluster: ${MGMT}
      - cluster: ${CLUSTER1}
      - cluster: ${CLUSTER2}
  template:
    metadata:
      name: platform-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io/background
    spec:
      project: platform
      source:
        repoURL: http://gitea-http.gitea:3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        path: platform/{{cluster}}
      destination:
        name: '{{cluster}}'
        namespace: default
      syncPolicy:
        automated:
          allowEmpty: true
          prune: true
        syncOptions:
        - ApplyOutOfSyncOnly=true
EOF
mkdir -p ${GITOPS_PLATFORM}/argo-cd

cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-mgmt-installation.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gloo-platform-mgmt-installation
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
  - resources-finalizer.argocd.argoproj.io/background
spec:
  project: platform
  destination:
    name: ${MGMT}
    namespace: gloo-mesh
  syncPolicy:
    automated:
      allowEmpty: true
      prune: true
    syncOptions:
    - CreateNamespace=true
  ignoreDifferences:
  - kind: Secret
    jsonPointers:
    - /data/ca.crt
    - /data/tls.crt
    - /data/tls.key
    - /data/token
  - group: certificate.cert-manager.io
    kind: Certificate
    jsonPointers:
    - /spec/duration
    - /spec/renewBefore
  sources:
  - chart: gloo-platform-crds
    repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
    targetRevision: 2.9.1
    helm:
      releaseName: gloo-platform-crds
      parameters:
      - name: "featureGates.ExternalWorkloads"
        value: "true"
  - chart: gloo-platform
    repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
    targetRevision: 2.9.1
    helm:
      releaseName: gloo-platform
      valueFiles:
      - \$values/platform/argo-cd/gloo-platform-mgmt-installation-values.yaml
  - repoURL: http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):3180/gloo-gitops/gitops-repo.git
    targetRevision: HEAD
    ref: values
EOF
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-mgmt-installation-values.yaml
licensing:
  glooTrialLicenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: mgmt
glooInsightsEngine:
  enabled: false
glooMgmtServer:
  enabled: true
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
  skipAutoMigration: true
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
  ExternalWorkloads: true
EOF
cat <<EOF >${GITOPS_PLATFORM}/argo-cd/kustomization.yaml
namespace: argocd
resources:
- gloo-platform-mgmt-installation.yaml
EOF

cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
resources:
- ../argo-cd
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gloo Platform management server"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n argocd get application gloo-platform-mgmt-installation 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server 2>/dev/null) ]]; do
  sleep 1
done"
if [[ ! $(kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server --timeout 10s) ]]; then
  echo "Gloo Mesh Management Server did not deploy"
  exit 1
fi
until kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server 2>/dev/null; do sleep 1; done
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/check-deployment.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/get-gloo-mesh-mgmt-server-ip.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/cluster1.yaml
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: cluster1
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF

cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/cluster2.yaml
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: cluster2
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- cluster1.yaml
- cluster2.yaml
EOF
mkdir -p ${GITOPS_PLATFORM}/${CLUSTER1}

cat <<EOF >${GITOPS_PLATFORM}/${CLUSTER1}/ns-gloo-mesh.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh
EOF

cat <<EOF >${GITOPS_PLATFORM}/${CLUSTER1}/relay-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: relay-root-tls-secret
  namespace: gloo-mesh
data:
  ca.crt: $(kubectl --context ${MGMT} -n gloo-mesh get secret relay-root-tls-secret -o jsonpath='{.data.ca\.crt}')
---
apiVersion: v1
kind: Secret
metadata:
  name: relay-identity-token-secret
  namespace: gloo-mesh
data:
  token: $(kubectl --context ${MGMT} -n gloo-mesh get secret relay-identity-token-secret -o jsonpath='{.data.token}')
EOF

cat <<EOF >${GITOPS_PLATFORM}/${CLUSTER1}/kustomization.yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "1"
resources:
- ns-gloo-mesh.yaml
- relay-secrets.yaml
EOF
cp -r ${GITOPS_PLATFORM}/${CLUSTER1} ${GITOPS_PLATFORM}/${CLUSTER2}
cat <<EOF >${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: gloo-platform-agents-installation
spec:
  generators:
  - list:
      elements:
      - cluster: ${CLUSTER1}
      - cluster: ${CLUSTER2}
  template:
    metadata:
      name: gloo-platform-{{cluster}}-installation
      annotations:
        argocd.argoproj.io/sync-wave: "2"
      finalizers:
      - resources-finalizer.argocd.argoproj.io/background
    spec:
      project: platform
      destination:
        name: '{{cluster}}'
        namespace: gloo-mesh
      syncPolicy:
        automated:
          prune: true
      ignoreDifferences:
      - group: apiextensions.k8s.io
        kind: CustomResourceDefinition
        name: istiooperators.install.istio.io
        jsonPointers:
        - /metadata/labels
      - kind: Secret
        name: postgresql
        jsonPointers:
        - /data/postgres-password
      - group: certificate.cert-manager.io
        kind: Certificate
        jsonPointers:
        - /spec/duration
        - /spec/renewBefore
      sources:
      - chart: gloo-platform-crds
        repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
        targetRevision: 2.9.1
        helm:
          releaseName: gloo-platform-crds
          parameters:
          - name: "featureGates.ExternalWorkloads"
            value: "true"
      - chart: gloo-platform
        repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
        targetRevision: 2.9.1
        helm:
          releaseName: gloo-platform
          valueFiles:
          - \$values/platform/argo-cd/gloo-platform-agents-installation-values.yaml
          parameters:
          - name: common.cluster
            value: '{{cluster}}'
          - name: "glooSpireServer.server.trustDomain"
            value: '{{cluster}}'
      - repoURL: http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        ref: values
EOF
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation-values.yaml
common:
  cluster: undefined
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
EOF
cat <<EOF >>${GITOPS_PLATFORM}/argo-cd/kustomization.yaml
- gloo-platform-agents-installation.yaml
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Onboard workload clusters"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get kubernetescluster cluster1 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/workspaces
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/workspaces/workspace-global.yaml
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

cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "2"
resources:
- workspace-global.yaml
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- workspaces
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Indicate east-west gateway"
git -C ${GITOPS_REPO_LOCAL} push
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/istio-lifecycle-manager-install/tests/istio-version.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
export GITOPS_GATEWAYS=${GITOPS_REPO_LOCAL}/gateways
mkdir -p ${GITOPS_GATEWAYS}
cat <<EOF > ${GITOPS_ARGOCD}/gateways.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: gateways
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: gateways
spec:
  generators:
  - list:
      elements:
      - cluster: ${MGMT}
      - cluster: ${CLUSTER1}
      - cluster: ${CLUSTER2}
  template:
    metadata:
      name: gateways-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io/background
    spec:
      project: gateways
      source:
        repoURL: http://gitea-http.gitea:3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        path: gateways/{{cluster}}
      destination:
        name: '{{cluster}}'
        namespace: gloo-mesh
      syncPolicy:
        automated:
          allowEmpty: true
          prune: true
        syncOptions:
        - ApplyOutOfSyncOnly=true
EOF
mkdir -p ${GITOPS_GATEWAYS}/base/gateway-services

cat <<EOF > ${GITOPS_GATEWAYS}/base/gateway-services/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: istio-gateways
  labels:
    istio.io/rev: 1-25
EOF

cat <<EOF >${GITOPS_GATEWAYS}/base/gateway-services/kustomization.yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "3"
resources:
- ns.yaml
EOF

cat <<EOF > ${GITOPS_GATEWAYS}/base/gateway-services/ingress.yaml
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
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
    revision: 1-25
  type: LoadBalancer
EOF

cat <<EOF > ${GITOPS_GATEWAYS}/base/gateway-services/east-west.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: eastwestgateway
    topology.istio.io/network: cluster1
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
    topology.istio.io/network: cluster1
  type: LoadBalancer
EOF

cat <<EOF >>${GITOPS_GATEWAYS}/base/gateway-services/kustomization.yaml
- ingress.yaml
- east-west.yaml
EOF
mkdir -p ${GITOPS_GATEWAYS}/${CLUSTER1}/services

cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/services/kustomization.yaml
patches:
- target:
    kind: Namespace
    name: istio-system
  patch: |-
    - op: replace
      path: /metadata/labels/topology.istio.io~1network
      value: cluster1
- target:
    kind: Service
    name: istio-eastwestgateway
  patch: |-
    - op: replace
      path: /metadata/labels/topology.istio.io~1network
      value: cluster1
    - op: replace
      path: /spec/selector/topology.istio.io~1network
      value: cluster1
resources:
- ../../base/gateway-services
EOF

cat <<EOF >${GITOPS_GATEWAYS}/${CLUSTER1}/kustomization.yaml
resources:
- services
EOF

mkdir -p ${GITOPS_GATEWAYS}/${CLUSTER2}/services

cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER2}/services/kustomization.yaml
patches:
- target:
    kind: Namespace
    name: istio-system
  patch: |-
    - op: replace
      path: /metadata/labels/topology.istio.io~1network
      value: cluster2
- target:
    kind: Service
    name: istio-eastwestgateway
  patch: |-
    - op: replace
      path: /metadata/labels/topology.istio.io~1network
      value: cluster2
    - op: replace
      path: /spec/selector/topology.istio.io~1network
      value: cluster2
resources:
- ../../base/gateway-services
EOF

cat <<EOF >${GITOPS_GATEWAYS}/${CLUSTER2}/kustomization.yaml
resources:
- services
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gateway services"
git -C ${GITOPS_REPO_LOCAL} push
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/istio

cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/istio/ilm-cluster1.yaml
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: cluster1-installation
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: cluster1
        defaultRevision: true
      revision: 1-25
      istioOperatorSpec:
        profile: minimal
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
        namespace: istio-system
        values:
          global:
            meshID: mesh1
            multiCluster:
              clusterName: cluster1
            network: cluster1
          cni:
            excludeNamespaces:
            - istio-system
            - kube-system
            logLevel: info
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

cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/istio/ilm-cluster2.yaml
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: cluster2-installation
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: cluster2
        defaultRevision: true
      revision: 1-25
      istioOperatorSpec:
        profile: minimal
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
        namespace: istio-system
        values:
          global:
            meshID: mesh1
            multiCluster:
              clusterName: cluster2
            network: cluster2
          cni:
            excludeNamespaces:
            - istio-system
            - kube-system
            logLevel: info
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

cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/istio/kustomization.yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "3"
resources:
- ilm-cluster1.yaml
- ilm-cluster2.yaml
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- istio
EOF
mkdir -p ${GITOPS_GATEWAYS}/${MGMT}

cat <<EOF > ${GITOPS_GATEWAYS}/${MGMT}/glm-cluster1.yaml
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: cluster1-ingress
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: cluster1
        activeGateway: false
      gatewayRevision: 1-25
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
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
---
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: cluster1-eastwest
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: cluster1
        activeGateway: false
      gatewayRevision: 1-25
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
        values:
          gateways:
            istio-ingressgateway:
              customService: true
        components:
          ingressGateways:
            - name: istio-eastwestgateway
              namespace: istio-gateways
              enabled: true
              label:
                istio: eastwestgateway
                topology.istio.io/network: cluster1
              k8s:
                env:
                  - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                    value: cluster1
EOF

cat <<EOF > ${GITOPS_GATEWAYS}/${MGMT}/glm-cluster2.yaml
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: cluster2-ingress
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: cluster2
        activeGateway: false
      gatewayRevision: 1-25
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
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
---
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: cluster2-eastwest
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: cluster2
        activeGateway: false
      gatewayRevision: 1-25
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
        values:
          gateways:
            istio-ingressgateway:
              customService: true
        components:
          ingressGateways:
            - name: istio-eastwestgateway
              namespace: istio-gateways
              enabled: true
              label:
                istio: eastwestgateway
                topology.istio.io/network: cluster2
              k8s:
                env:
                  - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                    value: cluster2
EOF

cat <<EOF >>${GITOPS_GATEWAYS}/${MGMT}/kustomization.yaml
resources:
- glm-cluster2.yaml
- glm-cluster1.yaml
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Istio and gateway lifecycle managers"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get ilm cluster1-installation 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
until kubectl --context ${MGMT} -n gloo-mesh wait --timeout=180s --for=jsonpath='{.status.clusters.cluster1.installations.*.state}'=HEALTHY istiolifecyclemanagers/cluster1-installation; do
  echo "Waiting for the Istio installation to complete"
  sleep 1
done
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-system get deploy -o json | jq '[.items[].status.readyReplicas] | add') -ge 1 ]]; do
  sleep 1
done"
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]]; do
  sleep 1
done"
until kubectl --context ${MGMT} -n gloo-mesh wait --timeout=180s --for=jsonpath='{.status.clusters.cluster2.installations.*.state}'=HEALTHY istiolifecyclemanagers/cluster2-installation; do
  echo "Waiting for the Istio installation to complete"
  sleep 1
done
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER2} -n istio-system get deploy -o json | jq '[.items[].status.readyReplicas] | add') -ge 1 ]]; do
  sleep 1
done"
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER2} -n istio-gateways get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]]; do
  sleep 1
done"
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/istio-lifecycle-manager-install/tests/istio-ready.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
export GITOPS_BOOKINFO=${GITOPS_REPO_LOCAL}/bookinfo
mkdir -p ${GITOPS_BOOKINFO}
cat <<EOF > ${GITOPS_ARGOCD}/bookinfo.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: bookinfo
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: bookinfo
spec:
  generators:
  - list:
      elements:
      - cluster: ${CLUSTER1}
      - cluster: ${CLUSTER2}
  template:
    metadata:
      name: bookinfo-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: bookinfo
      source:
        repoURL: http://gitea-http.gitea:3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        path: bookinfo/{{cluster}}
      destination:
        name: '{{cluster}}'
        namespace: default
      syncPolicy:
        automated:
          allowEmpty: true
          prune: true
        syncOptions:
        - ApplyOutOfSyncOnly=true
EOF
mkdir -p ${GITOPS_BOOKINFO}/base/frontends
cp data/steps/deploy-bookinfo/productpage-v1.yaml ${GITOPS_BOOKINFO}/base/frontends/

mkdir -p ${GITOPS_BOOKINFO}/base/backends
cp data/steps/deploy-bookinfo/details-v1.yaml data/steps/deploy-bookinfo/ratings-v1.yaml data/steps/deploy-bookinfo/reviews-v1-v2.yaml \
  ${GITOPS_BOOKINFO}/base/backends/
cat <<EOF >${GITOPS_BOOKINFO}/base/frontends/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookinfo-frontends
  labels:
    istio.io/rev: 1-25
EOF

cat <<EOF >${GITOPS_BOOKINFO}/base/backends/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookinfo-backends
  labels:
    istio.io/rev: 1-25
EOF
cat <<EOF >${GITOPS_BOOKINFO}/base/frontends/kustomization.yaml
resources:
- ns.yaml
- productpage-v1.yaml
EOF

cat <<EOF >${GITOPS_BOOKINFO}/base/backends/kustomization.yaml
resources:
- ns.yaml
- details-v1.yaml
- ratings-v1.yaml
- reviews-v1-v2.yaml
EOF
mkdir -p ${GITOPS_BOOKINFO}/${CLUSTER1}/frontends ${GITOPS_BOOKINFO}/${CLUSTER1}/backends

cat <<EOF >${GITOPS_BOOKINFO}/${CLUSTER1}/frontends/kustomization.yaml
namespace: bookinfo-frontends
resources:
- ../../base/frontends
EOF

cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/backends/kustomization.yaml
namespace: bookinfo-backends
patches:
- target:
    kind: Deployment
    name: reviews-v1
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: CLUSTER_NAME
        value: ${CLUSTER1}
- target:
    kind: Deployment
    name: reviews-v2
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: CLUSTER_NAME
        value: ${CLUSTER1}
resources:
- ../../base/backends
EOF

cat <<EOF >${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
resources:
- frontends
- backends
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Bookinfo on ${CLUSTER1}"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 4 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
cp -r ${GITOPS_BOOKINFO}/${CLUSTER1} ${GITOPS_BOOKINFO}/${CLUSTER2}
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER2}/backends/kustomization.yaml
namespace: bookinfo-backends
patches:
- target:
    kind: Deployment
    name: reviews-v1
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: CLUSTER_NAME
        value: ${CLUSTER2}
- target:
    kind: Deployment
    name: reviews-v2
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: CLUSTER_NAME
        value: ${CLUSTER2}
- target:
    kind: Deployment
    name: reviews-v3
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: CLUSTER_NAME
        value: ${CLUSTER2}
resources:
- ../../base/backends
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Bookinfo on ${CLUSTER2}"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER2} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER2} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 4 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
git -C ${GITOPS_REPO_LOCAL} checkout -b reviews-v3
cp data/steps/deploy-bookinfo/reviews-v3.yaml ${GITOPS_BOOKINFO}/${CLUSTER2}/backends/reviews-v3.yaml
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER2}/backends/kustomization.yaml
- reviews-v3.yaml
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "v3 of reviews service"
git -C ${GITOPS_REPO_LOCAL} push -u origin reviews-v3
git -C ${GITOPS_REPO_LOCAL} checkout main
{ PR_ID=$(curl -Ss ${GITEA_HTTP}/api/v1/repos/gloo-gitops/gitops-repo/pulls \
  -H "accept: application/json" -H "Content-Type: application/json" \
  -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
  -d '{
    "title": "Add v3 of bookinfo reviews",
    "base": "main",
    "head": "reviews-v3"
  }' | tee /dev/fd/3 | jq '.id'); } 3>&1
kubectl --context ${CLUSTER2} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER2} -n bookinfo-backends get pods
curl -i ${GITEA_HTTP}/api/v1/repos/gloo-gitops/gitops-repo/pulls/${PR_ID}/merge \
  --fail-with-body \
  -H "accept: application/json" -H "Content-Type: application/json" \
  -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
  -d '{ "do": "merge" }'
until [[ $? -eq 0 ]]; do
  attempt=$((attempt+1))
  sleep 2
  echo "Retrying merge command ($attempt)..."
  if [[ $attempt -lt 5 ]]; then
    curl -i ${GITEA_HTTP}/api/v1/repos/gloo-gitops/gitops-repo/pulls/${PR_ID}/merge \
      --fail-with-body \
      -H "accept: application/json" -H "Content-Type: application/json" \
      -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
      -d '{ "do": "merge" }'
  fi
done
sleep 2
git -C ${GITOPS_REPO_LOCAL} checkout main
git -C ${GITOPS_REPO_LOCAL} fetch
git -C ${GITOPS_REPO_LOCAL} pull
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
export GITOPS_HTTPBIN=${GITOPS_REPO_LOCAL}/httpbin
mkdir -p ${GITOPS_HTTPBIN}
cat <<EOF > ${GITOPS_ARGOCD}/httpbin.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: httpbin
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - namespace: '*'
    server: '*'
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: httpbin
spec:
  generators:
  - list:
      elements:
      - cluster: ${CLUSTER1}
  template:
    metadata:
      name: httpbin-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: httpbin
      source:
        repoURL: http://gitea-http.gitea:3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        path: httpbin/{{cluster}}
      destination:
        name: '{{cluster}}'
        namespace: default
      syncPolicy:
        automated:
          allowEmpty: true
          prune: true
        syncOptions:
        - ApplyOutOfSyncOnly=true
EOF
mkdir -p ${GITOPS_HTTPBIN}/base

cat <<EOF >${GITOPS_HTTPBIN}/base/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: httpbin
EOF

cat <<EOF > ${GITOPS_HTTPBIN}/base/not-in-mesh.yaml

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
cat <<EOF > ${GITOPS_HTTPBIN}/base/in-mesh.yaml

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
cat <<EOF >${GITOPS_HTTPBIN}/base/kustomization.yaml
resources:
- ns.yaml
- not-in-mesh.yaml
- in-mesh.yaml
EOF

mkdir -p ${GITOPS_HTTPBIN}/${CLUSTER1}

cat <<EOF >${GITOPS_HTTPBIN}/${CLUSTER1}/kustomization.yaml
namespace: httpbin
resources:
- ../base
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "httpbin on ${CLUSTER1}"
git -C ${GITOPS_REPO_LOCAL} push
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
cat <<EOF >${GITOPS_PLATFORM}/${CLUSTER1}/ns-gloo-mesh-addons.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh-addons
  labels:
    istio.io/rev: 1-25
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${CLUSTER1}/kustomization.yaml
- ns-gloo-mesh-addons.yaml
EOF

cp ${GITOPS_PLATFORM}/${CLUSTER1}/ns-gloo-mesh-addons.yaml ${GITOPS_PLATFORM}/${CLUSTER2}/

cat <<EOF >>${GITOPS_PLATFORM}/${CLUSTER2}/kustomization.yaml
- ns-gloo-mesh-addons.yaml
EOF
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-addons-installation.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: gloo-platform-addons
spec:
  generators:
  - list:
      elements:
      - cluster: ${CLUSTER1}
      - cluster: ${CLUSTER2}
  template:
    metadata:
      name: gloo-platform-addons-{{cluster}}
      annotations:
        argocd.argoproj.io/sync-wave: "2"
      finalizers:
      - resources-finalizer.argocd.argoproj.io/background
    spec:
      project: platform
      destination:
        name: '{{cluster}}'
        namespace: gloo-mesh-addons
      syncPolicy:
        automated:
          prune: true
      ignoreDifferences:
      - kind: Secret
        name: ext-auth-service-signing-key
        jsonPointers:
        - /data/signing-key
      sources:
      - chart: gloo-platform
        repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
        targetRevision: 2.9.1
        helm:
          releaseName: gloo-platform
          valueFiles:
          - \$values/platform/argo-cd/gloo-platform-addons-installation-values.yaml
          parameters:
          - name: common.cluster
            value: '{{cluster}}'
      - repoURL: http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        ref: values
EOF
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-addons-installation-values.yaml
common:
  cluster: undefined
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
cat <<EOF >>${GITOPS_PLATFORM}/argo-cd/kustomization.yaml
- gloo-platform-addons-installation.yaml
EOF
cat <<EOF > ${GITOPS_PLATFORM}/${CLUSTER1}/ext-auth-server.yaml
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
cat <<EOF > ${GITOPS_PLATFORM}/${CLUSTER1}/rate-limit-server-settings.yaml
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
cat <<EOF >>${GITOPS_PLATFORM}/${CLUSTER1}/kustomization.yaml
- ext-auth-server.yaml
- rate-limit-server-settings.yaml
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gloo Platform add-ons"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n gloo-mesh-addons get eas ext-auth-server 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Platform add-ons cluster1 deployment", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["ext-auth-service", "rate-limiter"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-mesh-addons", k8sObj: deploy }));
  });
});
describe("Gloo Platform add-ons cluster2 deployment", () => {
  let cluster = process.env.CLUSTER2
  let deployments = ["ext-auth-service", "rate-limiter"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-mesh-addons", k8sObj: deploy }));
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-gloo-mesh-addons/tests/check-addons-deployments.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Platform add-ons cluster1 service", () => {
  let cluster = process.env.CLUSTER1
  let services = ["ext-auth-service", "rate-limiter"];
  services.forEach(service => {
    it(service + ' exists in ' + cluster, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "gloo-mesh-addons", k8sType: "service", k8sObj: service }));
  });
});
describe("Gloo Platform add-ons cluster2 service", () => {
  let cluster = process.env.CLUSTER2
  let services = ["ext-auth-service", "rate-limiter"];
  services.forEach(service => {
    it(service + ' exists in ' + cluster, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "gloo-mesh-addons", k8sType: "service", k8sObj: service }));
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-gloo-mesh-addons/tests/check-addons-services.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/workspaces
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/workspaces/gateways.yaml
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
  - name: cluster2
    namespaces:
    - name: istio-gateways
    - name: gloo-mesh-addons
EOF
cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/workspace-settings.yaml
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
if [ ! -f ${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml ]; then
  cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
resources:
EOF
fi

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
- gateways.yaml
EOF

if [ $(yq 'contains({"resources": ["workspaces"]})' ${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml) = false ]; then
  cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- workspaces
EOF
fi

cat <<EOF >>${GITOPS_GATEWAYS}/${CLUSTER1}/kustomization.yaml
- workspace-settings.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gateways workspace"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get workspace gateways 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/workspaces
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/workspaces/bookinfo.yaml
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
  - name: cluster2
    namespaces:
    - name: bookinfo-frontends
    - name: bookinfo-backends
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/workspace-settings.yaml
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
if [ ! -f ${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml ]; then
  cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
resources:
EOF
fi

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
- bookinfo.yaml
EOF

if [ $(yq 'contains({"resources": ["workspaces"]})' ${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml) = false ]; then
  cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- workspaces
EOF
fi

cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- workspace-settings.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Bookinfo workspace"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get workspace bookinfo 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/virtualgateway.yaml
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
cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/routetable-main.yaml
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
cat <<EOF >>${GITOPS_GATEWAYS}/${CLUSTER1}/kustomization.yaml
- virtualgateway.yaml
- routetable-main.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Virtual gateway and main route table"
git -C ${GITOPS_REPO_LOCAL} push
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/routetable-productpage.yaml
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
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- routetable-productpage.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Bookinfo route table"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get rt productpage 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
./scripts/register-domain.sh cluster1-bookinfo.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster2-bookinfo.example.com ${HOST_GW_CLUSTER2}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTP)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `http://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
cat <<EOF >${GITOPS_GATEWAYS}/base/gateway-services/ingress-certs.yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: tls-secret
  namespace: istio-gateways
stringData:
  tls.crt: |
$(cat tls.crt | sed 's/^/    /')
  tls.key: |
$(cat tls.key | sed 's/^/    /')
EOF

cat <<EOF >>${GITOPS_GATEWAYS}/base/gateway-services/kustomization.yaml
- ingress-certs.yaml
EOF
cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/virtualgateway.yaml
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
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Secure the gateway"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \"\$(kubectl --context ${CLUSTER1} -n istio-gateways get vg north-south-gw -ojsonpath='{.spec.listeners[?(@.tls.mode==\"SIMPLE\")]}' 2>/dev/null)\" != \"\" ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available-secure.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/gateway-expose/tests/otel-metrics.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=150 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/fault-injection.yaml
apiVersion: resilience.policy.gloo.solo.io/v2
kind: FaultInjectionPolicy
metadata:
  name: ratings-fault-injection
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        fault_injection: "true"
  config:
    delay:
      fixedDelay: 2s
      percentage: 100
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/routetable-ratings.yaml
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: ratings
  namespace: bookinfo-frontends
spec:
  hosts:
    - 'ratings.bookinfo-backends.svc.cluster.local'
  workloadSelectors:
  - selector:
      labels:
        app: reviews
  http:
    - name: ratings
      labels:
        fault_injection: "true"
      matchers:
      - uri:
          prefix: /
      forwardTo:
        destinations:
          - ref:
              name: ratings
              namespace: bookinfo-backends
            port:
              number: 9080
EOF
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- fault-injection.yaml
- routetable-ratings.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Ratings fault injection"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get rt ratings 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/retry-timeout.yaml
apiVersion: resilience.policy.gloo.solo.io/v2
kind: RetryTimeoutPolicy
metadata:
  name: reviews-request-timeout
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        request_timeout: "0.5s"
  config:
    requestTimeout: 0.5s
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/routetable-reviews.yaml
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: reviews
  namespace: bookinfo-frontends
spec:
  hosts:
    - 'reviews.bookinfo-backends.svc.cluster.local'
  workloadSelectors:
  - selector:
      labels:
        app: productpage
  http:
    - name: reviews
      labels:
        request_timeout: "0.5s"
      matchers:
      - uri:
          prefix: /
      forwardTo:
        destinations:
          - ref:
              name: reviews
              namespace: bookinfo-backends
            port:
              number: 9080
            subset:
              version: v2
EOF
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- retry-timeout.yaml
- routetable-reviews.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Reviews timeout retry"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get rt reviews 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD~2..
git -C ${GITOPS_REPO_LOCAL} commit -m "Revert traffic policies"
git -C ${GITOPS_REPO_LOCAL} push
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/root-trust.yaml
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
EOF
cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- root-trust.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Root trust policy"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get rtp root-trust-policy 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
until [[ $(kubectl --context ${MGMT} -n gloo-mesh get rtp root-trust-policy 2>/dev/null) ]]; do sleep 1; done

bash ./data/steps/root-trust-policy/restart-istio-pods.sh ${CLUSTER1}
bash ./data/steps/root-trust-policy/restart-istio-pods.sh ${CLUSTER2}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("cacerts secrets have been created", () => {
    const clusters = [process.env.CLUSTER1, process.env.CLUSTER2];
    clusters.forEach(cluster => {
        it('Secret is present in ' + cluster, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "istio-system", k8sType: "secret", k8sObj: "cacerts" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/root-trust-policy/tests/cacert-secrets-created.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=150 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
printf "Waiting for all pods needed for the test..."
printf "\n"
kubectl --context ${CLUSTER1} get deploy -n bookinfo-backends -oname|xargs -I {} kubectl --context ${CLUSTER1} rollout status -n bookinfo-backends {}
kubectl --context ${CLUSTER2} get deploy -n bookinfo-backends -oname|xargs -I {} kubectl --context ${CLUSTER2} rollout status -n bookinfo-backends {}
printf "\n"
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

const testerPodName = "tester-root-trust-policy";
before(function (done) {
  chaiExec(`kubectl --context ${process.env.CLUSTER1} -n gloo-mesh run --image=alpine/openssl:3.3.1 ${testerPodName} --command --wait=false -- sleep infinity`);
  chaiExec(`kubectl --context ${process.env.CLUSTER2} -n gloo-mesh run --image=alpine/openssl:3.3.1 ${testerPodName} --command --wait=false -- sleep infinity`);
  done();
});
after(function (done) {
  chaiExec(`kubectl --context ${process.env.CLUSTER1} -n gloo-mesh delete pod ${testerPodName} --wait=false`);
  chaiExec(`kubectl --context ${process.env.CLUSTER2} -n gloo-mesh delete pod ${testerPodName} --wait=false`);
  done();
});

describe("Certificate issued by Gloo Mesh", () => {
  var expectedOutput = "i:O=gloo-mesh";

  it('Gloo mesh is the organization for ' + process.env.CLUSTER1 + ' certificate', () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} exec -t -n gloo-mesh ${testerPodName} -- openssl s_client -showcerts -connect ratings.bookinfo-backends:9080 -alpn istio`);

    expect(cli).stdout.to.contain(expectedOutput);
    expect(cli).stderr.not.to.be.empty;
  });


  it('Gloo mesh is the organization for ' + process.env.CLUSTER2 + ' certificate', () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER2} exec -t -n gloo-mesh ${testerPodName} -- openssl s_client -showcerts -connect ratings.bookinfo-backends:9080 -alpn istio`);

    expect(cli).stdout.to.contain(expectedOutput);
    expect(cli).stderr.not.to.be.empty;
  });

});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/root-trust-policy/tests/certificate-issued-by-gloo-mesh.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/virtualdestination-reviews.yaml
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: reviews
  namespace: bookinfo-backends
spec:
  hosts:
  - reviews.global
  services:
  - namespace: bookinfo-backends
    labels:
      app: reviews
  ports:
    - number: 9080
      protocol: HTTP
EOF

cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- virtualdestination-reviews.yaml
EOF
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Route to reviews using virtual destination"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get vd reviews 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl --context $CLUSTER1 -n bookinfo-frontends exec deploy/productpage-v1 -- python -c "import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)"
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should get responses from cluster2", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)\"";
  it('Got a response from cluster1', () => helpers.genericCommand({ command: command, responseContains: "cluster1" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/east-west-virtual-destination/tests/reviews-from-cluster1.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should get responses from cluster2", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)\"";
  it('Got a response from cluster2', () => helpers.genericCommand({ command: command, responseContains: "cluster2" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/east-west-virtual-destination/tests/reviews-from-cluster2.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/failover-reviews.yaml
apiVersion: resilience.policy.gloo.solo.io/v2
kind: FailoverPolicy
metadata:
  name: failover
  namespace: bookinfo-backends
spec:
  applyToDestinations:
  - kind: VIRTUAL_DESTINATION
    selector:
      labels:
        failover: "true"
  config:
    localityMappings: []
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/outlierdetection-reviews.yaml
apiVersion: resilience.policy.gloo.solo.io/v2
kind: OutlierDetectionPolicy
metadata:
  name: outlier-detection
  namespace: bookinfo-backends
spec:
  applyToDestinations:
  - kind: VIRTUAL_DESTINATION
    selector:
      labels:
        failover: "true"
  config:
    consecutiveErrors: 2
    interval: 5s
    baseEjectionTime: 30s
    maxEjectionPercent: 100
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/virtualdestination-reviews.yaml
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: reviews
  namespace: bookinfo-backends
  labels:
    failover: "true"
spec:
  hosts:
  - reviews.global
  services:
  - namespace: bookinfo-backends
    labels:
      app: reviews
  ports:
    - number: 9080
      protocol: HTTP
EOF
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- failover-reviews.yaml
- outlierdetection-reviews.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Manage reviews traffic with failover"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get failoverpolicy failover 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should get responses from cluster2", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)\"";
  it('Got a response from cluster1', () => helpers.genericCommand({ command: command, responseContains: "cluster1" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/east-west-virtual-destination/tests/reviews-from-cluster1.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
kubectl --context $CLUSTER1 -n bookinfo-frontends exec deploy/productpage-v1 -- python -c "import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)"
kubectl --context ${CLUSTER1} -n bookinfo-backends scale deploy/reviews-v1 --replicas=0
kubectl --context ${CLUSTER1} -n bookinfo-backends scale deploy/reviews-v2 --replicas=0
kubectl --context ${CLUSTER1} -n bookinfo-backends wait --for=jsonpath='{.spec.replicas}'=0 deploy/reviews-v1
kubectl --context ${CLUSTER1} -n bookinfo-backends wait --for=jsonpath='{.spec.replicas}'=0 deploy/reviews-v2
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should get responses from cluster2", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)\"";
  it('Got a response from cluster2', () => helpers.genericCommand({ command: command, responseContains: "cluster2" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/east-west-virtual-destination/tests/reviews-from-cluster2.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
kubectl --context $CLUSTER1 -n bookinfo-frontends exec deploy/productpage-v1 -- python -c "import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)"
kubectl --context ${CLUSTER1} -n bookinfo-backends scale deploy/reviews-v1 --replicas=1
kubectl --context ${CLUSTER1} -n bookinfo-backends scale deploy/reviews-v2 --replicas=1
kubectl --context ${CLUSTER1} -n bookinfo-backends wait --for=jsonpath='{.status.readyReplicas}'=1 deploy/reviews-v1
kubectl --context ${CLUSTER1} -n bookinfo-backends wait --for=jsonpath='{.status.readyReplicas}'=1 deploy/reviews-v2
kubectl --context ${CLUSTER1} -n bookinfo-backends patch deploy reviews-v1 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'
kubectl --context ${CLUSTER1} -n bookinfo-backends patch deploy reviews-v2 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "reviews","command": ["sleep", "20h"]}]}}}}'
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout status deploy/reviews-v1
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout status deploy/reviews-v2
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should get responses from cluster2", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)\"";
  it('Got a response from cluster2', () => helpers.genericCommand({ command: command, responseContains: "cluster2" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/east-west-virtual-destination/tests/reviews-from-cluster2.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
kubectl --context $CLUSTER1 -n bookinfo-frontends exec deploy/productpage-v1 -- python -c "import requests; r = requests.get('http://reviews.global:9080/reviews/0'); print(r.text)"
kubectl --context ${CLUSTER1} -n bookinfo-backends patch deployment reviews-v1  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
kubectl --context ${CLUSTER1} -n bookinfo-backends patch deployment reviews-v2  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout status deploy/reviews-v1
kubectl --context ${CLUSTER1} -n bookinfo-backends rollout status deploy/reviews-v2
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD~2..
git -C ${GITOPS_REPO_LOCAL} commit -m "Revert reviews virtual destination routing"
git -C ${GITOPS_REPO_LOCAL} push
(timeout 2s kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh) || (kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy/in-mesh && kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh)
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');
describe("Communication allowed", () => {
  it("Response code should be 200", () => {
    const podName = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin get pods -l app=not-in-mesh -o jsonpath='{.items[0].metadata.name}'" }).replaceAll("'", "");
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin debug -i -q " + podName + " --image=curlimages/curl -- curl -s -o /dev/null -w \"%{http_code}\" http://reviews.bookinfo-backends:9080/reviews/0" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/zero-trust/tests/not-in-mesh-to-in-mesh-allowed.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');
describe("Communication allowed", () => {
  it("Response code should be 200", () => {
    const podName = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin get pods -l app=in-mesh -o jsonpath='{.items[0].metadata.name}'" }).replaceAll("'", "");
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin debug -i -q " + podName + " --image=curlimages/curl -- curl -s -o /dev/null -w \"%{http_code}\" http://reviews.bookinfo-backends:9080/reviews/0" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/zero-trust/tests/in-mesh-to-in-mesh-allowed.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/workspace-settings.yaml
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
  options:
    serviceIsolation:
      enabled: true
      trimProxyConfig: true
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Enable service isolation"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \"\$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get workspacesettings bookinfo -ojsonpath='{.spec.options.serviceIsolation.enabled}' 2>/dev/null)\" = \"true\" ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');
describe("Communication not allowed", () => {
  it("Response code shouldn't be 200", () => {
    const podName = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin get pods -l app=not-in-mesh -o jsonpath='{.items[0].metadata.name}'" }).replaceAll("'", "");
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin debug -i -q " + podName + " --image=curlimages/curl -- curl -s -o /dev/null -w \"%{http_code}\" --max-time 3 http://reviews.bookinfo-backends:9080/reviews/0" }).replaceAll("'", "");
    expect(command).not.to.contain("200");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/zero-trust/tests/not-in-mesh-to-in-mesh-not-allowed.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');
describe("Communication not allowed", () => {
  it("Response code shouldn't be 200", () => {
    const podName = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin get pods -l app=in-mesh -o jsonpath='{.items[0].metadata.name}'" }).replaceAll("'", "");
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n httpbin debug -i -q " + podName + " --image=curlimages/curl -- curl -s -o /dev/null -w \"%{http_code}\" --max-time 3 http://reviews.bookinfo-backends:9080/reviews/0" }).replaceAll("'", "");
    expect(command).not.to.contain("200");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/zero-trust/tests/in-mesh-to-in-mesh-not-allowed.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/accesspolicy-productpage.yaml
apiVersion: security.policy.gloo.solo.io/v2
kind: AccessPolicy
metadata:
  name: allow-productpage
  namespace: bookinfo-frontends
spec:
  applyToDestinations:
  - selector:
      labels:
        app: productpage
  config:
    authz:
      allowedClients:
      - serviceAccountSelector:
          name: istio-ingressgateway-1-25-service-account
          namespace: istio-gateways
      - serviceAccountSelector:
          name: istio-eastwestgateway-1-25-service-account
          namespace: istio-gateways
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/accesspolicy-details-reviews.yaml
apiVersion: security.policy.gloo.solo.io/v2
kind: AccessPolicy
metadata:
  name: allow-details-reviews
  namespace: bookinfo-frontends
spec:
  applyToDestinations:
  - selector:
      labels:
        app: details
  - selector:
      labels:
        app: reviews
  config:
    authz:
      allowedClients:
      - serviceAccountSelector:
          name: bookinfo-productpage
      allowedMethods:
      - GET
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/accesspolicy-ratings.yaml
apiVersion: security.policy.gloo.solo.io/v2
kind: AccessPolicy
metadata:
  name: allow-ratings
  namespace: bookinfo-frontends
spec:
  applyToDestinations:
  - selector:
      labels:
        app: ratings
  config:
    authz:
      allowedClients:
      - serviceAccountSelector:
          name: bookinfo-reviews
EOF
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- accesspolicy-productpage.yaml
- accesspolicy-details-reviews.yaml
- accesspolicy-ratings.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Access policies"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get accesspolicy allow-productpage 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {

  it("Response code shouldn't be 200 accessing ratings", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://ratings.bookinfo-backends:9080/ratings/0', timeout=3); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).not.to.contain("200");
  });

  it("Response code should be 200 accessing reviews with GET", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://reviews.bookinfo-backends:9080/reviews/0'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });

  it("Response code should be 403 accessing reviews with HEAD", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.head('http://reviews.bookinfo-backends:9080/reviews/0'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("403");
  });

  it("Response code should be 200 accessing details", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://details.bookinfo-backends:9080/details/0'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/httpbin/zero-trust/tests/bookinfo-access.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD~2..
git -C ${GITOPS_REPO_LOCAL} commit -m "Revert zero trust configuration"
git -C ${GITOPS_REPO_LOCAL} push
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/kube-prometheus-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
  - resources-finalizer.argocd.argoproj.io/background
spec:
  project: platform
  destination:
    name: ${MGMT}
    namespace: monitoring
  syncPolicy:
    automated:
      allowEmpty: true
      prune: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
  sources:
  - chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: 55.9.0
    helm:
      releaseName: kube-prometheus-stack
      valueFiles:
      - \$values/platform/argo-cd/kube-prometheus-stack-values.yaml
  - repoURL: http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):3180/gloo-gitops/gitops-repo.git
    targetRevision: HEAD
    ref: values
EOF

cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/kube-prometheus-stack-values.yaml
prometheus:
  service:
    type: LoadBalancer
  prometheusSpec:
    enableRemoteWriteReceiver: true
grafana:
  service:
    type: LoadBalancer
    port: 3000
  additionalDataSources:
  - name: prometheus-GM
    uid: prometheus-GM
    type: prometheus
    url: http://prometheus-server.gloo-mesh:80
  grafana.ini:
    auth.anonymous:
      enabled: true
  defaultDashboardsEnabled: false

EOF

cat <<EOF >>${GITOPS_PLATFORM}/argo-cd/kustomization.yaml
- kube-prometheus-stack.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "kube-prometheus-stack"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n argocd get application kube-prometheus-stack 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n monitoring rollout status deploy/kube-prometheus-stack-grafana 2>/dev/null) ]]; do
  sleep 1
done"
if [[ ! $(kubectl --context ${MGMT} -n monitoring rollout status deploy/kube-prometheus-stack-grafana --timeout 10s) ]]; then
  echo "kube-prometheus-stack did not deploy"
  exit 1
fi
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("kube-prometheus-stack deployments are ready", () => {
  it('kube-prometheus-stack-kube-state-metrics pods are ready', () => helpers.checkDeployment({ context: process.env.MGMT, namespace: "monitoring", k8sObj: "kube-prometheus-stack-kube-state-metrics" }));
  it('kube-prometheus-stack-grafana pods are ready', () => helpers.checkDeployment({ context: process.env.MGMT, namespace: "monitoring", k8sObj: "kube-prometheus-stack-grafana" }));
  it('kube-prometheus-stack-operator pods are ready', () => helpers.checkDeployment({ context: process.env.MGMT, namespace: "monitoring", k8sObj: "kube-prometheus-stack-operator" }));
});

describe("kube-prometheus-stack daemonset is ready", () => {
  it('kube-prometheus-stack-prometheus-node-exporter pods are ready', () => helpers.checkDaemonSet({ context: process.env.MGMT, namespace: "monitoring", k8sObj: "kube-prometheus-stack-prometheus-node-exporter" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/gloo-platform-observability/tests/grafana-installed.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
PROD_PROMETHEUS_IP=$(kubectl get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation-values-gloo.yaml
telemetryCollectorCustomization:
  extraProcessors:
    filter/gloo:
      metrics:
        include:
          match_type: regexp
          metric_names:
            - "gloo_mesh_.*"
            - "relay_.*"
  extraPipelines:
    metrics/gloo:
      receivers:
      - prometheus
      processors:
      - filter/gloo
      - batch
      exporters:
      - otlp

EOF
yq -i '(.spec.template.spec.sources[] | select(.chart == "gloo-platform")).helm.valueFiles += ["$values/platform/argo-cd/gloo-platform-agents-installation-values-gloo.yaml"]' \
  ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation.yaml
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "New Helm values for Gloo metrics"
git -C ${GITOPS_REPO_LOCAL} push
kubectl --context $CLUSTER1 rollout restart daemonset/gloo-telemetry-collector-agent -n gloo-mesh
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/cm-operational-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: operational-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  operational-dashboard.json: |-
$(cat data/steps/gloo-platform-observability/operational-dashboard.json | sed -e 's/^/    /;')
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- cm-operational-dashboard.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gloo Platform operator dashboard"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n monitoring get cm operational-dashboard 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation-values-istio.yaml
telemetryCollectorCustomization:
  extraProcessors:
    batch/istiod:
      send_batch_size: 10000
      timeout: 10s
    filter/istiod:
      metrics:
        include:
          match_type: regexp
          metric_names:
            - "pilot.*"
            - "process.*"
            - "go.*"
            - "container.*"
            - "envoy.*"
            - "galley.*"
            - "sidecar.*"
            # - "istio_build.*" re-enable this after this is fixed upstream
  extraExporters:
    prometheusremotewrite/production:
      endpoint: http://${PROD_PROMETHEUS_IP}:9090/api/v1/write
  extraPipelines:
    metrics/istiod:
      receivers:
      - prometheus
      processors:
      - memory_limiter
      - batch/istiod
      - filter/istiod
      exporters:
      - prometheusremotewrite/production

EOF
yq -i '(.spec.template.spec.sources[] | select(.chart == "gloo-platform")).helm.valueFiles += ["$values/platform/argo-cd/gloo-platform-agents-installation-values-istio.yaml"]' \
  ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation.yaml
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "New Helm values for Istio metrics"
git -C ${GITOPS_REPO_LOCAL} push
kubectl --context $CLUSTER1 rollout restart daemonset/gloo-telemetry-collector-agent -n gloo-mesh
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/cm-istio-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-control-plane-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  istio-control-plane-dashboard.json: |-
$(cat data/steps/gloo-platform-observability/istio-control-plane-dashboard.json | sed -e 's/^/    /;')
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- cm-istio-dashboard.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Istio control plane dashboard"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n monitoring get cm istio-control-plane-dashboard 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation-values-spire.yaml
glooSpireServer:
  enabled: true
  controller:
    verbose: true
  server:
    trustDomain: cluster1
postgresql:
  enabled: true
  global:
    postgresql:
      auth:
        database: spire
        password: gloomesh
        username: spire
telemetryCollectorCustomization:
  pipelines:
    metrics/otlp_relay:
      enabled: true
prometheus:
  skipAutoMigration: true
EOF

yq -i '(.spec.template.spec.sources[] | select(.chart == "gloo-platform")).helm.valueFiles += ["$values/platform/argo-cd/gloo-platform-agents-installation-values-spire.yaml"]' \
  ${GITOPS_PLATFORM}/argo-cd/gloo-platform-agents-installation.yaml
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Enable spire server"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n gloo-mesh get deploy gloo-spire-server 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl --context ${CLUSTER1} -n istio-system delete secrets cacerts
kubectl --context ${CLUSTER1} -n istio-system delete issuedcertificates,podbouncedirectives --all
kubectl --context ${CLUSTER1} -n gloo-mesh rollout status deploy
bash ./data/steps/root-trust-policy/restart-istio-pods.sh ${CLUSTER1}
kubectl --context ${CLUSTER1} -n gloo-mesh rollout restart deploy gloo-mesh-agent
printf "Waiting for all pods needed for the test..."
printf "\n"
kubectl --context ${CLUSTER1} -n istio-gateways rollout status deploy
kubectl --context ${CLUSTER1} -n gloo-mesh rollout status deploy
printf "\n"
export VM_APP="vm1"
export VM_NAMESPACE="virtualmachines"
export VM_NETWORK="vm-network"
cat <<EOF >${GITOPS_BOOKINFO}/${CLUSTER1}/ns-virtualmachines.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${VM_NAMESPACE}
EOF
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/workspaces/bookinfo.yaml
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
    - name: virtualmachines
  - name: cluster2
    namespaces:
    - name: bookinfo-frontends
    - name: bookinfo-backends
EOF
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/workspaces/gateways.yaml
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
    - name: gloo-mesh
  - name: cluster2
    namespaces:
    - name: istio-gateways
    - name: gloo-mesh-addons
EOF
docker run -d --name vm1 --network kind --privileged -v `pwd`/vm1:/vm djannot/ubuntu-systemd:22.04
docker exec vm1 bash -c "sed 's/127.0.0.11/8.8.8.8/' /etc/resolv.conf > /vm/resolv.conf"
docker exec vm1 cp /vm/resolv.conf /etc/resolv.conf
docker exec vm1 apt update -y
docker exec vm1 apt-get install -y iputils-ping curl iproute2 iptables python3 sudo dnsutils
cluster1_cidr=$(kubectl --context ${CLUSTER1} -n kube-system get pod -l component=kube-controller-manager -o jsonpath='{.items[0].spec.containers[0].command}' | jq -r '.[] | select(. | startswith("--cluster-cidr="))' | cut -d= -f2)
cluster2_cidr=$(kubectl --context ${CLUSTER2} -n kube-system get pod -l component=kube-controller-manager -o jsonpath='{.items[0].spec.containers[0].command}' | jq -r '.[] | select(. | startswith("--cluster-cidr="))' | cut -d= -f2)

docker exec vm1 $(kubectl --context ${CLUSTER1} get nodes -o=jsonpath='{range .items[*]}{"ip route add "}{"'${cluster1_cidr}' via "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
docker exec vm1 $(kubectl --context ${CLUSTER2} get nodes -o=jsonpath='{range .items[*]}{"ip route add "}{"'${cluster2_cidr}' via "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
docker cp $HOME/.gloo-mesh/bin/meshctl vm1:/usr/local/bin/
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/externalworkload.yaml
apiVersion: networking.gloo.solo.io/v2alpha1
kind: ExternalWorkload
metadata:
  name: ${VM_APP}
  namespace: virtualmachines
  labels:
    app: ${VM_APP}
spec:
  connectedClusters:
    ${CLUSTER1}: virtualmachines
  identitySelector:
    joinToken:
      enable: true
  ports:
    - name: http-vm
      number: 9999
    - name: tcp-db
      number: 3306
      protocol: TCP
EOF
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- ns-virtualmachines.yaml
- externalworkload.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "External workload"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} get ns ${VM_NAMESPACE} 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
uuid_regex_partial="[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
uuid_regex="^${uuid_regex_partial}$"
start_time=$(date +%s) # Capture start time
duration=120 # Set duration for 2 minutes (120 seconds)
# Loop until JOIN_TOKEN matches the UUID format
while [[ ! "${JOIN_TOKEN}" =~ ${uuid_regex} ]]; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    if [[ $elapsed -ge $duration ]]; then
        echo "Timeout reached. Exiting loop."
        break
    fi

    echo "Waiting for JOIN_TOKEN to have the correct format..."
    export JOIN_TOKEN=$(meshctl external-workload gen-token --kubecontext ${CLUSTER1} --trust-domain ${CLUSTER1} --ttl 3600 --ext-workload virtualmachines/${VM_APP} --plain=true | grep -ioE "${uuid_regex_partial}")
    sleep 1 # Pause for 1 second
done
[[ "${JOIN_TOKEN}" =~ ${uuid_regex} ]] || (echo "JOIN_TOKEN does not match the UUID format." && exit 1)
export EW_GW_ADDR=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=eastwestgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}{.items[0].status.loadBalancer.ingress[0].ip}')
echo -n Waiting for EW be ready...
timeout -v 1m bash -c "
until nc -z ${EW_GW_ADDR} 31338;
do
  sleep 1
  echo -n .
done"
echo
export GLOO_AGENT_URL=https://storage.googleapis.com/gloo-platform/vm/v2.9.1/gloo-workload-agent.deb
export ISTIO_URL=https://storage.googleapis.com/solo-workshops/istio-binaries/1.25.3/istio-sidecar.deb
echo -n Trying to onboard the VM...
MAX_ATTEMPTS=10
ATTEMPTS=0
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  kubectl --context ${CLUSTER1} -n gloo-mesh rollout restart deploy gloo-spire-server
  kubectl --context ${CLUSTER1} -n gloo-mesh rollout status deploy gloo-spire-server
  sleep 30

  export JOIN_TOKEN=$(meshctl external-workload gen-token --kubecontext ${CLUSTER1} --trust-domain ${CLUSTER1} --ttl 3600 --ext-workload virtualmachines/${VM_APP} --plain=true | grep -ioE "${uuid_regex_partial}")
  timeout 1m docker exec vm1 meshctl ew onboard --install \
  --attestor token \
  --join-token ${JOIN_TOKEN} \
  --cluster ${CLUSTER1} \
  --gateway-addr ${EW_GW_ADDR} \
  --gateway-service-account $(kubectl --context ${CLUSTER1} -n istio-gateways get sa -l istio=eastwestgateway -o jsonpath='{.items[0].metadata.name}') \
  --gateway istio-gateways/istio-eastwestgateway-1-25 \
  --trust-domain ${CLUSTER1} \
  --istio-rev 1-25 \
  --network vm-network \
  --gloo ${GLOO_AGENT_URL} \
  --istio ${ISTIO_URL} \
  --ext-workload virtualmachines/${VM_APP} | tee output.log
  cat output.log | grep "Onboarding complete!"
  if [ $? -eq 0 ]; then
    break
  fi
  ATTEMPTS=$((ATTEMPTS + 1))
  echo "Onboarding failed, retrying... (${ATTEMPTS}/${MAX_ATTEMPTS})"
  sleep 2
done
if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
  echo "Onboarding failed after $MAX_ATTEMPTS attempts"
  exit 1
fi
docker exec vm1 curl -v localhost:15000/clusters | grep productpage.bookinfo-frontends.svc.cluster.local
docker exec vm1 curl -I productpage.bookinfo-frontends.svc.cluster.local:9080/productpage
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The VM should be able to access the productpage service", () => {
  const command = 'docker exec vm1 curl -s -o /dev/null -w "%{http_code}" productpage.bookinfo-frontends.svc.cluster.local:9080/productpage';
  it("Got the expected status code 200", () => helpers.genericCommand({ command: command, responseContains: "200" }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/vm-integration-spire/tests/vm-access-productpage.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
docker exec -d vm1 python3 -m http.server 9999
kubectl --context ${CLUSTER1} -n bookinfo-frontends exec $(kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- python -c "import requests; r = requests.get('http://${VM_APP}.virtualmachines.ext.cluster.local:9999'); print(r.text)"
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should be able to access the VM", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://" + process.env.VM_APP + ".virtualmachines.ext.cluster.local:9999'); print(r.status_code)\"";
  it('Got the expected status code 200', () => helpers.genericCommand({ command: command, responseContains: "200" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/vm-integration-spire/tests/productpage-access-vm.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
docker exec vm1 apt-get update
docker exec vm1 apt-get install -y mariadb-server
docker exec vm1 sed -i '/bind-address/c\bind-address  = 0.0.0.0' /etc/mysql/mariadb.conf.d/50-server.cnf
docker exec vm1 systemctl start mysql

docker exec -i vm1 mysql <<EOF
# Grant access to root
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'password' WITH GRANT OPTION;
# Grant root access to other IPs
CREATE USER 'root'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SELECT host, user FROM mysql.user;
EOF

docker exec vm1 systemctl restart mysql
docker exec vm1 curl -LO https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/src/mysql/mysqldb-init.sql
docker exec vm1 sh -c 'mysql -u root -ppassword < mysqldb-init.sql'
docker exec vm1 mysql -u root -ppassword test -e "select * from ratings;"
cp data/steps/vm-integration-spire/bookinfo-ratings-v2-mysql-vm.yaml ${GITOPS_BOOKINFO}/${CLUSTER1}/backends/ratings-v2-mysql-vm.yaml

cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/backends/kustomization.yaml
- ratings-v2-mysql-vm.yaml
EOF

yq -i '. |= ({"replicas":[{"name":"ratings-v1","count":0}]}) + .' ${GITOPS_BOOKINFO}/${CLUSTER1}/backends/kustomization.yaml

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "New ratings version with external database"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get deploy ratings-v2-mysql-vm 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl --context ${CLUSTER1} -n bookinfo-backends wait --for=delete pod -l app=ratings,version=v1
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("The ratings service should use the database running on the VM", () => {
  it('Got reviews v2 with ratings in cluster1', () => helpers.checkBody({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', body: 'text-black', match: true }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/vm-integration-spire/tests/ratings-using-vm.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD~2..
git -C ${GITOPS_REPO_LOCAL} commit -m "Revert external workload"
git -C ${GITOPS_REPO_LOCAL} push
docker rm -f vm1
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Productpage can send requests to httpbin.org", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://httpbin.org/get'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/secure-egress/tests/productpage-to-httpbin-allowed.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
cat <<EOF > ${GITOPS_GATEWAYS}/${MGMT}/glm-cluster1-egress.yaml
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: cluster1-egress
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
        - name: cluster1
          activeGateway: false
      gatewayRevision: 1-25
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.25.3-solo
        components:
          egressGateways:
            - enabled: true
              label:
                istio: egressgateway
              name: istio-egressgateway
              namespace: istio-gateways
EOF

cat <<EOF >>${GITOPS_GATEWAYS}/${MGMT}/kustomization.yaml
- glm-cluster1-egress.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "cluster1 egress gateway lifecycle manager"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get glm cluster1-egress 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
ATTEMPTS=1
until [[ $(kubectl --context $CLUSTER1 -n istio-gateways get deploy -l istio=egressgateway -o json | jq '[.items[].status.readyReplicas] | add') -ge 1 ]] || [ $ATTEMPTS -gt 120 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/virtualgateway-egress.yaml
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: egress-gw
  namespace: istio-gateways
spec:
  listeners:
    - exposedExternalServices:
        - host: httpbin.org
      appProtocol: HTTPS
      port:
        number: 443
      tls:
        mode: ISTIO_MUTUAL
      http: {}
  workloads:
    - selector:
        labels:
          app: istio-egressgateway
          istio: egressgateway
EOF
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/frontends/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: bookinfo-frontends
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels: {}
      podSelector:
        matchLabels: {}
  - to:
    - ipBlock:
        cidr: $(kubectl --context ${CLUSTER2} -n istio-gateways get svc -l istio=eastwestgateway -o jsonpath='{.items[].status.loadBalancer.ingress[0].ip}')/32
    ports:
      - protocol: TCP
        port: 15443
        endPort: 15443
EOF
cat <<EOF >>${GITOPS_GATEWAYS}/${CLUSTER1}/kustomization.yaml
- virtualgateway-egress.yaml
EOF

cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/frontends/kustomization.yaml
- networkpolicy.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "cluster1 egress VirtualGateway and network policy"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get netpol restrict-egress 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication not allowed", () => {
  it("Productpage can NOT send requests to httpbin.org", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://httpbin.org/get', timeout=5); print(r.text)\"" }).replaceAll("'", "");
    expect(command).not.to.contain("User-Agent");
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/secure-egress/tests/productpage-to-httpbin-not-allowed.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
cat <<EOF > ${GITOPS_BOOKINFO}/${CLUSTER1}/frontends/externalservice.yaml
apiVersion: networking.gloo.solo.io/v2
kind: ExternalService
metadata:
  name: httpbin
  namespace: bookinfo-frontends
  labels:
    expose: 'true'
spec:
  hosts:
    - httpbin.org
  ports:
    - clientsideTls: {}
      egressGatewayRoutes:
        portMatch: 80
        virtualGatewayRefs:
          - cluster: cluster1
            name: egress-gw
            namespace: istio-gateways
      name: https
      number: 443
      protocol: HTTPS
EOF

cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/frontends/kustomization.yaml
- externalservice.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "httpbin external service"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get externalservice httpbin 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl --context ${CLUSTER1} -n bookinfo-frontends exec $(kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- python -c "import requests; r = requests.get('http://httpbin.org/get'); print(r.text)"
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Productpage can send requests to httpbin.org", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://httpbin.org/get'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/secure-egress/tests/productpage-to-httpbin-allowed.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
cat <<EOF > ${GITOPS_GATEWAYS}/${CLUSTER1}/accesspolicy-allow-get-httpbin.yaml
apiVersion: security.policy.gloo.solo.io/v2
kind: AccessPolicy
metadata:
  name: allow-get-httpbin
  namespace: istio-gateways
spec:
  applyToDestinations:
  - kind: EXTERNAL_SERVICE
    selector: 
      name: httpbin
      namespace: bookinfo-frontends
      cluster: cluster1
  config:
    authz:
      allowedClients:
      - serviceAccountSelector:
          name: bookinfo-productpage
      allowedMethods:
      - GET
    enforcementLayers:
      mesh: true
      cni: false
EOF

cat <<EOF >>${GITOPS_GATEWAYS}/${CLUSTER1}/kustomization.yaml
- accesspolicy-allow-get-httpbin.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "httpbin access policy"
git -C ${GITOPS_REPO_LOCAL} push
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get accesspolicy allow-get-httpbin 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Productpage can send GET requests to httpbin.org", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.get('http://httpbin.org/get'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("200");
  });

  it("Productpage can't send POST requests to httpbin.org", () => {
    const command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.CLUSTER1 + " -n bookinfo-frontends exec deploy/productpage-v1 -- python -c \"import requests; r = requests.post('http://httpbin.org/post'); print(r.status_code)\"" }).replaceAll("'", "");
    expect(command).to.contain("403");
  });
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/apps/bookinfo/secure-egress/tests/productpage-to-httpbin-only-get-allowed.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD~4..
git -C ${GITOPS_REPO_LOCAL} commit -m "Revert egress resources"
git -C ${GITOPS_REPO_LOCAL} push
