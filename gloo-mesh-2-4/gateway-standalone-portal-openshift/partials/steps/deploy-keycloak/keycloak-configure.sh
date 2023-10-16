# Create initial token to register the client
read -r client token <<<\$(curl -m 2 -H "Authorization: Bearer \${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' \$KEYCLOAK_URL/admin/realms/master/clients-initial-access | jq -r '[.id, .token] | @tsv')
export KEYCLOAK_CLIENT=\${client}
# Register the client
read -r id secret <<<\$(curl -m 2 -X POST -d "{ \"clientId\": \"\${KEYCLOAK_CLIENT}\" }" -H "Content-Type:application/json" -H "Authorization: bearer \${token}" \${KEYCLOAK_URL}/realms/master/clients-registrations/default| jq -r '[.id, .secret] | @tsv')
export KEYCLOAK_SECRET=\${secret}
# Add allowed redirect URIs
curl -m 2 -H "Authorization: Bearer \${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["'https://\${ENDPOINT_HTTPS_GW_CLUSTER1}'/callback","'https://\${ENDPOINT_HTTPS_GW_CLUSTER1}'/*","'https://\${ENDPOINT_HTTPS_GW_CLUSTER1}'/get"]}' \$KEYCLOAK_URL/admin/realms/master/clients/\${id}
# Add the group attribute in the JWT token returned by Keycloak
curl -m 2 -H "Authorization: Bearer \${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' \$KEYCLOAK_URL/admin/realms/master/clients/\${id}/protocol-mappers/models
# Create first user
curl -m 2 -H "Authorization: Bearer \${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@example.com", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' \$KEYCLOAK_URL/admin/realms/master/users
# Create second user
curl -m 2 -H "Authorization: Bearer \${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user2", "email": "user2@solo.io", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' \$KEYCLOAK_URL/admin/realms/master/users