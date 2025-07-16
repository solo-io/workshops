#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
source ./scripts/assert.sh
export MGMT=cluster1
export CLUSTER1=cluster1
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
./scripts/check.sh cluster1
kubectl config use-context ${MGMT}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = ["cluster1"];

    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
kubectl apply --kustomize "https://github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.2.1"
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gateway API CRDs", () => {
  it('Gateways are created', () => helpers.k8sObjectIsPresent({ namespace: "default", k8sType: "crd", k8sObj: "gateways.gateway.networking.k8s.io" }));
  it('Httproutes are created', () => helpers.k8sObjectIsPresent({ namespace: "default", k8sType: "crd", k8sObj: "httproutes.gateway.networking.k8s.io" }));
  it('Referencegrants are created', () => helpers.k8sObjectIsPresent({ namespace: "default", k8sType: "crd", k8sObj: "referencegrants.gateway.networking.k8s.io" }));
  it('Gatewayclasses are created', () => helpers.k8sObjectIsPresent({ namespace: "default", k8sType: "crd", k8sObj: "gatewayclasses.gateway.networking.k8s.io" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/install/tests/check-gatewayapi.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
helm upgrade --install --create-namespace --namespace kgateway-system \
  --version v2.0.1 kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds
helm upgrade --install --create-namespace --namespace kgateway-system \
  --version v2.0.1 kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("kgateway", () => {
    it('kgateway pods are ready', () => helpers.checkDeployment({ namespace: "kgateway-system", k8sObj: "kgateway" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/install/tests/check-kgateway.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("kateway GatewayClass", () => {
  it('kgateway GatewayClass is created', () => helpers.k8sObjectIsPresent({ namespace: "kgateway-system", k8sType: "gatewayclass", k8sObj: "kgateway" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/install/tests/check-gatewayclass.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/httpbin/httpbin.yaml
kubectl wait --for=condition=Ready=True pod -l app=httpbin
kubectl apply -f data/steps/kgateway-labs/basics/gtw.yaml
kubectl wait --for=condition=Programmed=True gtw/my-gateway
kubectl apply -f data/steps/kgateway-labs/basics/route.yaml
kubectl wait --for=jsonpath='{.status.listeners[0].attachedRoutes}'=1 gtw my-gateway
export GW_IP=$(kubectl get gtw my-gateway -ojsonpath='{.status.addresses[0].value}')
./scripts/register-domain.sh httpbin.example.com ${GW_IP}
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/basics/tests/http.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
step certificate create httpbin.example.com httpbin.crt httpbin.key \
  --profile self-signed --subtle --no-password --insecure --force
kubectl create secret tls httpbin-cert \
  --cert=httpbin.crt --key=httpbin.key
kubectl apply -f data/steps/kgateway-labs/https/gtw.yaml
kubectl apply -f data/steps/kgateway-labs/https/route.yaml
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/https/tests/https.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
kubectl apply -f data/steps/kgateway-labs/https/redirect.yaml
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/https/tests/redirect-http-to-https.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
kubectl create ns infra
kubectl create ns httpbin
kubectl apply -n httpbin -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/httpbin/httpbin.yaml
kubectl create ns bookinfo
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/bookinfo/platform/kube/bookinfo.yaml
    step certificate create httpbin.example.com httpbin.crt httpbin.key \
      --profile self-signed --subtle --no-password --insecure --force

    kubectl -n infra create secret tls httpbin-cert \
      --cert=httpbin.crt --key=httpbin.key
    step certificate create bookinfo.example.com bookinfo.crt bookinfo.key \
      --profile self-signed --subtle --no-password --insecure --force

    kubectl -n infra create secret tls bookinfo-cert \
      --cert=bookinfo.crt --key=bookinfo.key
kubectl -n infra apply -f data/steps/kgateway-labs/shared-gw/gtw.yaml
kubectl -n httpbin apply -f data/steps/kgateway-labs/shared-gw/httpbin-route.yaml
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Check that the httpbin route is marked as NotAllowedByListeners by the gateway", () => {
  const command = `kubectl -n httpbin get httproute httpbin -o jsonpath='{.status.parents[*].conditions[?(@.type=="Accepted")].reason}'`;
  it('Httproute "Accepted" status is NotAllowedByListeners', () => helpers.genericCommand({ command: command, responseContains: "NotAllowedByListeners" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/tests/check-httproute-status.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
kubectl apply -n infra -f data/steps/kgateway-labs/shared-gw/gtw-with-allowed-routes.yaml
kubectl label ns httpbin self-serve-ingress=true
kubectl label ns bookinfo self-serve-ingress=true
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Check that the httpbin route is marked as Accepted by the gateway", () => {
  const command = `kubectl -n httpbin get httproute httpbin -o jsonpath='{.status.parents[*].conditions[?(@.type=="Accepted")].reason}'`;
  it('Httproute "Accepted" status is Accepted', () => helpers.genericCommand({ command: command, responseContains: "Accepted" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/tests/check-httproute-status.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
kubectl -n bookinfo apply -f data/steps/kgateway-labs/shared-gw/bookinfo-route.yaml
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Check that the bookinfo route is marked as Accepted by the gateway", () => {
  const command = `kubectl -n bookinfo get httproute bookinfo -o jsonpath='{.status.parents[*].conditions[?(@.type=="Accepted")].reason}'`;
  it('Httproute "Accepted" status is Accepted', () => helpers.genericCommand({ command: command, responseContains: "Accepted" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/tests/check-httproute-status.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/../https/tests/https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
kubectl -n infra apply -f data/steps/kgateway-labs/shared-gw/redirect.yaml
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/../https/tests/redirect-http-to-https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
kubectl apply -f data/steps/kgateway-labs/routing-rules/reviews-endpoint.yaml
export GW_IP=$(kubectl get gtw -n infra infra-gateway -ojsonpath='{.status.addresses[0].value}')
./scripts/register-domain.sh bookinfo.example.com ${GW_IP}
./scripts/register-domain.sh httpbin.example.com ${GW_IP}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');
const chai = require("chai");
const expect = chai.expect;

describe("bookinfo through HTTPS", () => {
  const upstreamList = ["reviews-v1","reviews-v2","reviews-v3"];
  upstreamList.forEach(upstream => {
    const command = "curl  -ks https://bookinfo.example.com/reviews/123";
    it(`Checking presence of text '${upstream}'`, () => {
      helpers.getOutputForCommand({ command: command }).should.contain(upstream);
      });
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/bookinfo/platform/kube/bookinfo-versions.yaml
kubectl apply -f data/steps/kgateway-labs/routing-rules/reviews-split.yaml
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');
const chai = require("chai");
const expect = chai.expect;

describe("bookinfo through HTTPS", () => {
  const upstreamList = ["reviews-v1","reviews-v2"];
  upstreamList.forEach(upstream => {
    const command = "curl  -ks https://bookinfo.example.com/reviews/123";
    it(`Checking presence of text '${upstream}'`, () => {
      helpers.getOutputForCommand({ command: command }).should.contain(upstream);
      });
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');
const chai = require("chai");
const expect = chai.expect;

describe("bookinfo through HTTPS", () => {
  const upstreamList = ["reviews-v3"];
  upstreamList.forEach(upstream => {
    const command = "curl  -ks https://bookinfo.example.com/reviews/123";
    it(`Checking absence of text '${upstream}'`, () => {
      helpers.getOutputForCommand({ command: command }).should.not.contain(upstream);
      helpers.getOutputForCommand({ command: command }).should.not.contain(upstream);
      helpers.getOutputForCommand({ command: command }).should.not.contain(upstream);
      });
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl apply -f data/steps/kgateway-labs/routing-rules/reviews-header-match.yaml
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');
const chai = require("chai");
const expect = chai.expect;

describe("bookinfo through HTTPS", () => {
  const upstreamList = ["reviews-v2"];
  upstreamList.forEach(upstream => {
    const command = "curl  -ks https://bookinfo.example.com/reviews/123";
    it(`Checking presence of text '${upstream}'`, () => {
      helpers.getOutputForCommand({ command: command }).should.contain(upstream);
      });
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');
const chai = require("chai");
const expect = chai.expect;

describe("bookinfo through HTTPS", () => {
  const upstreamList = ["reviews-v1","reviews-v3"];
  upstreamList.forEach(upstream => {
    const command = "curl  -ks https://bookinfo.example.com/reviews/123";
    it(`Checking absence of text '${upstream}'`, () => {
      helpers.getOutputForCommand({ command: command }).should.not.contain(upstream);
      helpers.getOutputForCommand({ command: command }).should.not.contain(upstream);
      helpers.getOutputForCommand({ command: command }).should.not.contain(upstream);
      });
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');
const chai = require("chai");
const expect = chai.expect;

describe("bookinfo through HTTPS", () => {
  const upstreamList = ["reviews-v3"];
  upstreamList.forEach(upstream => {
    const command = "curl -H 'role: qa' -ks https://bookinfo.example.com/reviews/123";
    it(`Checking presence of text '${upstream}'`, () => {
      helpers.getOutputForCommand({ command: command }).should.contain(upstream);
      });
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl apply -f data/steps/kgateway-labs/routing-rules/add-requestheader.yaml
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request-type header correctly set", () => {
  it('Checking text \'Request-Type\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/headers', body: 'Request-Type' }));
  it('Checking text \'external\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/headers', body: 'external' }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/headers.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl apply -f data/steps/kgateway-labs/routing-rules/url-rewrite.yaml
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl rollout status -n argo-rollouts deploy argo-rollouts
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Argo is healthy", () => {
    it(`Argo service is present`, () => helpers.k8sObjectIsPresent({ namespace: "argo-rollouts", k8sType: "service", k8sObj: "argo-rollouts-metrics" }));
    it(`Argo pods are ready`, () => helpers.checkDeploymentsWithLabels({ namespace: "argo-rollouts", labels: "app.kubernetes.io/name=argo-rollouts", instances: 1 }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/argo-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl replace -f data/steps/kgateway-labs/rollouts/argo-gwapi-plugin-cm.yaml
kubectl apply -f data/steps/kgateway-labs/rollouts/argo-rbac.yaml
kubectl rollout restart deployment -n argo-rollouts argo-rollouts
kubectl rollout status -n argo-rollouts deploy argo-rollouts
kubectl apply -f data/steps/kgateway-labs/rollouts/gtw.yaml
kubectl apply -f data/steps/kgateway-labs/rollouts/ratings.yaml
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Ratings service is healthy", () => {
    it(`Ratings service is present`, () => helpers.k8sObjectIsPresent({ namespace: "default", k8sType: "service", k8sObj: "ratings" }));
    it(`Ratings pods are ready`, () => helpers.checkDeploymentsWithLabels({ namespace: "default", labels: "app=ratings", instances: 1 }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/ratings-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl apply -f data/steps/kgateway-labs/rollouts/services.yaml
kubectl apply -f data/steps/kgateway-labs/rollouts/route.yaml
kubectl apply -f data/steps/kgateway-labs/rollouts/rollout.yaml
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The rollout should progress", () => {
  const canaryWeight = "kubectl get rollout reviews-rollout -ojsonpath='{.status.canary.weights.canary.weight}'";
  const stableWeight = "kubectl get rollout reviews-rollout -ojsonpath='{.status.canary.weights.stable.weight}'";
  it('Canary weight should decrease', () => helpers.genericCommand({ command: canaryWeight, responseContains: "0" }));
  it('Stable weight should increase', () => helpers.genericCommand({ command: stableWeight, responseContains: "100" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/rollout-progress.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
export GW_IP=$(kubectl get gtw my-gateway -ojsonpath='{.status.addresses[0].value}')
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Reviews route is healthy", () => {
  const domain = "bookinfo.example.com";
  const command = `curl -ks "http://${domain}/reviews/123" -o /dev/null -w "%{http_code}" --resolve "${domain}:80:${process.env.GW_IP}" --max-time 0.5`;
  it(`Got the expected status code 200 for ${domain}`, () => {
    const res = helpers.getOutputForCommand({ command: command });
    res.should.contain("200");
  });
});

describe("Reviews is not calling ratings", () => {
  const domain = "bookinfo.example.com";
  const command = `curl -ks "http://${domain}/reviews/123" --resolve "${domain}:80:${process.env.GW_IP}" --max-time 0.5`;
  it(`Got the expected status code 200 for ${domain}`, () => {
    const res = helpers.getOutputForCommand({ command: command });
    res.should.not.contain("rating");
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/reviews-route-v1-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-*
sudo mv ./kubectl-argo-* /usr/local/bin/kubectl-argo-rollouts
kubectl argo rollouts set image reviews-rollout reviews=docker.io/istio/examples-bookinfo-reviews-v2:1.20.2
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Reviews route is healthy", () => {
  const domain = "bookinfo.example.com";
  const command = `curl -ks "http://${domain}/reviews/123" -o /dev/null -w "%{http_code}" -H "role: qa" --resolve "${domain}:80:${process.env.GW_IP}" --max-time 0.5`;
  it(`Got the expected status code 200 for ${domain}`, () => {
    const res = helpers.getOutputForCommand({ command: command });
    res.should.contain("200");
  });
});

describe("Reviews is calling ratings", () => {
  const domain = "bookinfo.example.com";
  const command = `curl -ks "http://${domain}/reviews/123" -H "role: qa" --resolve "${domain}:80:${process.env.GW_IP}" --max-time 0.5`;
  it(`Got the expected status code 200 for ${domain}`, () => {
    const res = helpers.getOutputForCommand({ command: command });
    res.should.contain("rating");
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/reviews-route-v2-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Reviews route is healthy", () => {
  const domain = "bookinfo.example.com";
  const command = `curl -ks "http://${domain}/reviews/123" -o /dev/null -w "%{http_code}" --resolve "${domain}:80:${process.env.GW_IP}" --max-time 0.5`;
  it(`Got the expected status code 200 for ${domain}`, () => {
    const res = helpers.getOutputForCommand({ command: command });
    res.should.contain("200");
  });
});

describe("Reviews is not calling ratings", () => {
  const domain = "bookinfo.example.com";
  const command = `curl -ks "http://${domain}/reviews/123" --resolve "${domain}:80:${process.env.GW_IP}" --max-time 0.5`;
  it(`Got the expected status code 200 for ${domain}`, () => {
    const res = helpers.getOutputForCommand({ command: command });
    res.should.not.contain("rating");
  });
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/reviews-route-v1-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl argo rollouts promote reviews-rollout
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The rollout should progress", () => {
  const canaryWeight = "kubectl get rollout reviews-rollout -ojsonpath='{.status.canary.weights.canary.weight}'";
  const stableWeight = "kubectl get rollout reviews-rollout -ojsonpath='{.status.canary.weights.stable.weight}'";
  it('Canary weight should decrease', () => helpers.genericCommand({ command: canaryWeight, responseContains: "0" }));
  it('Stable weight should increase', () => helpers.genericCommand({ command: stableWeight, responseContains: "100" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/rollout-progress.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
wget https://github.com/cert-manager/cert-manager/releases/download/v1.12.4/cert-manager.yaml

kubectl --context ${CLUSTER1} apply -f cert-manager.yaml
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager-cainjector
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager-webhook
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-amazon-pod-identity-webhook
kubectl --context ${CLUSTER1} rollout status deploy/pod-identity-webhook
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Amazon EKS pod identity webhook", () => {
  it('Amazon EKS pod identity webhook is ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "default", k8sObj: "pod-identity-webhook" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/deploy-amazon-pod-identity-webhook/tests/pods-available.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: Backend
metadata:
  name: lambda-echo
  namespace: httpbin
  labels:
    lab: gateway-lambda
spec:
  type: AWS
  aws:
    region: eu-west-1
    accountId: "253915036081"
    auth:
      type: Secret
      secretRef:
        name: aws-creds
    lambda:
      functionName: workshop-echo
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: aws-creds
  namespace: httpbin
  labels:
    lab: gateway-lambda
type: Opaque
stringData:
  accessKey: ${AWS_ACCESS_KEY_ID}
  secretKey: ${AWS_SECRET_ACCESS_KEY}
  sessionToken: ""
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lambda-echo
  namespace: httpbin
  labels:
    delegation.kgateway.dev/label: httpbin
    lab: gateway-lambda
spec:
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /lambda
    backendRefs:
    - name: lambda-echo
      namespace: httpbin
      group: gateway.kgateway.dev
      kind: Backend
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  if (!process.env.AWS_ACCESS_KEY_ID) {
      console.error("[Warning] AWS_ACCESS_KEY_ID is not set");
    }
  it(`Checking text 'foo' in response`, () => process.env.AWS_ACCESS_KEY_ID ? helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/lambda', data: '{"foo":"bar"}', body: 'foo', match: true }) : true);
})
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/apps/httpbin/gateway-lambda/tests/check-lambda-echo.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context ${CLUSTER1} delete secret -n httpbin aws-creds
kubectl --context ${CLUSTER1} annotate sa -n kgateway-system http "eks.amazonaws.com/role-arn=arn:aws:iam::253915036081:role/lambda-workshop" --overwrite
kubectl --context ${CLUSTER1} rollout restart deployment -n kgateway-system http
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: Backend
metadata:
  name: lambda-echo
  namespace: httpbin
  labels:
    lab: gateway-lambda
spec:
  type: AWS
  aws:
    region: eu-west-1
    accountId: "253915036081"
    lambda:
      functionName: workshop-echo
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  if (!process.env.AWS_ACCESS_KEY_ID) {
      console.error("[Warning] AWS_ACCESS_KEY_ID is not set");
    }
  it(`Checking text 'foo' in response`, () => process.env.AWS_ACCESS_KEY_ID ? helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/lambda', data: '{"foo":"bar"}', body: 'foo', match: true }) : true);
})
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/apps/httpbin/gateway-lambda/tests/check-lambda-echo.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context ${CLUSTER1} -n httpbin delete Backend,HTTPRoute,Secret -l 'lab=gateway-lambda'
kubectl --context ${CLUSTER1} annotate sa -n kgateway-system http "eks.amazonaws.com/role-arn-"
kubectl --context ${CLUSTER1} rollout status deployment -n kgateway-system http
kubectl --context ${CLUSTER1} rollout restart deployment -n kgateway-system http
