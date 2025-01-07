
<!--bash
source ./scripts/assert.sh
-->



<center>
<img src="images/document-gloo-mesh.svg" style="height: 100px;"/>
</center>

# <center>Gloo Mesh Enterprise (2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85)</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD Cluster(s)](#lab-1---deploy-kind-cluster(s)-)
* [Lab 2 - Deploy and register Gloo Mesh](#lab-2---deploy-and-register-gloo-mesh-)
* [Lab 3 - Deploy Httpbin to cluster1](#lab-3---deploy-httpbin-to-cluster1-)
* [Lab 4 - Deploy Httpbin to cluster2](#lab-4---deploy-httpbin-to-cluster2-)
* [Lab 5 - Deploy Gloo Gateway to cluster1](#lab-5---deploy-gloo-gateway-to-cluster1-)
* [Lab 6 - Deploy Gloo Gateway to cluster2](#lab-6---deploy-gloo-gateway-to-cluster2-)
* [Lab 7 - Distributed configs](#lab-7---distributed-configs-)



## Introduction <a name="introduction"></a>

Gloo Mesh Enterprise is a distribution of the [Istio](https://istio.io/) service mesh that is hardened for production support across multicluster hybrid clusters and service meshes.
With Gloo Mesh Enterprise, you get an extensible, open-source based set of API tools to connect and manage your services across multiple clusters and service meshes.
It includes n-4 Istio version support with security patches to address Common Vulnerabilities and Exposures (CVEs), as well as special builds to meet regulatory standards such as Federal Information Processing Standards (FIPS).

The Gloo Mesh API simplifies the complexity of your service mesh by installing custom resource definitions (CRDs) that you configure.
Then, Gloo Mesh translates these CRDs into Istio resources across your environment, and provides visibility across all of the resources and traffic.
Enterprise features include multitenancy, global failover and routing, observability, and east-west rate limiting and policy enforcement through authorization and authentication plug-ins.

### Gloo Mesh Enterprise overview

Gloo Mesh Enterprise provides many unique features, including:

* Upstream-first approach to feature development
* Installation, upgrade, and management across clusters and service meshes
* Advanced features for security, traffic routing, tranformations, observability, and more
* End-to-end Istio support and CVE security patching for n-4 versions
* Specialty builds for distroless and FIPS compliance
* 24x7 production support and one-hour Severity 1 SLA
* Portal modules to extend functionality
* Workspaces for simplified multi-tenancy
* Zero-trust architecture for both north-south ingress and east-west service traffic
* Single pane of glass for operational management of Istio, including global observability

<img src="images/gloo-mesh-graph.png" alt="Gloo Mesh Enterprise graph" style="width:100%;max-width:800px" />

### Want to learn more about Gloo Mesh Enterprise?

You can find more information about Gloo Mesh Enterprise in the official documentation: <https://docs.solo.io/gloo-mesh/>




## Lab 1 - Deploy KinD Cluster(s) <a name="lab-1---deploy-kind-cluster(s)-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variables:

```bash
export MGMT=mgmt
export CLUSTER1=cluster1
export CLUSTER2=cluster2
```

Deploy the KinD clusters:

```bash
bash ./data/steps/deploy-kind-clusters/deploy-mgmt.sh
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
bash ./data/steps/deploy-kind-clusters/deploy-cluster2.sh
```
Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh mgmt
./scripts/check.sh cluster1
./scripts/check.sh cluster2
```

**Note:** If you run the `check.sh` script immediately after the `deploy.sh` script, you may see a jsonpath error. If that happens, simply wait a few seconds and try again.

Once the `check.sh` script completes, execute the `kubectl get pods -A` command, and verify that all pods are in a running state.
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = ["mgmt", "cluster1", "cluster2"];

    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 2 - Deploy and register Gloo Mesh <a name="lab-2---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


Before we get started, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85
mkdir -p $HOME/.gloo-mesh/bin
curl "https://storage.googleapis.com/gloo-platform-dev/meshctl/$GLOO_MESH_VERSION/meshctl-$(uname | tr '[:upper:]' '[:lower:]')-amd64" > $HOME/.gloo-mesh/bin/meshctl
chmod +x $HOME/.gloo-mesh/bin/meshctl
export PATH=$HOME/.gloo-mesh/bin:$PATH
```
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->

Install the Kubernetes Gateway and the Gloo CRDs in the management plane.

```bash
kubectl --context ${MGMT} apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

helm upgrade -i -n gloo-system \
--repo https://storage.googleapis.com/solo-public-helm \
  gloo-gateway gloo/gloo \
  --create-namespace \
  --version 1.17.16 \
  --kube-context $CLUSTER1 \
  -f -<<EOF
discovery:
  enabled: false
gatewayProxies:
  gatewayProxy:
    disabled: true
gloo:
  disableLeaderElection: true
EOF
```

Run the following commands to deploy the Gloo Mesh management plane:

```bash
kubectl --context ${MGMT} create ns gloo-mesh

helm upgrade --install gloo-platform-crds gloo-platform-crds \
  --repo https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85

helm upgrade --install gloo-platform gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${MGMT} \
  --version 2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85 \
  -f -<<EOF
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
EOF

kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
```

<!--bash
kubectl wait --context ${MGMT} --for=condition=Ready -n gloo-mesh --all pod
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

Then, you need to set the environment variable to tell the Gloo Mesh agents how to communicate with the management plane:
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/check-deployment.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
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
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/get-gloo-mesh-mgmt-server-ip.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->

```bash
export ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].*}'):9900
export HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH%:*})
export ENDPOINT_TELEMETRY_GATEWAY=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-telemetry-gateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):4317
export ENDPOINT_GLOO_MESH_UI=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-ui -o jsonpath='{.status.loadBalancer.ingress[0].*}'):8090
```

Check that the variables have correct values:
```
echo $HOST_GLOO_MESH
echo $ENDPOINT_GLOO_MESH
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

describe("Address '" + process.env.HOST_GLOO_MESH + "' can be resolved in DNS", () => {
    it(process.env.HOST_GLOO_MESH + ' can be resolved', (done) => {
        return dns.lookup(process.env.HOST_GLOO_MESH, (err, address, family) => {
            expect(address).to.be.an.ip;
            done();
        });
    });
});
EOF
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->
Finally, you need to register the cluster(s).


Here is how you register the first one:

```bash
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
  --repo https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER1} \
  --version 2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85

helm upgrade --install gloo-platform gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER1} \
  --version 2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85 \
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
EOF
```

Note that the registration can also be performed using `meshctl cluster register`.

And here is how you register the second one:

```bash
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
  --repo https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85

helm upgrade --install gloo-platform gloo-platform \
  --repo https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts \
  --namespace gloo-mesh \
  --kube-context ${CLUSTER2} \
  --version 2.7.0-beta1-2024-11-18-gg-config-distribution-07bf4f3f85 \
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
EOF
```

You can check the cluster(s) have been registered correctly using the following commands:
```
meshctl --kubecontext ${MGMT} check
```

```
pod=$(kubectl --context ${MGMT} -n gloo-mesh get pods -l app=gloo-mesh-mgmt-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${MGMT} -n gloo-mesh debug -q -i ${pod} --image=curlimages/curl -- curl -s http://localhost:9091/metrics | grep relay_push_clients_connected
```

You should get an output similar to this:
```,nocopy
# HELP relay_push_clients_connected Current number of connected Relay push clients (Relay Agents).
# TYPE relay_push_clients_connected gauge
relay_push_clients_connected{cluster="cluster1"} 1
relay_push_clients_connected{cluster="cluster2"} 1
```
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 3 - Deploy Httpbin to cluster1 <a name="lab-3---deploy-httpbin-to-cluster1-"></a>


We're going to deploy the httpbin application to demonstrate several features of Gloo Gateway.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app twice (`httpbin1` and `httpbin2`).

```bash
kubectl --context ${CLUSTER1} create ns httpbin
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
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 4 - Deploy Httpbin to cluster2 <a name="lab-4---deploy-httpbin-to-cluster2-"></a>


We're going to deploy the httpbin application to demonstrate several features of Gloo Gateway.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app twice (`httpbin1` and `httpbin2`).

```bash
kubectl --context ${CLUSTER2} create ns httpbin
kubectl apply --context ${CLUSTER2} -f - <<EOF
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

kubectl apply --context ${CLUSTER2} -f - <<EOF
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
```

You can follow the progress using the following command:

<!--bash
echo -n Waiting for httpbin pods to be ready...
kubectl --context ${CLUSTER2} -n httpbin rollout status deployment
-->
```shell
kubectl --context ${CLUSTER2} -n httpbin get pods
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
  let cluster = process.env.CLUSTER2
  let deployments = ["httpbin1", "httpbin2"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "httpbin", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




## Lab 5 - Deploy Gloo Gateway to cluster1 <a name="lab-5---deploy-gloo-gateway-to-cluster1-"></a>

You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Next, install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash
helm repo add solo-public-helm https://storage.googleapis.com/solo-public-helm

helm repo update

helm upgrade -i -n gloo-system \
  gloo-gateway solo-public-helm/gloo \
  --create-namespace \
  --version 1.17.16 \
  --kube-context $CLUSTER1 \
  -f -<<EOF
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
  deployment:
    livenessProbeEnabled: true
discovery:
  enabled: false
rbac:
  namespaced: true
  nameSuffix: gg-demo
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
NAME                                READY   STATUS      RESTARTS   AGE
gateway-certgen-h5z9t               0/1     Completed   0          52s
gateway-proxy-7474c7bf9b-dsvtz      3/3     Running     0          47s
gloo-6b5575f9fc-8f2zs               1/1     Running     0          47s
gloo-resource-rollout-check-4bt5g   0/1     Completed   0          47s
gloo-resource-rollout-h5jf4         0/1     Completed   0          47s
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["gloo"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-gloo-gateway/tests/check-gloo.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->



## Lab 6 - Deploy Gloo Gateway to cluster2 <a name="lab-6---deploy-gloo-gateway-to-cluster2-"></a>

You can deploy Gloo Gateway with the `glooctl` CLI or declaratively using Helm.

We're going to use the Helm option.

Install the Kubernetes Gateway API CRDs as they do not come installed by default on most Kubernetes clusters.

```bash
kubectl --context $CLUSTER2 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Next, install Gloo Gateway. This command installs the Gloo Gateway control plane into the namespace `gloo-system`.

```bash
helm repo add solo-public-helm https://storage.googleapis.com/solo-public-helm

helm repo update

helm upgrade -i -n gloo-system \
  gloo-gateway solo-public-helm/gloo \
  --create-namespace \
  --version 1.17.16 \
  --kube-context $CLUSTER2 \
  -f -<<EOF
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
  deployment:
    livenessProbeEnabled: true
discovery:
  enabled: false
rbac:
  namespaced: true
  nameSuffix: gg-demo
EOF
```

Run the following command to check that the Gloo Gateway pods are running:

<!--bash
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER2 -n gloo-system rollout status deployment
-->
```bash
kubectl --context $CLUSTER2 -n gloo-system get pods
```

Here is the expected output:

```,nocopy
NAME                                READY   STATUS      RESTARTS   AGE
gateway-certgen-h5z9t               0/1     Completed   0          52s
gateway-proxy-7474c7bf9b-dsvtz      3/3     Running     0          47s
gloo-6b5575f9fc-8f2zs               1/1     Running     0          47s
gloo-resource-rollout-check-4bt5g   0/1     Completed   0          47s
gloo-resource-rollout-h5jf4         0/1     Completed   0          47s
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["gloo"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/imported/gloo-gateway/templates/steps/deploy-gloo-gateway/tests/check-gloo.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->



## Lab 7 - Distributed configs <a name="lab-7---distributed-configs-"></a>

In this lab, we will explore the concept of distributed configurations in Gloo Mesh. We will demonstrate how Gloo Mesh enables you to manage configurations centrally from the management cluster while distributing them to the Gateways deployed in registered clusters (cluster1 and cluster2 in this case).

### Prepare Namespaces

Before we start distributing configuration, let's create a namespace on all three clusters that will contain the centrally-managed gateway resources:

```bash
kubectl --context $MGMT create ns gloo-gateway-config
kubectl --context $CLUSTER1 create ns gloo-gateway-config
kubectl --context $CLUSTER2 create ns gloo-gateway-config
```

Having a dedicated namespace for these resources on workload clusters allows RBAC to be applied to these resources if needed.

### Deploy a Centrally Managed GatewayClass

Next, we will deploy a `GatewayClass` named `centrally-managed` in the management cluster. This deployment will automatically create gateways in the workload clusters for any Gateways that use this class.

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: centrally-managed
spec:
  controllerName: solo.io/gloo-gateway-mgmt-plane
EOF
```

### Define a Generic Gateway

Now, a central management team can deploy a Gateway and HTTPRoute to the management cluster. The Gateway will simply expose port 80 and reference the GatewayClass we just defined:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: generic-gateway
  namespace: gloo-gateway-config
spec:
  gatewayClassName: centrally-managed
  listeners:
    - name: http
      port: 80
      protocol: "HTTP"
EOF
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gateway", () => {
  it('should be created in cluster1', () => {
    helpers.checkDeploymentHasPod({ context: process.env.CLUSTER1, namespace: "gloo-gateway-config", deployment: "gloo-proxy-generic-gateway-gloo-gateway-config" });
  })

  it('should be created in cluster2', () => {
    helpers.checkDeploymentHasPod({ context: process.env.CLUSTER2, namespace: "gloo-gateway-config", deployment: "gloo-proxy-generic-gateway-gloo-gateway-config" });
  })
});
EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/distributed-configs/tests/check-gateway.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->

Next apply the HTTPRoute:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: parent-route-httpbin
  namespace: gloo-gateway-config
spec:
  parentRefs:
    - name: generic-gateway
  hostnames:
    - "httpbin"
  rules:
    - backendRefs:
      - name: '*'
        group: gateway.networking.k8s.io
        kind: HTTPRoute
        namespace: httpbin
      filters:
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: Foo
                value: bar
EOF
```

After a brief delay, Gloo Mesh will distribute the Gateway and HTTPRoute configurations to the registered clusters (cluster1 and cluster2). Verify that these resources have been created in the `gloo-gateway-config` namespace of each cluster.

```shell
kubectl --context $CLUSTER1 -n gloo-gateway-config get gtw,httproute
```

```shell
kubectl --context $CLUSTER2 -n gloo-gateway-config get gtw,httproute,pod,svc
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("HTTPRoute", () => {
  it('should be propagated to cluster1', () => {
    return helpers.genericCommand({
      command: `kubectl --context=${process.env.CLUSTER1} get httproutes.gateway.networking.k8s.io -n gloo-gateway-config`,
      responseContains: 'httpbin'
    });
  })

  it('should be propagated to cluster2', () => {
    return helpers.genericCommand({
      command: `kubectl --context=${process.env.CLUSTER2} get httproutes.gateway.networking.k8s.io -n gloo-gateway-config`,
      responseContains: 'httpbin'
    });
  })
});

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/distributed-configs/tests/verify-routes-created-in-clusters.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->


### Deploy Child HTTPRoutes

Now, let's deploy child `HTTPRoute` resources in the `httpbin` namespace on both `cluster1` and `cluster2`. These child routes will define the actual backend service (`httpbin1`) to which traffic will be routed by the parent route.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
  - backendRefs:
    - name: httpbin1
      port: 8000
EOF

kubectl apply --context ${CLUSTER2} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
  - backendRefs:
    - name: httpbin1
      port: 8000
EOF
```

Validate that the traffic reaches the `httpbin1` service in Cluster1 by sending a request to the Gateway IP and checking the response:

```shell
export GATEWAY_IP_CLUSTER1=$(kubectl --context $CLUSTER1 -n gloo-gateway-config get svc gloo-proxy-generic-gateway-gloo-gateway-config -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -i -H "Host: httpbin" $GATEWAY_IP_CLUSTER1/get
```

Validate the same for the second cluster:

```shell
export GATEWAY_IP_CLUSTER2=$(kubectl --context $CLUSTER2 -n gloo-gateway-config get svc gloo-proxy-generic-gateway-gloo-gateway-config -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -i -H "Host: httpbin" $GATEWAY_IP_CLUSTER2/get
```

<!--bash
cat <<'EOF' > ./test.js
const httpHelpers = require('./tests/chai-http');
const execHelpers = require('./tests/chai-exec');

describe("httpbin is accessible", () => {
  let cluster1 = process.env.CLUSTER1;
  let cluster2 = process.env.CLUSTER2;

  let gateway_ip_cluster1 = execHelpers.getOutputForCommand({ command: `kubectl --context ${cluster1} -n gloo-gateway-config get svc gloo-proxy-generic-gateway-gloo-gateway-config -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`}).replaceAll("'", "");

  let gateway_ip_cluster2 = execHelpers.getOutputForCommand({ command: `kubectl --context ${cluster2} -n gloo-gateway-config get svc gloo-proxy-generic-gateway-gloo-gateway-config -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`}).replaceAll("'", "");

  it('httpbin is available in cluster1', () => httpHelpers.checkURLWithIP({ ip: gateway_ip_cluster1, host: `httpbin`, path: '/get', retCode: 200 }));

  it('httpbin is available in cluster2', () => httpHelpers.checkURLWithIP({ ip: gateway_ip_cluster2, host: `httpbin`, path: '/get', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-workshop/build/templates/steps/distributed-configs/tests/check-connectivity-children.test.js.liquid"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail || { DEBUG_MODE=true mocha ./test.js --timeout 120000; exit 1; }
-->




