
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
* [Lab 2 - Deploy the Amazon pod identity webhook](#lab-2---deploy-the-amazon-pod-identity-webhook-)
* [Lab 3 - Deploy Gloo Gateway Enterprise](#lab-3---deploy-gloo-gateway-enterprise-)
* [Lab 4 - Deploy the httpbin demo app](#lab-4---deploy-the-httpbin-demo-app-)
* [Lab 5 - Expose the httpbin application through the gateway](#lab-5---expose-the-httpbin-application-through-the-gateway-)
* [Lab 6 - Execute Lambda functions](#lab-6---execute-lambda-functions-)



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




## Lab 2 - Deploy the Amazon pod identity webhook <a name="lab-2---deploy-the-amazon-pod-identity-webhook-"></a>

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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-amazon-pod-identity-webhook/tests/pods-available.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
-->



## Lab 3 - Deploy Gloo Gateway Enterprise <a name="lab-3---deploy-gloo-gateway-enterprise-"></a>


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
  --version 1.18.14 \
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
        serviceAccount:
          extraAnnotations:
            eks.amazonaws.com/role-arn: arn:aws:iam::253915036081:role/lambda-workshop
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
  settings:
    aws:
      enableServiceAccountCredentials: true
      stsCredentialsRegion: eu-west-1
    disableKubernetesDestinations: true
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
  let cluster = process.env.CLUSTER1;
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
-->



## Lab 4 - Deploy the httpbin demo app <a name="lab-4---deploy-the-httpbin-demo-app-"></a>


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
```bash,norun-workshop
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
-->




## Lab 5 - Expose the httpbin application through the gateway <a name="lab-5---expose-the-httpbin-application-through-the-gateway-"></a>




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
while true; do
  GLOO_PROXY_SVC=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -oname 2>/dev/null || echo "")
  if [[ -n "$GLOO_PROXY_SVC" ]]; then
    echo "Service gloo-proxy-http has been created."
    break
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ $RETRY_COUNT -ge $MAX_RETRIES ]]; then
    echo "Warning: Maximum retries reached. Service gloo-proxy-http could not be found."
    break
  fi

  echo "Waiting for service gloo-proxy-http to be created... Attempt $RETRY_COUNT/$MAX_RETRIES"
  sleep 1
done

# Then, wait for the IP to be assigned
RETRY_COUNT=0
MAX_RETRIES=60
while [[ -z "$PROXY_IP" && $RETRY_COUNT -lt $MAX_RETRIES && -n "$GLOO_PROXY_SVC" ]]; do
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
./scripts/register-domain.sh httpbin.example.com ${IP}
```



Try to access the application through HTTP:

```bash,norun-workshop
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/http.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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

```bash,norun-workshop
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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

```bash,norun-workshop
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/redirect-http-to-https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
-->






## Lab 6 - Execute Lambda functions <a name="lab-6---execute-lambda-functions-"></a>
[<img src="https://img.youtube.com/vi/gD6GLMlP-Qc/maxresdefault.jpg" alt="VIDEO LINK" width="560" height="315"/>](https://youtu.be/gD6GLMlP-Qc "Video Link")

First of all, you need to create an `Upstream` object corresponding to the AWS destination:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: lambda
  namespace: httpbin
spec:
  aws: 
    region: eu-west-1
    roleArn: arn:aws:iam::253915036081:role/lambda-workshop
    lambdaFunctions:
    - lambdaFunctionName: workshop-echo
      logicalName: workshop-echo
    destinationOverrides:
      requestTransformation: true
EOF
```

Finally, you can create a `HTTPRoute` to expose the `echo` Lambda function through the gateway:

```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lambda
  namespace: httpbin
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
        type: Exact
        value: /lambda
    backendRefs:
    - name: lambda
      kind: Upstream
      group: gloo.solo.io
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gloo.solo.io
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

```bash,norun-workshop
curl -k "https://httpbin.example.com/lambda" -d '{"foo":"bar"}'
```

You should get a response like below:

```js,nocopy
{
  "headers": {
    ":authority": "httpbin.example.com",
    ":method": "GET",
    ":path": "/lambda",
    ":scheme": "https",
    "accept": "*/*",
    "user-agent": "curl/8.5.0",
    "x-forwarded-proto": "https",
    "x-request-id": "118e4181-d8d6-4a64-a304-ac247b2a7d84"
  },
  "httpMethod": "GET",
  "multiValueHeaders": {},
  "multiValueQueryStringParameters": {},
  "path": "/lambda",
  "queryString": "",
  "queryStringParameters": {}
}

```

It's very similar to what the `httpbin` application provides. It displays information about the request is has received.
<!--bash
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  it('Checking text \'"path":"/lambda"\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/lambda', body: '"path":"/lambda"', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/gateway-lambda/tests/check-lambda-echo.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
Let's update the `Upstream`:
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: lambda
  namespace: httpbin
spec:
  aws: 
    region: eu-west-1
    roleArn: arn:aws:iam::253915036081:role/lambda-workshop
    lambdaFunctions:
    - lambdaFunctionName: workshop-api-gateway
      logicalName: workshop-api-gateway
    destinationOverrides:
      unwrapAsApiGateway: true
EOF
```

And the `HTTPRoute`:
```bash
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lambda
  namespace: httpbin
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
        type: Exact
        value: /lambda
    backendRefs:
    - name: lambda
      kind: Upstream
      group: gloo.solo.io
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gloo.solo.io
            kind: Parameter
            name: workshop-api-gateway
EOF
```

The `unwrapAsApiGateway` instructs Gloo Gateway to parse the response differently.

You should now be able to invoke the Lambda function using the following command:

```sh
curl -k "https://httpbin.example.com/lambda"
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
curl -k "https://httpbin.example.com/lambda" -I
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Lambda integration is working properly", () => {
  it('Checking text \'"TotalCodeSize": 104330022\' in ' + process.env.CLUSTER1, () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/lambda', body: '"TotalCodeSize": 104330022', match: true }));
  it('Checking headers in ' + process.env.CLUSTER1, () => helpersHttp.checkHeaders({ host: `https://httpbin.example.com`, path: '/lambda', expectedHeaders: [{key: "key", value: "value"}, {key: "x-custom-header", value: "My value,My other value"}], match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/gateway-lambda/tests/check-lambda-api-gateway.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
-->

Let's remove the annotation and restart the pods:

```bash
kubectl --context ${CLUSTER1} -n gloo-system annotate sa -l gloo=kube-gateway "eks.amazonaws.com/role-arn-"
kubectl --context ${CLUSTER1} -n gloo-system rollout restart deploy gloo-proxy-http
```

And also delete the different objects we've created:

```bash
kubectl --context ${CLUSTER1} -n httpbin delete upstream lambda
```






