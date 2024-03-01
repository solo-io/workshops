
<!--bash
#!/usr/bin/env bash

source ./scripts/assert.sh
-->



<center><img src="images/gloo-gateway.png" alt="Gloo Mesh Gateway" style="width:70%;max-width:800px" /></center>

# <center>Gloo Mesh Gateway (2.5.1)</center>



## Table of Contents
* [Introduction](#introduction)
* [Lab 1 - Deploy a KinD cluster](#lab-1---deploy-a-kind-cluster-)
* [Lab 2 - Deploy Gitea](#lab-2---deploy-gitea-)
* [Lab 3 - Deploy Argo CD](#lab-3---deploy-argo-cd-)
* [Lab 4 - Deploy and register Gloo Mesh](#lab-4---deploy-and-register-gloo-mesh-)
* [Lab 5 - Deploy Istio using Gloo Mesh Lifecycle Manager](#lab-5---deploy-istio-using-gloo-mesh-lifecycle-manager-)
* [Lab 6 - Deploy the Bookinfo demo app](#lab-6---deploy-the-bookinfo-demo-app-)
* [Lab 7 - Deploy the httpbin demo app](#lab-7---deploy-the-httpbin-demo-app-)
* [Lab 8 - Deploy Gloo Mesh Addons](#lab-8---deploy-gloo-mesh-addons-)
* [Lab 9 - Create the gateways workspace](#lab-9---create-the-gateways-workspace-)
* [Lab 10 - Create the bookinfo workspace](#lab-10---create-the-bookinfo-workspace-)
* [Lab 11 - Expose the productpage through a gateway](#lab-11---expose-the-productpage-through-a-gateway-)
* [Lab 12 - Create the httpbin workspace](#lab-12---create-the-httpbin-workspace-)



## Introduction <a name="introduction"></a>

Gloo Mesh Gateway is a feature-rich, Kubernetes-native ingress controller and next-generation API gateway, based on Istio and Envoy.

With Gloo Mesh Gateway, you have access to its exceptional function-level routing, discovery capabilities, numerous features, tight integration with leading open-source projects, and support for legacy apps, microservices, and serverless.
It is uniquely designed to support hybrid applications in which multiple technologies, architectures, protocols, and clouds can co-exist.

Built on [Istio's ingress gateway](https://www.solo.io/topics/istio/istio-ingress-gateway/), Gloo Mesh Gateway uses an Envoy proxy as the ingress gateway to manage and control traffic that enters your Kubernetes cluster.
You use custom resources, such as Gloo virtual gateways, route tables, and policies to implement security measures that meet your business and app requirements, and that simplify configuring ingress traffic rules.
Because these resources offer declarative, API-driven configuration, you can easily integrate Gloo Mesh Gateway into your existing GitOps and CI/CD workflows.

### Why would you choose an API Gateway based on Istio and Envoy?

There are many good reasons why:

* First of all, it's high-performance software written in C++
* They're driven by a neutral foundation (CNCF, like Kubernetes), so their roadmaps aren't driven by a single vendor
* And probably, more importantly, you have already adopted or you're probably going to adopt a service mesh in the future. Chances are high that this service mesh will be Istio and if it's not the case it will most probably be a service mesh based on Envoy
* So choosing an API Gateway based on Istio and Envoy will allow you to get the metrics for your API Gateway and your Service Mesh in the same format. So you can troubleshoot issues in a common way

### Why would you choose Gloo Mesh Gateway?

* It has been developed from the beginning with the idea to be configured 100% through YAML
* It provides all the functionalities you expect from a modern API Gateway:
  * External authentication based on OAuth2, JWT, API keys, …
  * Authorization based on OPA
  * Advanced rate-limiting
  * Web Application Firewall based on ModSecurity
  * Advanced transformation
  * Customization through WebAssembly
* It includes Gloo Portal, a Kubernetes-native developer portal
* And much more

These features enable Platform Engineers as well as development teams to implement powerful mechanisms to manage and secure traffic, implement access control, transform requests and responses, and gain observability over their services.

The true power unfolds when combining the above-mentioned capabilities to achieve the desired outcome.
In the labs that follow we present some of the common patterns that our customers use and provide a good entry point into the workings of Gloo Mesh Gateway.

### Want to learn more about Gloo Mesh Gateway?

You can find more information about Gloo Mesh Gateway in the official documentation: <https://docs.solo.io/gloo-gateway/>




## Lab 1 - Deploy a KinD cluster <a name="lab-1---deploy-a-kind-cluster-"></a>


Clone this repository and go to the directory where this `README.md` file is.

Set the context environment variables:

```bash
export MGMT=cluster1
export CLUSTER1=cluster1
```

Run the following commands to deploy a Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):

```bash
./scripts/deploy.sh 1 cluster1 us-west us-west-1
```

Then run the following commands to wait for all the Pods to be ready:

```bash
./scripts/check.sh cluster1
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
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Clusters are healthy", () => {
    const clusters = [process.env.MGMT, process.env.CLUSTER1];
    clusters.forEach(cluster => {
        it(`Cluster ${cluster} is healthy`, () => helpers.k8sObjectIsPresent({ context: cluster, namespace: "default", k8sType: "service", k8sObj: "kubernetes" }));
    });
});
EOF
echo "executing test dist/workshop/build/templates/steps/deploy-kind-cluster/tests/cluster-healthy.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 2 - Deploy Gitea <a name="lab-2---deploy-gitea-"></a>

GitOps is a DevOps automation technique based on Git. To implement it, your processes depend
on a centralised Git hosting tool such as GitHub or GitLab. In this exercise we'll provide
our own hosted Git instance that can be used to push code changes to, and create and approve
pull requests in.

Run the following commands to create a Gitea Git hosting service in your environment:

```bash
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update

helm upgrade --install gitea gitea-charts/gitea \
  --version 10.1.0 \
  --kube-context ${MGMT} \
  --namespace gitea \
  --create-namespace \
  --wait \
  -f -<<EOF
service:
  http:
    type: LoadBalancer
    port: 3180
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
      OFFLINE_MODE: true
EOF

kubectl --context ${MGMT} -n gitea wait svc gitea-http --for=jsonpath='{.status.loadBalancer.ingress[0].*}' --timeout=300s
```

Let's create a user that can create a new repo, push changes, and work with pull requests:

```bash
export GITEA_HTTP=http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].*}'):3180

GITEA_ADMIN_TOKEN=$(curl -Ss ${GITEA_HTTP}/api/v1/users/gitea_admin/tokens \
  -H "Content-Type: application/json" \
  -d '{"name": "workshop", "scopes": ["write:admin", "write:repository"]}' \
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
```

You can now see the list of Gitea repos by clicking the "Git" tab above. If you need to, you
can log in with username `gloo-gitops` and password `password` that were used to create the user.

Now, if you need to push a repo to Gitea, you can simply add a remote to it and push.
We don't have a repo to work with yet but this is how you would do it:

```,nocopy
git config credential.helper '!f() { sleep 1; echo "username=gloo-gitops"; echo "password=password"; }; f'
git remote add origin ${GITEA_HTTP}/gloo-gitops/new-repo.git
git push -u origin main
```

Note that the credentials are stored **insecurely** here as a convenience for these exercises.



## Lab 3 - Deploy Argo CD <a name="lab-3---deploy-argo-cd-"></a>

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes that we can use to
deploy and synchronise applications and configuration from a state stored in a Git repo.

Run the following commands to install Argo CD in your environment:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argo-cd argo/argo-cd \
  --version 5.53.6 \
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
  cm:
    timeout.reconciliation: 10s
EOF

kubectl --context ${MGMT} -n argocd wait svc argo-cd-argocd-server --for=jsonpath='{.status.loadBalancer.ingress[0].*}' --timeout=300s
```

Download and install the `argocd` CLI tool that we'll use to manage the Argo CD server:

```bash
mkdir -p ${HOME}/bin
curl -Lo ${HOME}/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.9.5/argocd-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/aarch/arm/' | sed 's/x86_/amd/')
chmod +x ${HOME}/bin/argocd
export PATH=$HOME/bin:$PATH
```

Next, log in to the Argo CD server and rename the default cluster (which is where Argo CD
is running) to match our environment:

```bash
ARGOCD_HTTP_IP=$(kubectl --context ${MGMT} -n argocd get svc argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].*}')
ARGOCD_ADMIN_SECRET=$(kubectl --context ${MGMT} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd --kube-context ${MGMT} login ${ARGOCD_HTTP_IP}:3280 --username admin --password ${ARGOCD_ADMIN_SECRET} --plaintext

argocd cluster set in-cluster --name ${MGMT}
```
We can check that our cluster list looks correct:

```bash
argocd cluster list
```

You should get an output like the following:

```,nocopy
SERVER                          NAME      VERSION  STATUS   MESSAGE                                                  PROJECT
https://kubernetes.default.svc  cluster1           Unknown  Cluster has no applications and is not being monitored.
```

Now we're ready to use Argo CD to manage applications as part of continuous delivery and GitOps.
We'll start by creating a GitOps repo that our teams will share. Note that teams can have their own repos
to work separately if that suits their workflow better.

```bash
mkdir -p data/steps/gitops-repo
export GITOPS_REPO_LOCAL=$(realpath data/steps/gitops-repo)
```

At the root of our shared GitOps directory, we'll create a new subdirectory called `argo-cd` that we'll use to sync
configuration to Argo CD:

```bash
export GITOPS_ARGOCD=${GITOPS_REPO_LOCAL}/argo-cd
mkdir -p ${GITOPS_ARGOCD} && touch ${GITOPS_ARGOCD}/.gitignore
```

Instantiate the shared GitOps directory as a Git repo:

```bash
git -C ${GITOPS_REPO_LOCAL} init -b main
git -C ${GITOPS_REPO_LOCAL} config user.email "gloo-gitops@solo.io"
git -C ${GITOPS_REPO_LOCAL} config user.name "Solo.io GitOps User"
```

We'll need the URL of our Git server. Save that in an environment variable:

```bash
GITEA_HTTP=http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].*}'):3180
```

Commit and push our repo to the Git server:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Initial commit of Gloo GitOps"

git -C ${GITOPS_REPO_LOCAL} config credential.helper '!f() { sleep 1; echo "username=gloo-gitops"; echo "password=password"; }; f'
git -C ${GITOPS_REPO_LOCAL} remote add origin ${GITEA_HTTP}/gloo-gitops/gitops-repo.git

git -C ${GITOPS_REPO_LOCAL} push -u origin main
```

While we now have a Git repo that we'll use to sync Argo CD configuration, we need to tell Argo CD where to
get that configuration from and how to apply it. We'll use two Kubernetes custom resources for this, one to
define a new "project" and another to create an "application" that declares how the config will be synced:

```bash
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
  - repoURL: ${GITEA_HTTP}/gloo-gitops/gitops-repo.git
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
```

These are applied directly to Argo CD, but we'll keep them in our GitOps repo in case we need to make any
changes in the future:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Manage argo-cd config"
git -C ${GITOPS_REPO_LOCAL} push
```

Now, check the Argo CD UI tab above. After a few seconds, you should see an application created
for our Argo CD configuration, which is synchronised with the Git repo that we just created.
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

describe("Argo CD config", () => {
  it("syncs to mgmt cluster", () => {
    let cli = chaiExec(process.env.HOME + "/bin/argocd --kube-context " + process.env.MGMT + " app get argocd-" + process.env.MGMT);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bServer:\\s+" + process.env.MGMT + "\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bRepo:\\s+http://(?:[0-9]{1,3}\.){3}[0-9]{1,3}:3180/gloo-gitops/gitops-repo.git\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bPath:\\s+argo-cd\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bHealth Status:\\s+Healthy\\b"));
  });
});

EOF
echo "executing test dist/workshop/build/templates/steps/deploy-argo-cd/tests/argo-cd-sync-repo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
Finally, let's test that everything is working correctly. We'll define a pod manifest, commit
it to our repo, push it to the remote, and check that Argo CD creates that pod in our cluster.

First, switch back to the terminal and create our pod manifest:

```bash
cat <<EOF > ${GITOPS_ARGOCD}/nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: default
spec:
  containers:
  - image: nginx
    name: nginx
EOF
```

Commit and push it to our remote:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Add nginx"
git -C ${GITOPS_REPO_LOCAL} push
```
<!--bash
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
-->

Now, check the Argo CD UI tab again and click into the "argocd-[[ Instruqt-Var key="MGMT" hostname="" ]]"
application. After a short period, you'll see an `nginx` pod appear linked to the application.
The status of this pod will be shown as a tag on the pod box in the UI.

Let's make sure the pod got deployed by switching back to the terminal and running this command:

```bash
until kubectl --context ${MGMT} -n default wait --for=condition=ready pod/nginx --timeout=30s 2>/dev/null; do sleep 1; done
```

Now let's delete the pod manifest from the repo and check that it gets removed from the
cluster:

```bash
git -C ${GITOPS_REPO_LOCAL} revert --no-commit HEAD
git -C ${GITOPS_REPO_LOCAL} commit -m "Delete nginx"
git -C ${GITOPS_REPO_LOCAL} push

kubectl --context ${MGMT} -n default wait --for=delete pod/nginx --timeout=30s
```



## Lab 4 - Deploy and register Gloo Mesh <a name="lab-4---deploy-and-register-gloo-mesh-"></a>
[<img src="https://img.youtube.com/vi/djfFiepK4GY/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/djfFiepK4GY "Video Link")


Before we get started, let's install the `meshctl` CLI:

```bash
export GLOO_MESH_VERSION=v2.5.1
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
    expect(process.env.MGMT).not.to.be.empty
    expect(process.env.CLUSTER1).not.to.be.empty
  });

  it("Gloo Mesh licence environment variables should not be empty", () => {
    expect(process.env.GLOO_MESH_LICENSE_KEY).not.to.be.empty
  });
});
EOF
echo "executing test dist/workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/environment-variables.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
GitOps allows flexible interactions between the different teams involved in building and running modern
applications. For these exercises we focus on a small number of *personas* that manage their own resources
and may work in distinct ways. These personas are:

* A **platform team**, who install and manage Gloo Platform and any cross-cutting concerns, like Istio
* A **gateways team**, who manage the ingress and east-west gateways and cross-cutting traffic concerns like
external DNS names or certificates
* **Application teams**, who decide how their apps are deployed and what routing requirements they have

Find out more about the personas that Gloo Platform was designed for [here](https://docs.solo.io/gloo-mesh-enterprise/latest/concepts/about/persona/).

The platform team will use a Git repo to store the desired state of the Gloo Platform installation. This repo
has already been created at the location in environment variable `${GITOPS_REPO_LOCAL}`, so we'll create
a new subdirectory for the platform team:

```bash
export GITOPS_PLATFORM=${GITOPS_REPO_LOCAL}/platform
mkdir -p ${GITOPS_PLATFORM}/${MGMT}
```

First, we'll create an Argo CD `Project` and `ApplicationSet` to apply the platform team's resources. This will
create an Argo CD `Application` for each configured cluster, and apply cluster-specific configuration from the
respective cluster subdirectory:

```bash
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
  template:
    metadata:
      name: platform-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io/background
    spec:
      project: platform
      source:
        repoURL: ${GITEA_HTTP}/gloo-gitops/gitops-repo.git
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
```

Next, we'll create another Argo CD `Application` for the installation of the Gloo Platform management plane.
This will deploy the Gloo Platform CRDs and the management server as a pair of Helm releases, using a set of
Helm values that we'll store alongside this application spec in the GitOps repo:

```bash
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
    targetRevision: 2.5.1
    helm:
      releaseName: gloo-platform-crds
  - chart: gloo-platform
    repoURL: https://storage.googleapis.com/gloo-platform/helm-charts
    targetRevision: 2.5.1
    helm:
      releaseName: gloo-platform-mgmt
      valueFiles:
      - \$values/platform/argo-cd/gloo-platform-mgmt-installation-values.yaml
  - repoURL: http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].*}'):3180/gloo-gitops/gitops-repo.git
    targetRevision: HEAD
    ref: values
EOF
```

We'll use the following Helm values file to configure the Gloo Platform management server:

```bash
cat <<EOF > ${GITOPS_PLATFORM}/argo-cd/gloo-platform-mgmt-installation-values.yaml
licensing:
  glooTrialLicenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: cluster1
glooInsightsEngine:
  enabled: false
glooMgmtServer:
  enabled: true
  ports:
    healthcheck: 8091
  registerCluster: true
prometheus:
  enabled: true
  skipAutoMigration: true
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
glooAgent:
  enabled: true
  relay:
    serverAddress: gloo-mesh-mgmt-server:9900
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: gloo-telemetry-gateway:4317

EOF
```

We're going to use [Kustomize](https://kustomize.io/) later on to help minimise duplication of configuration,
so we'll create the `Kustomization` files needed to make sure our resources are included:

```bash
cat <<EOF >${GITOPS_PLATFORM}/argo-cd/kustomization.yaml
namespace: argocd
resources:
- gloo-platform-mgmt-installation.yaml
EOF

cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
resources:
- ../argo-cd
EOF
```

Finally, commit and push the management server config to Git for it to take effect:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gloo Platform management server"
git -C ${GITOPS_REPO_LOCAL} push
```
<!--bash
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
-->

Take a look at the Argo CD dashboard to see the new `Application`s sync. While the config is synced,
wait for the deployment to complete by running the following in the terminal:

```bash
until kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server 2>/dev/null; do sleep 1; done
```

<!--bash
kubectl wait --context ${MGMT} --for=condition=Ready -n gloo-mesh --all pod
timeout 2m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

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
});
EOF
echo "executing test dist/workshop/build/templates/steps/deploy-and-register-gloo-mesh/tests/cluster-registration.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 5 - Deploy Istio using Gloo Mesh Lifecycle Manager <a name="lab-5---deploy-istio-using-gloo-mesh-lifecycle-manager-"></a>
[<img src="https://img.youtube.com/vi/f76-KOEjqHs/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/f76-KOEjqHs "Video Link")

We are going to deploy Istio using Gloo Mesh Lifecycle Manager.

In this GitOps workshop, we'll assume that the platform team and the gateways team are separate teams,
so they will have separate subdirectories in the GitOps repo to work in. Let's create the directory for
the gateways team to manage their configuration in:

```bash
export GITOPS_GATEWAYS=${GITOPS_REPO_LOCAL}/gateways
mkdir -p ${GITOPS_GATEWAYS}
```

We'll use an Argo CD project and `ApplicationSet` to apply the gateway team's resources. This will create
an Argo CD `Application` for each configured cluster, and apply cluster-specific configuration from the
respective cluster subdirectory:

```bash
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
  template:
    metadata:
      name: gateways-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io/background
    spec:
      project: gateways
      source:
        repoURL: ${GITEA_HTTP}/gloo-gitops/gitops-repo.git
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
```

Let's create Kubernetes services for the gateways:

We're going to define base manifests for the gateway services, and then apply customisations
using Kustomize to modify them for their target clusters:

```bash
mkdir -p ${GITOPS_GATEWAYS}/base/gateway-services

cat <<EOF > ${GITOPS_GATEWAYS}/base/gateway-services/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: istio-gateways
  labels:
    istio.io/rev: 1-20
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
    revision: 1-20
  type: LoadBalancer
EOF

cat <<EOF >>${GITOPS_GATEWAYS}/base/gateway-services/kustomization.yaml
- ingress.yaml
EOF
```

We'll use Kustomize to apply tweaks to the base service manifests to match our desired state
for each workload cluster:

```bash
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
```

It allows us to have full control on which Istio revision we want to use.

Commit and push the service manifests to Git for them to take effect:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gateway services"
git -C ${GITOPS_REPO_LOCAL} push
```

Then, we can tell Gloo Mesh to deploy the Istio control planes and the gateways in the cluster(s).

This will involve two teams, the platform team that manages Istio, and the gateways team for the gateways themselves.
The platform team will create the `IstioLifecycleManager`s to roll out Istio on the workload clusters:

```bash
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
      revision: 1-20
      istioOperatorSpec:
        profile: minimal
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.20.2-solo
        namespace: istio-system
        values:
          global:
            meshID: mesh1
            multiCluster:
              clusterName: cluster1
            network: cluster1
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
          ingressGateways:
          - name: istio-ingressgateway
            enabled: false
EOF

cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/istio/kustomization.yaml
commonAnnotations:
  argocd.argoproj.io/sync-wave: "3"
resources:
- ilm-cluster1.yaml
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- istio
EOF
```

The gateways team will create the `GatewayLifecycleManager`s to create the Istio gateways on the workload clusters:

```bash
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
      gatewayRevision: 1-20
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.20.2-solo
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
      gatewayRevision: 1-20
      istioOperatorSpec:
        profile: empty
        hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
        tag: 1.20.2-solo
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
                  - name: ISTIO_META_ROUTER_MODE
                    value: "sni-dnat"
                  - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                    value: cluster1
EOF

cat <<EOF >${GITOPS_GATEWAYS}/${MGMT}/kustomization.yaml
resources:
- glm-cluster1.yaml
EOF
```

Commit and push the lifecycle manager manifests to Git for them to take effect:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Istio and gateway lifecycle managers"
git -C ${GITOPS_REPO_LOCAL} push
```
<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get ilm cluster1-installation 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->

<!--bash
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
-->

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
  it('istiod pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-system", labels: "app=istiod", instances: 1 }));
  it('gateway pods are ready in cluster ' + process.env.CLUSTER1, () => helpers.checkDeploymentsWithLabels({ context: process.env.CLUSTER1, namespace: "istio-gateways", labels: "app=istio-ingressgateway", instances: 2 }));
  it("Gateways have an ip attached in cluster " + process.env.CLUSTER1, () => {
    let cli = chaiExec("kubectl --context " + process.env.CLUSTER1 + " -n istio-gateways get svc -l app=istio-ingressgateway -o jsonpath='{.items}'");
    cli.stderr.should.be.empty;
    let deployments = JSON.parse(cli.stdout.slice(1,-1));
    expect(deployments).to.have.lengthOf(1);
    deployments.forEach((deployment) => {
      expect(deployment.status.loadBalancer).to.have.property("ingress");
    });
  });
});

EOF
echo "executing test dist/workshop/build/templates/steps/istio-lifecycle-manager-install/tests/istio-ready.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
<!--bash
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o json | jq '.items[0].status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
-->

```bash
export HOST_GW_CLUSTER1="$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}')"
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



## Lab 6 - Deploy the Bookinfo demo app <a name="lab-6---deploy-the-bookinfo-demo-app-"></a>
[<img src="https://img.youtube.com/vi/nzYcrjalY5A/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/nzYcrjalY5A "Video Link")

We're going to deploy the bookinfo application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](https://istio.io/latest/docs/examples/bookinfo/).

Our example bookinfo application will be managed by its own team, who will use their own subdirectory in the
shared GitOps repo:

```bash
export GITOPS_BOOKINFO=${GITOPS_REPO_LOCAL}/bookinfo
mkdir -p ${GITOPS_BOOKINFO}
```

We'll use an Argo CD project and `ApplicationSet` to apply the bookinfo team's resources. This will create
an Argo CD `Application` for each configured cluster, and apply cluster-specific configuration from the
respective cluster subdirectory:

```bash
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
  template:
    metadata:
      name: bookinfo-{{cluster}}
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: bookinfo
      source:
        repoURL: ${GITEA_HTTP}/gloo-gitops/gitops-repo.git
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
```

Then, we'll copy the separate constituents of the bookinfo distributed application into our Git repo:

```bash
mkdir -p ${GITOPS_BOOKINFO}/base/frontends
cp data/steps/deploy-bookinfo/productpage-v1.yaml ${GITOPS_BOOKINFO}/base/frontends/

mkdir -p ${GITOPS_BOOKINFO}/base/backends
cp data/steps/deploy-bookinfo/details-v1.yaml data/steps/deploy-bookinfo/ratings-v1.yaml data/steps/deploy-bookinfo/reviews-v1-v2.yaml \
  ${GITOPS_BOOKINFO}/base/backends/
```

We'll define two namespaces with the necessary labels for Istio injection:
```bash
cat <<EOF >${GITOPS_BOOKINFO}/base/frontends/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookinfo-frontends
  labels:
    istio.io/rev: 1-20
EOF

cat <<EOF >${GITOPS_BOOKINFO}/base/backends/ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookinfo-backends
  labels:
    istio.io/rev: 1-20
EOF
```

Next, add the Kustomize resources to include these manifests:

```bash
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
```

Run the following commands to deploy the bookinfo application on `cluster1`:

Create `Kustomization`s to adapt the base resources for the first cluster:

```bash
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
```

Commit and push the application manifests to Git for them to start deploying in the first cluster:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Bookinfo on ${CLUSTER1}"
git -C ${GITOPS_REPO_LOCAL} push
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

<!--bash
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
});
EOF
echo "executing test dist/workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 7 - Deploy the httpbin demo app <a name="lab-7---deploy-the-httpbin-demo-app-"></a>
[<img src="https://img.youtube.com/vi/w1xB-o_gHs0/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/w1xB-o_gHs0 "Video Link")

We're going to deploy the httpbin application to demonstrate several features of Gloo Mesh.

You can find more information about this application [here](http://httpbin.org/).

Our example httpbin application will be managed by its own team, who will use their own subdirectory in the
shared GitOps repo:

```bash
export GITOPS_HTTPBIN=${GITOPS_REPO_LOCAL}/httpbin
mkdir -p ${GITOPS_HTTPBIN}
```

We'll use an Argo CD project and `ApplicationSet` to apply the httpbin team's resources. This will create
an Argo CD `Application` for each configured cluster, and apply cluster-specific configuration from the
respective cluster subdirectory:

```bash
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
        repoURL: ${GITEA_HTTP}/gloo-gitops/gitops-repo.git
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
```

Run the following commands to deploy the httpbin app on `cluster1`. The deployment will be called `not-in-mesh` and won't have the sidecar injected (because we don't label the namespace).

```bash
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
        - containerPort: 80
EOF
```

Then, we deploy a second version, which will be called `in-mesh` and will have the sidecar injected (because of the label `istio.io/rev` in the Pod template).

```bash
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
        istio.io/rev: 1-20
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

Add the Kustomize resources to include these manifests:

```bash
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
```

Commit to the GitOps repo:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "httpbin on ${CLUSTER1}"
git -C ${GITOPS_REPO_LOCAL} push
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
echo "executing test dist/workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->



## Lab 8 - Deploy Gloo Mesh Addons <a name="lab-8---deploy-gloo-mesh-addons-"></a>
[<img src="https://img.youtube.com/vi/_rorug_2bk8/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/_rorug_2bk8 "Video Link")

To use the Gloo Mesh Gateway advanced features (external authentication, rate limiting, ...), you need to install the Gloo Mesh addons.

First, you need to create a namespace for the addons, with Istio injection enabled:

```bash
cat <<EOF >${GITOPS_PLATFORM}/${CLUSTER1}/ns-gloo-mesh-addons.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh-addons
  labels:
    istio.io/rev: 1-20
EOF

cat <<EOF >>${GITOPS_PLATFORM}/${CLUSTER1}/kustomization.yaml
- ns-gloo-mesh-addons.yaml
EOF
```

Then, you can deploy the addons on the cluster(s) using Helm:

Create an Argo CD `Application` to install the Gloo Platform add-ons:

```bash
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
        targetRevision: 2.5.1
        helm:
          releaseName: gloo-platform
          valueFiles:
          - \$values/platform/argo-cd/gloo-platform-addons-installation-values.yaml
          parameters:
          - name: common.cluster
            value: '{{cluster}}'
      - repoURL: http://$(kubectl --context ${MGMT} -n gitea get svc gitea-http -o jsonpath='{.status.loadBalancer.ingress[0].*}'):3180/gloo-gitops/gitops-repo.git
        targetRevision: HEAD
        ref: values
EOF
```

We'll use the following Helm values file to configure the Gloo Platform add-ons:

```bash
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
```

Add these files for `Kustomize` to include:

```bash
cat <<EOF >>${GITOPS_PLATFORM}/argo-cd/kustomization.yaml
- gloo-platform-addons-installation.yaml
EOF
```

For teams to setup external authentication, the gateways team needs to create and `ExtAuthServer` object they can reference.

Let's create the `ExtAuthServer` object:

```bash
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
```

For teams to setup rate limiting, the gateways team needs to create and `RateLimitServerSettings` object they can reference.

Let's create the `RateLimitServerSettings` object:

```bash
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
```

Update the `Kustomization` to include these files:

```bash
cat <<EOF >>${GITOPS_PLATFORM}/${CLUSTER1}/kustomization.yaml
- ext-auth-server.yaml
- rate-limit-server-settings.yaml
EOF
```

Commit to the GitOps repo:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Gloo Platform add-ons"
git -C ${GITOPS_REPO_LOCAL} push
```

<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n gloo-mesh-addons get eas ext-auth-server 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->
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

EOF
echo "executing test dist/workshop/build/templates/steps/deploy-gloo-mesh-addons/tests/check-addons-deployments.test.js.liquid"
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

EOF
echo "executing test dist/workshop/build/templates/steps/deploy-gloo-mesh-addons/tests/check-addons-services.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 2m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->
This is what the environment looks like now:

![Gloo Platform Workshop Environment](images/steps/deploy-gloo-mesh-addons/gloo-mesh-workshop-environment.svg)



## Lab 9 - Create the gateways workspace <a name="lab-9---create-the-gateways-workspace-"></a>
[<img src="https://img.youtube.com/vi/QeVBH0eswWw/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/QeVBH0eswWw "Video Link")

We're going to create a workspace for the team in charge of the Gateways.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.
We'll create those in the `workspaces` directory in our GitOps repo:

```bash
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/workspaces
```

Let's create the `gateways` workspace which corresponds to the `istio-gateways` and the `gloo-mesh-addons` namespaces on the cluster(s):

```bash
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
EOF
```

Then, the Gateway team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `gateways` workspace (so the `istio-gateways` or the `gloo-mesh-addons` namespace):

```bash
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
```

The Gateway team has decided to import the following from the workspaces that have the label `allow_ingress` set to `true` (using a selector):
- all the Kubernetes services exported by these workspaces
- all the resources (RouteTables, VirtualDestination, ...) exported by these workspaces that have the label `expose` set to `true`

Track these resources for Kustomize and commit them to the GitOps repo:

```bash
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
```
<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get workspace gateways 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->



## Lab 10 - Create the bookinfo workspace <a name="lab-10---create-the-bookinfo-workspace-"></a>

We're going to create a workspace for the team in charge of the Bookinfo application.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.
We'll create those in the `workspaces` directory in our GitOps repo:

```bash
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/workspaces
```

Let's create the `bookinfo` workspace which corresponds to the `bookinfo-frontends` and `bookinfo-backends` namespaces on the cluster(s):

```bash
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
EOF
```

Then, the Bookinfo team creates a `WorkspaceSettings` Kubernetes object in one of the namespaces of the `bookinfo` workspace (so the `bookinfo-frontends` or the `bookinfo-backends` namespace):

```bash
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
```

The Bookinfo team has decided to export the following to the `gateway` workspace (using a reference):
- the `productpage` and the `reviews` Kubernetes services
- all the resources (RouteTables, VirtualDestination, ...) that have the label `expose` set to `true`

Track these resources for Kustomize and commit them to the GitOps repo:

```bash
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
```
<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get workspace bookinfo 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->

This is how the environment looks like with the workspaces:

![Gloo Mesh Workspaces](images/steps/create-bookinfo-workspace/gloo-mesh-workspaces.svg)




## Lab 11 - Expose the productpage through a gateway <a name="lab-11---expose-the-productpage-through-a-gateway-"></a>
[<img src="https://img.youtube.com/vi/emyIu99AOOA/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/emyIu99AOOA "Video Link")

In this step, we're going to expose the `productpage` service through the Ingress Gateway using Gloo Mesh.

The Gateway team must create a `VirtualGateway` to configure the Istio Ingress Gateway in cluster1 to listen to incoming requests.

```bash
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
```

Then, the Gateway team should create a parent `RouteTable` to configure the main routing.

```bash
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
```

In this example, you can see that the Gateway team is delegating the routing details to the `bookinfo` and `httpbin` workspaces. The teams in charge of these workspaces can expose their services through the gateway.

The Gateway team can use this main `RouteTable` to enforce a global WAF policy, but also to have control on which hostnames and paths can be used by each application team.

The Gateway team will track these resources for Kustomize and commit them to the GitOps repo:

```bash
cat <<EOF >>${GITOPS_GATEWAYS}/${CLUSTER1}/kustomization.yaml
- virtualgateway.yaml
- routetable-main.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Virtual gateway and main route table"
git -C ${GITOPS_REPO_LOCAL} push
```

Then, the Bookinfo team can create a `RouteTable` to determine how they want to handle the traffic.

```bash
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
```

The Bookinfo team will track this resource for Kustomize and commit it to the GitOps repo:

```bash
cat <<EOF >>${GITOPS_BOOKINFO}/${CLUSTER1}/kustomization.yaml
- routetable-productpage.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Bookinfo route table"
git -C ${GITOPS_REPO_LOCAL} push
```
<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo-frontends get rt productpage 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->
Let's add the domains to our `/etc/hosts` file:

```bash
./scripts/register-domain.sh cluster1-bookinfo.example.com ${HOST_GW_CLUSTER1}
./scripts/register-domain.sh cluster1-httpbin.example.com ${HOST_GW_CLUSTER1}
```

Once Argo CD has synced these resources, you can access the `productpage` service
using this URL: [http://cluster1-bookinfo.example.com/productpage](http://cluster1-bookinfo.example.com/productpage).

You should now be able to access the `productpage` application through the browser.
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTP)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `http://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/workshop/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available.test.js.liquid"
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
```

> <i>Note: Secrets should not be stored in the GitOps repo in an unencrypted form (see [Sealed Secrets](https://sealed-secrets.netlify.app/)
for a mechanism to store secrets properly). We store them unencrypted in this workshop for simplicity.</i>

Finally, the Gateway team needs to update the `VirtualGateway` to use this secret:

```bash
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
```

Commit these changes to the GitOps repo:

```bash
git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "Secure the gateway"
git -C ${GITOPS_REPO_LOCAL} push
```
<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \"\$(kubectl --context ${CLUSTER1} -n istio-gateways get vg north-south-gw -ojsonpath='{.spec.listeners[?(@.tls.mode==\"SIMPLE\")]}' 2>/dev/null)\" != \"\" ]]; do
  sleep 1
  echo -n .
done"
echo
-->

Once Argo CD has synced these resources, you can now access the `productpage` application securely through the browser.
You can access the `productpage` service using this URL: <https://cluster1-bookinfo.example.com/productpage>.

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
<!--bash
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Productpage is available (HTTPS)", () => {
  it('/productpage is available in cluster1', () => helpers.checkURL({ host: `https://cluster1-bookinfo.example.com`, path: '/productpage', retCode: 200 }));
})
EOF
echo "executing test dist/workshop/build/templates/steps/apps/bookinfo/gateway-expose/tests/productpage-available-secure.test.js.liquid"
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
    podName = helpers.getOutputForCommand({ command: "kubectl -n gloo-mesh get pods -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' --context " + process.env.MGMT }).replaceAll("'", "");
    command = helpers.getOutputForCommand({ command: "kubectl --context " + process.env.MGMT + " -n gloo-mesh debug -q -i " + podName + " --image=curlimages/curl -- curl -s http://localhost:9090/api/v1/query?query=istio_requests_total" }).replaceAll("'", "");
    expect(command).to.contain("cluster\":\"cluster1");
  });
});


EOF
echo "executing test dist/workshop/build/templates/steps/apps/bookinfo/gateway-expose/tests/otel-metrics.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout 3m mocha ./test.js --timeout 10000 --retries=150 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
-->

This diagram shows the flow of the request (through the Istio Ingress Gateway):

![Gloo Mesh Gateway](images/steps/gateway-expose/gloo-mesh-gateway.svg)




## Lab 12 - Create the httpbin workspace <a name="lab-12---create-the-httpbin-workspace-"></a>

We're going to create a workspace for the team in charge of the httpbin application.

The platform team needs to create the corresponding `Workspace` Kubernetes objects in the Gloo Mesh management cluster.
We'll create those in the `workspaces` directory in our GitOps repo:

```bash
mkdir -p ${GITOPS_PLATFORM}/${MGMT}/workspaces
```

Let's create the `httpbin` workspace which corresponds to the `httpbin` namespace on `cluster1`:

```bash
cat <<EOF > ${GITOPS_PLATFORM}/${MGMT}/workspaces/httpbin.yaml
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
cat <<EOF > ${GITOPS_HTTPBIN}/${CLUSTER1}/workspace-settings.yaml
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

Track these resources for Kustomize and commit them to the GitOps repo:

```bash
if [ ! -f ${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml ]; then
  cat <<EOF >${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
resources:
EOF
fi

cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/workspaces/kustomization.yaml
- httpbin.yaml
EOF

if [ $(yq 'contains({"resources": ["workspaces"]})' ${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml) = false ]; then
  cat <<EOF >>${GITOPS_PLATFORM}/${MGMT}/kustomization.yaml
- workspaces
EOF
fi

cat <<EOF >>${GITOPS_HTTPBIN}/${CLUSTER1}/kustomization.yaml
- workspace-settings.yaml
EOF

git -C ${GITOPS_REPO_LOCAL} add .
git -C ${GITOPS_REPO_LOCAL} commit -m "httpbin workspace"
git -C ${GITOPS_REPO_LOCAL} push
```
<!--bash
echo -n Waiting for Argo CD to sync...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${MGMT} -n gloo-mesh get workspace httpbin 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
-->



