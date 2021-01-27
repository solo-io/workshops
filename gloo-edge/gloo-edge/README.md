# Gloo Edge Workshop

Gloo Edge is a feature-rich, Kubernetes-native ingress controller, and next-generation API gateway. Gloo is exceptional in its function-level routing; its support for legacy apps, microservices and serverless; its discovery capabilities; its numerous features; and its tight integration with leading open-source projects. Gloo is uniquely designed to support hybrid applications, in which multiple technologies, architectures, protocols, and clouds can coexist.

The goal of this workshop is to expose some key features of Gloo API Gateway, like traffic management, security, and API management.

## Lab Environment

The following Lab environment consists of a Kubernetes environment deployed locally using kind, during this workshop we are going to deploy a demo application and expose/protect it using Gloo Edge.

In this workshop we will:
* Deploy a demo application (Istio's [bookinfo](https://istio.io/latest/docs/examples/bookinfo/) demo app) on a k8s cluster and expose it through Gloo Edge
* Deploy a second version of the demo app and route traffic to both versions
* Secure the demo app using TLS
* Secure the demo app using OIDC
* Rate limit the traffic going to the demo app
* Transform a response using Gloo transformations
* Configure access logs
* Use several of these features together to configure an advanced OIDC workflow

## Lab 0: Demo Environment Creation

Go to the `/home/solo/workshops/gloo-edge/gloo-edge` directory:

```
cd /home/solo/workshops/gloo-edge/gloo-edge
```

### Create a Kubernetes Cluster

Deploy a local Kubernetes cluster using this command:

```bash
../../scripts/deploy.sh 1 gloo-edge
```

Then verify that your Kubernetes cluster is ready: 

```bash
../../scripts/check.sh gloo-edge
```

### Install Gloo 

Run the commands below to deploy Gloo Edge Enterprise:

```bash
kubectl config use-context gloo-edge
glooctl upgrade --release=v1.6.3
glooctl install gateway enterprise --version 1.6.3 --license-key $LICENSE_KEY
```

Gloo Edge can also be deployed using a Helm chart.

Use the following commands to wait for the Gloo Edge components to be deployed:

```bash
until kubectl get ns gloo-system
do
  sleep 1
done

until [ $(kubectl -n gloo-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  echo "Waiting for all the gloo-system pods to become ready"
  sleep 1
done
```

## Lab 1: Traffic Management

### Routing to a Kubernetes Service 

In this step we will expose a demo service to the outside world using Gloo Edge.

First let's deploy a demo application called bookinfo:

```bash
kubectl create ns bookinfo 
kubectl -n bookinfo  apply -f https://raw.githubusercontent.com/istio/istio/1.7.3/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl delete deployment reviews-v1 reviews-v3 -n bookinfo
```
 
```
                 +----------------------------------------------------------------------------+
                 |                                                                            |
                 |                                         +---------------+                  |
                 |                                         |-------+       |                  |
                 +-------+                                 ||Product       |                  |
+-Client-------->+  Envoy+-------------------------------->-|Page  |       |                  |
                 +---+---+                                 +-------+       |                  |
                 |   |                                     |Bookinfo       |                  |
                 |   |                                     +v2             |                  |
                 |   |                                     +---------------+                  |
                 |   |                                                                        |
                 |   |                                                                        |
                 |   |                                                                        |
                 | +-v------------+                                                           |
                 | |  Gloo Edge   |                                                           |
                 | |              |                                                           |
                 | +--------------+                                                           |
                 |                                                                            |
                 |Kubernetes                                                                  |
                 +----------------------------------------------------------------------------+
```

The bookinfo app has 3 versions of a microservice called reviews.  We will keep only the version 2 of the reviews microservice for this step and will add the other versions later.  An easy way to distinguish among the different versions in the web interface is to look at the stars: v1 displays no stars in the reviews, v2 displays black stars, and v3 displays red stars.


Gloo Edge uses a discovery mechanism to create Upstreams automatically, but Upstreams can be also created manually using Kubernetes CRDs.

After a few seconds, Gloo Edge will discover the newly created service and create an Upstream called  `bookinfo-productpage-9080` (Gloo Edge uses the convention `namespace-service-port` for the discovered Upstreams).

To verify that the Upstream was created properly, run the following command: 

```bash
until glooctl get upstream bookinfo-productpage-9080 2> /dev/null
do
    echo waiting for upstream bookinfo-productpage-9080 to be discovered
    sleep 3
done
```

It should return the discovered upstream with an `Accepted` status: 

```
+---------------------------+------------+----------+----------------------------+
|         UPSTREAM          |    TYPE    |  STATUS  |          DETAILS           |
+---------------------------+------------+----------+----------------------------+
| bookinfo-productpage-9080 | Kubernetes | Accepted | svc name:      productpage |
|                           |            |          | svc namespace: bookinfo    |
|                           |            |          | port:          9080        |
|                           |            |          |                            |
+---------------------------+------------+----------+----------------------------+
```

Now that the Upstream CRD has been created, we need to create a Gloo Edge Virtual Service that routes traffic to it:

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

The creation of the Virtual Service exposes the Kubernetes service through the gateway.

We can access the application using the web browser by running the following command:

```
chromium $(glooctl proxy url)/productpage
```

It should return the bookinfo application webpage. Note that the review stars are black (v2).

![Lab](images/1.png)


### Routing to Multiple Upstreams

In many cases, we need to route traffic to two different versions of an application to test a new feature. In this step, we are going to update the Virtual Service to route traffic to two different Upstreams:

The first step is to create a new deployment of the demo application, this time with the version 3 of the reviews microservice: 

```bash
kubectl create ns bookinfo-beta 
kubectl -n bookinfo-beta apply -f https://raw.githubusercontent.com/istio/istio/1.7.3/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl delete deployment reviews-v1 reviews-v2 -n bookinfo-beta
```

```
                 +----------------------------------------------------------------------------+
                 |                                                                            |
                 |                                         +---------------+                  |
                 |                                         |-------+       |                  |
                 +-------+            50%                  ||Product       |                  |
+-Client-------->+  Envoy+-------------------------------->-|Page  |       |                  |
                 |       |            50%                  +-------+       |                  |
                 |       +----------------------------+    |Bookinfo       |                  |
                 +---+---+                            |    +v2             |                  |
                 |   |                                |    +---------------+                  |
                 |   |                                |                                       |
                 |   |                                |    +---------------+                  |
                 |   |                                |    |-------+       |                  |
                 | +-v------------+                   +--->-|Product       |                  |
                 | |  Gloo Edge   |                        ||Page  |       |                  |
                 | |              |                        +-------+       |                  |
                 | +--------------+                        |Bookinfo beta  |                  |
                 |                                         +v3             |                  |
                 |Kubernetes                               |---------------+                  |
                 +----------------------------------------------------------------------------+
```

Verify that the Upstream for the beta application was created, using the following command: 


```bash
until glooctl get upstream bookinfo-beta-productpage-9080 2> /dev/null
do
    echo waiting for upstream bookinfo-beta-productpage-9080 to be discovered
    sleep 3
done
```

Now we can route to multiple Upstreams by updating the Virtual Service as follow: 

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

We should see either the black star reviews (v2) or the new red star reviews (v3) when refreshing the page.

![Lab](images/2.png)

## Lab 2: Security

In this lab, we will explore some Gloo Edge features related to security. 

### Network Encryption - Server TLS

In this step we are going to secure our demo application using TLS.

Let's first create a private key and a self-signed certificate to use in our demo Virtual Service:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
```

Then we have store them in a Kubernetes secret running the following command:

```bash
kubectl create secret tls upstream-tls --key tls.key \
   --cert tls.crt --namespace gloo-system
```

To setup TLS we have to add the SSL config to the Virtual Service:

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

Now the application is securely exposed through TLS. To test the TLS configuration, run the following command to open the browser (note that now the traffic is served using https): 

```
chromium $(glooctl proxy url --port https)/productpage 
```

### OIDC Support

In many use cases, we need to restrict the access to our applications to authenticated users. In this step, we will secure our application using an OIDC Identity Provider.

Let's start by installing Keycloak:

```bash
kubectl create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes-examples/keycloak.yaml
kubectl rollout status deploy/keycloak
```

<!--bash
sleep 30
-->

Then, we need to configure it and create a user with the credentials `user1/password`:

```bash
# Get Keycloak URL and token
KEYCLOAK_URL=http://$(kubectl get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/auth
KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)

# Create initial token to register the client
read -r client token <<<$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' $KEYCLOAK_URL/admin/realms/master/clients-initial-access | jq -r '[.id, .token] | @tsv')

# Register the client
read -r id secret <<<$(curl -X POST -d "{ \"clientId\": \"${client}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${token}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default| jq -r '[.id, .secret] | @tsv')

# Add allowed redirect URIs
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"serviceAccountsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["https://172.18.0.210/callback", "http://portal.example.com/callback"]}' $KEYCLOAK_URL/admin/realms/master/clients/${id}

# Add the group attribute in the JWT token returned by Keycloak
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models

# Create a user
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@solo.io", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users
```

The architecture looks like this now:

```
                 +----------------------------------------------------------------------------+
                 |                                                                            |
                 |                                         +---------------+                  |
                 |                                         |-------+       |                  |
                 +-------+            50%                  ||Product       |                  |
+-Client-------->+  Envoy+-------------------------------->-|Page  |       |                  |
                 |       |            50%                  +-------+       |                  |
                 |       +----------------------------+    |Bookinfo       |                  |
                 +---+---------------------+          |    +v2             |                  |
                 |   |                     |          |    +---------------+                  |
                 |   |                    Auth        |                                       |
                 |   |                     |          |    +---------------+                  |
                 |   |                     |          |    |-------+       |                  |
                 | +-v------------+        |          +--->-|Product       |                  |
                 | |  Gloo Edge   |   +----v-----+         ||Page  |       |                  |
                 | |              |   |          |         +-------+       |                  |
                 | +--------------+   |   IDP    |         |Bookinfo beta  |                  |
                 |                    +----------+         +v3             |                  |
                 |Kubernetes                               |---------------+                  |
                 +----------------------------------------------------------------------------+
```

The next step is to configure the authentication in the Virtual Service. For this we will have to create a Kubernetes Secret that contains the OIDC secret:

```bash
glooctl create secret oauth --namespace gloo-system --name keycloak-oauth --client-secret ${secret}
```

Then we will create an AuthConfig, which is a Gloo Edge CRD that contains authentication information: 

```bash
kubectl apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: keycloak-oauth
  namespace: gloo-system
spec:
  configs:
  - oauth2:
      oidcAuthorizationCode:
        appUrl: https://172.18.0.210
        callbackPath: /callback
        clientId: ${client}
        clientSecretRef:
          name: keycloak-oauth
          namespace: gloo-system
        issuerUrl: "${KEYCLOAK_URL}/realms/master/"
        scopes:
        - email
EOF
```

Finally we activate the authentication on the Virtual Service by referencing the AuthConfig:

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
          name: keycloak-oauth
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

To test the authentication, refresh the web browser.

If you login as the `user1` user with the password `password`, Gloo should redirect you to the application.

![Lab](images/3.png)

### Rate Limiting

In this step, we are going to use rate limiting to protect our demo application.

To enable rate limiting on our Virtual Service, we will first create a RateLimitConfig CRD:

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

Now let's update our Virtual Service to use the bookinfo application with the new rate limit enforced: 

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
          name: keycloak-oauth
          namespace: gloo-system
# ---------------- Rate limit config ------------------
      rateLimitConfigs:
        refs:
        - name: global-limit
          namespace: gloo-system
#------------------------------------------------------
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

To test rate limiting, refresh the browser until you see a 429 message. 

![Lab](images/4.png)

### Web Application Firewall (WAF)

A web application firewall (WAF) protects web applications by monitoring, filtering and blocking potentially harmful traffic and attacks that can overtake or exploit them.

Gloo Edge Enterprise includes the ability to enable the ModSecurity Web Application Firewall for any incoming and outgoing HTTP connections. 

Let's update our Virtual Service to restrict the characters allowed for usernames.

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
          name: keycloak-oauth
          namespace: gloo-system
      rateLimitConfigs:
        refs:
        - name: global-limit
          namespace: gloo-system
# ---------------- Web Application Firewall -----------
      waf:
        customInterventionMessage: 'Username should only contain letters'
        ruleSets:
        - ruleStr: |
            # Turn rule engine on
            SecRuleEngine On
            SecRule ARGS:/username/ "[^a-zA-Z]" "t:none,phase:2,deny,id:6,log,msg:'allow only letters in username'"
#------------------------------------------------------
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

The rule means that a username can only contains letters.

Click on the `Sign in` button and try to login with a user called `user1` (the password doesn't matter).

You should get the following error message:

```
Username should only contain letters
```

## Lab 3: Data Transformation

In this section we will explore how to transform requests using Gloo Edge.

### Response Transformation

The following example demonstrates how to modify a response using Gloo Edge. We are going to return a basic html page when the response code is 429 (rate limited).  

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
          name: keycloak-oauth
          namespace: gloo-system
      rateLimitConfigs:
        refs:
        - name: global-limit
          namespace: gloo-system
      waf:
        customInterventionMessage: 'Username should only contain letters'
        ruleSets:
        - ruleStr: |
            # Turn rule engine on
            SecRuleEngine On
            SecRule ARGS:/username/ "[^a-zA-Z]" "t:none,phase:2,deny,id:6,log,msg:'allow only letters in username'"
# ---------------- Transformation ------------------          
      transformations:
        responseTransformation:
          transformationTemplate:
            parseBodyBehavior: DontParse
            body: 
              text: '{% if header(":status") == "429" %}<html><body style="background-color:powderblue;"><h1>Too many Requests!</h1><p>Try again after 10 seconds</p></body></html>{% else %}{{ body() }}{% endif %}'    
#---------------------------------------------------
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

Refreshing your browser a couple times, you should be able to see a styled HTML page indicating that you reached the limit. 

## Lab 4: Delegation

Gloo Edge provides a feature referred to as delegation. Delegation allows a complete routing configuration to be assembled from separate config objects. The root config object delegates responsibility to other objects, forming a tree of config objects. The tree always has a Virtual Service as its root, which delegates to any number of Route Tables. Route Tables can further delegate to other Route Tables.

Use cases for delegation include:

- Allowing multiple tenants to own add, remove, and update routes without requiring shared access to the root-level Virtual Service
- Sharing route configuration between Virtual Services
- Simplifying blue-green routing configurations by swapping the target Route Table for a delegated route.
- Simplifying very large routing configurations for a single Virtual Service
- Restricting ownership of routing configuration for a tenant to a subset of the whole Virtual Service.

Let's rewrite our Virtual Service to use delegate the routing information to a Route Table:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteTable
metadata:
  name: demo
  namespace: gloo-system
spec:
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
---
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
          name: keycloak-oauth
          namespace: gloo-system
      rateLimitConfigs:
        refs:
        - name: global-limit
          namespace: gloo-system
      waf:
        customInterventionMessage: 'Username should only contain letters'
        ruleSets:
        - ruleStr: |
            # Turn rule engine on
            SecRuleEngine On
            SecRule ARGS:/username/ "[^a-zA-Z]" "t:none,phase:2,deny,id:6,log,msg:'allow only letters in username'"
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
        delegateAction:
          ref:
            name: 'demo'
            namespace: 'gloo-system'
EOF
```

As you can see, in this case the security options remains in the `VirtualService` (and can be managed by the infrastructure team) whil the routing options are now in the `RouteTable` (and can be managed by the application team).

## Lab 5: Observability

### Metrics

Gloo Edge automatically generates a Grafana dashboard for whole-cluster stats (overall request timing, aggregated response codes, etc.), and dynamically generates a more-specific dashboard for each upstream that is tracked.

Let's run the following command to allow access ot the Grafana UI:

```
kubectl port-forward -n gloo-system svc/glooe-grafana 8001:80
```

You can now access the Grafana UI at http://localhost:8001 and login with `admin/admin`.

You can take a look at the `Gloo -> Envoy Statistics` Dashboard that provides global statistics:

![Grafana Envoy Statistics](images/grafana1.png)

You can also see that Gloo is dynamically generating a Dashboard for each Upstream:

![Grafana Upstream](images/grafana2.png)

You can run the following command to see the default template used to generate these templates:

```
kubectl -n gloo-system get cm gloo-observability-config -o yaml
```

If you want to customize how these per-upstream dashboards look, you can provide your own template to use by writing a Grafana dashboard JSON representation to that config map key. 

### Access Logging

Access logs are important to check if a system is behaving correctly and for debugging purposes. Logs aggregators (datadog, splunk..etc) use agents deployed on the Kubernetes clusters to collect logs.  

Lets first enable access logging on the gateway: 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: Gateway
metadata:
  labels:
    app: gloo
  name: gateway-proxy-ssl
  namespace: gloo-system
spec:
  bindAddress: '::'
  bindPort: 8443
  httpGateway: {}
  proxyNames:
  - gateway-proxy
  ssl: true
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

```
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
```

Refresh your browser a couple times to generate some traffic.

Check the access logs running the following command:

```bash
kubectl logs -n gloo-system deployment/gateway-proxy | grep '^{' | jq
```

If you refresh the browser to send additional requests until the rate limiting threshold is exceeded, then you will see both `200 OK` and `429 Too Many Requests` responses in the access logs, as in the example below.

```
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
  "upstreamName": "bookinfo-beta-productpage-9080_gloo-system",
  "responseCode": 200
}
{
  "httpMethod": "GET",
  "systemTime": "2020-10-22T21:38:19.168Z",
  "targetDuration": null,
  "path": "/productpage",
  "protocol": "HTTP/2",
  "responseFlags": "-",
  "clientDuration": 3,
  "number": null,
  "responseCode": 429,
  "upstreamName": null,
  "messageType": null,
  "requestId": "494c3cc7-e476-4414-8c50-499f3619f84c"
}
```

These logs can now be collected by the Log aggregator agents and potentially forwarded to your favorite enterprise logging service. 

The following labs are optional. The instructor will go through them.

## Lab 6: Advanced Authentication Workflows

As you've seen in the previous lab, Gloo Edge supports authentication via OpenID Connect (OIDC). OIDC is an identity layer on top of the OAuth 2.0 protocol. In OAuth 2.0 flows, authentication is performed by an external Identity Provider (IdP) which, in case of success, returns an Access Token representing the user identity. The protocol does not define the contents and structure of the Access Token, which greatly reduces the portability of OAuth 2.0 implementations.

The goal of OIDC is to address this ambiguity by additionally requiring Identity Providers to return a well-defined ID Token. OIDC ID tokens follow the JSON Web Token standard and contain specific fields that your applications can expect and handle. This standardization allows you to switch between Identity Providers – or support multiple ones at the same time – with minimal, if any, changes to your downstream services; it also allows you to consistently apply additional security measures like Role-based Access Control (RBAC) based on the identity of your users, i.e. the contents of their ID token.

As explained above, Keycloak will return a JWT token, so we’ll use Gloo to extract some claims from this token and to create new headers corresponding to these claims.

Finally, we’ll see how Gloo Edge RBAC rules can be created to leverage the claims contained in the JWT token.

First of all, let's deploy a new application that returns information about the requests it receives:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: httpbin
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      version: v1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      serviceAccountName: httpbin
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        ports:
        - containerPort: 80
EOF
```

Let’s modify the Virtual Service using the yaml below:

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
          name: keycloak-oauth
          namespace: gloo-system
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            single:
              upstream:
                name: default-httpbin-8000
                namespace: gloo-system
EOF
```

Let's take a look at what the application returns:

```
chromium $(glooctl proxy url --port https)/get 
```

You should get the following output:

```
{
  "args": {}, 
  "headers": {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", 
    "Accept-Encoding": "gzip, deflate, br", 
    "Accept-Language": "en-US,en;q=0.9", 
    "Content-Length": "0", 
    "Cookie": "id_token=eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJZd18zVTBoOFFkbGpsODBiSkQxUDhzbUtud0ZYYkVJZE0xZjlMU3R1N2E0In0.eyJleHAiOjE2MDc0MTkxNjksImlhdCI6MTYwNzQxOTEwOSwiYXV0aF90aW1lIjoxNjA3NDE4NzQ5LCJqdGkiOiI0NzMyNjU5Mi0xY2Q0LTQzNjItODA5ZS01NzA2YzU5MTU2MzYiLCJpc3MiOiJodHRwOi8vMTcyLjE4LjAuMjExOjgwODAvYXV0aC9yZWFsbXMvbWFzdGVyIiwiYXVkIjoiZjg3YzAzOWQtNTdiZi00NTQzLWExZjAtOGIyMmZjNmY5ZTYwIiwic3ViIjoiN2Q0N2I2YmYtOTcyYi00OGRjLWI3YjctM2U5N2NlZGM4NjM1IiwidHlwIjoiSUQiLCJhenAiOiJmODdjMDM5ZC01N2JmLTQ1NDMtYTFmMC04YjIyZmM2ZjllNjAiLCJzZXNzaW9uX3N0YXRlIjoiOGJmNjAzMTYtY2NmYi00ZWZkLWFiNDgtOTc5MmQzNTkzNzBhIiwiYXRfaGFzaCI6InJxZHVfVEVucHZaUElDSm1SblMwM0EiLCJhY3IiOiIwIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyMSIsImVtYWlsIjoidXNlcjFAc29sby5pbyIsImdyb3VwIjoidXNlcnMifQ.FnuiURxT6Y8NZGKcFxlud0jgz9QieZiYx5zB0VXeIMeTrKvcmWxkFEViIF22MvaGh2jYRSoSCCqiR3JwMgmMTtDU2NPuAL6FyLbeeOOxOw6h7zc4XRKHzzwPH4p8l6Np4GLgHEPzlP_ZGochgieeYGA5kKzV2r6BrFFoKAbHTio5waJlnyDQQ6_EbBfHngrgiW8ngrMD5RiryhJ-idaNae_bM0KrXTow0xVFpOlo59E03N_QamJeegAPZnwpm5meEMN1w8uHm2WRe3NtUxb2sLBoQoJIKZj-7AsRNPzfJ5kbUQ250Sdbeeo4t6mmO5Vf472DkxzyPho3gf-avLINLg; access_token=eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJZd18zVTBoOFFkbGpsODBiSkQxUDhzbUtud0ZYYkVJZE0xZjlMU3R1N2E0In0.eyJleHAiOjE2MDc0MTkxNjksImlhdCI6MTYwNzQxOTEwOSwiYXV0aF90aW1lIjoxNjA3NDE4NzQ5LCJqdGkiOiJhNmI5MDk5MC0zYjBhLTQwZjItYmI0Yy0yMTc0NTlmZjUyMjQiLCJpc3MiOiJodHRwOi8vMTcyLjE4LjAuMjExOjgwODAvYXV0aC9yZWFsbXMvbWFzdGVyIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6IjdkNDdiNmJmLTk3MmItNDhkYy1iN2I3LTNlOTdjZWRjODYzNSIsInR5cCI6IkJlYXJlciIsImF6cCI6ImY4N2MwMzlkLTU3YmYtNDU0My1hMWYwLThiMjJmYzZmOWU2MCIsInNlc3Npb25fc3RhdGUiOiI4YmY2MDMxNi1jY2ZiLTRlZmQtYWI0OC05NzkyZDM1OTM3MGEiLCJhY3IiOiIwIiwicmVhbG1fYWNjZXNzIjp7InJvbGVzIjpbIm9mZmxpbmVfYWNjZXNzIiwidW1hX2F1dGhvcml6YXRpb24iXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6Im9wZW5pZCBlbWFpbCBwcm9maWxlIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyMSIsImVtYWlsIjoidXNlcjFAc29sby5pbyIsImdyb3VwIjoidXNlcnMifQ.NT4_BFfaDvngCKkg2X1_8eIiyA76sCwIbNo0nFdnelg9wr1PBCW1mFLh8PvD4NQjy26KuYZswMoGtwP5y-6PAuHzoH9Pxe2peeLEGuWhhDfhjE9RknG9qFxVS1jV3-i3rTewoPMJKHFP29Ocmkl9CB31zShOyhsj19YTYWy7wB9Da_GMH7kRjmvYaiZOsNdZ8LVNBeFTp0QYz1xTss-KABBXJNbC164aokWGDwe2wDPyNPf9ZYoEQ4zwjX4Qt5-hBaBnMIH6Je4hei05pjZikiuDcW4KvGOEAfFR6xPWLW0pfxfmuKghAigYhpq5BmLIisgByN0jsfVGRcKkD1_gXQ", 
    "Host": "172.18.0.210", 
    "Sec-Fetch-Dest": "document", 
    "Sec-Fetch-Mode": "navigate", 
    "Sec-Fetch-Site": "none", 
    "Sec-Fetch-User": "?1", 
    "Upgrade-Insecure-Requests": "1", 
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36", 
    "X-Envoy-Expected-Rq-Timeout-Ms": "15000", 
    "X-User-Id": "http://172.18.0.211:8080/auth/realms/master;7d47b6bf-972b-48dc-b7b7-3e97cedc8635"
  }, 
  "origin": "192.168.149.15", 
  "url": "https://172.18.0.210/get"
}
```

As you can see, the browser has sent the cookie as a header in the HTTP request.

### Request transformation

Gloo is able to perform advanced transformations of the request and response.

Let’s modify the Virtual Service using the yaml below:

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
          name: keycloak-oauth
          namespace: gloo-system
# -------------Extract Token------------------
      stagedTransformations:
        early:
          requestTransforms:
            - requestTransformation:
                transformationTemplate:
                  extractors:
                    token:
                      header: 'cookie'
                      regex: 'id_token=(.*); .*'
                      subgroup: 1
                  headers:
                    jwt:
                      text: '{{ token }}'
#--------------------------------------------- 
#--------------Remove Header------------------ 
      headerManipulation:
        requestHeadersToRemove:
        - "cookie"
#--------------------------------------------- 
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            single:
              upstream:
                name: default-httpbin-8000
                namespace: gloo-system
EOF
```

This transformation is using a regular expression to extract the JWT token from the `cookie` header, creates a new `jwt` header that contains the token and removes the `cookie` header.

Here is the output you should get if you refresh the web page:

```
{
  "args": {}, 
  "headers": {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", 
    "Accept-Encoding": "gzip, deflate, br", 
    "Accept-Language": "en-US,en;q=0.9", 
    "Cache-Control": "max-age=0", 
    "Content-Length": "0", 
    "Host": "172.18.0.210", 
    "Jwt": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJZd18zVTBoOFFkbGpsODBiSkQxUDhzbUtud0ZYYkVJZE0xZjlMU3R1N2E0In0.eyJleHAiOjE2MDc0MTkyOTMsImlhdCI6MTYwNzQxOTIzMywiYXV0aF90aW1lIjoxNjA3NDE4NzQ5LCJqdGkiOiI2NWExYzM0Ni0wNTY5LTQwNWUtYTNmZi0wOTVjZGE3MGRiYmMiLCJpc3MiOiJodHRwOi8vMTcyLjE4LjAuMjExOjgwODAvYXV0aC9yZWFsbXMvbWFzdGVyIiwiYXVkIjoiZjg3YzAzOWQtNTdiZi00NTQzLWExZjAtOGIyMmZjNmY5ZTYwIiwic3ViIjoiN2Q0N2I2YmYtOTcyYi00OGRjLWI3YjctM2U5N2NlZGM4NjM1IiwidHlwIjoiSUQiLCJhenAiOiJmODdjMDM5ZC01N2JmLTQ1NDMtYTFmMC04YjIyZmM2ZjllNjAiLCJzZXNzaW9uX3N0YXRlIjoiOGJmNjAzMTYtY2NmYi00ZWZkLWFiNDgtOTc5MmQzNTkzNzBhIiwiYXRfaGFzaCI6IkV5ZUtXbjhELWdZQlIxOWhpaEg2YXciLCJhY3IiOiIwIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJ1c2VyMSIsImVtYWlsIjoidXNlcjFAc29sby5pbyIsImdyb3VwIjoidXNlcnMifQ.nrwvo8F1jKjyQCED95gLYAvYi9TxRRDW6_Z8WC8c61WU1hHUMsHJG77G-CG0T8NwORG2cB7dlP3iu_M_e9BaONCsCZsUZUCpwV5w7ZsFxbbMy4jWSuQyd38kTnoFyMHQGxCXGI0VS02TqsAaO6oQIjwoC6Ib_6MKxsgYNrIGhp7FihO7D1rfBW-Ggvqx88INFSMCKWOft6xzYvBS6JQcDjLXMAkc4TOmTBFZkfXpepsKlDjFxW5DreaDZXv1zIUM-dG-1MRk_N5CPg_OWgnjiF4gKWTqCG8hJd__QPwo4RO7FqM5BM8o0u_lugNbgHlB-09GjO7NTZiZHiQB3HxWVw", 
    "Sec-Fetch-Dest": "document", 
    "Sec-Fetch-Mode": "navigate", 
    "Sec-Fetch-Site": "none", 
    "Sec-Fetch-User": "?1", 
    "Upgrade-Insecure-Requests": "1", 
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36", 
    "X-Envoy-Expected-Rq-Timeout-Ms": "15000", 
    "X-User-Id": "http://172.18.0.211:8080/auth/realms/master;7d47b6bf-972b-48dc-b7b7-3e97cedc8635"
  }, 
  "origin": "192.168.149.15", 
  "url": "https://172.18.0.210/get"
}
```

You can see that the `jwt` header has been added to the request while the cookie header has been removed.

### Extract information from the JWT token

JWKS is a set of public keys that can be used to verify the JWT tokens.

Now, we can update the Virtual Service to validate the token, extract claims from the token and create new headers based on these claims.

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
          name: keycloak-oauth
          namespace: gloo-system
      stagedTransformations:
        early:
          requestTransforms:
            - requestTransformation:
                transformationTemplate:
                  extractors:
                    token:
                      header: 'cookie'
                      regex: 'id_token=(.*); .*'
                      subgroup: 1
                  headers:
                    jwt:
                      text: '{{ token }}'
      headerManipulation:
        requestHeadersToRemove:
        - "cookie"
#--------------Extract claims-----------------
      jwt:
        providers:
          dex:
            issuer: http://172.18.0.211:8080/auth/realms/master
            tokenSource:
              headers:
              - header: Jwt
            claimsToHeaders:
            - claim: email
              header: x-solo-claim-email
            - claim: email_verified
              header: x-solo-claim-email-verified
            jwks:
              remote:
                url: http://keycloak.default.svc:8080/auth/realms/master/protocol/openid-connect/certs
                upstreamRef:
                  name: default-keycloak-8080
                  namespace: gloo-system
#--------------------------------------------- 
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            single:
              upstream:
                name: default-httpbin-8000
                namespace: gloo-system
EOF
```

Here is the output you should get if you refresh the web page:

```
{
  "args": {}, 
  "headers": {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", 
    "Accept-Encoding": "gzip, deflate, br", 
    "Accept-Language": "en-US,en;q=0.9", 
    "Cache-Control": "max-age=0", 
    "Content-Length": "0", 
    "Host": "172.18.0.210", 
    "Sec-Fetch-Dest": "document", 
    "Sec-Fetch-Mode": "navigate", 
    "Sec-Fetch-Site": "cross-site", 
    "Sec-Fetch-User": "?1", 
    "Upgrade-Insecure-Requests": "1", 
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36", 
    "X-Envoy-Expected-Rq-Timeout-Ms": "15000", 
    "X-Solo-Claim-Email": "user1@solo.io", 
    "X-Solo-Claim-Email-Verified": "false", 
    "X-User-Id": "http://172.18.0.211:8080/auth/realms/master;7d47b6bf-972b-48dc-b7b7-3e97cedc8635"
  }, 
  "origin": "192.168.149.15", 
  "url": "https://172.18.0.210/get"
}
```

As you can see, Gloo Edge has added the x-solo-claim-email and x-solo-claime-email-verified headers using the information it has extracted from the JWT token.

It will allow the application to know who the user is and if his email has been verified.

### RBAC using the claims of the JWT token

Gloo Edge can also be used to set RBAC rules based on the claims of the JWT token returned by the identity provider.

Let’s update the Virtual Service as follow:

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
          name: keycloak-oauth
          namespace: gloo-system
      stagedTransformations:
        early:
          requestTransforms:
            - requestTransformation:
                transformationTemplate:
                  extractors:
                    token:
                      header: 'cookie'
                      regex: 'id_token=(.*); .*'
                      subgroup: 1
                  headers:
                    jwt:
                      text: '{{ token }}'
      headerManipulation:
        requestHeadersToRemove:
        - "cookie"
      jwt:
        providers:
          dex:
            issuer: http://172.18.0.211:8080/auth/realms/master
            tokenSource:
              headers:
              - header: Jwt
            claimsToHeaders:
            - claim: email
              header: x-solo-claim-email
            - claim: email_verified
              header: x-solo-claim-email-verified
            jwks:
              remote:
                url: http://keycloak.default.svc:8080/auth/realms/master/protocol/openid-connect/certs
                upstreamRef:
                  name: default-keycloak-8080
                  namespace: gloo-system
#--------------Add RBAC rule------------------
      rbac:
        policies:
          viewer:
            permissions:
              methods:
              - GET
              pathPrefix: /get
            principals:
            - jwtPrincipal:
                claims:
                  email: user1@solo.io
#--------------------------------------------- 
    domains:
      - '*'
    routes:
      - matchers:
          - prefix: /
        routeAction:
            single:
              upstream:
                name: default-httpbin-8000
                namespace: gloo-system
EOF
```

If you refresh the web page, you should still get the same response you got before.

But if you change the path to anything that doesn't start with `/get`, you should get the following response:

```
RBAC: access denied
```

## Lab 7 : Gloo Portal

Gloo Portal provides a framework for managing the definitions of APIs, API client identity, and API policies on top of Gloo Edge or of the Istio Ingress Gateway. Vendors of API products can leverage Gloo Portal to secure, manage, and publish their APIs independent of the operations used to manage networking infrastructure.

### Install Developer Portal

We'll use Helm to deploy the Developer portal:

```bash
helm repo add dev-portal https://storage.googleapis.com/dev-portal-helm
helm repo update

cat << EOF > gloo-values.yaml
gloo:
  enabled: true
licenseKey:
  secretRef:
    name: license
    namespace: gloo-system
    key: license-key
EOF

kubectl create namespace dev-portal
helm install dev-portal dev-portal/dev-portal -n dev-portal --values gloo-values.yaml  --version=0.5.0
```

<!--bash
until kubectl get ns dev-portal
do
  sleep 1
done
-->

Use the following snippet to wait for the installation to finish:

```bash
until [ $(kubectl -n dev-portal get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep true -c) -eq 4 ]; do
  echo "Waiting for all the Dev portal pods to become ready"
  sleep 1
done
```

### Create an API Doc

Managing APIs with the Developer Portal happens through the use of two resources: the API Doc and API Product.

API Docs are Kubernetes Custom Resources which packages the API definitions maintained by the maintainers of an API. Each API Doc maps to a single Swagger Specification or set of gRPC descriptors. The APIs endpoints themselves are provided by backend services.

Let's create an API Doc using the Swagger Specification of the bookinfo demo app:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: APIDoc
metadata:
  name: bookinfo-schema
  namespace: default
spec:
  openApi:
    content:
      fetchUrl: https://raw.githubusercontent.com/istio/istio/1.7.3/samples/bookinfo/swagger.yaml
EOF
```

You can then check the status of the API Doc using the following command:

```bash
kubectl get apidoc -n default bookinfo-schema -oyaml
```

### Create an API Product

API Products are Kubernetes Custom Resources which bundle the APIs defined in API Docs into a product which can be exposed to ingress traffic as well as published on a Portal UI. The Product defines what API operations are being exposed, and the routing information to reach the services.

Let's create an API Product using the API Doc we've just created and pointing to the 2 versions of our Bookinfo application:

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: APIProduct
metadata:
  name: bookinfo-product
  namespace: default
spec:
  displayInfo: 
    description: Bookinfo Product
    title: Bookinfo Product
    image:
      fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-edge/gloo-edge/images/books.png
  versions:
  - name: v1
    apis:
    - apiDoc:
        name: bookinfo-schema
        namespace: default
    tags:
      stable: {}
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: productpage
            namespace: bookinfo
            port: 9080
  - name: v2
    apis:
    - apiDoc:
        name: bookinfo-schema
        namespace: default
    tags:
      stable: {}
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: productpage
            namespace: bookinfo-beta
            port: 9080
EOF
```

You can then check the status of the API Product using the following command:

```bash
kubectl get apiproducts.devportal.solo.io -n default bookinfo-product -oyaml
```

Now, we are going to create an Environment named dev using the domain api.example.com and expose v1 and v2 of our Bookinfo API Product.

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
  - api.example.com
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  apiProducts:
  - name: bookinfo-product
    namespace: default
    publishedVersions:
    - name: v1
    - name: v2
EOF
```

You can then check the status of the Environment using the following command:

```bash
kubectl get environment.devportal.solo.io -n default dev -oyaml
```

### Test the Service

When targeting Gloo Edge, Gloo Portal manages a set of Gloo Edge Custom Resource Definitions (CRDs) on behalf of users:

- VirtualServices: Gloo Portal generates a Gloo Edge VirtualService for each API Product. The VirtualService contains a single HTTP route for each API operation exposed in the product. Routes are named and their matchers are derived from the OpenAPI definition.
- Upstreams: Gloo Portal generates a Gloo Upstream for each unique destination references in an API Product route.

So, you can now access the API using the command below:

```bash
curl -H "Host: api.example.com" http://172.18.0.210/api/v1/products
```

```
[
  {
    "id": 0,
    "title": "The Comedy of Errors",
    "descriptionHtml": "<a href=\"https://en.wikipedia.org/wiki/The_Comedy_of_Errors\">Wikipedia Summary</a>: The Comedy of Errors is one of <b>William Shakespeare's</b> early plays. It is his shortest and one of his most farcical comedies, with a major part of the humour coming from slapstick and mistaken identity, in addition to puns and word play."
  }
]
```

### Configure a Portal

Once a set of APIs have been bundled together in an API Product, those products can be published in a user-friendly interface through which outside developers can discover, browse, request access to, and interact with APIs. This is done by defining Portals, a custom resource which tells Gloo Portal how to publish a customized website containing an interactive catalog of those products.

We'll integrate the Portal with Keycloak, so we need to define a couple of variables and create a secret:

```bash
KEYCLOAK_URL=http://$(kubectl get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/auth
KEYCLOAK_CLIENT=$(kubectl -n gloo-system get authconfigs.enterprise.gloo.solo.io keycloak-oauth -o jsonpath='{.spec.configs[0].oauth2.oidcAuthorizationCode.clientId}')

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: bookinfo-portal-oidc-secret
  namespace: default
data:
  client_secret: $(kubectl -n gloo-system get secret keycloak-oauth -o jsonpath='{.data.oauth}' | base64 --decode | awk '{ print $2 }' | base64)
EOF
```

Let's create the Portal:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: Portal
metadata:
  name: bookinfo-portal
  namespace: default
spec:
  displayName: Bookinfo Portal
  description: The Developer Portal for the Bookinfo API
  banner:
    fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-edge/gloo-edge/images/books.png
  favicon:
    fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-edge/gloo-edge/images/books.png
  primaryLogo:
    fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-edge/gloo-edge/images/books.png
  customStyling: {}
  staticPages: []
  domains:
  - portal.example.com

  oidcAuth:
    callbackUrlPrefix: http://portal.example.com/
    clientId: ${KEYCLOAK_CLIENT}
    clientSecret:
      name: bookinfo-portal-oidc-secret
      namespace: default
      key: client_secret
    groupClaimKey: group
    issuer: ${KEYCLOAK_URL}/realms/master

  publishedEnvironments:
  - name: dev
    namespace: default
EOF
````

You can now check the status of the API Product using the following command:

```bash
kubectl get portal -n default bookinfo-portal -oyaml
```

We need to update the `/etc/hosts` file to be able to access the Portal:

```bash
cat <<EOF | sudo tee -a /etc/hosts
172.18.0.210 api.example.com
172.18.0.210 portal.example.com
EOF
```

### Configure a Rate Limiting Policy

We can now update the Environment to secure it and to define a rate limit:

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
  - api.example.com
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  apiProducts:
  - name: bookinfo-product
    namespace: default
    plans:
    - authPolicy:
        apiKey: {}
      displayName: Basic
      name: basic
      rateLimit:
        requestsPerUnit: 5
        unit: MINUTE
    publishedVersions:
    - name: v1
    - name: v2
EOF
```

And finally, we need to let the users of the `users` group to access the Portal and use this plan:

```bash
cat << EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: Group
metadata:
  name: oidc-group
  namespace: default
spec:
  accessLevel:
    apiProducts:
    - name: bookinfo-product
      namespace: default
      environments:
      - name: dev
        namespace: default
        plans:
        - basic
    portals:
    - name: bookinfo-portal
      namespace: default
  oidcGroup:
    groupName: users
EOF
```

### Explore the Administrative Interface

Let's run the following command to allow access ot the admin UI of Gloo Portal:

```
kubectl port-forward -n dev-portal svc/admin-server 8000:8080
```

You can now access the admin UI at http://localhost:8000

![Admin Developer Portal](images/dev-portal-admin.png)

Take the time to explore the UI and see the different components we have created.

### Explore the Portal Interface

The user Portal we have created is available at http://portal.example.com

![User Developer Portal](images/dev-portal-user.png)

Log in with the user `user1` and the password `password`.

Click on `user1@solo.io` on the top right corner and select `API Keys`.

Click on `API Keys` again and Add an API Key.

![User Developer Portal API Key](images/dev-portal-api-key.png)

Click on the key to copy the value to the clipboard.

Click on the `APIs` tab.

![User Developer Portal APIs](images/dev-portal-apis.png)

You can click on on of the versions of the `Bookinfo Product` and explore the API.

You can also test the API and use the `Authorize` button to set your API key.

![User Developer Portal API](images/dev-portal-api.png)

### Verify the Rate Limiting Policy

Now we're going to exercise the service using `curl`:

So, we need to retrieve the API key first:

```
key=$(kubectl get secret -l environments.devportal.solo.io=dev.default -n default -o jsonpath='{.items[0].data.api-key}' | base64 --decode)
```

Then, we can run the following command:

```
curl -H "Host: api.example.com" -H "api-key: ${key}" http://172.18.0.210/api/v1/products -v
```

You should get a result similar to:

```
*   Trying 172.18.0.210...
* TCP_NODELAY set
* Connected to 172.18.0.210 (172.18.0.210) port 80 (#0)
> GET /api/v1/products HTTP/1.1
> Host: api.example.com
> User-Agent: curl/7.52.1
> Accept: */*
> api-key: OTA4OGMyYWMtNmE4Yi02OWRmLTJjZGUtYzQ2Zjc1NTE4OTFm
> 
< HTTP/1.1 200 OK
< content-type: application/json
< content-length: 395
< server: envoy
< date: Wed, 14 Oct 2020 12:25:26 GMT
< x-envoy-upstream-service-time: 2
< 
* Curl_http_done: called premature == 0
* Connection #0 to host 172.18.0.210 left intact
[{"id": 0, "title": "The Comedy of Errors", "descriptionHtml": "<a href=\"https://en.wikipedia.org/wiki/The_Comedy_of_Errors\">Wikipedia Summary</a>: The Comedy of Errors is one of <b>William Shakespeare's</b> early plays. It is his shortest and one of his most farcical comedies, with a major part of the humour coming from slapstick and mistaken identity, in addition to puns and word play."}]
```

Now, execute the curl command again several times.

As soon as you reach the rate limit, you should get the following output:

```
*   Trying 172.18.0.210...
* TCP_NODELAY set
* Connected to 172.18.0.210 (172.18.0.210) port 80 (#0)
> GET /api/v1/products HTTP/1.1
> Host: api.example.com
> User-Agent: curl/7.52.1
> Accept: */*
> api-key: OTA4OGMyYWMtNmE4Yi02OWRmLTJjZGUtYzQ2Zjc1NTE4OTFm
> 
< HTTP/1.1 429 Too Many Requests
< x-envoy-ratelimited: true
< date: Wed, 14 Oct 2020 12:25:48 GMT
< server: envoy
< content-length: 0
< 
* Curl_http_done: called premature == 0
* Connection #0 to host 172.18.0.210 left intact
```

## Lab 8 : Extend Envoy with WebAssembly

WebAssembly (WASM) is the future of cloud-native infrastructure extensibility.

WASM is a safe, secure, and dynamic way of extending infrastructure with the language of your choice. WASM tool chains compile your code from any of the supported languages into a type-safe, binary format that can be loaded dynamically in a WASM sandbox/VM.

The Envoy Wasm filter is already available, but it's not ready for production use yet. More info available in [this Blog Post](https://www.solo.io/blog/the-state-of-webassembly-in-envoy-proxy/).

Both Gloo Edge and Istio are based on Envoy, so they can take advantage of WebAssembly.

One of the projects for working with WASM and Envoy proxy is [WebAssembly Hub](https://webassemblyhub.io/).

WebAssembly Hub is a meeting place for the community to share and consume WebAssembly Envoy extensions. You can easily search and find extensions that meet the functionality you want to add and give them a try.

Gloo Edge Enterprise CLI comes with all the features you need to develop, build, push and deploy your Wasm filters.

You just need to add the Wasm extension to it:

```bash
wget https://github.com/solo-io/workshops/raw/master/gloo-edge/gloo-edge/glooctl-wasm-linux-amd64
mv glooctl-wasm-linux-amd64 /home/solo/.gloo/bin/glooctl-wasm
chmod +x /home/solo/.gloo/bin/glooctl-wasm
```

Note tha we are currently developing in plugin for `glooctl` to allow you to do the same with `glooctl wasm` commands.

The main advantage of building a Wasm Envoy filter is that you can manipulate requests (and responses) exactly the way it makes sense for your specific use cases.

Perhaps you want to gather some metrics only when the request contain specific headers, or you want to enrich the request by getting information from another API, it doesn't matter, you're now free to do exactly what you want.

The first decision you need to take is to decide which SDK (so which language) you want to use. SDKs are currently available for C++, AssemblyScript, RUST and TinyGo.

Not all the languages can be compiled to WebAssembly and don't expect that you'll be able to import any external packages (like the Amazon SDK).

There are 2 main reasons why you won't be able to do that:

- The first one is that you'll need to tell Envoy to send HTTP requests for you (if you need to get information from an API, for example).
- The second one is that most of these languages are not supporting all the standard packages you expect. For example, TinyGo doesn't have a JSON package and AssemblyScript doesn't have a Regexp package.

So, you need to determine what you want your filter to do, look at what kind of packages you'll need (Regexp, ...) and check which one of the language you already know is matching your requirements.

For example, if you want to manipulate the response headers with a regular expression and you have some experience with Golang, then you'll probably choose TinyGo.

In this lab, we won't focus on developing a filter, but on how to build, push and deploy filters.

### Develop

The Gloo Edge Enterprise CLI can be used to create the skeleton for you.

Let's take a look at the help of the `glooctl wasm` option:

```
glooctl wasm

The interface for managing Gloo Edge WASM filters

Usage:
  wasm [command]

Available Commands:
  build       Build a wasm image from the filter source directory.
  deploy      Deploy an Envoy WASM Filter to the Gloo Gateway Proxies (Envoy).
  help        Help about any command
  init        Initialize a project directory for a new Envoy WASM Filter.
  list        List Envoy WASM Filters stored locally or published to webassemblyhub.io.
  login       Log in so you can push images to the remote server.
  pull        Pull wasm filters from remote registry
  push        Push a wasm filter to remote registry
  tag         Create a tag TARGET_IMAGE that refers to SOURCE_IMAGE
  undeploy    Remove an Envoy WASM Filter from the Gloo Gateway Proxies (Envoy).
  version     Display the version of glooctl wasm

Flags:
  -h, --help   help for wasm

Use "wasm [command] --help" for more information about a command.
```

The following command will create the skeleton to build a Wasm filter using AssemblyScript:

```
glooctl wasm init helloworld --language=assemblyscript
```

It will ask what platform you will run your filter on (because the SDK version can be different based on the ABI corresponding to the version of Envoy used by this Platform).

And it will create the following file structure under the directory you have indicated:

```
./package-lock.json
./.gitignore
./assembly
./assembly/index.ts
./assembly/tsconfig.json
./package.json
./runtime-config.json
```

The most interesting file is the index.ts one, where you'll write the code corresponding to your filter:

```
export * from "@solo-io/proxy-runtime/proxy";
import { RootContext, Context, RootContextHelper, ContextHelper, registerRootContext, FilterHeadersStatusValues, stream_context } from "@solo-io/proxy-runtime";

class AddHeaderRoot extends RootContext {
  configuration : string;

  onConfigure(): bool {
    let conf_buffer = super.getConfiguration();
    let result = String.UTF8.decode(conf_buffer);
    this.configuration = result;
    return true;
  }

  createContext(): Context {
    return ContextHelper.wrap(new AddHeader(this));
  }
}

class AddHeader extends Context {
  root_context : AddHeaderRoot;
  constructor(root_context:AddHeaderRoot){
    super();
    this.root_context = root_context;
  }
  onResponseHeaders(a: u32): FilterHeadersStatusValues {
    const root_context = this.root_context;
    if (root_context.configuration == "") {
      stream_context.headers.response.add("hello", "world!");
    } else {
      stream_context.headers.response.add("hello", root_context.configuration);
    }
    return FilterHeadersStatusValues.Continue;
  }
}

registerRootContext(() => { return RootContextHelper.wrap(new AddHeaderRoot()); }, "add_header");
```

We'll keep the default content, so the filter will add a new Header in all the Responses with the key hello and the value passed to the filter (or world! if no value is passed to it).

### Build

We're ready to compile the code into WebAssembly.

The Gloo Edge Enterprise CLI will make your life easier again.

You simply need to run the following commands:

```
cd /home/solo/workshops/gloo-edge/gloo-edge/helloworld
glooctl wasm build assemblyscript -t webassemblyhub.io/djannot/helloworld-gloo-ee:1.6 .
```

You can see that I've indicated that I wanted to use `webassemblyhub.io/djannot/helloworld-gloo-ee:1.6` for the Image reference.

The Gloo Edge Enterprise CLI will create an OCI compliant image with this tag. It's exactly the same as when you use the Docker CLI and the Docker Hub.

### Push

The image has been built, so we can now push it to the Web Assembly Hub.

But you would need to create a free account and to run `glooctl wasm login` to authenticate.

To simplify the lab, we will use the image that has already been pushed.

![Web Assembly Hub](images/web-assembly-hub.png)

But note that the command to push the Image is the following one:

```
glooctl wasm push webassemblyhub.io/djannot/helloworld-gloo-ee:1.6
```

Then, if you go to the Web Assembly Hub, you'll be able to see the Image of your Wasm filter

### Deploy

It's now time to deploy your Wasm filter on Gloo Edge !

Note that you can also deploy it on Istio using Gloo Mesh.

You can deploy it using `glooctl wasm deploy`, but we now live in a Declarative world, so let's do it the proper way.

You can deploy your filter by updating the `Gateway` CRD (Custom Resource Definition).

To deploy your Wasm filter, use the following commands:

```bash
cat > gateway-patch.yaml <<EOF
spec:
  httpGateway:
    options:
      wasm:
        filters:
        - config:
            '@type': type.googleapis.com/google.protobuf.StringValue
            value: "Gloo Edge Enterprise"
          image: webassemblyhub.io/djannot/helloworld-gloo-ee:1.6
          name: myfilter
          root_id: add_header
EOF

kubectl -n gloo-system patch gateway gateway-proxy --type=merge --patch "$(cat gateway-patch.yaml)"
```

Modify the Virtual Service using the yaml below:

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
                name: default-httpbin-8000
                namespace: gloo-system
EOF
```

And run the following command:

```
curl $(glooctl proxy url)/get  -I
```

You should get the following output:

```
HTTP/1.1 200 OK
server: envoy
date: Tue, 26 Jan 2021 08:38:54 GMT
content-type: application/json
content-length: 1254
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 3
hello: Gloo Edge Enterprise
```

This is the end of the workshop. We hope you enjoyed it !