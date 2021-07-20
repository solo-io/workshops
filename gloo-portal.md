# Gloo Portal Workshop

Gloo Portal provides a framework for managing API definitions, API client identity, and API policies on top of Gloo Edge or Istio Ingress Gateway. Vendors of API products can leverage Gloo Portal to secure, manage, and publish their APIs independently of the operations used to manage networking infrastructure.

This workshop aims to expose some key features of the Gloo Portal like API lifecycle, authentication, and branding.

## OpenAPI vs Swagger

OpenAPI is a specification, while Swagger is a toolset for implementing the OpenAPI specification.

The OpenAPI Specification \(OAS\) defines a standard, language-agnostic interface to RESTful APIs, which allows both humans and computers to discover and understand the service's capabilities without access to source code, documentation, or through network traffic inspection. When properly defined, a consumer can understand and interact with the remote service with minimal implementation logic.

Swagger is the name associated with some of the most well-known and widely used tools for implementing the OpenAPI specification. The Swagger toolset includes a mix of open-source, free, and commercial tools, which can be used at different stages of the API lifecycle.

## Lab Environment

The Lab environment consists of a Virtual Machine where you will deploy a Kubernetes cluster using [kind](https://kind.sigs.k8s.io/).  You will then deploy Gloo Edge and Gloo Portal on this Kubernetes cluster.

## Lab 0: Deploy a Kubernetes Cluster and Keycloak

Go to the `/home/solo/workshops/gloo-portal` directory:

```text
cd /home/solo/workshops/gloo-portal
```

Deploy a local Kubernetes cluster using this command:

```bash
../scripts/deploy.sh 1 gloo-portal
```

Then verify that your Kubernetes cluster is ready:

```bash
../scripts/check.sh gloo-portal
```

The `check.sh` script will return immediately with no output if the cluster is ready. Otherwise, it will output a series of periodic "waiting" messages until the cluster is up.

[Keycloak](https://keycloak.org) is an open-source identity management platform that we will use to secure access to the Gloo Portal.

First, let's deploy a Keycloak instance to our Kubernetes cluster:

```bash
kubectl create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes-examples/keycloak.yaml
kubectl rollout status deploy/keycloak
```

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

## Lab 1: Build an application from an OpenAPI document

As explained above, Swagger is a set of tools and one of the Swagger tools is called [Swagger Codegen](https://github.com/swagger-api/swagger-codegen).

It allows generation of API client libraries \(SDK generation\), server stubs and documentation automatically given an OpenAPI Spec.

In this lab, we'll use it to create a demo application from an OpenAPI document. But we won't even need to deploy `Swagger Codegen` because it's available online on a service called [Swagger Generator](https://generator.swagger.io/).

![Swagger Generator](.gitbook/assets/swagger-generator.png)

And the demo application we will build is called the [Swagger Petstore](https://github.com/swagger-api/swagger-petstore).

The OpenAPI document of the `Petstore` application is available [here](https://petstore.swagger.io/v2/swagger.json).

Run the following command to see the beginning of the document, formatted using `jq`:

```text
curl -s https://petstore.swagger.io/v2/swagger.json | jq . | head -25
```

The output should be similar to this:

```text
{
  "swagger": "2.0",
  "info": {
    "description": "This is a sample server Petstore server.  You can find out more about Swagger at [http://swagger.io](http://swagger.io) or on [irc.freenode.net, #swagger](http://swagger.io/irc/).  For this sample, you can use the api key `special-key` to test the authorization filters.",
    "version": "1.0.5",
    "title": "Swagger Petstore",
    "termsOfService": "http://swagger.io/terms/",
    "contact": {
      "email": "apiteam@swagger.io"
    },
    "license": {
      "name": "Apache 2.0",
      "url": "http://www.apache.org/licenses/LICENSE-2.0.html"
    }
  },
  "host": "petstore.swagger.io",
  "basePath": "/v2",
  "tags": [
    {
      "name": "pet",
      "description": "Everything about your Pets",
      "externalDocs": {
        "description": "Find out more",
        "url": "http://swagger.io"
      }
```

You can see a key called `basePath` with a value `v2`.

Including the version of an API in the `basePath` is a common way to manage the lifecycle of an application, even if there is no standard. Other approaches exist \(like using a header, a different host, etc.\).

There are 2 OpenAPI documents in the current directory:

* swagger-petstore-v1.json
* swagger-petstore-v2.json

Run the following command to see the different between the 2 files:

```text
diff swagger-petstore-v1.json swagger-petstore-v2.json
```

Here is the expected output:

```text
17c17
<   "basePath": "/v1",
---
>   "basePath": "/v2",
910c910,911
<         "name"
---
>         "name",
>         "photoUrls"
922a924,935
>         },
>         "photoUrls": {
>           "type": "array",
>           "xml": {
>             "wrapped": true
>           },
>           "items": {
>             "type": "string",
>             "xml": {
>               "name": "photoUrl"
>             }
>           }
```

The v1 is just missing an attribute, named `photoUrls`, on the `Pet` object.

### Generate a Go skeleton from the v1

Run the command below to generate the application code using the `swagger-petstore-v1.json`:

```bash
wget -O petstore-v1.zip $(curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{
  "swaggerUrl": "https://github.com/solo-io/workshops/raw/master/gloo-portal/swagger-petstore-v1.json"
}' 'https://generator.swagger.io/api/gen/servers/go-server' | jq -r .link)
```

Uncompress the archive:

```bash
rm -rf petstore-v1
unzip petstore-v1.zip -d petstore-v1
```

Go to the `petstore-v1/go-server-server` directory:

```bash
cd petstore-v1/go-server-server
```

Take a look at the content of the `go/api_pet.go` file:

```text
/*
 * Swagger Petstore
 *
 * This is a sample server Petstore server.  You can find out more about Swagger at [http://swagger.io](http://swagger.io) or on [irc.freenode.net, #swagger](http://swagger.io/irc/).  For this sample, you can use the api key `special-key` to test the authorization filters.
 *
 * API version: 1.0.5
 * Contact: apiteam@swagger.io
 * Generated by: Swagger Codegen (https://github.com/swagger-api/swagger-codegen.git)
 */

package swagger

import (
    "net/http"
)

func AddPet(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func DeletePet(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func FindPetsByStatus(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func FindPetsByTags(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func GetPetById(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func UpdatePet(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func UpdatePetWithForm(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}

func UploadFile(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json; charset=UTF-8")
    w.WriteHeader(http.StatusOK)
}
```

As you can see, `Swagger Generator` has created the skeleton for our application, but we would still need to write all the logic around creating objects, updating objects, ...

We won't implement this logic here. Instead we're going to use the `swaggerapi/petstore` Docker image. Luckily, an environment variable called `SWAGGER_BASE_PATH` can be set to define the base path we want to use. We'll use it to simulate the deployment of 2 versions of the `Petstore` application.

### Deploy the 2 versions

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

In Gloo Portal, an **Environment** corresponds to a collection of compute resources where applications are deployed. This mirrors the practices of many organizations with development and production environments, often with multiple intermediate environments, such as those for shared testing and staging. We begin by creating an **Environment** named `dev`, using the domain `dev.petstore.com` to expose the `v1` and `v2` versions of the `Petstore` application.

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

When targeting Gloo Edge, Gloo Portal manages a set of Gloo Edge Custom Resource Definitions \(CRDs\) on behalf of users:

* **VirtualServices**: Gloo Portal generates a Gloo Edge **VirtualService** for each **API Product**. The **VirtualService** contains a single HTTP route for each API operation exposed in the product. Routes are named and their matchers are derived from the OpenAPI document.
* **Upstreams**: Gloo Portal generates a Gloo **Upstream** for each unique destination referenced in an **API Product** route.

We need to update the `/etc/hosts` file to be able to access our API \(and later the Portal\):

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

```text
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

```text
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

```text
kubectl port-forward -n dev-portal svc/admin-server 8000:8080
```

You can now access the admin UI at [http://localhost:8000](http://localhost:8000)

![Admin Developer Portal](.gitbook/assets/dev-portal-admin%20%285%29.png)

Take the time to explore the UI and see the different components we have created using `kubectl`.

## Lab 6: Explore the Portal Interface

The user Portal we have created is available at [http://portal.petstore.com](http://portal.petstore.com)

![User Developer Portal](.gitbook/assets/dev-portal-user%20%289%29.png)

Log in with the user `user1` and the password `password`.

Click "View APIs", then click on the version `v1`, scroll down and click on the `GET /v1/store/inventory` API call.

Click on `Try it out` and then on the `Execute` button.

You should get a 200 response:

![User Developer Portal API call OK](.gitbook/assets/dev-portal-api-call-ok.png)

Take the time to explore the UI and see the difference between the 2 versions for the `POST /v2/pet` API call. Only v2 has the `photoUrls` key.

## Lab 7: Secure the access to the API with API keys

We've already secured the access to the Portal UI, but we didn't secure the API itself yet.

We can update the Environment to create a plan \(called `Basic`\) with its associated rate limit. Consumers will authenticate themselves using an API key:

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

![User Developer Portal API Key](.gitbook/assets/dev-portal-api-key%20%282%29.png)

You can click on the key to copy the value to the clipboard and `Authorize` the call through the UI, but this time we are going to use curl.

So, we need to retrieve the API key first:

```text
key=$(kubectl get secret -l environments.devportal.solo.io=dev.default -n default -o jsonpath='{.items[0].data.api-key}' | base64 --decode)
```

Then, we can run the following command:

```text
curl -H "api-key: ${key}" http://dev.petstore.com/v1/store/inventory -vvv
```

You should get a result similar to:

```text
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

```text
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

```text
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

We can update the Environment to create a plan \(called `Basic auth`\) with its associated rate limit. Consumers will authenticate themselves using an OAuth token:

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

```text
token=$(curl -d "client_id=admin-cli" -d "username=user1" -d "password=password" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```

Then, we can run the following command:

```text
curl -H "Authorization: Bearer ${token}" http://dev.petstore.com/v1/store/inventory -vvv
```

You should get a result similar to:

```text
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

```text
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

```text
token=$(curl -d "client_id=admin-cli" -d "username=user1" -d "password=password" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
```

Then, we can run the following command:

```text
./grpcurl -plaintext -H "Authorization: Bearer ${token}" -authority dev.petstore.com 172.18.1.2:80 test.solo.io.PetStore/ListPets
```

You should get a result similar to:

```text
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

As you've seen in the previous lab, we've been able to provide a few pictures \(banner, logo, etc.\).

But you can completely change the look & feel of the **Portal** by providing your own CSS.

Let's use this feature to change the color of the title.

First of all, go to the main page of the Portal \([http://portal.petstore.com](http://portal.petstore.com)\) and click on the top right corner to open the menu of the web browser. Then, click on `Web Developer` and select `Inspector`.

In the developer tools, click on the arrow on the top left corner and then on the title:

![User Developer Portal Select HTML](.gitbook/assets/dev-portal-select-html.png)

You can see the CSS below displayed on the right:

```text
.home-page-portal-title {
    font-size: 48px;
    line-height: 58px;
    margin-top: 80px;
}
```

Go to the admin Portal \([http://localhost:8000](http://localhost:8000)\), click on `Portals` and then on the `Pestore Portal`.

Click on the `Advanced Portal Customization` link and provide the CSS below:

```text
.home-page-portal-title {
    font-size: 48px;
    line-height: 58px;
    margin-top: 80px;
    color: gold
}
```

![User Developer Portal Admin CSS](.gitbook/assets/dev-portal-admin-css.png)

Save the change and go back to the main page of the Portal:

![User Developer Portal After CSS](.gitbook/assets/dev-portal-after-css.png)

Run the command below to see how the yaml of the Portal has been updated:

```bash
kubectl get portals.devportal.solo.io petstore-portal -o yaml
```

You'll see the new section below:

```text
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

```text
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

```text
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

Go to the admin Portal \([http://localhost:8000](http://localhost:8000)\), click on `Portals` and then on the `Pestore Portal`.

Click on the `Pages` tab and then on the `Add a Page` link.

Create a new `Static Page`:

![Developer Portal Static Page Create](.gitbook/assets/dev-portal-static-page-create.png)

Then edit it to provide the Markdown content:

![Developer Portal Static Page Create](.gitbook/assets/dev-portal-static-page-edit.png)

Publish the change, go back to the main page of the Portal and click on the `FAQ` button:

![User Developer Portal Static Page](.gitbook/assets/dev-portal-static-page.png)

Again, run the command below to see how the yaml of the Portal has been updated:

```bash
kubectl get portals.devportal.solo.io petstore-portal -o yaml
```

You'll see the new section below:

```text
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

```text
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

```text
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

![Developer Portal Dynamic Page Create](.gitbook/assets/dev-portal-dynamic-page-create.png)

You need to upload the `dynamic.html` file.

Go back to the main page of the Portal and click on the `Dynamic` button:

![User Developer Portal Dynamic Page](.gitbook/assets/dev-portal-dynamic-page.png)

Again, run the command below to see how the yaml of the Portal has been updated:

```bash
kubectl get portals.devportal.solo.io petstore-portal -o yaml
```

You'll see the new section below:

```text
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

```text
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

