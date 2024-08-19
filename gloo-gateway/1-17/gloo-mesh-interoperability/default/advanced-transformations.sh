#!/usr/bin/env bash
source /root/.env 2>/dev/null || true
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
echo "executing test dist/gloo-gateway-workshop/build/templates/steps/apps/httpbin/advanced-transformations/tests/header-added.test.js.liquid"
tempfile=$(mktemp)
echo "saving errors in ${tempfile}"
timeout --signal=INT 3m mocha ./test.js --timeout 10000 --retries=120 --bail 2> ${tempfile} || { cat ${tempfile} && exit 1; }
