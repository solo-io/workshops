helm upgrade --install gloo-platform gloo-platform/gloo-platform \
  --namespace gloo-mesh-addons \
  --kube-context= \
  --version 2.4.2 \
 -f -<<EOF
common:
  cluster: 
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