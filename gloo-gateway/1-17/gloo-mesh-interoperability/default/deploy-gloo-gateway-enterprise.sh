#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
kubectl --context $CLUSTER1 apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
helm repo add gloo-ee-helm https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade -i -n gloo-system \
  gloo-gateway gloo-ee-helm/gloo-ee \
  --create-namespace \
  --version 1.17.1 \
  --kube-context $CLUSTER1 \
  --set-string license_key=$LICENSE_KEY \
  -f -<<EOF
gloo:
  kubeGateway:
    enabled: true
    gatewayParameters:
      glooGateway:
        istio:
          istioProxyContainer:
            istioDiscoveryAddress: istiod-1-23.istio-system.svc:15012
            istioMetaClusterId: cluster1
            istioMetaMeshId: mesh1
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gateway:
    persistProxySpec: false
    logLevel: info
    validation:
      enabled: false
      disableTransformationValidation: false
      alwaysAcceptResources: false
  gloo:
    logLevel: info
    deployment:
      replicas: 1
      customEnv:
        - name: GG_PORTAL_PLUGIN
          value: "true"
      livenessProbeEnabled: true
  discovery:
    enabled: false
  rbac:
    namespaced: true
    nameSuffix: gg-demo
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
settings:
  disableKubernetesDestinations: true
global:
  extensions:
    rateLimit:
      enabled: true
    extAuth:
      enabled: true
  istioSDS:
    enabled: true
  istioIntegration:
    enabled: true
    enableAutoMtls: true
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/deploy-gloo-gateway-enterprise/tests/check-gloo.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
