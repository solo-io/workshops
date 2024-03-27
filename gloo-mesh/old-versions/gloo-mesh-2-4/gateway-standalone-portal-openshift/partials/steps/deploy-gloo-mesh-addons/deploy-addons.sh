helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh-addons \
  --kube-context=undefined \
  --version 2.4.6 \
 -f -<<EOF
common:
  cluster: undefined
glooPortalServer:
  enabled: true
  apiKeyStorage:
    redis:
      enabled: true
      address: redis.gloo-mesh-addons:6379
    secretKey: ThisIsSecret
glooAgent:
  enabled: false
  floatingUserId: true
extAuthService:
  enabled: true
  extAuth:
    apiKeyStorage:
      name: redis
      enabled: true
      config: 
        connection: 
          host: redis.gloo-mesh-addons:6379
      secretKey: ThisIsSecret
rateLimiter:
  enabled: true
EOF