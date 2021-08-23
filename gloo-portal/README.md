# Gloo Portal Workshop

Gloo Portal is a Kubernetes native solution aiming to facilitate API publication and API consumption for developers.

More technically, Gloo Portal adheres to the Operator pattern and transforms Custom Resources into customized and ready-to-use developer portals. These portals are fully brandable and secured web applications.

Gloo Portal provides a framework for managing API definitions, API client identity, and API policies on top of Gloo Edge or Istio Ingress Gateway. Vendors of API products can leverage Gloo Portal to secure, manage, and publish their APIs independently of the operations used to manage networking infrastructure.

This workshop aims to expose some key features of the Gloo Portal like API lifecycle, authentication, and branding.


## Your workshop environment

The Lab environment consists of a Virtual Machine where you will deploy a Kubernetes cluster using [kind](https://kind.sigs.k8s.io/).  
You will then deploy Gloo Edge and Gloo Portal on this Kubernetes cluster.

### Init step 1

Navigate to the work directory and create local Kubernetes cluster with KinD:

```bash
cd /home/solo/workshops/gloo-portal
../scripts/deploy.sh 1 gloo-portal
```

Then verify that your Kubernetes cluster is ready: 

```bash
../scripts/check.sh gloo-portal
```

The `check.sh` script will return immediately with no output if the cluster is ready.  Otherwise, it will output a series of periodic "waiting" messages until the cluster is up.


### Init step 2

Let's deploy **Gloo Edge**:

```bash
helm repo update

helm upgrade -i gloo glooe/gloo-ee --namespace gloo-system --version 1.8.5 --create-namespace --set-string license_key="$LICENSE_KEY"
```

NOTE: Gloo Portal requires a subscription to Gloo Edge Enterprise or to Gloo Mesh Enterprise.

### Init step 3

Finally, let's deploy **Gloo Portal**:

```bash
cat << EOF > portal-values.yaml
glooEdge:
  enabled: true
licenseKey:
  secretRef:
    name: license
    namespace: gloo-system
    key: license-key
EOF

helm repo add gloo-portal https://storage.googleapis.com/dev-portal-helm
helm repo update
helm install gloo-portal gloo-portal/gloo-portal -n gloo-portal --values portal-values.yaml --version=1.1.0-beta4 --create-namespace
```


## Lab 1: Crafting your first API Product

First, some conceptual elements to better understand how the Gloo Portal CRDs work together.

You will define `APIDocs` Custom Resources, standing for references to OpenAPI (or gRPC) specifications. 

![APIDocs](images/apidoc.png)

Then, you will combine these `APIDocs` into a single `APIProduct`.

![APIProducts](images/apiproduct-apidocs.png)

In this workshop, we will combine 2 small `APIDoc`s into the `v1` of our Petstore `APIProduct` 
And one larger `APIDoc` as the `v2` of our Petstore `APIProduct`.  
See:

![APIProduct composition](images/petstore-apiproduct-apidocs.png)

The `APIProduct` comes with two versions of it:
- `/v1` will expose endpoints for the `/pets/*` and `/users/*` endpoints, and it will route requests to the `petstore-v1` application
- `/v2` will expose all of the endpoints, including `/pets/*`, `/users/*` and also `/store/*`, and it will route requests to the `petstore-v2` application

We'll start by deploying the well-known Petstore app, twice. This will simulate the two versions of it, accessible behind two different Kubernetes Services.

### Step 1.1

Create two deployments of the Petstore app

```bash
for i in {1..2}; do
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petstore-v$i
spec:
  replicas: 1
  selector:
    matchLabels:
      app: petstore
      version: v$i
  template:
    metadata:
      labels:
        app: petstore
        version: v$i
    spec:
      containers:
        - name: petstore
          image: swaggerapi/petstore
          # env:
          #   - name: SWAGGER_BASE_PATH
          #     value: /
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: petstore-v$i
spec:
  ports:
    - name: http
      port: 8080
      targetPort: http
      protocol: TCP
  selector:
    app: petstore
    version: v$i
EOF
; done
```

Now, let's check if Gloo Edge has automatically created 2 `Upstream` CRs for these 2 services:

```bash
kubectl -n gloo-system get upstreams
```

The output should be like:
```text
...
default-petstore-v1-8080                               9s
default-petstore-v2-8080                               8s
...
```
Great!


### Step 1.2

Create the `APIDoc`s from our 3 OpenApi specs:

![Pets only](images/OAI-snapshot-pets-only.png) ![Users only](images/OAI-snapshot-users-only.png) ![All combined](images/OAI-snapshot-pets-full.png)


```bash
for i in petstore-openapi-v1-pets petstore-openapi-v1-users petstore-openapi-v2-full; do

cat <<EOF | kubectl apply -f -
apiVersion: portal.gloo.solo.io/v1beta1
kind: APIDoc
metadata:
  name: $i
  namespace: default
spec:
  openApi:
    content:
      fetchUrl: https://raw.githubusercontent.com/solo-io/workshops/master/gloo-portal/openapi-specs/$i.json
EOF
; done
```

Let's be curious and take a look at the status of one these `APIDoc`s:
```bash
kubectl get apidoc
kubectl get apidoc petstore-openapi-v1-pets -o yaml
```

The output is something like that:
```yaml
...
status:
  description: 'This is a sample server Petstore server.  You can find out more about
    Swagger at [http://swagger.io](http://swagger.io) or on [irc.freenode.net, #swagger](http://swagger.io/irc/).  For
    this sample, you can use the api key `special-key` to test the authorization filters.'
  displayName: Swagger Petstore
  observedGeneration: 1
  openApi:
    operations:
    - operationId: addPet
      path: /api/pet
      summary: Add a new pet to the store
      verb: POST
    - operationId: deletePet
      path: /api/pet/{petId}
      summary: Deletes a pet
      verb: DELETE
    - operationId: findPetsByStatus
      path: /api/pet/findByStatus
      summary: Finds Pets by status
      verb: GET
    - operationId: findPetsByTags
      path: /api/pet/findByTags
      summary: Finds Pets by tags
      verb: GET
    - operationId: getPetById
      path: /api/pet/{petId}
      summary: Find pet by ID
      verb: GET
    - operationId: updatePet
      path: /api/pet
      summary: Update an existing pet
      verb: PUT
    - operationId: updatePetWithForm
      path: /api/pet/{petId}
      summary: Updates a pet in the store with form data
      verb: POST
    - operationId: uploadFile
      path: /api/pet/{petId}/uploadImage
      summary: uploads an image
      verb: POST
  state: Succeeded
  version: 1.0.5
  ```

As you can see, the different endpoints of the OpenAPI spec have been parsed by the Gloo Portal controller.

Finally, let's create the `APIProduct`, with its 2 versions:

```bash
cat << EOF | kubectl apply -f -
apiVersion: portal.gloo.solo.io/v1beta1
kind: APIProduct
metadata:
  name: petstore-product
  namespace: default
  labels:
    app: petstore
spec:
  displayInfo: 
    title: Petstore Product
    description: Fabulous API product for the Petstore
  versions:
  - name: v1
    apis:
      - apiDoc:
          name: petstore-openapi-v1-pets
          namespace: default
      - apiDoc:
          name: petstore-openapi-v1-users
          namespace: default
    gatewayConfig:
      route:
        inlineRoute:
          backends:
            - upstream:
                name: default-petstore-v1-8080
                namespace: gloo-system
  - name: v2
    apis:
    - apiDoc:
        name: petstore-openapi-v2-full
        namespace: default
    gatewayConfig:
      route:
        inlineRoute:
          backends:
            - upstream:
                name: default-petstore-v2-8080
                namespace: gloo-system
EOF
```

Reminder: the `APIProduct` is named `petstore-product`. It is avaible in 2 different versions:
- v1 is built upon 2 APIDocs, containing operations for Pets on one side, and Users on the other side
- v2 is build upon 1 APIDoc, containing all the operations

As you can see, we have configured different routes for the two version, so that `/v1` targets our `Upstream` called `default-petstore-v1-8080`  
and `/v2` targets our `Upstream` called `default-petstore-v2-8080`.


## Lab 2: deploying the API

### Step 2.1

Let's publish our API on a Gateway! In this workshop, and in order to leverage advanced API Gateway features, we will rely on Gloo Edge (the other option being an Istio Gateway).  
We need to prepare an `Environment` CR, where we will set the domain(s) and, optionally, some security options like authentication or rate-limiting rules:

![Environment](images/env-to-apiproducts.png)

```bash
cat << EOF > env.yaml
apiVersion: portal.gloo.solo.io/v1beta1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
    - api.mycompany.corp # the domain name where the API will be exposed
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  basePath: /ecommerce # a global basepath for our APIs
  apiProducts: # we will select our APIProduct using a selector and the 2 version of it
    - namespaces:
      - "*" 
      labels:
      - key: app
        operator: In
        values:
        - petstore
      versions:
        names:
        - v1
        - v2
      basePath: "{%version%}" # this will dynamically prefix the API with the version names
  gatewayConfig:
    disableRoutes: false # we actually want to expose the APIs on a Gateway (optional)
EOF

kubectl apply -f env.yaml
```

This `Environment` CR is watched by the Gloo Portal controller. 
It will generate a Gloo Edge `VirtualService`, as shown in this schema:

![Environment controller](images/env-controller.png)


You can then check the status of the `Environment` using the following command:

```bash
kubectl get environments.portal.gloo.solo.io dev -o yaml
```

The output is pretty big but it should end with:

```
state: Succeeded
```

### Step 2.2

As explained above, Gloo Portal will configure Gloo Edge to expose our APIs.  
Using the command below, you'll see the Gloo Edge `VirtualService` created by Gloo Portal:

```bash
kubectl get virtualservice dev -o yaml
```

You should see something like this:
```yaml
...
spec:
  displayName: Development
  virtualHost:
    domains:
    - api.mycompany.corp
    routes:
    - delegateAction:
        selector:
          labels:
            apiproducts.portal.gloo.solo.io: petstore-product.default
            apiproducts.portal.gloo.solo.io/version: v2
            environments.portal.gloo.solo.io: dev.default
      matchers:
      - prefix: /
      name: petstore-product.v2
      options:
        regexRewrite:
          pattern:
            regex: ^/ecommerce/v2/(.*)$
          substitution: /\1
    - delegateAction:
        selector:
          labels:
            apiproducts.portal.gloo.solo.io: petstore-product.default
            apiproducts.portal.gloo.solo.io/version: v1
            environments.portal.gloo.solo.io: dev.default
      matchers:
      - prefix: /
      name: petstore-product.v1
      options:
        regexRewrite:
          pattern:
            regex: ^/ecommerce/v1/(.*)$
          substitution: /\1
status:
  reportedBy: gateway
  state: 1
  subresourceStatuses:
    '*v1.Proxy.gloo-system.gateway-proxy':
      reportedBy: gloo
      state: 1
```

As you can see, the `Environment` CR has been declined into a `VirtualService` CR and also some `RouteTables` CRs.  
Let's have a closer look to `RouteTables`:

```bash
kubectl get routetable
```

```
NAME                      AGE
dev.petstore-product.v1   10m
dev.petstore-product.v2   10m
```

```bash
kubectl get routetable dev.petstore-product.v1 -o yaml
```

Extract:
```yaml
...
  - matchers:
    - methods:
      - GET
      - OPTIONS
      regex: /ecommerce/v1/api/pet/[^/]+?
    name: petstore-product.default.petstore-openapi-v1-pets.default.getPetById
    options:
      stagedTransformations:
        early:
          requestTransforms:
          - matcher:
              prefix: /
            requestTransformation:
              transformationTemplate:
                dynamicMetadataValues:
                - key: environment
                  value:
                    text: dev.default
                - key: api_product
                  value:
                    text: petstore-product.default
                passthrough: {}
    routeAction:
      multi:
        destinations:
        - destination:
            upstream:
              name: default-petstore-v1-8080
              namespace: gloo-system
          weight: 1
...
```

The combination of these CRs will generate the expected configuration for Envoy.

### Step 2.3

Now let's consume the API!

```bash
# v1
# one of the /pet endpoint
curl -s $(glooctl proxy url)/ecommerce/v1/api/pet/1 -H "Host: api.mycompany.corp" | jq
# one of the /user endpoint
curl -s -X POST $(glooctl proxy url)/ecommerce/v2/api/user/createWithList -H "Host: api.mycompany.corp" -d '[{"id":0,"username":"jdoe","firstName":"John","lastName":"Doe","email":"john@doe.me","password":"string","phone":"string","userStatus":0}]' -H "Content-type: application/json"
curl -s $(glooctl proxy url)/ecommerce/v2/api/user/jdoe -H "Host: api.mycompany.corp" | jq

# v2
# one of the /store endpoint
curl -s $(glooctl proxy url)/ecommerce/v2/api/store/order/1 -H "Host: api.mycompany.corp" | jq

```


## Lab 3 - Publishing the APIs on a developer portal

You need a `Portal` Custom Resource to expose your APIs to developers. That will configure a developer portal webapp, which is fully brandable.

![Portal controller](images/portal-controller.png)


```bash
cat <<EOF | kubectl apply -f -
apiVersion: portal.gloo.solo.io/v1beta1
kind: Portal
metadata:
  name: ecommerce-portal
  namespace: default
spec:
  displayName: E-commerce Portal
  description: The Gloo Portal for the Petstore API and much more!
  banner:
    fetchUrl: https://i.imgur.com/EXbBN1a.jpg
  favicon:
    fetchUrl: https://i.imgur.com/QQwlQG3.png
  primaryLogo:
    fetchUrl: https://i.imgur.com/hjgPMNP.png
  customStyling: {}
  staticPages: []

  domains:
  - portal.mycompany.corp

  publishedEnvironments:
  - name: dev
    namespace: default

  allApisPublicViewable: true
EOF
```

To access it, you need to override the domain name on your machine:

```bash
cat <<EOF | sudo tee -a /etc/hosts
$(kubectl -n gloo-system get service gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}') portal.mycompany.corp
$(kubectl -n gloo-system get service gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}') api.mycompany.corp
EOF
```

The developer Portal we have created is now available at http://portal.mycompany.corp/

```bash
open http://portal.mycompany.corp/
```

![Developer Portal](images/petstore-portal-homepage.png)

Take a few minutes to browse the developer portal.  
Under the **APIs** menu, you will find the 2 version of our `APIProduct`:

![APIs](images/petstore-portal-apis.png)

Click the 1st line with 'v1', and you are now able to use the ' try-it-out' feature:

![try-it-out](images/petstore-portal-tryitout.png)

Later in this workshop, you will secure the access to the developer portal and also the access to the APIs.

# Lab 4: Explore the Admin UI

On top of these developer portal web UIs, Gloo Portal comes with an additional Admin-centric web UI, so that you can have a global overview of all the Gloo Portal resources:
- APIDocs
- APIProducts
- Environments
- Portals
- Users and Groups

You can access this admin UI using a port-forward:

```bash
kubectl -n gloo-portal port-forward svc/gloo-portal-admin-server 8080
```

Then, open http://localhost:8080 and you should find this webapp:

![Admin UI Homepage](images/admin-homepage.png)

Explore the menus and find your `APIProduct`, `Environment` and `Portal` resources.



### Securing the access to the Portal web app for developers

One easy way to go is to create User CRs:

```bash
pass=$(htpasswd -bnBC 10 "" super-password2 | tr -d ':\n')
kubectl create secret generic user2-password \
  -n default --type=opaque \
  --from-literal=password=$pass

kubectl apply -f -<<EOF
apiVersion: portal.gloo.solo.io/v1beta1
kind: User
metadata:
  name: user2
  namespace: default
spec:
  accessLevel:
    portals:
    - name: ecommerce-portal
      namespace: default
  basicAuth:
    passwordSecretKey: password
    passwordSecretName: user2-password
    passwordSecretNamespace: default
  email: foo2@solo.io
  username: user2
EOF
```

# ==============================================
# ================ DRAFT END ===================
# ==============================================



[Keycloak](https://keycloak.org) is an open-source identity management platform that we will use to secure access to the Gloo Portal.

First, let's deploy a Keycloak instance to our Kubernetes cluster:

```bash
kubectl create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/12.0.4/kubernetes-examples/keycloak.yaml
kubectl rollout status deploy/keycloak
```

<!--bash
sleep 30
-->

Then, we need to configure it and to create a new user with these credentials: `user1/password`:

```bash
# Get Keycloak URL and token
KEYCLOAK_URL=http://$(kubectl get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/auth
KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)

# Create initial token to register the client
read -r client token <<<$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' $KEYCLOAK_URL/admin/realms/master/clients-initial-access | jq -r '[.id, .token] | @tsv')

# Register the client
read -r id secret <<<$(curl -X POST -d "{ \"clientId\": \"${client}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${token}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default| jq -r '[.id, .secret] | @tsv')

# Add allowed redirect URIs
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"serviceAccountsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["http://portal.petstore.com/callback", "http://portal.petstore.com/oauth-redirect"], "webOrigins": ["http://portal.petstore.com"]}' $KEYCLOAK_URL/admin/realms/master/clients/${id}

# Add the group attribute in the JWT token returned by Keycloak
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models

# Create a user
curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@solo.io", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users
```










### Deploy the 2 versions

We're going to use the `swaggerapi/petstore` Docker image. Luckily, an environment variable called `SWAGGER_BASE_PATH` can be set to define the base path we want to use. We'll use it to simulate the deployment of 2 versions of the `Petstore` application.

Use the following snippet to deploy the 2 versions of the application:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petstore-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: petstore
      version: v1
  template:
    metadata:
      labels:
        app: petstore
        version: v1
    spec:
      containers:
        - name: petstore
          image: swaggerapi/petstore
          env:
          - name: SWAGGER_BASE_PATH
            value: /v1
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: petstore-v1
spec:
  ports:
    - name: http
      port: 8080
      targetPort: http
      protocol: TCP
  selector:
    app: petstore
    version: v1
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petstore-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: petstore
      version: v2
  template:
    metadata:
      labels:
        app: petstore
        version: v2
    spec:
      containers:
        - name: petstore
          image: swaggerapi/petstore
          env:
          - name: SWAGGER_BASE_PATH
            value: /v2
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: petstore-v2
spec:
  ports:
    - name: http
      port: 8080
      targetPort: http
      protocol: TCP
  selector:
    app: petstore
    version: v2
EOF
```

## Lab 2: Deploy Gloo Edge and Gloo Portal

### Install Gloo Edge

Run the commands below to deploy Gloo Edge Enterprise:

```bash
glooctl upgrade --release=v1.7.3
glooctl install gateway enterprise --version v1.7.5 --license-key $LICENSE_KEY
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

### Install Gloo Portal

We'll use Helm to deploy Gloo Portal:

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
helm install dev-portal dev-portal/dev-portal -n dev-portal --values gloo-values.yaml  --version=0.7.4
```

<!--bash
until kubectl get ns dev-portal
do
  sleep 1
done
-->

Use the following snippet to wait for the installation to finish:

```bash
kubectl -n dev-portal wait pod --all --for condition=Ready --timeout -1s
```

## Lab 3: Expose the API

### Create the API Docs

Managing APIs with Gloo Portal happens through the use of three resources: the API Doc, the API Product and the Environment.

**API Docs** are Kubernetes Custom Resources that package the API definitions created by the maintainers of an API. Each **API Doc** maps to a _single_ OpenAPI document. The APIs endpoints themselves are provided by backend services.

Let's create an **API Doc** using the OpenAPI document of the `v1` version of the `Petstore` demo application:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: APIDoc
metadata:
  name: petstore-v1
  namespace: default
spec:
  openApi:
    content:
      fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-portal/swagger-petstore-v1.json
EOF
```

You can then check the status of the API Doc using the following command:

```bash
kubectl get apidocs.devportal.solo.io petstore-v1 -o yaml
```

Let's do the same for the second version:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: APIDoc
metadata:
  name: petstore-v2
  namespace: default
spec:
  openApi:
    content:
      fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-portal/swagger-petstore-v2.json
EOF
```

Note that the API Doc's OpenAPI document has been parsed and now reflects all the operations published by the Petstore interface.

```bash
kubectl get apidocs.devportal.solo.io petstore-v2 -o yaml
```

The YAML output is abridged to highlight the discovered operations.

```yaml
apiVersion: devportal.solo.io/v1alpha1
kind: APIDoc
metadata:
  ...
  name: petstore-v2
  namespace: default
  ...
spec:
  openApi:
    content:
      fetchUrl: https://github.com/solo-io/workshops/raw/master/gloo-portal/swagger-petstore-v2.json
status:
  description: 'This is a sample server Petstore server. ...'
  displayName: Swagger Petstore
  observedGeneration: 1
  openApi:
    operations:
    - operationId: addPet
      path: /v2/pet
      summary: Add a new pet to the store
      verb: POST
    - operationId: createUser
      path: /v2/user
      summary: Create user
      verb: POST
    ...
    - operationId: uploadFile
      path: /v2/pet/{petId}/uploadImage
      summary: uploads an image
      verb: POST
  state: Succeeded
  version: 1.0.5
```


### Create an API Product

**API Products** are Kubernetes Custom Resources which bundle the APIs defined in **API Docs** into a product that can be exposed to ingress traffic as well as published on a Portal UI. An **API Product** defines what API operations are being exposed, and the routing information to reach the services.

Let's build an **API Product** using the **API Docs** we've just created to point to the two versions of the `Petstore` application:

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: APIProduct
metadata:
  name: petstore
  namespace: default
spec:
  displayInfo: 
    description: Petstore Product
    title: Petstore Product
    image:
      fetchUrl: https://i.imgur.com/EXbBN1a.jpg
  versions:
  - name: v1
    apis:
    - apiDoc:
        name: petstore-v1
        namespace: default
    tags:
      stable: {}
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: petstore-v1
            namespace: default
            port: 8080
  - name: v2
    apis:
    - apiDoc:
        name: petstore-v2
        namespace: default
    tags:
      stable: {}
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: petstore-v2
            namespace: default
            port: 8080
EOF
```

You can then check the status of the API Product using the following command:

```bash
kubectl get apiproducts.devportal.solo.io petstore -o yaml
```

### Create an Environment

In Gloo Portal, an **Environment** corresponds to a collection of compute resources where applications are deployed. This mirrors the practices of many organizations with development and production environments, often with multiple intermediate environments, such as those for shared testing and staging. 
We begin by creating an **Environment** named `dev`, using the domain `dev.petstore.com` to expose the `v1` and `v2` versions of the `Petstore` application.

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
  - dev.petstore.com
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  apiProducts:
  - name: petstore
    namespace: default
    publishedVersions:
    - name: v1
    - name: v2
EOF
```

You can then check the status of the Environment using the following command:

```bash
kubectl get environments.devportal.solo.io dev -o yaml
```

### Gloo Edge Virtual Service

You can see the Gloo Edge Virtual Service created by Gloo Portal to expose the API using the command below:

```bash
kubectl get virtualservice dev -o yaml
```

Here is the output:
```yaml
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"devportal.solo.io/v1alpha1","kind":"Environment","metadata":{"annotations":{},"name":"dev","namespace":"default"},"spec":{"apiProducts":[{"name":"petstore","namespace":"default","publishedVersions":[{"name":"v1"},{"name":"v2"}]}],"displayInfo":{"description":"This environment is meant for developers to deploy and test their APIs.","displayName":"Development"},"domains":["dev.petstore.com"]}}
  creationTimestamp: "2021-02-01T16:14:40Z"
  generation: 41
  labels:
    cluster.multicluster.solo.io: ""
    environments.devportal.solo.io: dev.default
...
    manager: gateway
    operation: Update
    time: "2021-02-03T10:37:57Z"
  name: dev
  namespace: default
  ownerReferences:
  - apiVersion: devportal.solo.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: Environment
    name: dev
    uid: 13c7a1e4-afcc-4ad9-896e-d62d4ac9194d
  resourceVersion: "437517"
  selfLink: /apis/gateway.solo.io/v1/namespaces/default/virtualservices/dev
  uid: 1862d8f2-93b2-46c6-91aa-56bd60b33ba3
spec:
  displayName: Development
  virtualHost:
    domains:
    - dev.petstore.com
    options: {}
    routes:
    - matchers:
      - exact: /v1/pet
        methods:
        - POST
        - OPTIONS
      name: dev.default.petstore.default.petstore-v1.default.addPet
      options: {}
      routeAction:
        multi:
          destinations:
          - destination:
              upstream:
                name: petstore-v1-8080-default
                namespace: dev-portal
            weight: 1

...
```

### Consume the API

When targeting Gloo Edge, Gloo Portal manages a set of Gloo Edge Custom Resource Definitions (CRDs) on behalf of users:

- **VirtualServices**: Gloo Portal generates a Gloo Edge **VirtualService** for each **API Product**. The **VirtualService** contains a single HTTP route for each API operation exposed in the product. Routes are named and their matchers are derived from the OpenAPI document.
- **Upstreams**: Gloo Portal generates a Gloo **Upstream** for each unique destination referenced in an **API Product** route.

We need to update the `/etc/hosts` file to be able to access our API (and later the Portal):

```bash
cat <<EOF | sudo tee -a /etc/hosts
$(kubectl -n gloo-system get service gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}') dev.petstore.com
$(kubectl -n gloo-system get service gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}') portal.petstore.com
EOF
```

You can now access the version `v1` of the API using the command below:

```bash
curl -s http://dev.petstore.com/v1/store/inventory | jq .
```

The output should be similar to below:

```
{
  "sold": 1,
  "pending": 2,
  "available": 7
}
```

You can also check that you can access the version `v2`:

```bash
curl http://dev.petstore.com/v2/store/inventory | jq .
```

The output should be the same:

```
{
  "sold": 1,
  "pending": 2,
  "available": 7
}
```

## Lab 4: Create a Portal

Once a set of APIs have been bundled together in an **API Product**, those products can be published in a user-friendly web interface through which outside developers can discover, browse and interact with APIs. This is done by defining **Portals**, a Custom Resource which tells Gloo Portal how to publish a customized website containing an interactive catalog of those products.

We'll integrate the Portal with Keycloak. So we need to fetch the client id and client secret that we have created earlier:

```bash
KEYCLOAK_URL=http://$(kubectl get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/auth
KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)

KEYCLOAK_ID=$(curl -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json"  $KEYCLOAK_URL/admin/realms/master/clients  | jq -r '.[] | select(.redirectUris[0] == "http://portal.petstore.com/callback") | .id')
KEYCLOAK_CLIENT=$(curl -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json"  $KEYCLOAK_URL/admin/realms/master/clients  | jq -r '.[] | select(.redirectUris[0] == "http://portal.petstore.com/callback") | .clientId')
KEYCLOAK_SECRET=$(curl -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json"  $KEYCLOAK_URL/admin/realms/master/clients/$KEYCLOAK_ID/client-secret | jq -r .value)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: petstore-portal-oidc-secret
  namespace: default
data:
  client_secret: $(echo $KEYCLOAK_SECRET | base64)
EOF
```

Let's create the **Portal**:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: Portal
metadata:
  name: petstore-portal
  namespace: default
spec:
  displayName: Petstore Portal
  description: The Developer Portal for the Petstore API
  banner:
    fetchUrl: https://i.imgur.com/EXbBN1a.jpg
  favicon:
    fetchUrl: https://i.imgur.com/QQwlQG3.png
  primaryLogo:
    fetchUrl: https://i.imgur.com/hjgPMNP.png
  customStyling: {}
  staticPages: []
  domains:
  - portal.petstore.com

  oidcAuth:
    callbackUrlPrefix: http://portal.petstore.com/
    clientId: ${KEYCLOAK_CLIENT}
    clientSecret:
      name: petstore-portal-oidc-secret
      namespace: default
      key: client_secret
    groupClaimKey: group
    issuer: ${KEYCLOAK_URL}/realms/master
  portalUrlPrefix: http://portal.petstore.com/

  publishedEnvironments:
  - name: dev
    namespace: default
EOF
```

You can now check the status of the Portal using the following command:

```bash
kubectl get portal -n default petstore-portal -oyaml
```

Create a Group CRD to allow the users of the `users` group to access the portal, the product and the environment:

```bash
cat << EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: Group
metadata:
  name: oidc-group
  namespace: default
spec:
  displayName: my-oidc-users-group
  accessLevel:
    apiProducts:
    - name: petstore
      namespace: default
      environments:
      - name: dev
        namespace: default
    portals:
    - name: petstore-portal
      namespace: default
  oidcGroup:
    groupName: users
EOF
```

You can now check the status of the **Group** using the following command:

```bash
kubectl get group -n default oidc-group -oyaml
```

## Lab 5: Explore the Administrative Interface

Let's run the following command to allow access of the admin UI of Gloo Portal:

```
kubectl port-forward -n dev-portal svc/admin-server 8000:8080
```

You can now access the admin UI at http://localhost:8000

![Admin Developer Portal](images/dev-portal-admin.png)

Take the time to explore the UI and see the different components we have created using `kubectl`.

## Lab 6: Explore the Portal Interface

The user Portal we have created is available at http://portal.petstore.com

![User Developer Portal](images/dev-portal-user.png)

Log in with the user `user1` and the password `password`.

Click "View APIs", then click on the version `v1`, scroll down and click on the `GET /v1/store/inventory` API call.

Click on `Try it out` and then on the `Execute` button.

You should get a 200 response:

![User Developer Portal API call OK](images/dev-portal-api-call-ok.png)

Take the time to explore the UI and see the difference between the 2 versions for the `POST /v2/pet` API call. Only v2 has the `photoUrls` key.

## Lab 7: Secure the access to the API with API keys

We've already secured the access to the Portal UI, but we didn't secure the API itself yet.

We can update the Environment to create a plan (called `Basic`) with its associated rate limit. Consumers will authenticate themselves using an API key:

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
  - dev.petstore.com
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  apiProducts:
  - name: petstore
    namespace: default
    # ----------------------- Add basic usage plan ----------------------
    plans:
    - authPolicy:
        apiKey: {}
      displayName: Basic
      name: basic
      rateLimit:
        requestsPerUnit: 5
        unit: MINUTE
    # -------------------------------------------------------------------
    publishedVersions:
    - name: v1
    - name: v2
EOF
```

And finally, we need to let the users of the `users` group to use this plan:

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
    - name: petstore
      namespace: default
      environments:
      - name: dev
        namespace: default
        # ----------------------- Add basic usage plan ----------------------
        plans:
        - basic
        # -------------------------------------------------------------------
    portals:
    - name: petstore-portal
      namespace: default
  oidcGroup:
    groupName: users
EOF
```

Go back to the Portal UI and try to execute the `GET /v1/store/inventory` API call again.

This time, you should get a 403 response.

Click on `user1@solo.io` on the top right corner and select `API Keys`.

Click on `API Keys` again and Add an API Key.

![User Developer Portal API Key](images/dev-portal-api-key.png)

You can click on the key to copy the value to the clipboard and `Authorize` the call through the UI, but this time we are going to use curl.

So, we need to retrieve the API key first:

```
key=$(kubectl get secret -l environments.devportal.solo.io=dev.default -n default -o jsonpath='{.items[0].data.api-key}' | base64 --decode)
```

Then, we can run the following command:

```
curl -H "api-key: ${key}" http://dev.petstore.com/v1/store/inventory -vvv
```

You should get a result similar to:

```
*   Trying 172.18.1.2...
* TCP_NODELAY set
* Connected to dev.petstore.com (172.18.1.2) port 80 (#0)
> GET /v1/store/inventory HTTP/1.1
> Host: dev.petstore.com
> User-Agent: curl/7.52.1
> Accept: */*
> api-key: YmMwYTE4OTEtOTA0Ni00OWY4LWQ0OTgtZDBjNDQ3YjUwM2Rm
> 
< HTTP/1.1 200 OK
< date: Wed, 03 Feb 2021 08:10:04 GMT
< access-control-allow-origin: *
< access-control-allow-methods: GET, POST, DELETE, PUT
< access-control-allow-headers: Content-Type, api_key, Authorization
< content-type: application/json
< server: envoy
< x-envoy-upstream-service-time: 2
< transfer-encoding: chunked
< 
* Curl_http_done: called premature == 0
* Connection #0 to host dev.petstore.com left intact
{"sold":1,"pending":2,"available":7}
```

Now, execute the curl command again several times.

As soon as you reach the rate limit, you should get the following output:

```
*   Trying 172.18.1.2...
* TCP_NODELAY set
* Connected to dev.petstore.com (172.18.1.2) port 80 (#0)
> GET /v1/store/inventory HTTP/1.1
> Host: dev.petstore.com
> User-Agent: curl/7.52.1
> Accept: */*
> api-key: YmMwYTE4OTEtOTA0Ni00OWY4LWQ0OTgtZDBjNDQ3YjUwM2Rm
> 
< HTTP/1.1 429 Too Many Requests
< x-envoy-ratelimited: true
< date: Wed, 03 Feb 2021 08:10:35 GMT
< server: envoy
< content-length: 0
< 
* Curl_http_done: called premature == 0
* Connection #0 to host dev.petstore.com left intact
```

### Gloo Edge Virtual Service

You can see the Gloo Edge Virtual Service updated by Gloo Portal using the command below:

```bash
kubectl get virtualservices.gateway.solo.io dev -o yaml
```

Here is the output:

```
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"devportal.solo.io/v1alpha1","kind":"Environment","metadata":{"annotations":{},"name":"dev","namespace":"default"},"spec":{"apiProducts":[{"name":"petstore","namespace":"default","plans":[{"authPolicy":{"apiKey":{}},"displayName":"Basic","name":"basic","rateLimit":{"requestsPerUnit":5,"unit":"MINUTE"}}],"publishedVersions":[{"name":"v1"},{"name":"v2"}]}],"displayInfo":{"description":"This environment is meant for developers to deploy and test their APIs.","displayName":"Development"},"domains":["dev.petstore.com"]}}
  creationTimestamp: "2021-02-01T16:14:40Z"
  generation: 37
  labels:
    cluster.multicluster.solo.io: ""
    environments.devportal.solo.io: dev.default
...
  name: dev
  namespace: default
  ownerReferences:
  - apiVersion: devportal.solo.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: Environment
    name: dev
    uid: 13c7a1e4-afcc-4ad9-896e-d62d4ac9194d
  resourceVersion: "414495"
  selfLink: /apis/gateway.solo.io/v1/namespaces/default/virtualservices/dev
  uid: 1862d8f2-93b2-46c6-91aa-56bd60b33ba3
spec:
  displayName: Development
  virtualHost:
    domains:
    - dev.petstore.com
    options:
      cors:
        allowHeaders:
        - api-key
        allowOrigin:
        - http://portal.petstore.com
        - https://portal.petstore.com
    routes:
    - matchers:
      - exact: /v1/pet

        methods:
        - POST
        - OPTIONS
      name: dev.default.petstore.default.petstore-v1.default.addPet
      options:
        extauth:
          configRef:
            name: dev
            namespace: default
        rateLimitConfigs:
          refs:
          - name: dev-default-petstore
            namespace: default
      routeAction:
        multi:
          destinations:
          - destination:
              upstream:
                name: petstore-v1-8080-default
                namespace: dev-portal
            weight: 1
...
```

The `extauth` and `rateLimitConfigs` options have been added on each route to secure the API.

## Lab 8: Secure the access to the API with OAuth tokens

We can update the Environment to create a plan (called `Basic auth`) with its associated rate limit. Consumers will authenticate themselves using an OAuth token:

```bash
KEYCLOAK_URL=http://$(kubectl get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/auth

cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
  - dev.petstore.com
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  apiProducts:
  - name: petstore
    namespace: default
    plans:
    # ----------------------------- Change authPolicy from apiKey to OAuth ------------------------------
    - authPolicy:
        oauth:
          authorizationUrl: ${KEYCLOAK_URL}/realms/master/protocol/openid-connect/auth
          tokenUrl: ${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token
          jwtValidation:
            issuer: ${KEYCLOAK_URL}/realms/master
            remoteJwks:
              refreshInterval: 60s
              url: ${KEYCLOAK_URL}/realms/master/protocol/openid-connect/certs
      displayName: Basic OAuth
      name: basic-oauth
    # ---------------------------------------------------------------------------------------------------
      rateLimit:
        requestsPerUnit: 5
        unit: MINUTE
    publishedVersions:
    - name: v1
    - name: v2
EOF
```

And finally, we need to let the users of the `users` group to use this plan:

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
    - name: petstore
      namespace: default
      environments:
      - name: dev
        namespace: default
        # ----------------------------- Specify new usage plan ------------------------------
        plans:
        - basic-oauth
        # -----------------------------------------------------------------------------------
    portals:
    - name: petstore-portal
      namespace: default
  oidcGroup:
    groupName: users
EOF
```

Now, we need to get an OAuth token:

```
token=$(curl -d "client_id=admin-cli" -d "username=user1" -d "password=password" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```

Then, we can run the following command:

```
curl -H "Authorization: Bearer ${token}" http://dev.petstore.com/v1/store/inventory -vvv
```

You should get a result similar to:

```
*   Trying 172.18.1.2:80...
* TCP_NODELAY set
* Connected to dev.petstore.com (172.18.1.2) port 80 (#0)
> GET /v1/store/inventory HTTP/1.1
> Host: dev.petstore.com
> User-Agent: curl/7.68.0
> Accept: */*
> Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI5UVJONFlBQm5EYzRGalRUTWpMVUNoU21qRER2TmNyek1EUTk1R25Ta240In0.eyJleHAiOjE2MTc5Nzc2NzQsImlhdCI6MTYxNzk3NzYxNCwianRpIjoiMjlhMDgyMDEtNTE3Ni00OGE2LTkyOTMtOTNkNWJmOGZkYmViIiwiaXNzIjoiaHR0cDovLzE3Mi4xOC4xLjE6ODA4MC9hdXRoL3JlYWxtcy9tYXN0ZXIiLCJzdWIiOiI5NDMyMGIyMS01ZDU0LTQ1NWEtYjI3Mi03ZTk4ZDFiMGIwYTIiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJhZG1pbi1jbGkiLCJzZXNzaW9uX3N0YXRlIjoiZTViMDgxNzgtMDA0NS00ZDBiLWJhMzgtN2VhYzcwYjcyZWE3IiwiYWNyIjoiMSIsInNjb3BlIjoiZW1haWwgcHJvZmlsZSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlcjEiLCJlbWFpbCI6InVzZXIxQHNvbG8uaW8ifQ.DU35ng9pyPS6ljXO7bTnt87Vj8dw0mE8PIHArKR5xzNvMn8mCFW5MyyM_FBrZwSCaYBFG5o_73bwPJ7drkj9xkCTnQrqzY174pJ0pJeNNggATMLw6pbJIp70hP3-gXP3ImqElPSU9mcx-kYBn6xt_zFvx9h-XmztIi_YHEJm-W6Dmjp1GWdFwepKOT1drrOCMC7mlUOp8QsLzUVvAv_ibK8SROslmQqqeXAP6wrjVm_GnFOYfse03pXLFImHoEh5bD4sJ8YTDtaWcLWcMMiiRCZ80wO76CmxNslaR-lCM2eSVbtpuXah1vnorS38QKitW85laDi50BWsy4M8yZ-w9A
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< date: Fri, 09 Apr 2021 14:13:36 GMT
< access-control-allow-origin: *
< access-control-allow-methods: GET, POST, DELETE, PUT
< access-control-allow-headers: Content-Type, api_key, Authorization
< content-type: application/json
< server: envoy
< x-envoy-upstream-service-time: 151
< transfer-encoding: chunked
< 
* Connection #0 to host dev.petstore.com left intact
{"sold":1,"pending":2,"available":7}
```

## Lab 9: gRPC

Gloo Portal can also be used to expose gRPC applications.

Let's deploy a gRPC version of our application:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: petstore-grpc
  name: petstore-grpc
  namespace: default
spec:
  selector:
    matchLabels:
      app: petstore-grpc
  replicas: 1
  template:
    metadata:
      labels:
        app: petstore-grpc
    spec:
      containers:
      - image: quay.io/solo-io/petstore-grpc:0.0.2
        name: petstore-grpc
        ports:
        - containerPort: 8080
          name: grpc
        env:
        - name: SERVER_PORT
          value: "8080"
---
apiVersion: v1
kind: Service
metadata:
  name: petstore-grpc
  namespace: default
  labels:
    service: petstore-grpc
spec:
  selector:
    app: petstore-grpc
  ports:
  - name: grpc
    port: 8080
    protocol: TCP

EOF
```

Let's create an **API Doc** using the reflection endpoint implemented by our gRPC application:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: devportal.solo.io/v1alpha1
kind: APIDoc
metadata:
  name: petstore-grpc-doc
  namespace: default
spec:
  grpc:
    reflectionSource:
      connectionTimeout: 5s
      insecure: true
      serviceAddress: petstore-grpc.default:8080
      # we use a reflection server here to tell the Gloo Portal
      # to fetch the schema contents directly from the petstore service.
EOF
```

You can then check the status of the API Doc using the following command:

```bash
kubectl get apidoc -n default petstore-grpc-doc -oyaml
```

Let's update our **API Product** to expose the gRPC **API Docs** we've just created:

```bash
cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: APIProduct
metadata:
  name: petstore
  namespace: default
spec:
  displayInfo: 
    description: Petstore Product
    title: Petstore Product
    image:
      fetchUrl: https://i.imgur.com/EXbBN1a.jpg
  versions:
  - name: v1
    apis:
    - apiDoc:
        name: petstore-v1
        namespace: default
    tags:
      stable: {}
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: petstore-v1
            namespace: default
            port: 8080
  - name: v2
    apis:
    - apiDoc:
        name: petstore-v2
        namespace: default
    tags:
      stable: {}
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: petstore-v2
            namespace: default
            port: 8080
  # ----------------------------- Add new gRPC version to APIProduct ------------------------------
  - name: v3
    apis:
    - apiDoc:
        name: petstore-grpc-doc
        namespace: default
    defaultRoute:
      inlineRoute:
        backends:
        - kube:
            name: petstore-grpc
            namespace: default
            port: 8080
  # -----------------------------------------------------------------------------------------------
    tags:
      stable: {}
EOF
```

You can then check the status of the API Product using the following command:

```bash
kubectl get apiproducts.devportal.solo.io petstore -o yaml
```

Note that the API Doc's reflection endpoint has been used to capture all the operations published by the Petstore gRPC interface.

```
apiVersion: devportal.solo.io/v1alpha1
kind: APIDoc
metadata:
  ...
  name: petstore-grpc-doc
  namespace: default
  ...
spec:
  grpc:
    reflectionSource:
      connectionTimeout: 5s
      insecure: true
      serviceAddress: petstore-grpc.default:8080
status:
  grpc:
    methods:
    - rpcName: ServerReflectionInfo
      rpcType: BIDIRECTIONAL_STREAMING
      serviceName: grpc.reflection.v1alpha.ServerReflection
    - rpcName: ListPets
      rpcType: UNARY
      serviceName: test.solo.io.PetStore
    - rpcName: FindPetById
      rpcType: UNARY
      serviceName: test.solo.io.PetStore
    - rpcName: AddPet
      rpcType: UNARY
      serviceName: test.solo.io.PetStore
    - rpcName: DeletePet
      rpcType: UNARY
      serviceName: test.solo.io.PetStore
    - rpcName: WatchPets
      rpcType: SERVER_STREAMING
      serviceName: test.solo.io.PetStore
  observedGeneration: 1
  state: Succeeded
```

Update the **Environment** to include the gRPC version:

```bash
KEYCLOAK_URL=http://$(kubectl get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/auth

cat << EOF | kubectl apply -f-
apiVersion: devportal.solo.io/v1alpha1
kind: Environment
metadata:
  name: dev
  namespace: default
spec:
  domains:
  - dev.petstore.com
  displayInfo:
    description: This environment is meant for developers to deploy and test their APIs.
    displayName: Development
  apiProducts:
  - name: petstore
    namespace: default
    plans:
    - authPolicy:
        oauth:
          authorizationUrl: ${KEYCLOAK_URL}/realms/master/protocol/openid-connect/auth
          tokenUrl: ${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token
          jwtValidation:
            issuer: ${KEYCLOAK_URL}/realms/master
            remoteJwks:
              refreshInterval: 60s
              url: ${KEYCLOAK_URL}/realms/master/protocol/openid-connect/certs
      displayName: Basic OAuth
      name: basic-oauth
      rateLimit:
        requestsPerUnit: 5
        unit: MINUTE
    publishedVersions:
    - name: v1
    - name: v2
    # ----------------------- Add v3 to dev Environment ----------------------
    - name: v3
    # ------------------------------------------------------------------------
EOF
```

Download and extract `grpcurl`:

```bash
wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.0/grpcurl_1.8.0_linux_x86_64.tar.gz
tar zxvf grpcurl_1.8.0_linux_x86_64.tar.gz 
```

Now, we need to get a new OAuth token:

```
token=$(curl -d "client_id=admin-cli" -d "username=user1" -d "password=password" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```

Then, we can run the following command:

```
./grpcurl -plaintext -H "Authorization: Bearer ${token}" -authority dev.petstore.com 172.18.1.2:80 test.solo.io.PetStore/ListPets
```

You should get a result similar to:

```
{
  "pets": [
    {
      "id": "1",
      "name": "Dog",
      "tags": [
        "puppy"
      ]
    },
    {
      "id": "2",
      "name": "Cat"
    }
  ]
}
```

## Lab 10: Portal rebranding

As you've seen in the previous lab, we've been able to provide a few pictures (banner, logo, etc.).

But you can completely change the look & feel of the **Portal** by providing your own CSS.

Let's use this feature to change the color of the title.

First of all, go to the main page of the Portal (http://portal.petstore.com) and click on the top right corner to open the menu of the web browser. Then, click on `Web Developer` and select `Inspector`.

In the developer tools, click on the arrow on the top left corner and then on the title:

![User Developer Portal Select HTML](images/dev-portal-select-html.png)

You can see the CSS below displayed on the right:

```
.home-page-portal-title {
    font-size: 48px;
    line-height: 58px;
    margin-top: 80px;
}
```

Go to the admin Portal (http://localhost:8000), click on `Portals` and then on the `Pestore Portal`.

Click on the `Advanced Portal Customization` link and provide the CSS below:

```
.home-page-portal-title {
    font-size: 48px;
    line-height: 58px;
    margin-top: 80px;
    color: gold
}
```

![User Developer Portal Admin CSS](images/dev-portal-admin-css.png)

Save the change and go back to the main page of the Portal:

![User Developer Portal After CSS](images/dev-portal-after-css.png)

Run the command below to see how the yaml of the Portal has been updated:

```bash
kubectl get portals.devportal.solo.io petstore-portal -o yaml
```

You'll see the new section below:

```
  customStyling:
    cssStylesheet:
      configMap:
        key: custom-stylesheet
        name: default-petstore-portal-custom-stylesheet
        namespace: default
```

Now, execute the following command to see the content of the config map:

```bash
kubectl get cm default-petstore-portal-custom-stylesheet -o yaml
```

Here is the expected output:

```
apiVersion: v1
binaryData:
  custom-stylesheet: LmhvbWUtcGFnZS1wb3J0YWwtdGl0bGUgewogICAgZm9udC1zaXplOiA0OHB4OwogICAgbGluZS1oZWlnaHQ6IDU4cHg7CiAgICBtYXJnaW4tdG9wOiA4MHB4OwogICAgY29sb3I6IGdvbGQ7Cn0=
kind: ConfigMap
metadata:
  creationTimestamp: "2021-02-03T08:16:05Z"
  managedFields:
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:binaryData:
        .: {}
        f:custom-stylesheet: {}
    manager: adminserver
    operation: Update
    time: "2021-02-03T08:47:50Z"
  name: default-petstore-portal-custom-stylesheet
  namespace: default
  resourceVersion: "419685"
  selfLink: /api/v1/namespaces/default/configmaps/default-petstore-portal-custom-stylesheet
  uid: 90148a56-519f-4953-a9fd-e7cb15411379
```

The `binaryData.custom-stylesheet` value is the CSS we provided encoded in base64.

You can use the CSS below to further rebrand it:

```
.home-page-portal-title {
    font-size: 48px;
    line-height: 58px;
    margin-top: 80px;
    color: gold;
}

.main-container-header {
    background: black;
}

.links-list a {
    color: white;
}

.links-list a.active {
    color: white;
}

.header-user-control-button {
    color: white;
}

.header-user-control-button[class~=is-open] {
    color: white;
}
```

## Lab 11: Extending the Portal

You can add static or dynamic pages.

It's very useful to provide additional information about your APIs, or even to load some billing information.

### Static pages

Static pages are very simple to add. You simply need to provide the content using the Markdown syntax.

Go to the admin Portal (http://localhost:8000), click on `Portals` and then on the `Pestore Portal`.

Click on the `Pages` tab and then on the `Add a Page` link.

Create a new `Static Page`:

![Developer Portal Static Page Create](images/dev-portal-static-page-create.png)

Then edit it to provide the Markdown content:

![Developer Portal Static Page Create](images/dev-portal-static-page-edit.png)

Publish the change, go back to the main page of the Portal and click on the `FAQ` button:

![User Developer Portal Static Page](images/dev-portal-static-page.png)

Again, run the command below to see how the yaml of the Portal has been updated:

```bash
kubectl get portals.devportal.solo.io petstore-portal -o yaml
```

You'll see the new section below:

```
  staticPages:
  - content:
      configMap:
        key: faq
        name: default-petstore-portal-faq
        namespace: default
    description: Frequently Asked Questions
    displayOnHomepage: true
    name: faq
    navigationLinkName: FAQ
    path: /faq
```

Now, execute the following command to see the content of the config map:

```bash
kubectl get cm default-petstore-portal-faq -o yaml
```

Here is the expected output:

```
apiVersion: v1
binaryData:
  faq: KipROiBDYW4gSSB1c2UgeW91ciBBUEkgdG8gc2VlIGhvdyBtYW55IHBldHMgYXJlIGF2YWlsYWJsZSA/KioKClI6IFllcywgeW91IGNhbg==
kind: ConfigMap
metadata:
  creationTimestamp: "2021-02-03T09:07:02Z"
  managedFields:
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:binaryData:
        .: {}
        f:faq: {}
    manager: adminserver
    operation: Update
    time: "2021-02-03T09:07:02Z"
  name: default-petstore-portal-faq
  namespace: default
  resourceVersion: "422806"
  selfLink: /api/v1/namespaces/default/configmaps/default-petstore-portal-faq
  uid: 5554f58e-807c-4238-97fb-7d6cb1f59533
```

The `binaryData.faq` value is the Markdown we provided encoded in base64.

### Dynamic pages

You can embed your own custom page in the Portal either by specifying a URL or by uploading your own file. In this example we will be uploading our own custom file that contains html and javascript.

It's very interesting because the Portal will pass to this page some information about the user and the API product.

Take a look at the content of the `dynamic.html` file that is located under `/home/solo/workshops/gloo-portal`.

The interesting part is the one below:

```
    <script>
      // the embedded page listens for a message event to receive data from the Portal
      window.addEventListener("message", function onMsg(msg) {
        // we must check the origin of the message to protect against XSS attacks
        if (msg.origin === "http://portal.petstore.com" && msg && msg.data) {
          let header = document.getElementById("user");
          let headerText = document.createTextNode(
            "the current user is: " + msg.data.currentUser
          );
          console.log("msg.data");
          console.log(msg.data);
          header.replaceWith(headerText);

          
          let apiProductInfo = document.getElementById("api-products");
          const apiProducts = document.createDocumentFragment();
          if (msg.data.apiProductsList.length > 0) {
            msg.data.apiProductsList.forEach((apiProduct) => {
              let apiProductEl = document.createElement("div");
              let apiProductText = document.createTextNode(
                "API Product: " +
                  apiProduct.displayName +
                  " with " +
                  apiProduct.versionsList.length +
                  " versions"
              );
              apiProductEl.appendChild(apiProductText);
              apiProducts.appendChild(apiProductEl);
            });
          }
          apiProductInfo.replaceWith(apiProducts);
        }
      });
    </script>
```

As you can see, Gloo Portal is passing information about the user and the API products to the dynamic page.

Click on the `Pages` tab and then on the `Add a Page` link.

Create a new `Dynamic Page`:

![Developer Portal Dynamic Page Create](images/dev-portal-dynamic-page-create.png)

You need to upload the `dynamic.html` file.

Go back to the main page of the Portal and click on the `Dynamic` button:

![User Developer Portal Dynamic Page](images/dev-portal-dynamic-page.png)

Again, run the command below to see how the yaml of the Portal has been updated:

```bash
kubectl get portals.devportal.solo.io petstore-portal -o yaml
```

You'll see the new section below:

```
  dynamicPages:
  - content:
      configMap:
        key: dynamic
        name: default-petstore-portal-dynamic
        namespace: default
    description: This is a dynamic page
    name: dynamic
    navigationLinkName: Dynamic
    path: /dynamic
```

Now, execute the following command to see the content of the config map:

```bash
kubectl get cm default-petstore-portal-dynamic -o yaml
```

Here is the expected output:

```
apiVersion: v1
binaryData:
  dynamic: PCFET0NUWVBFIGh0bWw+CjxodG1sIGxhbmc9ImVuIj4KICA8aGVhZD4KICAgIDxtZXRhIGNoYXJzZXQ9IlVURi04IiAvPgogICAgPG1ldGEgbmFtZT0idmlld3BvcnQiIGNvbnRlbnQ9IndpZHRoPWRldmljZS13aWR0aCwgaW5pdGlhbC1zY2FsZT0xLjAiIC8+CiAgICA8dGl0bGU+RGVtbyBQYWdlPC90aXRsZT4KICAgIDxzY3JpcHQ+CiAgICAgIC8vIHRoZSBlbWJlZGRlZCBwYWdlIGxpc3RlbnMgZm9yIGEgbWVzc2FnZSBldmVudCB0byByZWNlaXZlIGRhdGEgZnJvbSB0aGUgUG9ydGFsCiAgICAgIHdpbmRvdy5hZGRFdmVudExpc3RlbmVyKCJtZXNzYWdlIiwgZnVuY3Rpb24gb25Nc2cobXNnKSB7CiAgICAgICAgLy8gd2UgbXVzdCBjaGVjayB0aGUgb3JpZ2luIG9mIHRoZSBtZXNzYWdlIHRvIHByb3RlY3QgYWdhaW5zdCBYU1MgYXR0YWNrcwogICAgICAgIGlmIChtc2cub3JpZ2luID09PSAiaHR0cDovL3BvcnRhbC5wZXRzdG9yZS5jb20iICYmIG1zZyAmJiBtc2cuZGF0YSkgewogICAgICAgICAgbGV0IGhlYWRlciA9IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCJ1c2VyIik7CiAgICAgICAgICBsZXQgaGVhZGVyVGV4dCA9IGRvY3VtZW50LmNyZWF0ZVRleHROb2RlKAogICAgICAgICAgICAidGhlIGN1cnJlbnQgdXNlciBpczogIiArIG1zZy5kYXRhLmN1cnJlbnRVc2VyCiAgICAgICAgICApOwogICAgICAgICAgY29uc29sZS5sb2coIm1zZy5kYXRhIik7CiAgICAgICAgICBjb25zb2xlLmxvZyhtc2cuZGF0YSk7CiAgICAgICAgICBoZWFkZXIucmVwbGFjZVdpdGgoaGVhZGVyVGV4dCk7CgogICAgICAgICAgCiAgICAgICAgICBsZXQgYXBpUHJvZHVjdEluZm8gPSBkb2N1bWVudC5nZXRFbGVtZW50QnlJZCgiYXBpLXByb2R1Y3RzIik7CiAgICAgICAgICBjb25zdCBhcGlQcm9kdWN0cyA9IGRvY3VtZW50LmNyZWF0ZURvY3VtZW50RnJhZ21lbnQoKTsKICAgICAgICAgIGlmIChtc2cuZGF0YS5hcGlQcm9kdWN0c0xpc3QubGVuZ3RoID4gMCkgewogICAgICAgICAgICBtc2cuZGF0YS5hcGlQcm9kdWN0c0xpc3QuZm9yRWFjaCgoYXBpUHJvZHVjdCkgPT4gewogICAgICAgICAgICAgIGxldCBhcGlQcm9kdWN0RWwgPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCJkaXYiKTsKICAgICAgICAgICAgICBsZXQgYXBpUHJvZHVjdFRleHQgPSBkb2N1bWVudC5jcmVhdGVUZXh0Tm9kZSgKICAgICAgICAgICAgICAgICJBUEkgUHJvZHVjdDogIiArCiAgICAgICAgICAgICAgICAgIGFwaVByb2R1Y3QuZGlzcGxheU5hbWUgKwogICAgICAgICAgICAgICAgICAiIHdpdGggIiArCiAgICAgICAgICAgICAgICAgIGFwaVByb2R1Y3QudmVyc2lvbnNMaXN0Lmxlbmd0aCArCiAgICAgICAgICAgICAgICAgICIgdmVyc2lvbnMiCiAgICAgICAgICAgICAgKTsKICAgICAgICAgICAgICBhcGlQcm9kdWN0RWwuYXBwZW5kQ2hpbGQoYXBpUHJvZHVjdFRleHQpOwogICAgICAgICAgICAgIGFwaVByb2R1Y3RzLmFwcGVuZENoaWxkKGFwaVByb2R1Y3RFbCk7CiAgICAgICAgICAgIH0pOwogICAgICAgICAgfQogICAgICAgICAgYXBpUHJvZHVjdEluZm8ucmVwbGFjZVdpdGgoYXBpUHJvZHVjdHMpOwogICAgICAgIH0KICAgICAgfSk7CiAgICA8L3NjcmlwdD4KICA8L2hlYWQ+CgogIDxib2R5PgogICAgPGgxIGlkPSJ1c2VyIj48L2gxPgogICAgPGJyIC8+CiAgICA8aDEgaWQ9ImFwaS1wcm9kdWN0cyI+PC9oMT4KICA8L2JvZHk+CjwvaHRtbD4=
kind: ConfigMap
metadata:
  creationTimestamp: "2021-02-04T15:34:24Z"
  managedFields:
  - apiVersion: v1
    fieldsType: FieldsV1
    fieldsV1:
      f:binaryData:
        .: {}
        f:dynamic: {}
    manager: adminserver
    operation: Update
    time: "2021-02-04T15:34:24Z"
  name: default-petstore-portal-dynamic
  namespace: default
  resourceVersion: "11387"
  selfLink: /api/v1/namespaces/default/configmaps/default-petstore-portal-dynamic
  uid: d33b3c96-2325-476d-9c29-ce93f9c1e769
```

The `binaryData.dynamic` value is the content of the content of the `dynamic.html` file encoded in base64.

This is the end of the workshop. We hope you enjoyed it !











### Step 1.2

1 deployment of the Httpbin app

```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: httpbin
  namespace: default
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  namespace: default
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
  namespace: default
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




### Step 1.2

WithBelow are 4 versions of the Petstore OpenAPI spec:

Users only:

![Users only](images/OAI-snapshot-users-only.png)

Pets only:

![Pets only](images/OAI-snapshot-pets-only.png)

Pets and Users:

![Pets only](images/OAI-snapshot-pets-and-users.png)

All combined, with stores:

![All combined](images/OAI-snapshot-pets-full.png)

First, we will create 4 `APIDocs` from these different OpenAPI specifications, stored locally:

```bash
for i in petstore-openapi-v1-pets petstore-openapi-v1-users petstore-openapi-v1-pets-and-users petstore-openapi-v2-full; do
encoded=$(cat /home/solo/workshops/gloo-portal/openapi-specs/$i.json | base64 | sed 's/^/    /')

#k delete apidoc $i
#k delete cm $i

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: $i
  namespace: default
binaryData:
  doc: |
${encoded}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: portal.gloo.solo.io/v1beta1
kind: APIDoc
metadata:
  name: $i
  namespace: default
spec:
  openApi:
    content:
      configMap:
        name: $i
        namespace: default
        key: doc
EOF
; done
```
