# Gloo Workshop

Gloo is a feature-rich, Kubernetes-native ingress controller, and next-generation API gateway. Gloo is exceptional in its function-level routing; its support for legacy apps, microservices and serverless; its discovery capabilities; its numerous features; and its tight integration with leading open-source projects. Gloo is uniquely designed to support hybrid applications, in which multiple technologies, architectures, protocols, and clouds can coexist.

The goal of this workshop is to explose some key features of Gloo like traffic management, security, api management.


## Lab environment

!!! Need chart

## Lab 0: Demo environment creation

Go the the folder `/home/solo/workshops/gloo/gloo` directory using the terminal

```
cd /home/solo/workshops/gloo/gloo
```

### Create a Kubernetes cluster

```bash
../../scripts/deploy.sh 1 gloo
```

### Install Gloo 
```bash
kubectl config use-context gloo
glooctl upgrade --release=v1.5.0
glooctl install gateway enterprise --version 1.5.0 --license-key $LICENSE_KEY
```


## Lab 1: Traffic management

### Routing to an external service

Create an Upstream that points to the external service, this is used as a representation of a destination: 

```bash
glooctl -n gloo-system create upstream static --name echo --static-hosts postman-echo.com:80
```

To list the upstreams, run the following command:

```bash
glooctl get upstream echo
```

An upstream CRD has been added to your cluster: 

```bash
kubectl get upstream echo -n gloo-system -oyaml
```

Now we can create a virtual service that routes to the created upstream: 

```bash
glooctl add route  \                                                                                                                                                                      1
    --name echo  \
    --path-exact /request \
    --dest-name echo
```

To list the virtual services created, run the following command:

```bash
glooctl get virtualservice
```

A virtual service CRD has been added to your cluster:

```bash
kubectl get virtualservice -n gloo-system echo -oyaml 
```

Finally to test that the gateway will route to the upstream destination, run the following command:

```bash
curl -s -L $(glooctl proxy url)/request
```

The result received in from the upstream postman-echo.com:80/request


### Routing to a kubernetes service 

In this step we will expose a demo service to the outside traffic using Gloo, first lets create a demo service: 

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
      version: v1
  template:
    metadata:
      labels:
        app: echo
        version: v1
    spec:
      containers:
        - image: hashicorp/http-echo
          args:
            - "-text=version:v1"
            - -listen=:8080
          imagePullPolicy: Always
          name: echo-v1
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echo-v1
spec:
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  selector:
    app: echo
    version: v1
EOF
```

After few seconds, Gloo will discover the newly created service and create a corresponding Uptream called: default-echo-v1-80, to verify the the upstream got created run the following command: 
```bash
glooctl get upstream
```

Now that the upstream CRD has been created we can create an virtual service that routes to it:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: echo
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
              name: default-echo-v1-80
              namespace: gloo-system
EOF
```

The creation of the virtual service exposes the Kubernetes service through the gateway, we can make a test using the following command:

```bash
curl -s -L $(glooctl proxy url)
```

It should return "v1", this is the response from the service echo-v1.

### Routing to multiple upstreams

In this step we are going to create a virtual service that routes to two diffrent upstreams, the first step is to create a version 2 of our demo service: 


```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
      version: v2
  template:
    metadata:
      labels:
        app: echo
        version: v2
    spec:
      containers:
        - image: hashicorp/http-echo
          args:
            - "-text=version:v2"
            - -listen=:8080
          imagePullPolicy: Always
          name: echo-v2
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echo-v2
spec:
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  selector:
    app: echo
    version: v2
EOF
```

Verify the upstream default-echo-v1-80 got created running the following command: 

```bash
glooctl get upstream
```

Now that can create a virtual service that routes to two diffrents upstreams but creating the following CRD: 

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: echo
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
                        name: default-echo-v1-80
                        namespace: gloo-system
                - weight: 5
                    destination:
                    upstream:
                        name: default-echo-v2-80
                        namespace: gloo-system
EOF
```

To verfiy that Gloo is routing to the two diffrent uptreams (50% taffic each), run the following command, you should be able to see v1 and v2 as a response from service echo-v1 and echo-v2 respectivly: 

```bash
curl -s -L $(glooctl proxy url)
```


## Lab 2: Security
In this chapter we will explore some Gloo features related to security. 


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
  name: echo
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
                        name: default-echo-v1-80
                        namespace: gloo-system
                - weight: 5
                    destination:
                    upstream:
                        name: default-echo-v2-80
                        namespace: gloo-system
EOF
```


### OIDC Support
In the following chapter we will secure our API using an IDP, lets first start by installing dex (IDP) on our cluster:
 

```bash

cat > dex-values.yaml <<EOF
config:
  # The base path of dex and the external name of the OpenID Connect service.
  # This is the canonical URL that all clients MUST use to refer to dex. If a
  # path is provided, dex's HTTP service will listen at a non-root URL.
  issuer: http://dex.gloo-system.svc.cluster.local:32000

  # Instead of reading from an external storage, use this list of clients.
  staticClients:
  - id: gloo
    redirectURIs:
    - "$(glooctl proxy url)/callback"
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

The final step is to setup the authentication in the Virtual Service, for this we will have to create a Kubernetes Secret that contains the OIDC secret:

```bash
glooctl create secret oauth --client-secret secretvalue oauth
```

Then we will create an authconfig, which is a CRD that configure the authentication in Gloo: 


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
      app_url: "$(glooctl proxy url)"
      callback_path: /callback
      client_id: gloo
      client_secret_ref:
        name: oauth
        namespace: gloo-system
      issuer_url: http://dex.gloo-system.svc.cluster.local:32000/
      scopes:
      - email
EOF
```

Finally we activate the authentication on the virtualservice using the extauth config:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: echo
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
                        name: default-echo-v1-80
                        namespace: gloo-system
                - weight: 5
                    destination:
                    upstream:
                        name: default-echo-v2-80
                        namespace: gloo-system
EOF
```

