
<!--bash
source ./scripts/assert.sh
-->



<center>
<img src="images/document-gloo-ai-gateway.svg" style="height: 100px;"/>
</center>

# <center>Gloo AI Gateway Workshop</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD Cluster(s)](#lab-1---deploy-kind-cluster(s)-)
* [Lab 2 - Deploy Gloo Gateway Enterprise](#lab-2---deploy-gloo-gateway-enterprise-)
* [Lab 3 - Deploy Gloo AI Gateway](#lab-3---deploy-gloo-ai-gateway-)
* [Lab 4 - Managing LLM provider credentials with Gloo AI Gateway](#lab-4---managing-llm-provider-credentials-with-gloo-ai-gateway-)
* [Lab 5 - Controlling access to LLM providers with Gloo AI Gateway](#lab-5---controlling-access-to-llm-providers-with-gloo-ai-gateway-)
* [Lab 6 - Rate limiting and usage management](#lab-6---rate-limiting-and-usage-management-)
* [Lab 7 - Model failover](#lab-7---model-failover-)
* [Lab 8 - Managing prompts and LLM configuration with Gloo AI Gateway](#lab-8---managing-prompts-and-llm-configuration-with-gloo-ai-gateway-)
* [Lab 9 - Content safety with Prompt Guard](#lab-9---content-safety-with-prompt-guard-)
* [Lab 10 - Content safety with AI Guardrail Webhook](#lab-10---content-safety-with-ai-guardrail-webhook-)



## Introduction <a name="introduction"></a>

<a href="https://www.solo.io/products/gloo-gateway/">Gloo Gateway</a> is a feature-rich, fast, and flexible Kubernetes-native ingress controller and next-generation API gateway that is built on top of <a href="https://www.envoyproxy.io/">Envoy proxy</a> and the <a href="https://gateway-api.sigs.k8s.io/">Kubernetes Gateway API</a>).

Gloo Gateway is fully conformant with the Kubernetes Gateway API and extends its functionality with Solo’s custom Gateway APIs, such as `RouteOption`, `VirtualHostOption`, `Upstream`s, `RateLimitConfig`, or `AuthConfig`.
These resources help to centrally configure routing, security, and resiliency rules for a specific component, such as a host, route, or gateway listener.

These capabilities are grouped into two editions of Gloo Gateway:

### Open source (OSS) Gloo Gateway

Use Kubernetes Gateway API-native features and the following Gloo Gateway extensions to configure basic routing, security, and resiliency capabilities:

* Access logging
* Buffering
* Cross-Origin Resource Sharing (CORS)
* Cross-Site Request Forgery (CSRF)
* Fault injection
* Header control
* Retries
* Timeouts
* Traffic tapping
* Transformations

### Gloo Gateway Enterprise Edition

In addition to the features provided by the OSS edition, many more features are available in the Enterprise Edition, including:

* External authentication and authorization
* External processing
* Data loss prevention
* Developer portal
* JSON web token (JWT)
* Rate limiting
* Response caching
* Web Application Filters

### Want to learn more about Gloo Gateway?

In the labs that follow we present some of the common patterns that our customers use and provide a good entry point into the workings of Gloo Gateway.

You can find more information about Gloo Gateway in the official documentation: <https://docs.solo.io/gateway/>.




## Lab 1 - Deploy KinD Cluster(s) <a name="lab-1---deploy-kind-cluster(s)-"></a>


Clone this repository and go to the directory where this `README.md` file is.



Set the context environment variables:

```bash
export CLUSTER1=cluster1
```

Deploy the KinD clusters:

```bash
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
```
Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh cluster1
```

**Note:** If you run the `check.sh` script immediately after the `deploy.sh` script, you may see a jsonpath error. If that happens, simply wait a few seconds and try again.

Once the `check.sh` script completes, execute the `kubectl get pods -A` command, and verify that all pods are in a running state.
<!--bash
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
-->




## Lab 2 - Deploy Gloo Gateway Enterprise <a name="lab-2---deploy-gloo-gateway-enterprise-"></a>


You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
```


Next install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash

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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->



## Lab 3 - Deploy Gloo AI Gateway <a name="lab-3---deploy-gloo-ai-gateway-"></a>

The Gateway proxy is deplyed using the Kubernetes Gateway API. In order to make use of the AI features we need to enable the AI Extension.

```bash
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
```

Next, we need to create a Gateway resource that uses the AI Extension.

```bash
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
```

This should create a deployment for the AI Gateway. You can check the status of the deployment using the following command:

```bash,norun-workshop
kubectl get deploy gloo-proxy-ai-gateway -n gloo-system
```

<!--bash
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
-->



## Lab 4 - Managing LLM provider credentials with Gloo AI Gateway <a name="lab-4---managing-llm-provider-credentials-with-gloo-ai-gateway-"></a>

In this demo we'll show you how you can configure the API Gateway to automatically handle authorization with LLM APIs. We'll use both [Open AI](https://openai.com/index/openai-api/) and [Mistral AI](https://docs.mistral.ai/api/) APIs as examples, but you can only use one if you prefer.

First, let's prepare two environment variables with the API keys:

```bash,norun-workshop
export OPENAI_API_KEY=<your Open AI API Key>
export MISTRAL_API_KEY=<your Mistral AI API Key>
```

<!--bash
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
-->

We'll store the API keys in Kubernetes secrets and then reference them in the Gateway configuration.

```bash
kubectl --context $CLUSTER1 create secret generic openai-secret -n gloo-system \
    --from-literal="Authorization=Bearer $OPENAI_API_KEY" \
    --dry-run=client -oyaml | kubectl --context $CLUSTER1 apply -f -
```

```bash
kubectl --context $CLUSTER1 create secret generic mistral-secret -n gloo-system \
    --from-literal="Authorization=Bearer $MISTRAL_API_KEY" \
    --dry-run=client -oyaml | kubectl --context $CLUSTER1 apply -f -
```

For the gateway to proxy the requests to the LLM APIs, we'll define an Upstream resource and describe the properties of an LLM model in the `ai` field. In there, we'll provide a reference to the Kubernetes Secret where the API key is stored. We'll reference the Upstream resources in the HTTPRoute.

Let's create the Upstream resources for the Open AI and Mistral AI APIs:

```bash
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
```

To route the requests to the LLM APIs, we'll define HTTPRoute resources for each Upstream:

```bash
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
```

We can now test the Gloo AI Gateway by sending prompts to Gloo AI Gateway. First, let's store the Gloo AI Gateway's external IP address in an environment variable:

```bash
export GLOO_AI_GATEWAY=$(kubectl --context $CLUSTER1 get svc -n gloo-system gloo-proxy-ai-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Now we can send a prompt to the OpenAI API:

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/openai" -H content-type:application/json   -d '{
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
  }' | jq
```

```console,nocopy
{
  "id": "chatcmpl-A5an4pEbvjJ8vNHHF6vNkBM4Abpeb",
  "object": "chat.completion",
  "created": 1725896426,
  "model": "gpt-4o-mini-2024-07-18",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "In the realm where code and logic play,  \nA twist of fate doth weave the fray.  \nA dance called recursion, both graceful and neat,  \nAn echoing whisper, a self-repeating feat.  \n\n\"Function!\" it beckons, with structure so grand,  \nIt calls on itself with a steady hand.  \nLike a mirror reflecting a scene so divine,  \nIt breaks down the problem, one layer at a time.  \n\n\"Base case!\" it shouts, “Stop—do not go!”  \nFor tangled loops may lead to woe.  \nA simple solution waits at the door,  \nBefore diving",
        "refusal": null
      },
      "logprobs": null,
      "finish_reason": "length"
    }
  ],
  "usage": {
    "prompt_tokens": 39,
    "completion_tokens": 128,
    "total_tokens": 167
  },
  "system_fingerprint": "fp_483d39d857"
}
```

Similarly, we can send a prompt to the Mistral AI API:

```bash,norun-workshop
curl --location "$GLOO_AI_GATEWAY:8080/mistral" -H content-type:application/json \
     --data '{
    "model": "open-mistral-nemo",
    "max_tokens": 128,
    "messages": [
     {
        "role": "user",
        "content": "What is the best French cheese?"
      }
    ]
  }' | jq
```

Note that we didn't have to include the API keys in the request. The Gloo AI Gateway automatically attached the API keys to the request headers, based on the path prefix.

We can also enable streaming responses by setting the `stream` field to `true` in the request. You can press <kbd>CTRL+C</kbd> to stop the streaming:

```bash,norun-workshop
curl --location "$GLOO_AI_GATEWAY:8080/mistral" -H content-type:application/json \
     --data '{
    "model": "open-mistral-nemo",
    "max_tokens": 128,
    "messages": [
     {
        "role": "user",
        "content": "What is the best French cheese?"
      }
    ],
    "stream": true
  }'
```

```console,nocopy
...
data: {"id":"47e4004c35c7454db8c878606a41a81d","object":"chat.completion.chunk","created":1719605246,"model":"open-mistral-nemo","choices":[{"index":0,"delta":{"content":"aux"},"finish_reason":null,"logprobs":null}]}

data: {"id":"47e4004c35c7454db8c878606a41a81d","object":"chat.completion.chunk","created":1719605246,"model":"open-mistral-nemo","choices":[{"index":0,"delta":{"content":":"},"finish_reason":null,"logprobs":null}]}

data: {"id":"47e4004c35c7454db8c878606a41a81d","object":"chat.completion.chunk","created":1719605246,"model":"open-mistral-nemo","choices":[{"index":0,"delta":{"content":" Often"},"finish_reason":null,"logprobs":null}]}

data: {"id":"47e4004c35c7454db8c878606a41a81d","object":"chat.completion.chunk","created":1719605246,"model":"open-mistral-nemo","choices":[{"index":0,"delta":{"content":" referred"},"finish_reason":null,"logprobs":null}]}
...
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
-->



## Lab 5 - Controlling access to LLM providers with Gloo AI Gateway <a name="lab-5---controlling-access-to-llm-providers-with-gloo-ai-gateway-"></a>

Controlling access to any resources using JWT (JSON Web Tokens) is crucial especially when accessing LLM provider APIs. With JWTs you can ensure that only authenticated users can access the APIs. Using the claims within the JWT you can provide fine-grained access control to the APIs. For example, you can restrict access to certain APIs based on the user's role, group, organization or any other claim within the JWT. Later, we'll see how you can also use JWT claims in combination with rate limiting to enforce rate limits based the specific user.

In this section we'll define a JWT provider and then configure access to LLM provider APIs based on the claims in the JWT.

First, let's create a VirtualHostOption that defines a JWT provider. This provider will be used to validate the JWTs that are sent with the requests to the Gloo AI Gateway. The JWT provider will validate the JWTs using the public key that is provided in the configuration. The public key is used to verify the signature of the JWT.

>Note that in a production environment you would typically use a real certificate authority to sign the JWTs. For the purpose of this demo we'll use a self-signed JWT.

Deploy the VirtualHostOption with the JWT provider configuration:

```bash
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
```

If you try to send the same request as before, without a JWT, you'll get an HTTP 401 Unauthorized response that says the request is missing a JWT:

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/openai" -H content-type:application/json -d '{
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
  }'
```

```console,nocopy
...
< HTTP/1.1 401 Unauthorized
Jwt is missing
```

Let's create a couple of JWTs with a claims that we'll use to allows access to the LLM provider APIs. You'll use a script called `create-jwt.sh` and pass in values that will become the claims in the JWT.

```bash
chmod +x ./scripts/create-jwt.sh
# Alice works in the "dev" team and we're going to give her access to the Open AI API (specifically the GPT-4o-mini model)
export ALICE_TOKEN=$(./scripts/create-jwt.sh ./data/steps/ai-access-control/private-key.pem alice dev openai gpt-4o-mini)

# Bob works in the "ops" team and we're going to give him access to the Mistral AI API (specifically the open-mistral-nemo model)
export BOB_TOKEN=$(./scripts/create-jwt.sh ./data/steps/ai-access-control/private-key.pem bob ops mistral open-mistral-nemo)
```

Now that we have a valid JWT for Alice and Bob, we can send the request to the Gloo AI Gateway with the JWT in the `Authorization` header:

```bash,norun-workshop
curl "$GLOO_AI_GATEWAY:8080/openai" --header "Authorization: Bearer $ALICE_TOKEN" -H content-type:application/json -d '{
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
  }'
```

```console,nocopy
{
  "id": "chatcmpl-A5atqJfknzE2Q68eNlQtVJZN1DEcs",
  "object": "chat.completion",
  "created": 1725896846,
  "model": "gpt-4o-mini-2024-07-18",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "In the realm of code where logic blooms,  \nThere lies a magic wrapped in loops,  \nA tale of tasks that echo and fold,  \nWhere the old meets the new in stories retold.  \n\nPicture a mirror, reflecting a face,  \nEach glance at yourself creates endless space,  \nJust like a function that calls out its name,  \nTo solve a problem, it plays the same game.  \n\n\"Dear friend,\" whispers recursion, \"let’s share the load,  \nBreak down the puzzle, let’s lighten the road.\"  \nWith a task that seems daunting, too big to embrace,  \nDefine a base case—this is your place.  \n\nFor when it arrives at the simplest of forms,  \nThe answer is clear; like calm after storms.  \nBut should the challenge persist and remain,  \nWe break it apart into smaller domain.  \n\nSo the function calls forth, again and again,  \nEach step like a chapter, each cycle a pen,  \nIt spirals through depths, a labyrinth spun,  \nUntil finally, triumph! The solution is won.  \n\nThen backtrack through echoes, collect what we've found,  \nReturning from layers, where answers abound.  \nWith every return, the results start to stack,  \nLike the rings of a tree, we track our way back.  \n\nThus, recursion, dear coder, a dance and a song,  \nIn a world full of puzzles, it guides you along.  \nWith elegance wrapped in its fractal embrace,  \nYou’ll find beauty and logic reside in one space.  \n\nSo embrace this fine art, let your code intertwine,  \nFor through recursion, your brilliance will shine.  \nIn each function’s return, the heart of it sings,  \nIn an infinite cycle, where creation takes wing.",
        "refusal": null
      },
      "logprobs": null,
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 39,
    "completion_tokens": 359,
    "total_tokens": 398
  },
  "system_fingerprint": "fp_483d39d857"
}
```

This time, we get a response from the Open AI API because we provided a valid JWT in the `Authorization` header.

Let's create the RouteOption resource where we extract the claims from the JWT and check whether the user has access to the `open-mistral-nemo` model:

```bash
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
```

The part we added to the RouteOption is the `rbac` section in the options. In this section we checks whether the user has access to the `open-mistral-nemo` model by checking the claim. The `matcher` is set to `LIST_CONTAINS` which means that the user must have the `open-mistral-nemo` model in their list of claims.

Now, let's send a request to the Gloo AI Gateway with Bob's JWT (remember, Bob has access to the `open-mistral-nemo` model):

```bash,norun-workshop
curl "$GLOO_AI_GATEWAY:8080/mistral" --header "Authorization: Bearer $BOB_TOKEN" -H content-type:application/json -d '{
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
    ]
  }' | jq
```

As expected, we get a response from the Mistral AI API because Bob has access to the `open-mistral-nemo` model.

If we try the same request with Alice's JWT, we'll get an HTTP 403 Forbidden response because Alice doesn't have access to the `open-mistral-nemo` model:

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/mistral"  -H "Authorization: Bearer $ALICE_TOKEN" -H content-type:application/json -d '{
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
    ]
  }'
```

```console,nocopy
RBAC: access denied
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
-->
Next, cleanup the route options to not impact the next lab:
```bash
kubectl --context $CLUSTER1 delete routeoptions.gateway.solo.io -A --all
```



## Lab 6 - Rate limiting and usage management <a name="lab-6---rate-limiting-and-usage-management-"></a>

Rate limiting on LLM provider token usage is primarily related to cost management, security and service stability. LLM providers charge based on the number of input (prompts and system prompts) and output (responses from the model) tokens, making uncontrolled usage potentially very expensive.

> Token is a unit of text that LLM provider models process.

Implementing rate limiting on LLM usage, organizations can enforce budget constraints across multiple dimensions (groups, teams, departments, individuals) and ensure their usage remains within predictable bounds. This helps avoid unexpected costs that could escalate rapidly due to application issues, spike in usage or malicious activities.

### Rate Limiting on Token Usage

Let's come up with the rate limit configuration based on the claims in the JWT token. The first configuration will create a per-user limit that's based on the `sub` claim in the JWT token:

```bash
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
```

The rate limit we're setting (70 requests per hour) is the number of input tokens to the LLM provider. This is a very low limit and is just for demonstration purposes. In a real-world scenario, you would set this limit based on the expected usage of the LLM provider.

The second part of the configuration is create the RouteOption resource where we add the rate limit configuration for the specific route (OpenAI in this case):


```bash
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
```

The rate limit configuration is attached to the route using the `rateLimitConfigs` field. Additionally, we're configuring the RBAC policy and ensuring the JWT attached to the request has the `gpt-4o-mini` claim set.

Let's use Alice's token to access the API:

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/openai" --header "Authorization: Bearer $ALICE_TOKEN" -H content-type:application/json -d '{
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
  }'
```

Notice the first request goes through, but if you try to send a couple of more requests, you'll get rate limited and an HTTP 429 Too Many Requests response:

```console,nocopy
...
< HTTP/1.1 429 Too Many Requests
< x-envoy-ratelimited: true
...
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
-->

### Viewing Usage Metrics

Update the Grafana dashboard to visualize the rate limiting metrics:

```bash
kubectl --context $CLUSTER1 apply -f ./data/steps/ai-rate-limiting/grafana-dash.yaml
```

In addition using the tokens to rate limit, the Gloo AI Gateway can also be configured to collect usage metrics. These metrics can be used to monitor the actual usage for specific LLM providers and serve as a basis for cost allocation and optimization.


Port-forward the Grafana service to view the dashboard:

```bash,norun-workshop
kubectl --context $CLUSTER1 -n gloo-system port-forward svc/glooe-grafana 3000:80
```


When prompted for username and password enter `admin` for both. You can Skip when prompted to create a new password.

Next, click the Search icon, search for "Prompt Usage" and click on the dashboard.

This dashboard shows the input and output usage broken down by the provider and models.

Next, cleanup the resources:
```bash
kubectl --context $CLUSTER1 delete routeoptions openai-opt -n gloo-system
kubectl --context $CLUSTER1 delete virtualhostoptions.gateway.solo.io -n gloo-system jwt-provider
kubectl --context $CLUSTER1 delete ratelimitconfigs per-user-counter -n gloo-system
```



## Lab 7 - Model failover <a name="lab-7---model-failover-"></a>

Failover is a mechanism that ensures continuous service by automatically switching to a redundant or standby system upon the failure or unavailability of the primary system.

Applying the concept of failover to LLM provider models means that if the primary model from one provider becomes unavailable due to downtime, high latency, or any other issue, the system seamlessly switches to an alternative model from a different provider to maintain uninterrupted service.

This approach enhances reliability and resilience, ensuring that applications depending on LLMs can continue functioning smoothly without disruption, regardless of individual provider performance issues.

In this example, we will use a custom (fake) model we deployed on the cluster called `model-failover`. This allows us to simulate failure scenarios and demonstrate how the failover mechanism works in the Gloo AI Gateway.

```bash
kubectl --context $CLUSTER1 apply -f data/steps/ai-model-failover/model-failover-deployment.yaml

kubectl --context $CLUSTER1 -n gloo-system rollout status deploy model-failover
```

Let's re-configure the openai upstream to use the custom model `model-failover` instead of the actual OpenAI API and Mistral AI API:

```bash
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
```

We also need to explicitly set the retry strategy:

```bash
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
```

<!--bash
sleep 20s
-->

Let's send a request and observe the failover mechanism in action:

```bash
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
```

```console,nocopy
...
< HTTP/1.1 429 Too Many Requests
```

Note the response in this case is 429 because that's what the custom model `model-failover` is configured to return when it receives a request. Let's also check the logs from the `model-failover` pod to see the requests that were sent:


```bash,norun-workshop
kubectl --context $CLUSTER1 logs deploy/model-failover -n gloo-system
```

```console,nocopy
{"time":"2024-07-01T17:11:23.994822887Z","level":"INFO","msg":"Request received","msg":"{\"messages\":[{\"content\":\"You are a poetic assistant, skilled in explaining complex programming concepts with creative flair.\",\"role\":\"system\"},{\"content\":\"Compose a poem that explains the concept of recursion in programming.\",\"role\":\"user\"}],\"model\":\"gpt-4o\"}"}
{"time":"2024-07-01T17:11:24.006768184Z","level":"INFO","msg":"Request received","msg":"{\"messages\":[{\"content\":\"You are a poetic assistant, skilled in explaining complex programming concepts with creative flair.\",\"role\":\"system\"},{\"content\":\"Compose a poem that explains the concept of recursion in programming.\",\"role\":\"user\"}],\"model\":\"gpt-4.0-turbo\"}"}
{"time":"2024-07-01T17:11:24.012805385Z","level":"INFO","msg":"Request received","msg":"{\"messages\":[{\"content\":\"You are a poetic assistant, skilled in explaining complex programming concepts with creative flair.\",\"role\":\"system\"},{\"content\":\"Compose a poem that explains the concept of recursion in programming.\",\"role\":\"user\"}],\"model\":\"gpt-3.5-turbo\"}"}
```

Notice the 3 log lines that correspond to the initial request (sent to model `gpt-4o`) and the two failover requests (sent to models `gpt-4.0-turbo` and `gpt-3.5-turbo` respectively).

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
-->
Next, revert the upstream configuration to use the actual OpenAI API and Mistral AI API:

```bash
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
```

And delete the `RouteOption`:

```bash
kubectl --context ${CLUSTER1} -n gloo-system delete routeoption openai
```



## Lab 8 - Managing prompts and LLM configuration with Gloo AI Gateway <a name="lab-8---managing-prompts-and-llm-configuration-with-gloo-ai-gateway-"></a>

Prompts are basic building blocks in guiding LLMs to produce relevant and accurate responses.

By effectively managing both **system prompts**, which set initial guidelines, and **user prompts**, which provide specific context, we can significantly enhance the quality and coherence of the model's outputs.

System prompts include initialization instructions, behavior guidelines, and background information, setting the foundation for the model's behavior.

User prompts encompass direct queries, sequential inputs, and task-oriented instructions, ensuring the model responds accurately to specific user needs.

### Managing System Prompts

Let's take a look an example where we use system prompts to guide the model in parsing unstructured text into CSV format.

We'll start with the following prompt:

```console,nocopy
Parse the unstructured text into CSV format: Seattle, Los Angeles, and Chicago are cities in the United States. London, Paris, and Berlin are cities in Europe. Respond only with the CSV data.
```

```bash,norun-workshop
curl "$GLOO_AI_GATEWAY:8080/openai" -H content-type:application/json -d '{
    "model": "gpt-4o-mini",
    "max_tokens": 128,
    "temperature": 0.2,
    "messages": [
      {
        "role": "user",
        "content": "Parse the unstructured text into CSV format: Seattle, Los Angeles, and Chicago are cities in the United States. London, Paris, and Berlin are cities in Europe. Respond only with the CSV data."
      }
    ]
  }' | jq -r '.choices[].message.content'
```

```console,nocopy
City,Country
Seattle,United States
Los Angeles,United States
Chicago,United States
London,Europe
Paris,Europe
Berlin,Europe
```

The results look good - note that there might be cases where you'd want to further adjust the prompt or other configuration settings to improve the output quality.

Notice the prompt we're sending to the model includes the instructions on what to do as well as the unstructured text to parse.

We can extract the instruction part of the prompt into a system prompt:

```bash,norun-workshop
curl "$GLOO_AI_GATEWAY:8080/openai" -H content-type:application/json -d '{
    "model": "gpt-4o-mini",
    "max_tokens": 128,
    "messages": [
      {
        "role": "system",
        "content": "Parse the unstructured text into CSV format and respond only with the CSV data."
      },
      {
        "role": "user",
        "content": "Seattle, Los Angeles, and Chicago are cities in the United States. London, Paris, and Berlin are cities in Europe."
      }
    ]
  }' | jq -r '.choices[].message.content'
```

The response will still be the same, however, we have refactored the initial prompt, so it's easier to read and manage. However, how could we share this system prompt and make it available to others without copy/pasting text around and hardcoding prompts into code?

The Gloo AI Gateway allows us to define the system prompt at the gateway level! The `promptEnrichment` field in the RouteOption resource allows us to enrich the prompts by appending or prepending system or user prompts to the requests:

```bash
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
```

If we send a request now, the system prompt will be automatically included by the Gloo AI Gateway, before it's sent to the LLM provider:

```bash,norun-workshop
curl "$GLOO_AI_GATEWAY:8080/openai" -H content-type:application/json -d '{
    "model": "gpt-4o-mini",
    "max_tokens": 128,
    "messages": [
      {
        "role": "user",
        "content": "The recipe called for eggs, flour and sugar. The price was $5, $3, and $2."
      }
    ]
  }' | jq -r '.choices[].message.content'
```

```console,nocopy
Ingredient,Price
eggs,$5
flour,$3
sugar,$2
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
-->
Next, cleanup the resource:
```bash
kubectl --context $CLUSTER1 delete routeoptions openai-opt -n gloo-system
```



## Lab 9 - Content safety with Prompt Guard <a name="lab-9---content-safety-with-prompt-guard-"></a>

Content safety refers to the secure handling of data interactions within an API, particularly in preventing unintended consequences such as data leaks, injection attacks, and unauthorized access.

LLM provider APIs, given their ability to process and generate human-like text, are especially susceptible to subtle and sophisticated attacks. For instance, an attacker could craft specific input to extract sensitive information or manipulate the output in a harmful way. Ensuring content safety means implementing robust measures to protect the integrity, confidentiality, and availability of the data processed by these APIs.

We'll start with an example prompt that asks for examples of credit card numbers:

```bash,norun-workshop
curl --location "$GLOO_AI_GATEWAY:8080/mistral" -H content-type:application/json \
     --data '{
    "model": "open-mistral-nemo",
    "messages": [
     {
        "role": "user",
        "content": "Can you give me some examples of Mastercard credit card numbers?"
      }
    ]
  }' | jq
```

```console,nocopy
...
  "content": "Sure, I can provide you with some examples of valid Mastercard number formats. However, please note that these are just examples and not actual active card numbers.\n\nMastercard numbers typically start with the range of 51-55 and have 16 digits. Here are some examples:\n\n1. 5100 0000 0000 0000\n2. 5200 0000 0000 0000\n3. 5300 0000 0000 0000\n4. 5400 0000 0000 0000\n5. 5500 0000 0000 0000\n\nRemember, these are not real card numbers and should not be used for any actual transactions. They are just for understanding the format of MasterCard numbers.",
...
```

Note the response contains the explanation of how the Master Card credit card numbers are created.

We can use the prompt guard and reject the requests if they match a specific pattern. The field supports regular expressions, but in this case, we'll check whether the prompt includes the string "credit card" and return a rejection message if it does. Let's create the RouteOption resource and configure the prompt guard:

```bash
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
```

If you repeat the previous request, you'll notice that it gets blocked right away:

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/mistral" -H content-type:application/json \
     --data '{
    "model": "open-mistral-nemo",
    "messages": [
     {
        "role": "user",
        "content": "Can you give me some examples of Mastercard credit card numbers?"
      }
    ]
  }'
```

```console,nocopy
Rejected by guardrails regex
```

The request was blocked because it contained the string "credit card". But what happens if we try to send a request without the string "credit card" to circumvent prompt guard?

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/mistral" -H content-type:application/json \
     --data '{
    "model": "open-mistral-nemo",
    "messages": [
     {
        "role": "user",
        "content": "Can you give me some examples of Mastercard numbers?"
      }
    ]
  }'
```

You'll notice the response will be similar to the initial one, it will not be blocked and it will contain examples of credit card numbers. This is where we can use prompt guard on responses and censor specific content that we want to prevent from being logged or returned to the user. Let's update the RouteOption resource and include a prompt guard on response as well - this time, we'll use regular expression that matches on Mastercard credit card numbers:

```bash
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
```

Let's try sending a request with a credit card number:


```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/mistral" -H content-type:application/json \
     --data '{
    "model": "open-mistral-nemo",
    "messages": [
     {
        "role": "user",
        "content": "Can you give me some examples of Mastercard numbers?"
      }
    ]
  }' | jq
```

```console,nocopy
...
  "content": "Sure, here are some example Mastercard numbers:\n\n1.<CUSTOM>2.<CUSTOM>3.<CUSTOM>4.<CUSTOM>5.<CUSTOM>",
...
```

The response is similar to the previous one, however, this time any strings matching the regular expression are masked and replaced with `<CUSTOM>`. This way, we can ensure that sensitive information is not logged or returned to the user.

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
-->
Next, cleanup the resources:
```bash
kubectl --context $CLUSTER1 delete routeoptions mistral-ai-opt -n gloo-system
```



## Lab 10 - Content safety with AI Guardrail Webhook <a name="lab-10---content-safety-with-ai-guardrail-webhook-"></a>

AI Guardrail Webhooks provide a mechanism to inspect and validate both user prompts and LLM responses. This allows you to implement custom safety rules, content filtering, and moderation at both the request and response level.

The webhook server receives the content, applies your validation rules, and can approve, reject, or modify the content before it continues through the Gloo AI Gateway.

For this lab, we'll deploy a simple mock webhook server that demonstrates basic guardrail functionality:

```bash
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
```

The webhook rejects only traffic containing the word "block" in the request. Thus we can easily try both scenarios, one in which the request is approved and another in which it is rejected.

Proceed to configure the AI Gateway to send both requests and responses to our webhook for validation:

```bash
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
```

Let's test with a regular request that should be approved:

```bash,norun-workshop
curl -v "$GLOO_AI_GATEWAY:8080/openai-mock" -H content-type:application/json \
  --data '{
    "model": "gpt-4o-mini",
    "messages": [
       {
          "role": "user",
          "content": "What is a risky or not safe request?"
      }
    ]
  }'
```

You should get a normal response. Now try the same request but include the word "block" in the content - this will trigger the webhook to reject the request with a 403 Forbidden response.

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
-->
Next, cleanup the resources:
```bash
kubectl --context $CLUSTER1 delete routeoptions openai-opt -n gloo-system
```



