#!/usr/bin/env bash

echo "##### Deploy a KinD cluster #####"
source deploy-kind-cluster.sh

echo "##### Deploy and register Gloo Mesh #####"
source deploy-and-register-gloo-mesh.sh

echo "##### Deploy Istio using Gloo Mesh Lifecycle Manager #####"
source istio-lifecycle-manager-install.sh

echo "##### Deploy the Bookinfo demo app #####"
source deploy-bookinfo.sh

echo "##### Deploy the httpbin demo app #####"
source deploy-httpbin.sh

echo "##### Deploy Gloo Mesh Addons #####"
source deploy-gloo-mesh-addons.sh

echo "##### Create the gateways workspace #####"
source create-gateways-workspace.sh

echo "##### Create the bookinfo workspace #####"
source create-bookinfo-workspace.sh

echo "##### Expose the productpage through a gateway #####"
source gateway-expose.sh

echo "##### Create the httpbin workspace #####"
source create-httpbin-workspace.sh

echo "##### Expose an external service #####"
source gateway-external-service.sh

echo "##### Deploy Keycloak #####"
source deploy-keycloak.sh

echo "##### Securing the access with OAuth #####"
source gateway-extauth-oauth.sh

echo "##### Use the transformation filter to manipulate headers #####"
source gateway-transformation.sh

echo "##### Use the DLP policy to mask sensitive data #####"
source gateway-dlp.sh

echo "##### Apply rate limiting to the Gateway #####"
source gateway-ratelimiting.sh

echo "##### Use the Web Application Firewall filter #####"
source gateway-waf.sh

echo "##### Use the JWT filter to create headers from claims #####"
source gateway-jwt.sh

echo "##### Deploy Gloo Gateway #####"
source deploy-gloo-gateway-enterprise.sh

echo "##### Deploy the httpbin demo app #####"
source deploy-httpbin_1.sh

echo "##### Deploy Keycloak #####"
source deploy-keycloak_1.sh

echo "##### Expose the httpbin application through the gateway #####"
source expose-httpbin.sh

echo "##### Delegate with control #####"
source delegation.sh

echo "##### Modify the requests and responses #####"
source transformations.sh

echo "##### Split traffic between 2 backend services #####"
source traffic-split.sh

echo "##### Securing the access with OAuth #####"
source extauth-oauth.sh

echo "##### Use the transformation filter to manipulate headers #####"
source advanced-transformations.sh

echo "##### Apply rate limiting to the Gateway #####"
source ratelimiting.sh

echo "##### Use the Web Application Firewall filter #####"
source waf.sh

echo "##### Use the JWT filter to validate JWT and create headers from claims #####"
source jwt.sh

echo "##### Deploy Argo Rollouts #####"
source deploy-argo-rollouts.sh

echo "##### Roll out a new app version using Argo Rollouts #####"
source canary-rollout.sh

echo "##### Deploy the Bookinfo sample application #####"
source deploy-bookinfo_1.sh

echo "##### Expose the productpage API securely #####"
source dev-portal-api.sh

echo "##### Expose an external API and stitch it with the productpage API #####"
source dev-portal-stitching.sh

echo "##### Expose the dev portal backend #####"
source dev-portal-backend.sh

echo "##### Deploy and expose the dev portal frontend #####"
source dev-portal-frontend.sh

echo "##### Dev portal monetization #####"
source dev-portal-monetization.sh

echo "##### Deploy Backstage with the backend plugin #####"
source dev-portal-backstage-backend.sh
