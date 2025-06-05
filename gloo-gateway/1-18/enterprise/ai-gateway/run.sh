#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
source ./scripts/assert.sh
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml

helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.18.11 \
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
      livenessProbeEnabled: true
  discovery:
    enabled: false
observability:
  enabled: true
prometheus:
  enabled: true
  extraScrapeConfigs: |
    - job_name: 'custom'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_container_port_name]
        action: keep
        regex: '.*-monitoring'
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_container_port_number]
        action: replace
        regex: (.+):(?:\d+);(\d+)
        replacement: \${1}:\${2}
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
grafana:
  defaultInstallationEnabled: true
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
global:
  extensions:
    rateLimit:
      deployment:
        logLevel: debug
    extAuth:
      deployment:
        logLevel: debug
    caching:
      enabled: true
      deployment:
        logLevel: debug
EOF
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER1 -n gloo-system rollout status deployment
kubectl --context $CLUSTER1 -n gloo-system get pods
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
kubectl --context $CLUSTER1 apply -f- <<EOF
apiVersion: gateway.gloo.solo.io/v1alpha1
kind: GatewayParameters
metadata:
  name: gloo-gateway-override
  namespace: gloo-system
spec:
  kube:
    aiExtension:
      enabled: true
      ports:
      - name: ai-monitoring
        containerPort: 9092
EOF
kubectl --context $CLUSTER1 apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: ai-gateway
  namespace: gloo-system
  annotations:
    gateway.gloo.solo.io/gateway-parameters-name: gloo-gateway-override
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo AI Gateway", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["gloo-proxy-ai-gateway"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/deploy-ai-gateway/tests/check-ai-gateway.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;

describe("Required environment variables should contain value", () => {
  it("Validating that environment variables for LLM apikeys are set", () => {
    const llmApiKeyEnvVars = ['OPENAI_API_KEY','MISTRAL_API_KEY'];
    llmApiKeyEnvVars.forEach(element => {
      console.log(`Checking for Environment Variable ${element}...`);
      expect(process.env[element]).to.not.be.undefined.and.to.not.be.empty;
    });
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-credential-management/tests/environment-variables.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=0 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
kubectl --context $CLUSTER1 create secret generic openai-secret -n gloo-system \
    --from-literal="Authorization=Bearer $OPENAI_API_KEY" \
    --dry-run=client -oyaml | kubectl --context $CLUSTER1 apply -f -
kubectl --context $CLUSTER1 create secret generic mistral-secret -n gloo-system \
    --from-literal="Authorization=Bearer $MISTRAL_API_KEY" \
    --dry-run=client -oyaml | kubectl --context $CLUSTER1 apply -f -
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  labels:
    app: gloo
  name: mistral
  namespace: gloo-system
spec:
  ai:
    mistral:
      authToken:
        secretRef:
          name: mistral-secret
          namespace: gloo-system
---
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  labels:
    app: gloo
  name: openai
  namespace: gloo-system
spec:
  ai:
    openai:
      authToken:
        secretRef:
          name: openai-secret
          namespace: gloo-system
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: openai
  namespace: gloo-system
spec:
  parentRefs:
    - name: ai-gateway
      namespace: gloo-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /openai
    filters:
      - type: URLRewrite
        urlRewrite:
          path:
            type: ReplaceFullPath
            replaceFullPath: /v1/chat/completions
    backendRefs:
    - name: openai
      namespace: gloo-system
      group: gloo.solo.io
      kind: Upstream
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: mistral
  namespace: gloo-system
spec:
  parentRefs:
    - name: ai-gateway
      namespace: gloo-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /mistral
    filters:
      - type: URLRewrite
        urlRewrite:
          path:
            type: ReplaceFullPath
            replaceFullPath: /v1/chat/completions
    backendRefs:
    - name: mistral
      namespace: gloo-system
      group: gloo.solo.io
      kind: Upstream
EOF
export GLOO_AI_GATEWAY=$(kubectl --context $CLUSTER1 get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
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

const getGatewayIP = () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context ${cluster} get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.not.be.empty;
  return cli.output.trim().replace(/'/g, '');
};

describe("Managing LLM provider credentials", () => {
  let glooAIGatewayIP;

  before(() => {
    glooAIGatewayIP = getGatewayIP();
  });

  it('should route traffic to OpenAI API', () => {
    let curlCommand = `
curl -v "${glooAIGatewayIP}:8080/openai" -H content-type:application/json -d '{
  "model": "gpt-4o-mini",
  "max_tokens": 128,
  "messages": [
  {
    "role": "system",
    "content": "You are a poetic assistant, skilled in explaining complex programming concepts with creative flair."
  },
  {
    "role": "user",
    "content": "Compose a poem that explains the concept of recursion in programming."
  }
]}'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("model");
  });

  it('should route traffic to Mistral AI API', () => {
    let curlCommand = `
curl -v "${glooAIGatewayIP}:8080/mistral" -H content-type:application/json -d '{
  "model": "open-mistral-nemo",
  "max_tokens": 128,
  "messages": [
    {
      "role": "user",
      "content": "What is the best French cheese?"
    }
  ]
}'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("model");
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-credential-management/tests/check-configured-llms.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualHostOption
metadata:
  name: jwt-provider
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: ai-gateway
  options:
    jwt:
      providers:
        selfminted:
          issuer: solo.io
          jwks:
            local:
              key: |
                -----BEGIN PUBLIC KEY-----
                MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAskFAGESgB22iOsGk/UgX
                BXTmMtd8R0vphvZ4RkXySOIra/vsg1UKay6aESBoZzeLX3MbBp5laQenjaYJ3U8P
                QLCcellbaiyUuE6+obPQVIa9GEJl37GQmZIMQj4y68KHZ4m2WbQVlZVIw/Uw52cw
                eGtitLMztiTnsve0xtgdUzV0TaynaQrRW7REF+PtLWitnvp9evweOrzHhQiPLcdm
                fxfxCbEJHa0LRyyYatCZETOeZgkOHlYSU0ziyMhHBqpDH1vzXrM573MQ5MtrKkWR
                T4ZQKuEe0Acyd2GhRg9ZAxNqs/gbb8bukDPXv4JnFLtWZ/7EooKbUC/QBKhQYAsK
                bQIDAQAB
                -----END PUBLIC KEY-----
EOF
chmod +x ./scripts/create-jwt.sh
# Alice works in the "dev" team and we're going to give her access to the Open AI API (specifically the GPT-4o-mini model)
export ALICE_TOKEN=$(./scripts/create-jwt.sh ./data/steps/ai-access-control/private-key.pem alice dev openai gpt-4o-mini)

# Bob works in the "ops" team and we're going to give him access to the Mistral AI API (specifically the open-mistral-nemo model)
export BOB_TOKEN=$(./scripts/create-jwt.sh ./data/steps/ai-access-control/private-key.pem bob ops mistral open-mistral-nemo)
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: mistral-opt
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: mistral
  options:
    rbac:
      policies:
        viewer:
          nestedClaimDelimiter: .
          principals:
          - jwtPrincipal:
              claims:
                llms.mistral: open-mistral-nemo
              matcher: LIST_CONTAINS
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

const getGatewayIP = () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context ${cluster} get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.not.be.empty;
  return cli.output.trim().replace(/'/g, '');
};

describe("Managing access to the LLMs based on credentials", () => {
  let glooAIGatewayIP;

  const aliceToken = process.env.ALICE_TOKEN
  const bobToken = process.env.BOB_TOKEN

  before(() => {
    glooAIGatewayIP = getGatewayIP();
  });

  it('should admit traffic for JWTs with the specified model as a claim', () => {
    let curlCommand = `
curl "${glooAIGatewayIP}:8080/mistral" --header "Authorization: Bearer ${bobToken}" -H content-type:application/json -d '{
  "model": "open-mistral-nemo",
  "max_tokens": 128,
  "messages": [
  {
    "role": "system",
    "content": "You are a poetic assistant, skilled in explaining complex programming concepts with creative flair."
  },
  {
    "role": "user",
    "content": "Compose a poem that explains the concept of recursion in programming."
  }
]}'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("model");
  });


  it('should reject traffic for JWTs lacking the specified model as a claim', () => {
    let curlCommand = `
curl "${glooAIGatewayIP}:8080/mistral" --header "Authorization: Bearer ${aliceToken}" -H content-type:application/json -d '{
  "model": "open-mistral-nemo",
  "max_tokens": 128,
  "messages": [
    {
      "role": "system",
      "content": "You are a poetic assistant, skilled in explaining complex programming concepts with creative flair."
    },
    {
      "role": "user",
      "content": "Compose a poem that explains the concept of recursion in programming."
    }
]}'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("RBAC: access denied");
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-access-control/tests/check-llm-access.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
kubectl --context $CLUSTER1 delete routeoptions.gateway.solo.io -A --all
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: per-user-counter
  namespace: gloo-system
spec:
  raw:
    descriptors:
    - key: user-id
      rateLimit:
        requestsPerUnit: 70
        unit: HOUR
    rateLimits:
    - actions:
      - metadata:
          descriptorKey: user-id
          source: DYNAMIC
          default: unknown
          metadataKey:
            key: "envoy.filters.http.jwt_authn"
            path:
            - key: principal
            - key: sub

EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: openai-opt
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: openai
  options:
    rateLimitConfigs:
      refs:
      - name: per-user-counter
        namespace: gloo-system
    rbac:
      policies:
        viewer:
          nestedClaimDelimiter: .
          principals:
          - jwtPrincipal:
              claims:
                "llms.openai": "gpt-4o-mini"
              matcher: LIST_CONTAINS
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

const getGatewayIP = () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context ${cluster} get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.not.be.empty;
  return cli.output.trim().replace(/'/g, '');
};

describe("rate limiting based on token usage", () => {
  let glooAIGatewayIP;

  const aliceToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyAiaXNzIjogInNvbG8uaW8iLCAib3JnIjogInNvbG8uaW8iLCAic3ViIjogImFsaWNlIiwgInRlYW0iOiAiZGV2IiwgImxsbXMiOiB7ICJvcGVuYWkiOiBbICJncHQtNG8tbWluaSIgXSB9IH0.pfNX01HXsUUOicJ_hJuClE_T5K33bKiRPh2EvS2CZ7Yrxd7M0ctanQ5WU-PDpsiVRhdkPp4jidXL2d4odWF20O0-EtjJDaZz3Lu05SBCGSzlBv7iV3nuIo_AIgyfO9eKZNmQCKTZCRFGvK9PnFbblpxKh8vGYiys44OHsoGs1C-vuqQPmL0T_4tLpO09pvQ6cl_pAIBJrzjZseIxd0cL18Qt2KL0J39ZtzMxZizPEBs5XfeNFJOTCLVsEhFkBMs_zUjcE-d3nC3zFp8WefPDpvDi2Ofmne5pqQA5A0Xot-97EoEh2g7k2o-0BzHC1ThtUvFdfEgPF_RQYJjLnJ6ktQ"

  before(() => {
    glooAIGatewayIP = getGatewayIP();
  });


  it('rate limit with too many requests', () => {
    let curlCommand = `
  curl -v "${glooAIGatewayIP}:8080/openai" --header "Authorization: Bearer ${aliceToken}" -H content-type:application/json -d '{
    "model": "gpt-4o-mini",
    "max_tokens": 128,
    "messages": [
      {
        "role": "system",
        "content": "You are a poetic assistant, skilled in explaining complex programming concepts with creative flair."
      },
      {
        "role": "user",
        "content": "Compose a poem that explains the concept of recursion in programming."
      }
    ]
  }'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("Too Many Requests");
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-rate-limiting/tests/check-rate-limited.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl --context $CLUSTER1 apply -f ./data/steps/ai-rate-limiting/grafana-dash.yaml
kubectl --context $CLUSTER1 delete routeoptions openai-opt -n gloo-system
kubectl --context $CLUSTER1 delete virtualhostoptions.gateway.solo.io -n gloo-system jwt-provider
kubectl --context $CLUSTER1 delete ratelimitconfigs per-user-counter -n gloo-system
kubectl --context $CLUSTER1 apply -f data/steps/ai-model-failover/model-failover-deployment.yaml

kubectl --context $CLUSTER1 -n gloo-system rollout status deploy model-failover
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  labels:
    app: gloo
  name: openai
  namespace: gloo-system
spec:
  ai:
    multi:
      priorities:
      - pool:
        - openai:
            model: "gpt-4o"
            customHost:
              host: model-failover.gloo-system.svc.cluster.local
              port: 80
            authToken:
              secretRef:
                name: openai-secret
                namespace: gloo-system
      - pool:
        - openai:
            model: "gpt-4.0-turbo"
            customHost:
              host: model-failover.gloo-system.svc.cluster.local
              port: 80
            authToken:
              secretRef:
                name: openai-secret
                namespace: gloo-system
      - pool:
        - openai:
            model: "gpt-3.5-turbo"
            customHost:
              host: model-failover.gloo-system.svc.cluster.local
              port: 80
            authToken:
              secretRef:
                name: openai-secret
                namespace: gloo-system
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: openai
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: openai
  options:
    retries:
      retryOn: 'retriable-status-codes'
      retriableStatusCodes:
      - 429
      numRetries: 3
      previousPriorities:
        updateFrequency: 1
EOF
sleep 20s
curl -v "$GLOO_AI_GATEWAY:8080/openai" -H content-type:application/json -d '{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "system",
      "content": "You are a poetic assistant, skilled in explaining complex programming concepts with creative flair."
    },
    {
      "role": "user",
      "content": "Compose a poem that explains the concept of recursion in programming."
    }
  ]
}'
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

it('should have failed over to other configured models', () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context=${cluster} logs deploy/model-failover -n gloo-system`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.include("gpt-4o");
  expect(cli).output.to.include("gpt-4.0-turbo");
  expect(cli).output.to.include("gpt-3.5-turbo");
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-model-failover/tests/check-failover.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
cat <<EOF | kubectl --context $CLUSTER1 apply -f -
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  labels:
    app: gloo
  name: openai
  namespace: gloo-system
spec:
  ai:
    openai:
      authToken:
        secretRef:
          name: openai-secret
          namespace: gloo-system
EOF
kubectl --context ${CLUSTER1} -n gloo-system delete routeoption openai
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: openai-opt
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: openai
  options:
    ai:
      promptEnrichment:
        prepend:
        - role: "system"
          content: "Parse the unstructured text into CSV format and respond only with the CSV data."
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

const getGatewayIP = () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context ${cluster} get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.not.be.empty;
  return cli.output.trim().replace(/'/g, '');
};

describe("should return data according to configured prompt", () => {
  let glooAIGatewayIP;

  before(() => {
    glooAIGatewayIP = getGatewayIP();
  });

  it('returns csv output', () => {
    let curlCommand = `
curl "${glooAIGatewayIP}:8080/openai" -H content-type:application/json -d '{
  "model": "gpt-4o-mini",
  "max_tokens": 128,
  "messages": [
    {
      "role": "user",
      "content": "The recipe called for eggs, flour and sugar. The price was $5, $3, and $2."
    }
  ]
}'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);

    const sanitizedOutput = curlCli.output.toLowerCase().replace("$", "");
    expect(sanitizedOutput).to.include("eggs,5");
    expect(sanitizedOutput).to.include("flour,3");
    expect(sanitizedOutput).to.include("sugar,2");
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-prompt-management/tests/check-csv-output.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl --context $CLUSTER1 delete routeoptions openai-opt -n gloo-system
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: mistral-ai-opt
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: mistral
  options:
    ai:
      promptGuard:
        request:
          customResponse:
            message: "Rejected due to inappropriate content"
          regex:
            matches:
            - pattern: "credit card"
            action: REJECT
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: mistral-ai-opt
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: mistral
  options:
    ai:
      promptGuard:
        request:
          customResponse:
            message: "Rejected due to inappropriate content"
          regex:
            matches:
            - pattern: "credit card"
            action: REJECT
        response:
          regex:
            matches:
            # Credit card number regex
            - pattern: '\b(\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{4})\b'
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

const getGatewayIP = () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context ${cluster} get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.not.be.empty;
  return cli.output.trim().replace(/'/g, '');
};

describe("prompt guard", () => {
  let glooAIGatewayIP;

  before(() => {
    glooAIGatewayIP = getGatewayIP();
  });

  it('should mask credit card numbers in the response', () => {
    let curlCommand = `
curl "${glooAIGatewayIP}:8080/mistral" -H content-type:application/json \
  --data '{
    "model": "open-mistral-nemo",
    "messages": [
     {
        "role": "user",
        "content": "Can you give me some examples of Mastercard numbers?"
      }
    ]
  }'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("CUSTOM");
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-prompt-guard/tests/check-prompt-guard.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context $CLUSTER1 delete routeoptions mistral-ai-opt -n gloo-system
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ai-guardrail-webhook
  namespace: gloo-system
  labels:
    app: ai-guardrail
spec:
  replicas: 4
  selector:
    matchLabels:
      app: ai-guardrail-webhook
  template:
    metadata:
      labels:
        app: ai-guardrail-webhook
    spec:
      containers:
      - name: webhook
        image: gcr.io/solo-public/docs/ai-guardrail-webhook:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1"
---
apiVersion: v1
kind: Service
metadata:
  name: ai-guardrail-webhook
  namespace: gloo-system
  labels:
    app: ai-guardrail
spec:
  selector:
    app: ai-guardrail-webhook
  ports:
  - port: 8000
    targetPort: 8000
  type: LoadBalancer
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: openai-opt
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: openai
  options:
    ai:
      promptGuard:
        request:
          webhook:
            host: ai-guardrail-webhook.gloo-system.svc.cluster.local
            port: 8000
        response:
          webhook:
            host: ai-guardrail-webhook.gloo-system.svc.cluster.local
            port: 8000
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

const getGatewayIP = () => {
  const cluster = process.env.CLUSTER1
  const command = `kubectl --context ${cluster} get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`;
  const cli = chaiExec(command);
  expect(cli).to.exit.with.code(0);
  expect(cli).output.to.not.be.empty;
  return cli.output.trim().replace(/'/g, '');
};

describe("ai guardrail webhook", () => {
  let glooAIGatewayIP;

  before(() => {
    glooAIGatewayIP = getGatewayIP();
  });

  it('should approve regular traffic', () => {
    let curlCommand = `
curl "${glooAIGatewayIP}:8080/openai" -H content-type:application/json \
  --data '{
    "model": "gpt-4o-mini",
    "messages": [
     {
        "role": "user",
        "content": "Is this a risky request?"
      }
    ]
  }'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.not.to.include("request blocked");
  });

  it('should reject traffic containing the word block', () => {
    let curlCommand = `
curl "${glooAIGatewayIP}:8080/openai" -H content-type:application/json \
  --data '{
    "model": "gpt-4o-mini",
    "messages": [
     {
        "role": "user",
        "content": "Is this a risky request that should be blocked?"
      }
    ]
  }'`
    let curlCli = chaiExec(curlCommand);
    expect(curlCli).to.exit.with.code(0);
    expect(curlCli).output.to.include("request blocked");
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/ai-gateway/ai-guardrail-webhook/tests/check-ai-guardrail-webhook.test.js.liquid from lab number 10"
timeout --signal=INT 2m mocha ./test.js --timeout 10000 --retries=30 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
kubectl --context $CLUSTER1 delete routeoptions openai-opt -n gloo-system
