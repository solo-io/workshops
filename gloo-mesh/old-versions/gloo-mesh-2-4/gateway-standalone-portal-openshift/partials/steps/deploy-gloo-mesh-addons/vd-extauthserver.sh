kind: Namespace
apiVersion: v1
metadata:
  name: gloo-mesh-addons
---
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: extauthserver
  namespace: gloo-mesh-addons
spec:
  hosts:
  - extauth.global
  services:
  - labels:
      app: ext-auth-service
    cluster: cluster1
  ports:
    - number: 8083
      protocol: GRPC