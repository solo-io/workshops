
<!--bash
source ./scripts/assert.sh
-->



<center><img src="images/gloo-gateway.png" alt="Gloo Gateway" style="width:70%;max-width:800px" /></center>

# <center>Gloo Gateway Workshop</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy a KinD cluster](#lab-1---deploy-a-kind-cluster-)
* [Lab 2 - Deploy Istio in Ambient mode](#lab-2---deploy-istio-in-ambient-mode-)
* [Lab 3 - Deploy Gloo Gateway](#lab-3---deploy-gloo-gateway-)
* [Lab 4 - Deploy the httpbin demo app](#lab-4---deploy-the-httpbin-demo-app-)
* [Lab 5 - Deploy and use waypoint](#lab-5---deploy-and-use-waypoint-)



## Introduction <a name="introduction"></a>

[Gloo Gateway](https://www.solo.io/products/gloo-gateway/) is a feature-rich, fast, and flexible Kubernetes-native ingress controller and next-generation API gateway that is built on top of [Envoy proxy](https://www.envoyproxy.io/) and the [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/).

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




## Lab 1 - Deploy a KinD cluster <a name="lab-1---deploy-a-kind-cluster-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variable:

```bash
export CLUSTER1=cluster1
```

Run the following commands to deploy a Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):

```bash
./scripts/deploy-multi.sh 1 cluster1
```

Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh cluster1
```

**Note:** If you run the `check.sh` script immediately after the `deploy.sh` script, you may see a jsonpath error. If that happens, simply wait a few seconds and try again.

Once the `check.sh` script completes, when you execute the `kubectl get pods -A` command, you should see the following:

```,nocopy
NAMESPACE            NAME                                          READY   STATUS    RESTARTS   AGE
kube-system          calico-kube-controllers-59d85c5c84-sbk4k      1/1     Running   0          4h26m
kube-system          calico-node-przxs                             1/1     Running   0          4h26m
kube-system          coredns-6955765f44-ln8f5                      1/1     Running   0          4h26m
kube-system          coredns-6955765f44-s7xxx                      1/1     Running   0          4h26m
kube-system          etcd-cluster1-control-plane                   1/1     Running   0          4h27m
kube-system          kube-apiserver-cluster1-control-plane         1/1     Running   0          4h27m
kube-system          kube-controller-manager-cluster1-control-plane1/1     Running   0          4h27m
kube-system          kube-proxy-ksvzw                              1/1     Running   0          4h26m
kube-system          kube-scheduler-cluster1-control-plane         1/1     Running   0          4h27m
local-path-storage   local-path-provisioner-58f6947c7-lfmdx        1/1     Running   0          4h26m
metallb-system       controller-5c9894b5cd-cn9x2                   1/1     Running   0          4h26m
metallb-system       speaker-d7jkp                                 1/1     Running   0          4h26m
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-kind-cluster/tests/cluster-healthy.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->



## Lab 2 - Deploy Istio in Ambient mode <a name="lab-2---deploy-istio-in-ambient-mode-"></a>


Download the Istio release:

```bash
curl -L https://istio.io/downloadIstio | sh -

if [ -d "istio-"*/ ]; then
    cd istio-*/
    export PATH=$PWD/bin:$PATH
    cd ..
fi
```

Install Istio in Ambient mode:

```bash
helm upgrade --install istio-base \
  oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/base \
  -n istio-system --create-namespace \
  --version 1.23.1-solo \
  --kube-context ${CLUSTER1} \
  --wait

helm upgrade --install istio-cni \
  oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/cni \
  -n istio-system \
  --version 1.23.1-solo \
  --set profile=ambient \
  --set global.hub=us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo> \
  --set global.tag=1.23.1-solo \
  --kube-context ${CLUSTER1} \
  --wait

helm upgrade --install istiod \
  oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/istiod \
  -n istio-system \
  --version 1.23.1-solo \
  --set profile=ambient \
  --set global.hub=us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo> \
  --set global.tag=1.23.1-solo \
  --kube-context ${CLUSTER1} \
  --wait

helm upgrade --install ztunnel \
  oci://us-docker.pkg.dev/gloo-mesh/istio-helm-<enterprise_istio_repo>/ztunnel \
  -n istio-system \
  --version 1.23.1-solo \
  --set profile=ambient \
  --set hub=us-docker.pkg.dev/gloo-mesh/istio-<enterprise_istio_repo> \
  --set tag=1.23.1-solo \
  --set env.L7_ENABLED="true" \
  --kube-context ${CLUSTER1} \
  --wait
```

Run the following command to check the Istio Pods are running:

```bash
kubectl --context ${CLUSTER1} -n istio-system get pods
```

Here is the expected output:

```,nocopy
NAME                      READY   STATUS    RESTARTS   AGE
istio-cni-node-75ds2      1/1     Running   0          86s
istiod-7758df6879-pcvjt   1/1     Running   0          45s
ztunnel-zgf7b             1/1     Running   0          13s
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-istio-ambient/tests/check-istio.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->



## Lab 3 - Deploy Gloo Gateway <a name="lab-3---deploy-gloo-gateway-"></a>

You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```
Let's create the `gloo-system` namespace and label it to be part of the mesh:

```bash
kubectl --context $CLUSTER1 create namespace gloo-system
kubectl --context $CLUSTER1 label namespace gloo-system istio.io/dataplane-mode=ambient
```

Next, install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash
helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm

helm repo update

helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.18.0-beta1 \
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
      enabled: false
      disableTransformationValidation: false
      alwaysAcceptResources: false
  gloo:
    deployment:
      customEnv:
        - name: GG_PORTAL_PLUGIN
          value: "true"
        - name: ENABLE_WAYPOINTS
          value: "true"
      livenessProbeEnabled: true
  discovery:
    enabled: false
  rbac:
    namespaced: true
    nameSuffix: gg-demo
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
settings:
  disableKubernetesDestinations: true
ambient:
  waypoint:
    enabled: true
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->



## Lab 4 - Deploy the httpbin demo app <a name="lab-4---deploy-the-httpbin-demo-app-"></a>

We're going to deploy the httpbin application to demonstrate several features of Gloo Gateway.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app twice (`httpbin1` and `httpbin2`).

```bash
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

You can follow the progress using the following command:

<!--bash
echo -n Waiting for httpbin pods to be ready...
kubectl --context ${CLUSTER1} -n httpbin rollout status deployment
-->
```shell
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->




## Lab 5 - Deploy and use waypoint <a name="lab-5---deploy-and-use-waypoint-"></a>

Istio Ambient Mesh is using a proxy called Waypoint (based on Envoy) to provide L7 capabilities.

You can use Gloo Gateway as a Waypoint to get even more L7 features available.

To demonstrate it, let's deploy a Waypoint proxy in the `httpbin` namespace.

```bash
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
```

Run the following command to check the Waypoint has been deployed correctly:

```bash
kubectl --context ${CLUSTER1} -n httpbin rollout status deploy gloo-proxy-gloo-waypoint
```

You should get this output:

```
deployment "gloo-proxy-gloo-waypoint" successfully rolled out
```

Then, let's label the `httpbin2` service to use this Waypoint proxy.

```bash
kubectl --context ${CLUSTER1} -n httpbin label svc httpbin2 istio.io/use-waypoint=gloo-waypoint
```

We need a client to send request to the `httpbin2` service:

```bash
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
```

Now, let's demonstrate how to leverage the Waypoint proxy.

First of all, you can use the standard features provided by a standard waypoint.

Let's start with L7 Authorization.

```bash
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
        - cluster.local/ns/httpbin/sa/client
    to:
    - operation:
        methods: ["GET"]
EOF
```

This policy means that only the client can send requests to `httpbin2`, and only GET requests.

Try to send a POST request:

```shell
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s -X POST http://httpbin2:8000/post
```

You'll get the following response:

```,nocopy
RBAC: access denied
```

Try to send a GET request:

```shell
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get
```

This time it works !

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

describe("AuthorizationPolicy is working properly", function() {
  it("The client isn't allowed to send POST requests", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -m 2 --max-time 2 -s -X POST -o /dev/null -w "%{http_code}" "http://httpbin2:8000/post"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('403');
  });
  it("The client isn't allowed to send GET requests", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -m 2 --max-time 2 -s -o /dev/null -w "%{http_code}" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('200');
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waypoint/tests/authorization.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->

Let's delete the policy:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete authorizationpolicy allow-get-only
```

The Kubernetes Gateway API provides different options to add/update/remove request and response headers.

Let's try with request headers.

Update the `HTTPRoute` resource to do the following:
- add a new header `Foo` with the value `bar`
- update the value of the header `User-Agent` to `custom`
- remove the `To-Remove` header

```bash
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
```

Try to access the application (with the `To-Remove` request header added):

```shell
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get -H 'To-Remove: whatever'
```

Here is the expected output:

```json,nocopy
{
  "args": {},
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Foo": [
      "bar"
    ],
    "Host": [
      "httpbin2:8000"
    ],
    "User-Agent": [
      "custom"
    ],
    "X-Forwarded-Proto": [
      "https"
    ],
    "X-Request-Id": [
      "8595e525-4484-4aaa-8f56-97a96163c333"
    ]
  },
  "method": "GET",
  "origin": "127.0.0.6:48727",
  "url": "http://httpbin2:8000/get"
}
```

The transformations have been applied as expected.

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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waypoint/tests/request-headers.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->

Gloo Gateway provides some extensions to manipulate requests and responses in a more advanced way.

Let's extract the product name from the `User-Agent` header (getting read of the product version and comments).

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
```

Try to access the application:

```shell
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waypoint/tests/x-client-request-header.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->

As you can see, we've created a new header called `X-Client` by extracting some data from the `User-Agent` header using a regular expression.

And we've targetted the `HTTPRoute` using the `targetRefs` of the `RouteOption` object. With this approach, it applies to all its rules.

We can also use the extauth capabilities of Gloo Gateway. Let's secure the access to the `httpbin2` service using Api keys.

First, we need to create an `AuthConfig`, which is a CRD that contains authentication information. We will create a secret with the apikey as well:

```bash
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
```

After that, you need to update the `RouteOption`, to reference the `AuthConfig`:

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
    name: httpbin2
  options:
    extauth:
      configRef:
        name: apikeys
        namespace: httpbin
EOF
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waypoint/tests/authentication.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->

After you've completed these steps, you should be able to access the `httpbin2` service using the api key. You can test this by running the following command:

```shell
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get -H "api-key: apikey1"
```

You can see the `X-Organization` header added with the value gathered from the secret.

We can also use the rate limiting capabilities of Gloo Gateway. Let's secure the access to the `httpbin2` service using Api keys.

We're going to apply rate limiting to the Gateway to only allow 3 requests per minute for the users of the `solo.io` organization.

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
```

Run the following command several times:

```shell
kubectl --context ${CLUSTER1} -n httpbin exec deploy/client -- curl -s http://httpbin2:8000/get -H "api-key: apikey1" -I
```

You should get a `200` response code the first 3 times and a `429` response code after.

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

describe("Rate limiting is working properly", function() {
  it("The httpbin2 service should be rate limited", () => {
    let command = `kubectl --context ${process.env.CLUSTER1} -n httpbin exec deploy/client -- curl -s -o /dev/null -w "%{http_code}" -H "api-key: apikey1" "http://httpbin2:8000/get"`;
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('429');
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waypoint/tests/rate-limited.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && echo "" && cat ./test.js && exit 1; }
-->

Let's delete the resources we've created:

```bash
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
kubectl delete --context ${CLUSTER1} -n httpbin ratelimitconfig limit-users
kubectl delete --context ${CLUSTER1} -n httpbin authconfig apikeys
kubectl delete --context ${CLUSTER1} -n gloo-system secret global-apikey
kubectl delete --context ${CLUSTER1} -n httpbin httproute httpbin2
```



