
<!--bash
source ./scripts/assert.sh
-->



Kgateway is a feature-rich, fast, and flexible Kubernetes-native ingress controller and next-generation API gateway that is built on top of Envoy proxy and the Kubernetes Gateway API. An API Gateway is a reverse proxy that serves as a security barrier between your clients and the microservices that make up your app. In order to access a microservice, all clients must send a request to the API Gateway. The API Gateway then verifies and routes the request to the microservice.

Kgateway is fully conformant with the Kubernetes Gateway API and extends its functionality with custom Gateway APIs, such as RouteOption, VirtualHostOption, or Backends. These resources help to centrally configure advanced traffic management, security, and resiliency rules for a specific component, such as a host, route, or gateway listener.




## Introduction <a name="introduction"></a>

Kgateway is a feature-rich, fast, and flexible Kubernetes-native ingress controller and next-generation API gateway that is built on top of Envoy proxy and the Kubernetes Gateway API. An API Gateway is a reverse proxy that serves as a security barrier between your clients and the microservices that make up your app. In order to access a microservice, all clients must send a request to the API Gateway. The API Gateway then verifies and routes the request to the microservice.

Kgateway is fully conformant with the Kubernetes Gateway API and extends its functionality with custom Gateway APIs, such as RouteOption, VirtualHostOption, or Backends. These resources help to centrally configure advanced traffic management, security, and resiliency rules for a specific component, such as a host, route, or gateway listener.




##  1 - Deploy KinD Cluster(s) <a name="-1---deploy-kind-cluster(s)-"></a>


Clone this repository and go to the directory where this `README.md` file is.



Set the context environment variables:

```bash
export MGMT=cluster1
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
  You can see that your currently connected to this cluster by executing the `kubectl config get-contexts` command:

```
CURRENT   NAME         CLUSTER         AUTHINFO   NAMESPACE
          cluster1     kind-cluster1   cluster1
*         cluster2     kind-cluster2   cluster2
          mgmt         kind-mgmt       kind-mgmt
```

Run the following command to make `mgmt` the current cluster.

```bash
kubectl config use-context ${MGMT}
```
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
echo "executing test dist/kgateway-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 1"; exit 1; }
-->




##  2 - Install kgateway <a name="-2---install-kgateway-"></a>

In this lab, you will:

- Apply the Kubernetes Gateway API Custom Resource Definitions (CRDs)
- Install kgateway, a conformant implementation of the Kubernetes Gateway API
- Review the GatewayClass resource

Apply the Kubernetes Gateway API CRDs
=====================================

```bash
kubectl apply --kustomize "https://github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v1.2.1"
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gateway API CRDs", () => {
  it('Gateways are created', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "default", k8sType: "crd", k8sObj: "gateways.gateway.networking.k8s.io" }));
  it('Httproutes are created', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "default", k8sType: "crd", k8sObj: "httproutes.gateway.networking.k8s.io" }));
  it('Referencegrants are created', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "default", k8sType: "crd", k8sObj: "referencegrants.gateway.networking.k8s.io" }));
  it('Gatewayclasses are created', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "default", k8sType: "crd", k8sObj: "gatewayclasses.gateway.networking.k8s.io" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/install/tests/check-gatewayapi.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->

Review the Gateway API CRDs:

```bash,noexecute
kubectl api-resources --api-group=gateway.networking.k8s.io
```

Install kgateway
================

```bash
helm upgrade --install --create-namespace --namespace kgateway-system  \
  --version v2.0.0-rc.1 kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds
helm upgrade --install --create-namespace --namespace kgateway-system \
  --version v2.0.0-rc.1 kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway
```

Review the pods running in the `kgateway-system` namespaced:

```bash,noexecute
kubectl get pod -n kgateway-system
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("kgateway", () => {
  let cluster = process.env.CLUSTER1;
    it('kgateway pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "kgateway-system", k8sObj: "kgateway" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/install/tests/check-kgateway.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->

Review the GatewayClass resource
================================

```bash,noexecute
kubectl get gatewayclass kgateway -o yaml | bat -l yaml
```

```yaml,nocopy
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kgateway
  ...
spec:
  controllerName: kgateway.io/kgateway
  description: KGateway Controller
  parametersRef:
    group: gateway.kgateway.dev
    kind: GatewayParameters
    name: kgateway
    namespace: kgateway-system
status:
  conditions:
  - lastTransitionTime: "2025-02-11T22:43:33Z"
    message: ""
    observedGeneration: 1
    reason: Accepted
    status: "True"
    type: Accepted
  - lastTransitionTime: "2025-02-11T22:43:33Z"
    message: ""
    observedGeneration: 1
    reason: SupportedVersion
    status: "True"
    type: SupportedVersion
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("kateway GatewayClass", () => {
  it('kgateway GatewayClass is created', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "kgateway-system", k8sType: "gatewayclass", k8sObj: "kgateway" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/install/tests/check-gatewayclass.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->

Summary
=======

Installing kgateway is part of the responsibility of the infrastructure provider.

The installation deploys a controller, responsible for provisioning and programming gateways according to the resources specified by platform operators and development teams.

The controller is associated with a GatewayClass resource, which represents that particular implementation.

Next, we look at how to provision and program a gateway.




##  3 - Expose a service over HTTP <a name="-3---expose-a-service-over-http-"></a>

This lab walks you through the basics of the Kubernetes Gateway API.

You will:

- Provision a gateway
- Configure a routing rule to a backend workload, and
- Verify that requests are routed as expected.

Deploy `httpbin`
================

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/httpbin/httpbin.yaml
```

Wait for the `httpbin` pod to be ready:

```bash
kubectl wait --for=condition=Ready=True pod -l app=httpbin
```

Create a gateway
================

The team in charge of the gateway can create a Gateway resource and configure an HTTP listener.

Inspect the gateway resource:

```bash,noexecute
bat data/steps/kgateway-labs/basics/gtw.yaml
```

Apply the Gateway resource:

```bash
kubectl apply -f data/steps/kgateway-labs/basics/gtw.yaml
```

Wait for the Gateway to be programmed (ready).

```bash
kubectl wait --for=condition=Programmed=True gtw/my-gateway
```

Inspect the `status` section of the Gateway resource you just created:

```bash,noexecute
kubectl get gtw my-gateway -o yaml | bat -l yaml
```

Inspect the deployed gateway artifacts:

```bash,noexecute
kubectl get deploy,svc,pod
```

The deployment and service names match the name of the Gateway resource.


Application teams can create and attach their HTTPRoute to this gateway.

Configure routing
=================

An application team can create an HTTPRoute resource to expose the `httpbin` app on the gateway.

Inspect the HTTPRoute resource:

```bash,noexecute
bat data/steps/kgateway-labs/basics/route.yaml
```

Above, we associate the route with the host name `httpbin.example.com`.

Apply the HTTPRoute resource:

```bash
kubectl apply -f data/steps/kgateway-labs/basics/route.yaml
```

Wait for the route to be attached to the gateway:

```bash
kubectl wait --for=jsonpath='{.status.listeners[0].attachedRoutes}'=1 gtw my-gateway
```

Inspect the status of the route and confirm that it has a condition "Accepted" set to "True":

```bash,noexecute
kubectl get httproute httpbin -o yaml | bat -l yaml
```

Test
====

Capture the gateway external IP address to the environment variable `GW_IP`:

```bash
export GW_IP=$(kubectl get gtw my-gateway -ojsonpath='{.status.addresses[0].value}')
```

Send a test request to `httpbin` through the gateway:

```bash,noexecute
curl http://httpbin.example.com/headers --resolve httpbin.example.com:80:$GW_IP
```

The response should resemble the following json output:

```json,nocopy
{
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Host": [
      "httpbin.example.com:8080"
    ],
    "User-Agent": [
      "curl/8.11.1"
    ],
    "X-Envoy-Expected-Rq-Timeout-Ms": [
      "15000"
    ],
    "X-Forwarded-Proto": [
      "http"
    ],
    "X-Request-Id": [
      "bf08be7d-ed2f-4c5c-889c-f5c745db320f"
    ]
  }
}
```

<!--bash
./scripts/register-domain.sh httpbin.example.com ${GW_IP}
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/basics/tests/http.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
-->

Summary
=======

The general steps for working with the Kubernetes Gateway API are:

- Creating gateways on-demand by applying the `Gateway` resource, and
- Attaching routes that direct traffic to designated backends.




##  4 - Configure HTTPS <a name="-4---configure-https-"></a>

The workload `httpbin` is exposed via an ingress gateway over HTTP.

In this lab, you will retrofit the configuration so that only calls over HTTPS are accepted, and where HTTP requests are automatically redirected to HTTPS.

Initial state
=============

We begin with a Gateway with only an HTTP listener and attached route.

Capture the gateway external IP address to the environment variable `GW_IP`:

```bash,noexecute
export GW_IP=$(kubectl get gtw my-gateway -ojsonpath='{.status.addresses[0].value}')
```

Verify that requests over HTTP succeed:

```bash,noexecute
curl -v http://httpbin.example.com/headers \
  --resolve httpbin.example.com:80:$GW_IP
```

Steps
=====

### Generate a certificate

```bash
step certificate create httpbin.example.com httpbin.crt httpbin.key \
  --profile self-signed --subtle --no-password --insecure --force
```

### Create the tls secret

```bash
kubectl create secret tls httpbin-cert \
  --cert=httpbin.crt --key=httpbin.key
```

### Configure the gateway for https

Add an https listener to the gateway, referencing the above secret:

```bash,noexecute
bat data/steps/kgateway-labs/https/gtw.yaml
```

```bash
kubectl apply -f data/steps/kgateway-labs/https/gtw.yaml
```

### Attach to the route to the https listener

```bash,noexecute
bat data/steps/kgateway-labs/https/route.yaml
```

```bash
kubectl apply -f data/steps/kgateway-labs/https/route.yaml
```

### Test it

Call one of the endpoints of `httpbin`, over https:

```bash,noexecute
curl -v --insecure https://httpbin.example.com/headers \
  --resolve httpbin.example.com:443:$GW_IP
```
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/https/tests/https.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
-->

Redirect http to https
======================

Since the route we created is bound to the https listener, a request over http should return a 404 "Not found".

Verify this:

```bash,noexecute
curl -v http://httpbin.example.com/headers \
  --resolve httpbin.example.com:80:$GW_IP
```

Review the following HTTPRoute configuration for the http listener, with a filter to redirect the request to https with a 301 response code:

```bash,noexecute
bat data/steps/kgateway-labs/https/redirect.yaml
```

Apply the route:

```bash
kubectl apply -f data/steps/kgateway-labs/https/redirect.yaml
```

### Test it

Verify that a request over HTTP now returns a 301 "Moved Permanently" response code:

```bash,noexecute
curl -v http://httpbin.example.com/headers \
  --resolve httpbin.example.com:80:$GW_IP
```

Repeat the curl request, this time specifying that you wish to follow redirects (the -L flag):

```bash,noexecute
curl -v -L --insecure http://httpbin.example.com/headers \
  --resolve httpbin.example.com:80:$GW_IP \
  --resolve httpbin.example.com:443:$GW_IP
```

Confirm that the call succeeds and returns a JSON response.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/https/tests/redirect-http-to-https.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
-->




##  5 - Shared gateways <a name="-5---shared-gateways-"></a>


In this lab, you will re-implement the previous scenario, for two applications:  `httpbin`, and `bookinfo`.
This time around, you will use a gateway owned and managed by a platform team, and shared by both applications: a shared gateway.

Setup
=====

The platform team decides they will manage a shared gateway in a namespace named `infra`:

```bash
kubectl create ns infra
```

We have two app teams, one managing `httpbin` and the other the `bookinfo` app, each in their respective namespaces:

```bash
kubectl create ns httpbin
kubectl apply -n httpbin -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/httpbin/httpbin.yaml
```

```bash
kubectl create ns bookinfo
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/bookinfo/platform/kube/bookinfo.yaml
```

Certificates
============

We wish to configure two applications, one associated with the hostname `httpbin.example.com` and the other with `bookinfo.example.com`.

Create a tls certificate for each hostname:

1. For `httpbin`:

    ```bash
    step certificate create httpbin.example.com httpbin.crt httpbin.key \
      --profile self-signed --subtle --no-password --insecure --force

    kubectl -n infra create secret tls httpbin-cert \
      --cert=httpbin.crt --key=httpbin.key
    ```

1. For `bookinfo`:

    ```bash
    step certificate create bookinfo.example.com bookinfo.crt bookinfo.key \
      --profile self-signed --subtle --no-password --insecure --force

    kubectl -n infra create secret tls bookinfo-cert \
      --cert=bookinfo.crt --key=bookinfo.key
    ```

We choose to place the tls secrets in the `infra` namespace, under the management of the platform team.

The shared gateway
==================

We configure three listeners, one for port 80, and one each for port 443 for each hostname, with its tls configuration.

```bash,noexecute
bat data/steps/shared-gw/gtw.yaml
```

```bash
kubectl -n infra apply -f data/steps/kgateway-labs/shared-gw/gtw.yaml
```

Routes
======

```bash,noexecute
bat data/steps/shared-gw/httpbin-route.yaml
```

Apply the route for `httpbin`:

```bash
kubectl -n httpbin apply -f data/steps/kgateway-labs/shared-gw/httpbin-route.yaml
```

Inspect the `status` section of the route:

```bash,noexecute
kubectl -n httpbin get httproute httpbin -o yaml | bat -l yaml
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Check that the httpbin route is marked as NotAllowedByListeners by the gateway", () => {
  const command = `kubectl -n httpbin get httproute httpbin -o jsonpath='{.status.parents[*].conditions[?(@.type=="Accepted")].reason}'`;
  it('Httproute "Accepted" status is NotAllowedByListeners', () => helpers.genericCommand({ command: command, responseContains: "NotAllowedByListeners" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/tests/check-httproute-status.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

Note that the condition "Accepted" is "False" with reason "NotAllowedByListeners":

```yaml,nocopy
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  ...
spec:
  ...
status:
  parents:
  - conditions:
    - lastTransitionTime: "2025-02-12T21:26:46Z"
      message: ""
      observedGeneration: 1
      reason: NotAllowedByListeners
      status: "False"
      type: Accepted
    - lastTransitionTime: "2025-02-12T20:47:28Z"
      message: ""
      observedGeneration: 1
      reason: ResolvedRefs
      status: "True"
      type: ResolvedRefs
    controllerName: kgateway.io/kgateway
    parentRef:
      group: gateway.networking.k8s.io
      kind: Gateway
      name: infra-gateway
      namespace: infra
      sectionName: httpbin-https
```

Configure the "allowed routes" permissions on the gateway:

```bash,noexecute
bat data/steps/shared-gw/gtw-with-allowed-routes.yaml
```

```bash
kubectl apply -n infra -f data/steps/kgateway-labs/shared-gw/gtw-with-allowed-routes.yaml
```

Label each namespace to allow both applications to define routes against the shared gateway:

```bash
kubectl label ns httpbin self-serve-ingress=true
kubectl label ns bookinfo self-serve-ingress=true
```

Check the status of the route once more:

```bash,noexecute
kubectl -n httpbin get httproute httpbin -o yaml | bat -l yaml
```

Confirm that the "Accepted" condition now has the status "True".
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Check that the httpbin route is marked as Accepted by the gateway", () => {
  const command = `kubectl -n httpbin get httproute httpbin -o jsonpath='{.status.parents[*].conditions[?(@.type=="Accepted")].reason}'`;
  it('Httproute "Accepted" status is Accepted', () => helpers.genericCommand({ command: command, responseContains: "Accepted" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/tests/check-httproute-status.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

Apply the route specification for `bookinfo`:

```bash
kubectl -n bookinfo apply -f data/steps/kgateway-labs/shared-gw/bookinfo-route.yaml
```

Check that both routes attached successfully:

```bash,noexecute
kubectl get gtw -n infra infra-gateway -o json | jq '.status.listeners[] | {name: .name, attachedRoutes: .attachedRoutes}'
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Check that the bookinfo route is marked as Accepted by the gateway", () => {
  const command = `kubectl -n bookinfo get httproute bookinfo -o jsonpath='{.status.parents[*].conditions[?(@.type=="Accepted")].reason}'`;
  it('Httproute "Accepted" status is Accepted', () => helpers.genericCommand({ command: command, responseContains: "Accepted" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/tests/check-httproute-status.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

Test the routes
===============

Capture the IP address associated with the shared gateway:

```bash,noexecute
export GW_IP=$(kubectl get gtw -n infra infra-gateway -ojsonpath='{.status.addresses[0].value}')
```

Call `httpbin`:

```bash,noexecute
curl --insecure https://httpbin.example.com/headers --resolve httpbin.example.com:443:$GW_IP
```

Call `bookinfo`:

```bash,noexecute
curl -s --insecure https://bookinfo.example.com/productpage --resolve bookinfo.example.com:443:$GW_IP | grep title
```
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/../https/tests/https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

Redirect HTTP
=============

Platform operators are the only ones with access to the `infra` namespace and control routes attached to the HTTP listener.

They configure HTTP redirect to HTTPS for all applications:

```bash,noexecute
bat data/steps/shared-gw/redirect.yaml
```

Apply the route:

```bash
kubectl -n infra apply -f data/steps/kgateway-labs/shared-gw/redirect.yaml
```

Verify that requests to each app over HTTP result in a 301 redirect:

Test a request to `httpbin` over HTTP:

```bash,noexecute
curl -v http://httpbin.example.com/headers --resolve httpbin.example.com:80:$GW_IP
```

```console,nocopy
> GET /headers HTTP/1.1
> Host: httpbin.example.com
> User-Agent: curl/8.12.0
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 301 Moved Permanently
< location: https://httpbin.example.com/headers
< ...
```

Test a request to `bookinfo` over HTTP:

```bash,noexecute
curl -v http://bookinfo.example.com/productpage --resolve bookinfo.example.com:80:$GW_IP
```

View all routes

```bash,noexecute
kubectl get httproute -A
```

```console,nocopy
NAMESPACE   NAME                    HOSTNAMES           AGE
bookinfo    bookinfo                                    31s
httpbin     httpbin                                     52s
infra       all-redirect-to-https   ["*.example.com"]   8s
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/shared-gw/../https/tests/redirect-http-to-https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

Summary
=======

We now have separation of concerns and a well-defined process for onboarding new teams:

- Operators designate a namespace for the new team's application, and
- label the namespace "self-serve-ingress=true" thereby allowing attachment of routes the shared gateway.
- The platform team configures the tls secret for the application's hostname.
- The application team can self-service routes for their applications and APIs.




##  6 - HTTP routing rules <a name="-6---http-routing-rules-"></a>

In this lab, you will explore other aspects of the HTTPRoute resource configuration, specifically [routing rules](https://gateway-api.sigs.k8s.io/api-types/httproute/#rules), and what capabilities they enable.

Backend References
==================

Review the specification for the `httpbin` route from the previous lesson:

```bash,noexecute
kubectl get httproute -n httpbin httpbin -o yaml | bat -l yaml
```

Although the above example references a single backend reference, it's important to know that we can specify multiple `backendRefs`, and each can be given a weight.

This allows us to define [traffic splitting](https://gateway-api.sigs.k8s.io/guides/traffic-splitting/) scenarios.

### Example

In the `bookinfo` application, expose the `reviews` service via the `/reviews` endpoint on the gateway.

```bash,noexecute
bat data/steps/routing-rules/reviews-endpoint.yaml
```

Apply the rule:

```bash
kubectl apply -f data/steps/kgateway-labs/routing-rules/reviews-endpoint.yaml
```

Capture the gateway IP address to the environment variable `GW_IP`:

```bash,noexecute
export GW_IP=$(kubectl get gtw -n infra infra-gateway -ojsonpath='{.status.addresses[0].value}')
```

Verify that the route functions as expected:


```bash,noexecute
curl -s --insecure https://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:443:$GW_IP | jq
```

<!--bash
export GW_IP=$(kubectl get gtw -n infra infra-gateway -ojsonpath='{.status.addresses[0].value}')
./scripts/register-domain.sh bookinfo.example.com ${GW_IP}
./scripts/register-domain.sh httpbin.example.com ${GW_IP}
-->
<!--bash
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
-->

The `reviews` service is backed by three deployments: `reviews-v1`, `reviews-v2`, and `reviews-v3`.

Requests should load-balance across all three workloads.

#### Traffic Split

Configure routing rule so that 50% of the traffic is sent to `v1` and 50% to `v2`.

Create a service for each deployment:

```bash
kubectl apply -n bookinfo -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/bookinfo/platform/kube/bookinfo-versions.yaml
```

Confirm that distinct service definitions exist for each version of the `reviews` service:

```bash,noexecute
kubectl get svc -n bookinfo
```

Define a routing rule with two `backendRefs`, as follows:

```bash,noexecute
bat data/steps/routing-rules/reviews-split.yaml
```

Apply the rule:

```bash
kubectl apply -f data/steps/kgateway-labs/routing-rules/reviews-split.yaml
```

Test the route:

```bash,noexecute
for i in {1..10}; do curl -s --insecure https://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:443:$GW_IP | jq .podname; done
```
<!--bash
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
-->
<!--bash
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
-->
Observe that no requests are routed to `reviews-v3`.

Confirm that only versions 1 and 2 of the service are responding to these request, with roughly a 50% split.

Matches
=======

### Path matching

In previous lessons you have used mainly host-based matching:  requests to `httpbin.example.com` go to the `httpbin` backend whereas requests to `bookinfo.example.com` route to `bookinfo`.

In the previous example we also saw an example of path-based matching:  exposing and using specific paths or path prefixes to route requests to specific destinations.

A good example of path-based matching is `bookinfo-route.yaml` from the previous lesson:

```bash,noexecute
bat data/steps/routing-rules/setup-bookinfo-route.yaml
```

Above we see a collection of alternative paths that all route to the `productpage` backend.  Some paths use `Exact` path matching while others use the `PathPrefix` [path match type](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.PathMatchType).
Yet another option (not shown above) is `RegularExpression`.

### Header matching

Requests can also be distinguished or matched by the contents of their headers.
This is useful in any situation where wish to send one category of user to one destination and another to a separate backend, this includes A/B testing, canary rollouts, and more.

#### Example

We wish to route all requests from test users, distinguished through the presence of a `role` header with value of `qa`, to the new version of the `reviews` service, v3.  All other users should be directed to `reviews-v2`.


Review the following route configuration:

```bash,noexecute
bat data/steps/routing-rules/reviews-header-match.yaml
```

Apply the configuration:

```bash
kubectl apply -f data/steps/kgateway-labs/routing-rules/reviews-header-match.yaml
```

Test it:

1. Requests to `/reviews` that do not contain a header should be handled by v2:

    ```bash,noexecute
    curl -s --insecure https://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:443:$GW_IP | jq .podname
    ```
<!--bash
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
-->
<!--bash
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
-->

2. Requests with the header `role=qa` should be handled by v3:

    ```bash,noexecute
    curl -s --insecure -H "role: qa" https://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:443:$GW_IP | jq .podname
    ```
<!--bash
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
-->


Other aspects of an HTTP request that can be used for matching include the request method (GET, POST, etc..) and the request's query parameters.

Filters
=======

We saw an example use for a filter in the https configuration lesson with the RequestRedirect [filter type](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPRouteFilterType).

Here was the route in question:

```bash,noexecute
bat data/steps/routing-rules/setup-redirect.yaml
```

In the above scenario, all requests that came in to the HTTP listener were redirected to the HTTPS scheme.

The Gateway API offers a number of additional built-in types:  `RequestHeaderModifier`, `ResponseHeaderModifier`, `URLRewrite`, and `RequestMirror`.
In addition, the spec leaves the door open for custom filter extensions through the `ExtensionRef` filter type.

### Example 1:  Request Header Modification

We can add, remove, or change any header in an incoming request, on its way to its backend destination.

Say for example that `httpbin` needs to know whether the request it's handling came from a client outside the Kubernetes cluster, i.e. through the gateway.

Add a header to the request named `request-type` with value `external`.

```bash,noexecute
bat data/steps/routing-rules/add-requestheader.yaml
```

Apply the configuration:

```bash
kubectl apply -f data/steps/kgateway-labs/routing-rules/add-requestheader.yaml
```

Ask `httpbin` for a copy of the request headers it was given:

```bash,noexecute
curl --insecure https://httpbin.example.com/headers --resolve httpbin.example.com:443:$GW_IP
```
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request-type header correctly set", () => {
  it('Checking text \'Request-Type\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/headers', body: 'Request-Type' }));
  it('Checking text \'external\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/headers', body: 'external' }));
})
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/routing-rules/tests/headers.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
-->
Note the presence of the header `request-type: external` in the output:

```json,nocopy
{
  "headers": {
    ...
    "Request-Type": [
      "external"
    ],
    ...
  }
}
```

### Example 2: [URL Rewriting](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPURLRewriteFilter)

`httpbin` has a set of endpoints with the prefix `status` that returns different response codes.
For example, this request will produce a response code of 304 "Not Modified":

```bash,noexecute
curl -v --insecure https://httpbin.example.com/status/304 --resolve httpbin.example.com:443:$GW_IP
```

Such endpoints can be useful when testing our APIs.

When we build APIs, many such path prefixes get renamed as the API evolves.
We can imagine that perhaps the original path prefix was `response-code/` and was later renamed to the simpler `status/`.

URL rewriting can be useful in such cases to continue supporting the old path prefix.
For example:

```bash,noexecute
bat data/steps/routing-rules/url-rewrite.yaml
```

The above configuration will accept requests with the venerable path prefix `/response-code` and rewrite the url by replacing the prefix match with `/status` instead.

Apply the configuration:

```bash
kubectl apply -f data/steps/kgateway-labs/routing-rules/url-rewrite.yaml
```

Test it:

```bash,noexecute
curl -v --insecure https://httpbin.example.com/response-code/304 --resolve httpbin.example.com:443:$GW_IP
```

Confirm that the response code is indeed a 304.

Timeouts and retries
====================

HTTPRoute also sports a `timeouts` field for configuring timeouts, and a `retries` field (still marked experimental) to configure retries.
Both are worth keeping in mind as they can be useful for improving the resilience of distributed systems.

You will exercise these fields in a subsequent lesson.


Summary
=======

Routing rules in the Gateway API enable many use cases:

- Routes can have multiple backend references with weights, enabling traffic splitting.
- Different aspects of the request can be used for matching requests including path and request headers.
    These capabilities support A/B testing and canary rollouts.
- The API defines a number of built-in filters including request & response header modification, URL rewriting, request mirroring, and request redirects.
We will look at custom filters in a subsequent lesson.



##  7 - Canary releases with Argo Rollouts & kgateway <a name="-7---canary-releases-with-argo-rollouts-&-kgateway-"></a>

About Canary Releases
=====================

In a previous lesson on routing rules, we studied how the Gateway API supports traffic splitting.

Here is the route configuration we used in that lesson:

```bash,noexecute
bat data/steps/kgateway-labs/rollouts/reviews-split.yaml
```

This ability to configure routes with weights supports canary releases:  an algorithm for releasing a new version of a service safely, by gradually shifting traffic from the current version to the new "canary" version, as long as the new version remains healthy and is not exhibiting failures.

When manually performing a canary release, we configure two distinct services backed by two distinct deployments, and manually attach a `version` label to the pods which the services select to direct traffic to their corresponding version.

From there, we define an HTTPRoute that directs traffic, initially to the "stable" version of the app, by setting the weight to 100%.
The last step is a manual process of progressively editing the weights to shift the traffic to the new version, while monitoring the system's health.

[Argo rollouts](https://argoproj.github.io/argo-rollouts/) is a project designed to automate this process.

The conventions in Argo are to define two services, a stable version and a canary.
Instead of a Kubernetes Deployment, Argo offers the Rollout resource, which, in addition to defining the deployment details, also specifies the rollout strategy.
Instead of utilizing multiple deployments, each revision is backed by a distinct ReplicaSet.
Instead of using a "version" label, Argo labels each the pods with their corresponding hash value.
Finally Argo will automatically alter the weights on the specified HTTPRoute as the release progresses.

Argo supports the Gateway API [through a plugin](https://rollouts-plugin-trafficrouter-gatewayapi.readthedocs.io/).

The end result is automated canary releases.

To better understand how this works, let us walk through an example, using the `bookinfo` sample application's `reviews` service.
The sample application comes with three distinct versions of the `reviews` service: `reviews-v1`, `reviews-v2`, and `reviews-v3`.
Unliked v1, versions v2 and v3 call an upstream service named `ratings`.

Initial state
=============

- A Kubernetes cluster is running
- The Gateway API CRDs have been applied to the cluster
- The [kgateway](https://kgateway.dev/) open-source Gateway API implementation is installed

Install Argo Rollouts
=====================

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

Wait for the Argo controller rollout to complete.

```bash
kubectl rollout status -n argo-rollouts deploy argo-rollouts
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Argo is healthy", () => {
    it(`Argo service is present`, () => helpers.k8sObjectIsPresent({ namespace: "argo-rollouts", k8sType: "service", k8sObj: "argo-rollouts-metrics" }));
    it(`Argo pods are ready`, () => helpers.checkDeploymentsWithLabels({ namespace: "argo-rollouts", labels: "app.kubernetes.io/name=argo-rollouts", instances: 1 }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/argo-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->

Apply the following ConfigMap to install the [Gateway API plugin for Argo rollouts](https://rollouts-plugin-trafficrouter-gatewayapi.readthedocs.io/):

```bash
kubectl replace -f data/steps/kgateway-labs/rollouts/argo-gwapi-plugin-cm.yaml
```

Allow Argo Rollouts to edit HTTP routes:

```bash
kubectl apply -f data/steps/kgateway-labs/rollouts/argo-rbac.yaml
```

Restart the Argo rollouts controller:

```bash
kubectl rollout restart deployment -n argo-rollouts argo-rollouts
```

Wait for the new deployment rollout to complete.

```bash
kubectl rollout status -n argo-rollouts deploy argo-rollouts
```

Check the controller logs for confirmation that plugin was downloaded:

```bash,noexecute
kubectl logs -n argo-rollouts deploy/argo-rollouts | grep -i download
```

Look for messages resembling or matching the following:

```console,nocopy
Downloading plugin argoproj-labs/gatewayAPI from: https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.5.0/gatewayapi-plugin-linux-amd64
Download complete, it took 2.219166356s
```

Foundations
===========

Create the Gateway `my-gateway` with a simple HTTP listener:

```bash,noexecute
bat data/steps/kgateway-labs/rollouts/gtw.yaml
```

```bash
kubectl apply -f data/steps/kgateway-labs/rollouts/gtw.yaml
```

Deploy the `ratings` service, a service called by certain versions of the `reviews` service:

```bash
kubectl apply -f data/steps/kgateway-labs/rollouts/ratings.yaml
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Ratings service is healthy", () => {
    it(`Ratings service is present`, () => helpers.k8sObjectIsPresent({ namespace: "default", k8sType: "service", k8sObj: "ratings" }));
    it(`Ratings pods are ready`, () => helpers.checkDeploymentsWithLabels({ namespace: "default", labels: "app=ratings", instances: 1 }));
});
EOF
echo "executing test dist/kgateway-workshop/build/imported/kgateway-labs/templates/steps/rollouts/tests/ratings-healthy.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->

Arrange for argo rollouts to have both a "stable" and "canary" service definition for the `reviews` service, that it can manipulate:

```bash,noexecute
bat data/steps/kgateway-labs/rollouts/services.yaml
```

Argo will arrange to update these services' selectors to use the pod hash of the corresponding revision.

Apply the service definitions:

```bash
kubectl apply -f data/steps/kgateway-labs/rollouts/services.yaml
```

Configure an HTTPRoute that directs traffic to both services:

```bash,noexecute
bat data/steps/kgateway-labs/rollouts/route.yaml
```

Don't worry about assigning the `backendRefs` any weights, Argo rollouts will take care of that.

Apply the `bookinfo-reviews` HTTP route:

```bash
kubectl apply -f data/steps/kgateway-labs/rollouts/route.yaml
```

Rollouts
========

Instead of a Deployment resource for the reviews service, we use an Argo [Rollout resource](https://argoproj.github.io/argo-rollouts/features/specification/):

```bash,noexecute
bat data/steps/kgateway-labs/rollouts/rollout.yaml
```

Review the above rollout strategy:  each time a new version is rolled out Argo will walk through these steps:

- scale the canary release to one replica
- configure header-based routing, so that we can test the canary before we start shifting traffic to it
- pause and allow an individual to manually promote the rollout, in other words giving Argo the "ok" to proceed
- progressively shift the weight of the traffic onto the canary, beginning with 10%, and gradually increase until the rollout is complete

Apply the rollout:

```bash
kubectl apply -f data/steps/kgateway-labs/rollouts/rollout.yaml
```

Run the following `tmux` command to configure a two-panel layout:

```bash,noexecute
tmux attach
```

Watch the HTTPRoute weights change as Argo goes through the rollout phases of the canary release.

```bash,noexecute
kubectl argo rollouts get rollout reviews-rollout --watch
```
<!--bash
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
-->

Click on the bottom panel to give it focus.

Capture the Gateway IP address:

```bash
export GW_IP=$(kubectl get gtw my-gateway -ojsonpath='{.status.addresses[0].value}')
```

Verify that the route for the `reviews` service functions:

```bash,noexecute
curl http://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:80:$GW_IP | jq
```
<!--bash
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
-->
Trigger a rollout to v2:

```bash
kubectl argo rollouts set image reviews-rollout reviews=docker.io/istio/examples-bookinfo-reviews-v2:1.20.2
```

Verify that the first two steps of the rollout have taken place:

- The canary was deployed
- The header-based route has been applied

Check the `stable` and `canary` service selectors:

```bash,noexecute
kubectl get svc -o wide -l app=reviews
```

Observe that the selectors use the pod template hash to discriminate between revisions:

```console,nocopy
NAME             TYPE        CLUSTER-IP      PORT(S)    SELECTOR
reviews-canary   ClusterIP   10.43.191.34    9080/TCP   app=reviews,rollouts-pod-template-hash=594c75879c
reviews-stable   ClusterIP   10.43.127.185   9080/TCP   app=reviews,rollouts-pod-template-hash=7d484c47b8
```

Send a test call to the canary, using header-based matching:

```bash,noexecute
curl -H "role: qa" http://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:80:$GW_IP | jq
```
<!--bash
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
-->
Note how the json response indicates that this version of the `reviews` service made an upstream call to the `ratings` service.

On the other hand, a call without the header in question will produce a response from the stable revision:

```bash,noexecute
curl http://bookinfo.example.com/reviews/123 --resolve bookinfo.example.com:80:$GW_IP | jq
```
<!--bash
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
-->

Assuming we are satisfied that the canary revision is working properly, proceed to promote the new revision.

Promote the paused rollout to allow it to proceed:

```bash
kubectl argo rollouts promote reviews-rollout
```
<!--bash
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
-->

Observe the rollout proceed through its steps, and the canary revision's weight increase to 10% of requests, then 20%, and so on until all traffic has shifted fully to the canary, at which point the canary becomes the new stable revision.

Summary
=======

This lab demonstrated how Argo Rollouts can automate the process of performing canary releases through the Gateway API and the manipulation of routes.

The routes specifications are in turn processed by kgateway to program the Gateway accordingly.

This is a great example of how having a standard for Ingress allows tools like Argo Rollouts to function with any implementation of the Gateway API.




##  8 - Deploy the Amazon pod identity webhook <a name="-8---deploy-the-amazon-pod-identity-webhook-"></a>

To use the AWS Lambda integration, we need to deploy the Amazon EKS pod identity webhook.

A prerequisite is to install [Cert Manager](https://cert-manager.io/):

```bash
wget https://github.com/cert-manager/cert-manager/releases/download/v1.12.4/cert-manager.yaml

kubectl --context ${CLUSTER1} apply -f cert-manager.yaml
```

Wait for cert-manager to be running:

```bash
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager-cainjector
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager-webhook
```

Now, you can install the Amazon EKS pod identity webhook:

```bash
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-amazon-pod-identity-webhook
```

Wait for the pod identity webhook to be running:

```bash
kubectl --context ${CLUSTER1} rollout status deploy/pod-identity-webhook
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Amazon EKS pod identity webhook", () => {
  it('Amazon EKS pod identity webhook is ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "default", k8sObj: "pod-identity-webhook" }));
});
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/deploy-amazon-pod-identity-webhook/tests/pods-available.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
-->



##  9 - Execute Lambda functions <a name="-9---execute-lambda-functions-"></a>

First of all, you need to create a `Backend` object corresponding to the AWS destination:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: lambda
  labels:
    self-serve-ingress: "true"
---
apiVersion: gateway.kgateway.dev/v1alpha1
kind: Backend
metadata:
  name: lambda
  namespace: lambda
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
```

There are 2 ways to authenticate to AWS:
1. Use a `Secret` object containing the AWS credentials.
2. Use IRSA (IAM Role for Service Accounts) to authenticate to AWS.

Let's try the first option.

Create a `Secret` object containing the AWS credentials:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
stringData:
  accessKey: ${AWS_ACCESS_KEY_ID}
  secretKey: ${AWS_SECRET_ACCESS_KEY}
  sessionToken: ""
kind: Secret
metadata:
  name: aws-creds
  namespace: lambda
type: Opaque
EOF
```

Finally, you can create a `HTTPRoute` to expose the `echo` Lambda function through the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lambda
  namespace: lambda
spec:
  parentRefs:
    - name: infra-gateway
      namespace: infra
      sectionName: httpbin-https
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /lambda
    backendRefs:
    - name: lambda
      namespace: lambda
      group: gateway.kgateway.dev
      kind: Backend
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.kgateway.dev
            kind: Parameter
            name: workshop-echo
EOF
```

The `echo` lambda function is a simple Node.js function returning the even it receives:

```js,nocopy
exports.handler = async (event) => {
    return event;
};
```

You should now be able to invoke the Lambda function using the following command:

```bash,noexecute
curl -ki "https://httpbin.example.com/lambda" -d '{"foo":"bar"}'
```

You should get a response like below:

```log,nocopy
HTTP/1.1 200 OK
date: Thu, 13 Mar 2025 13:04:45 GMT
x-amzn-requestid: 4d11534f-2816-4f97-b27f-69b3f5446504
x-amzn-remapped-content-length: 0
x-amz-executed-version: $LATEST
x-amzn-trace-id: Root=1-67d2d7ed-614a9aa0375190d159a755d0;Parent=33671bbe415ae74c;Sampled=0;Lineage=1:3e56857a:0
x-envoy-expected-rq-timeout-ms: 15000
x-request-id: c9549f36-70fb-474c-bf47-2258fc6ce8d6
accept: */*
x-forwarded-for: 10.101.0.1
x-envoy-external-address: 10.101.0.1
content-type: application/x-www-form-urlencoded
content-length: 13
x-forwarded-proto: http
user-agent: curl/8.7.1
x-envoy-upstream-service-time: 182
server: envoy

{"foo":"bar"}
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  it(`Checking text 'foo' in response`, () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/lambda', data: '{"foo":"bar"}', body: 'foo', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/gateway-lambda/tests/check-lambda-echo.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
-->

Let's try the second option.

First, delete the `Secret` object we created previously:

```bash
kubectl --context ${CLUSTER1} delete secret -n infra aws-creds
```

Annotate the `infra-gateway` service account with the `eks.amazonaws.com/role-arn` annotation:
```bash
kubectl --context ${CLUSTER1} annotate sa -n infra infra-gateway "eks.amazonaws.com/role-arn=arn:aws:iam::253915036081:role/lambda-workshop"
```

Restart the `infra-gateway` deployment to apply the changes:
```bash
kubectl --context ${CLUSTER1} rollout restart deployment -n infra infra-gateway
```

Now update the `Backend` object to use IRSA:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: Backend
metadata:
  name: lambda
  namespace: lambda
spec:
  type: AWS
  aws:
    region: eu-west-1
    accountId: "253915036081"
    auth:
      type: IRSA
    lambda:
      functionName: workshop-echo
EOF
```

You should now be able to invoke the Lambda function using the same command as before:

```bash,noexecute
curl -ki "https://httpbin.example.com/lambda" -d '{"foo":"bar"}'
```

You should get the same response as before.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  it(`Checking text 'foo' in response`, () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/lambda', data: '{"foo":"bar"}', body: 'foo', match: true }));
})
EOF
echo "executing test dist/kgateway-workshop/build/templates/steps/gateway-lambda/tests/check-lambda-echo.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
-->



