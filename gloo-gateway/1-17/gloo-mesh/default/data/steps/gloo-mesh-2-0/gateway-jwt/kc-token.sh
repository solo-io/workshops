#!/bin/bash
echo "##### Saving Keycloak token #####"
export USER2_COOKIE_JWT=$(curl -Ssm 10 --fail-with-body \
  -d "client_id=gloo-ext-auth" \
  -d "client_secret=hKcDcqmUKCrPkyDJtCw066hTLzUbAiri" \
  -d "username=user2" \
  -d "password=password" \
  -d "grant_type=password" \
  "$KEYCLOAK_URL/realms/workshop/protocol/openid-connect/token" |
  jq -r .access_token)
kubectl -n keycloak create secret generic user2-token-jwt --from-literal=token=$USER2_COOKIE_JWT --dry-run=client -oyaml | kubectl --context ${MGMT} apply -f -
echo "User2 token: $USER2_COOKIE_JWT"
echo "##### Done getting tokens #####"