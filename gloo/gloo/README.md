# Gloo Workshop

Gloo is a feature-rich, Kubernetes-native ingress controller, and next-generation API gateway. Gloo is exceptional in its function-level routing; its support for legacy apps, microservices and serverless; its discovery capabilities; its numerous features; and its tight integration with leading open-source projects. Gloo is uniquely designed to support hybrid applications, in which multiple technologies, architectures, protocols, and clouds can coexist.

The goal of this workshop is to expose some key features of Gloo API Gateway, like traffic management, security, and API management.

## Lab environment

The following Lab environment consists of a Kubernetes environment deployed locally using kind, during this workshop we are going to deploy a demo application and expose/protect it using Gloo.
In this workshop we will:
* Deploy a demo application (istio's book info demo app) on a k8s cluster and expose it through Gloo
* Deploy a second version of the demo app, and route partial traffic to it
* Secure the demo app using TLS
* Secure the demo app using OIDC
* Rate limit the traffic going to the demo app
* Transform a response using Gloo transformations
* Configure access logs


![Lab](images/env.png)

## Lab 0: Demo environment creation

Go the folder `/home/solo/workshops/gloo/gloo` directory using the terminal

```
cd /home/solo/workshops/gloo/gloo
```

### Create a Kubernetes cluster

Deploy a local Kubernetes cluster using this command:
```bash
../../scripts/deploy.sh 1 gloo
```

Then verify that your Kubernetes cluster is ready to be used: 
```bash
../../scripts/check.sh gloo
```

### Install Gloo 
```bash
kubectl config use-context gloo
glooctl upgrade --release=v1.5.0
glooctl install gateway enterprise --version 1.5.0 --license-key $LICENSE_KEY
```


## Lab 1: Traffic management

### Routing to a Kubernetes service 

In this step we will expose a demo service to the outside traffic using Gloo, first lets create a demo service, we will deploy an application called book info: 
 
```
                 +----------------------------------------------------------------------------+
                 |                                                                            |
                 |                                         +---------------+                  |
                 |                                         |-------+       |                  |
                 +-------+                                 ||Product       |                  |
+-Client-------->+  Envoy+-------------------------------->-|Page  |       |                  |
                 +---+---+                                 +-------+       |                  |
                 |   |                                     |Book info      |                  |
                 |   |                                     +v2             |                  |
                 |   |                                     +---------------+                  |
                 |   |                                                                        |
                 |   |                                                                        |
                 |   |                                                                        |
                 | +-v-------+                                                                |
                 | |  Gloo   |                                                                |
                 | |         |                                                                |
                 | +---------+                                                                |
                 |                                                                            |
                 |Kubernetes                                                                  |
                 +----------------------------------------------------------------------------+


```

```bash
kubectl create ns bookinfo 
kubectl -n bookinfo  apply -f https://raw.githubusercontent.com/istio/istio/1.7.3/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl delete deployment reviews-v1 reviews-v3 -n bookinfo
```
Book info app has 3 versions of a micro service called reviews, let's keep only the versions 2 of the reviews micro service for this tutorial, we will add the other versions latter.


Gloo uses a discovery mechanism to create Upstreams automatically, Upstreams can be created manually too using CRDs.
After a few seconds, Gloo will discover the newly created service and create a corresponding Upstream called: **bookinfo-productpage-9080** (namespace-service-port), to verify that the upstream got created run the following command: 

```bash
until glooctl get upstream bookinfo-productpage-9080 
do
    echo waiting for upstream bookinfo-productpage-9080 to be discovered
    sleep 3
done
```


Now that the upstream CRD has been created, we need to create a virtual service that routes to it:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: demo
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
              name: bookinfo-productpage-9080
              namespace: gloo-system
EOF
```

The creation of the virtual service exposes the Kubernetes service through the gateway, we can make a test using the following command to open the browser:

```
/opt/google/chrome/chrome $(glooctl proxy url)/productpage
```

It should return the book info demo application webpage, note that the review stars are black. 

### Routing to multiple Upstreams

In this step we are going to create a virtual service that routes to two different Upstreams, the first step is to create a version 3 of our demo service: 


```bash
kubectl create ns bookinfo-beta 
kubectl -n bookinfo-beta  apply -f https://raw.githubusercontent.com/istio/istio/1.7.3/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl delete deployment reviews-v1 reviews-v2 -n bookinfo-beta
EOF
```
Book info app has 3 versions of a micro service called reviews, let's keep only the versions 3 of the reviews micro service for this application deployment.


Gloo uses a discovery mechanism to create Upstreams automatically, Upstreams can be created manually too using CRDs.
After a few seconds, Gloo will discover the newly created service and create a corresponding Upstream called: **bookinfo-beta-productpage-9080** (namespace-service-port), to verify that the upstream got created run the following command: 

```bash
until glooctl get upstream bookinfo-beta-productpage-9080 2> /dev/null
do
    echo waiting for upstream bookinfo-beta-productpage-9080 to be discovered
    sleep 3
done
```

Now we can route to multiple Upstreams by creating the following Virtual service CRD: 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: demo
  namespace: gloo-system
spec:
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
        # ----------------------- Multi Destination ----------------------
            multi:
                destinations:
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-productpage-9080
                          namespace: gloo-system
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-beta-productpage-9080
                          namespace: gloo-system
EOF
```

To check that Gloo is routing to the two different Upstreams (50% traffic each), run the following command, you should be able to see v1 and v2 as a response from service echo-v1 and echo-v2: 

```
/opt/google/chrome/chrome $(glooctl proxy url)/productpage 
```

## Lab 2: Security
In this chapter, we will explore some Gloo features related to security. 


### Network Encryption - Server TLS
Let's first create a private key and a self-signed certificate to use in our echo Virtual Service:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

Then we have store them as a secret in Kubernetes running the following command:
```bash
kubectl create secret tls upstream-tls --key tls.key \
   --cert tls.crt --namespace gloo-system
```

To setup Server Tls we have to add the SSL config to the Virtual Service:
```bash

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: demo
  namespace: gloo-system
spec:
  # The SSL config below activate TLS on the Virtual Service
  # ------------
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system
  # ------------    
  virtualHost:
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /productpage
        routeAction:
            multi:
                destinations:
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-productpage-9080
                          namespace: gloo-system
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-beta-productpage-9080
                          namespace: gloo-system
EOF
```

Now the gateway is secured through TLS, to test the TLS configuration run the following command: 

```bash
curl -k $(glooctl proxy url --port https) -v
```


### OIDC Support
In the following chapter we will secure our API using an IDP, lets first start by installing dex (IDP) on our cluster:
 

```bash

cat > dex-values.yaml <<EOF
service:
    type: LoadBalancer
config:
  # The base path of dex and the external name of the OpenID Connect service.
  # This is the canonical URL that all clients MUST use to refer to dex. If a
  # path is provided, dex's HTTP service will listen at a non-root URL.
  issuer: http://dex.gloo-system.svc.cluster.local:32000

  # Instead of reading from an external storage, use this list of clients.
  staticClients:
  - id: gloo
    redirectURIs:
    - "$(glooctl proxy url --port https)/callback"
    name: 'GlooApp'
    secret: secretvalue
  
  # A static list of passwords to login the end user. By identifying here, dex
  # won't look in its underlying storage for passwords.
  staticPasswords:
  - email: "admin@example.com"
    # bcrypt hash of the string "password"
    hash: "\$2a\$10\$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"
    username: "admin"
    userID: "08a8684b-db88-4b73-90a9-3cd1661f5466"
EOF

```

Then we can install dex: 

```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm install dex --namespace gloo-system stable/dex -f dex-values.yaml
```

Let save dex IP in an environment variable for future use:

```bash
export DEX_IP=$(kubectl get service dex --namespace gloo-system  --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
```
Because we are using a local Kubernetes cluster In this example we need to configure the dex host to point to the Load balancer IP:

```bash
echo "$DEX_IP dex.gloo-system.svc.cluster.local" | sudo tee -a /etc/hosts
```

The next step is to setup the authentication in the Virtual Service, for this we will have to create a Kubernetes Secret that contains the OIDC secret:

```bash
glooctl create secret oauth --client-secret secretvalue oauth
```

Then we will create an AuthConfig which is a CRD that configure the authentication in Gloo: 

```bash
kubectl apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oidc-dex
  namespace: gloo-system
spec:
  configs:
  - oauth:
      app_url: "$(glooctl proxy url --port https)"
      callback_path: /callback
      client_id: gloo
      client_secret_ref:
        name: oauth
        namespace: gloo-system
      issuer_url: http://$DEX_IP:32000
      scopes:
      - email
EOF
```

Finally we activate the authentication on the Virtual service using the AuthConfig:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: demo
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system  
  virtualHost:
# ------------------- OIDC -------------------
    options:
      extauth:
        configRef:
          name: oidc-dex
          namespace: gloo-system
#---------------------------------------------          
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            multi:
                destinations:
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-productpage-9080
                          namespace: gloo-system
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-beta-productpage-9080
                          namespace: gloo-system
EOF
```

To test the authentication, run the following command to open the browser: 

```
/opt/google/chrome/chrome $(glooctl proxy url --port https)/productpage 
```

If you login as the **admin@example.com** user with the password **password**, Gloo should redirect you to the sample application echo.

### Rate Limiting

To enable rate limit on a Virtual Service we will first create a rate limit config CRD:

```bash
kubectl apply -f - << EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: global-limit
  namespace: gloo-system
spec:
  raw:
    descriptors:
    - key: generic_key
      value: count
      rateLimit:
        requestsPerUnit: 10
        unit: MINUTE
    rateLimits:
    - actions:
      - genericKey:
          descriptorValue: count
EOF
```

Now let update our Virtual Service to include the rate limit config: 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: demo
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system  
  virtualHost:
    options:
      extauth:
        configRef:
          name: oidc-dex
          namespace: gloo-system
# ---------------- Rate limit config ------------------
      rateLimitConfigs:
        refs:
        - name: global-limit
          namespace: gloo-system
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            multi:
                destinations:
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-productpage-9080
                          namespace: gloo-system
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-beta-productpage-9080
                          namespace: gloo-system
EOF
```

To test the rate limiting, run the following command to open the browser, then refresh the browser a couple of times, you should see a 429 message indicating that the rate limit got enforced: 

```
/opt/google/chrome/chrome $(glooctl proxy url --port https)/productpage 
```


## LAB 3: Data transformation
In this section we will explore the request transformations using Gloo.

### Response transformation 
The following example demonstrates how to modify a response status code if a field exists in the response body for example. 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: demo
  namespace: gloo-system
spec:
  sslConfig:
    secretRef:
      name: upstream-tls
      namespace: gloo-system  
  virtualHost:
    options:
      extauth:
        configRef:
          name: oidc-dex
          namespace: gloo-system
      rateLimitConfigs:
        refs:
        - name: global-limit
          namespace: gloo-system
# ---------------- Transformation ------------------          
      transformations:
        responseTransformation:
          transformationTemplate:
            parseBodyBehavior: DontParse
            body: 
              text: '{% if header(":status") == "429" %}<html><body style="background-color:powderblue;"><h1>Too many Requests!</h1><p>Try again after 10 seconds</p></body></html>{% else %}{{ body() }}{% endif %}'    
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            multi:
                destinations:
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-productpage-9080
                          namespace: gloo-system
                - weight: 5
                  destination:
                      upstream:
                          name: bookinfo-beta-productpage-9080
                          namespace: gloo-system
EOF
```

## LAB 4: Logging

### Access Logs


Lets first activate the access logs on the gateway: 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: Gateway
metadata:
  labels:
    app: gloo
  name: gateway-proxy
  namespace: gloo-system
proxyNames:
- gateway-proxy
spec:
  bindAddress: '::'
  bindPort: 8080
  httpGateway: {}
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

Run the following curl the simulate some traffic:
```bash
curl -s -o /dev/null -w "%{http_code}" --location  "$(glooctl proxy url)/request"
```

Check the logs running the following command:
```bash
kubectl logs -n gloo-system deployment/gateway-proxy | grep '^{' | jq
```
