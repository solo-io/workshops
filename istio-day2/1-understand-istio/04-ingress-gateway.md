# Lab 4 :: Ingress Gateway

Getting started with Envoy based technology is best by starting small and iteratively growing. In this lab, we'll take a look at adopting Envoy first at the edge with the Istio ingress gateway. The intention of the ingress gateway is to allow traffic into the mesh. If you need more sophisticated edge gateway capabilities (rate limiting, request transformation, OIDC, LDAP, OPA, etc) then use a gateway specifically built for those use cases like [Gloo Edge](https://docs.solo.io/gloo-edge/latest/). 


## Prerequisites

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-day2/1-understand-istio/`. 

This lab builds on both lab 02 and 03 where we already installed Istio control plane using a minimal profile and using revisions. 

## Install Istio ingress gateway

We will continue the approach of using separate installation files for Istio components. We will install the ingress gateway using the following approach. This allows us to separate upgrades/changes to the control plane from the ingress gateway. Since the ingress gateway is likely taking production traffic, we want to treat it separately from other components. Let's install it using the following approach:

```bash
cat labs/04/ingress-gateways.yaml
```

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-ingress-gw-install
spec:
  profile: empty
  values:
    gateways:
      istio-ingressgateway:
        autoscaleEnabled: false
  components:
    ingressGateways:
    - name: istio-ingressgateway
      namespace: istio-system
      enabled: true
      k8s:
        overlays:
        - apiVersion: apps/v1
          kind: Deployment
          name: istio-ingressgateway
          patches:
          - path: spec.template.spec.containers[name:istio-proxy].lifecycle
            value:
               preStop:
                 exec:
                   command: ["sh", "-c", "sleep 5"]
```
Note this uses the `empty` profile and enables the `istio-ingressgateway` component. Let's install it with a revision that matches the control plane:

```bash
istioctl install -y -n istio-system -f labs/04/ingress-gateways.yaml --revision 1-8-3
```

We should check that the ingress gateway was correctly installed:

```bash
kubectl get po -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-5686db779c-8nr5p   1/1     Running   0          78s
istiod-1-8-3-5f4f595578-b22c8           1/1     Running   0          40m
kiali-7cb6f7f74d-k68mk                  1/1     Running   0          21m
```

The ingress gateway will create a Kubernetes Service of type `LoadBalancer`. Use this IP address to reach the gateway:

```bash
kubectl get svc -n istio-system
```

```
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.44.0.91     35.202.132.20   15021:32218/TCP,80:30062/TCP,443:30105/TCP,15012:32488/TCP,15443:30178/TCP   5m45s
istiod                 ClusterIP      10.44.10.140   <none>          15010/TCP,15012/TCP,443/TCP,15014/TCP                                        47m
istiod-1-8-3           ClusterIP      10.44.11.8     <none>          15010/TCP,15012/TCP,443/TCP,15014/TCP                                        44m
kiali                  ClusterIP      10.44.4.127    <none>          20001/TCP,9090/TCP                                                           26m
```

```bash
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

## Expose our apps

Even though we don't have our apps in the `istioinaction` namespace in the mesh yet, we can still use the Istio ingress gateway to route traffic to them. Let's apply a `Gateway` and `VirtualService` resource to permit this:

```bash
kubectl -n istioinaction apply -f sample-apps/ingress/
```

The ingress gateway will create new routes on the proxy that we should be able to call:

```bash
curl -H "Host: istioinaction.io" http://$GATEWAY_IP
```

We can query the gateway configuration using the `istioctl proxy-config` command:

```bash
istioctl proxy-config routes deploy/istio-ingressgateway.istio-system 
```

```
NOTE: This output only contains routes loaded via RDS.
NAME        DOMAINS              MATCH                  VIRTUAL SERVICE
http.80     istioinaction.io     /*                     web-api-gw-vs.istioinaction
            *                    /stats/prometheus*     
            *                    /healthz/ready*    
```

If we wanted to see an individual route, we can ask for its output as `json` like this:

```bash
istioctl proxy-config routes deploy/istio-ingressgateway.istio-system --name http.80 -o json
```


## Securing inbound traffic with HTTPS

To secure inbound traffic with HTTPS, we need a certificate with the appropriate SAN. Let's create one for `istioinaction.io`:

```bash
kubectl create -n istio-system secret tls istioinaction-cert --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt
```

We can update the gateway to use this cert:

```bash
cat labs/04/web-api-gw-https.yaml
```

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: web-api-gateway
spec:
  selector:
    istio: ingressgateway 
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "istioinaction.io"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "istioinaction.io"    
    tls:
      mode: SIMPLE
      credentialName: istioinaction-cert
```

Note, we are pointing to the `istioinaction-cert` and **that the cert must be in the same namespace as the ingress gateway deployment**. Even though the `Gateway` resource is in the `istioinaction` namespace, _the cert must be where the gateway is actually deployed_. 

```bash
kubectl -n istioinaction apply -f labs/04/web-api-gw-https.yaml
```

Example calling it:

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

What are some common issues that folks run into with this approach?

1) Users may not have access to write anything (ie, certs) into `istio-system`
2) Users may not manage their own certs
3) Integration with CA/PKI is highly desirable

Let's dig into these a bit. Let's delete the secret we created earlier and see what other options we have:

```bash
kubectl delete secret -n istio-system istioinaction-cert
```

## Integrate Istio ingress gateway with Cert Manager

In the previous lab we already had a cert for our domain. In this lab, let's use cert-manager to provision the certs for us using a backend CA. In this lab, the CA will be our own CA but cert-manager can be integrated with a lot of backend PKI --- which is a big reason why cert manager is so popular. 

Let's prep for the installation of cert manager:

```bash
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

Now do the actual installation:

```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.2.0 --create-namespace --set installCRDs=true
```

Verify things installed correctly:

```bash
kubectl get po -n cert-manager
```

Output:

```
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-85f9bbcd97-zslwx              1/1     Running   0          2m45s
cert-manager-cainjector-74459fcc56-xq6pk   1/1     Running   0          2m45s
cert-manager-webhook-57d97ccc67-xtl82      1/1     Running   0          2m45s
```

Since we're going to use our own CA as the backend, let's install the correct root certs/keys:

```bash
kubectl create -n cert-manager secret tls cert-manager-cacerts --cert labs/04/certs/ca/root-ca.crt --key labs/04/certs/ca/root-ca.key
```

NOTE: this is just for the lab... ideally if you use cert-manager, you'll be using Vault, LetsEncrypt, or your own PKI.

Let's configure a `ClusterIssuer` to use our CA:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: sandbox
spec:
  ca:
    secretName: cert-manager-cacerts
```

```bash
kubectl apply -f labs/04/cert-manager/ca-cluster-issuer.yaml 
```

Before we ask cert-manager to issue us a new cert for `istioinaction.io`, let's make sure we delete it from the previous lab:

```bash
kubectl delete secret -n istio-system istioinaction-cert
```

Now let's ask cert-manager to issue us a secret:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istioinaction-cert
  namespace: istio-system
spec:
  secretName: istioinaction-cert
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  subject:
    organizations:
    - solo.io
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
  - istioinaction.io  
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
```

```bash
kubectl apply -f labs/04/cert-manager/istioinaction-io-cert.yaml 
```

Let's make sure the certificate was recognized and issued:

```bash
kubectl get Certificate -n istio-system
```

```
NAME                 READY   SECRET               AGE
istioinaction-cert   True    istioinaction-cert   12s
```

Let's check the certificate SAN was specified correctly as `istioinaction.io`:

```bash
kubectl get secret -n istio-system istioinaction-cert -o jsonpath="{.data['tls\.crt']}" | base64 -D | step certificate inspect -
```

## Certificates in own namespace

Some teams choose to restrict access to `istio-system` namespace but still allow teams to own the resources in their own namespaces. For example, some organizations own the `istio-system` by the platform team, but service teams and SRE can help install things like secrets into their own namespace. For example, with our `istioinaction` namespace, we would be able to access only `istioinaction` namespace and not `istio-system`. 

We can use [kubed](https://appscode.com/products/kubed/v0.11.0/guides/config-syncer/intra-cluster/) to help sync secrets to the appropriate namespace.

Let's install `kubed`:

```bash
helm repo add appscode https://charts.appscode.com/stable/
helm repo update
helm install kubed appscode/kubed --version v0.12.0 --namespace kube-system
```

Let's uninstall the certs created by cert-manager:

```bash
kubectl delete -f ./labs/04/cert-manager/istioinaction-io-cert.yaml
kubectl -n istio-system delete secret istioinaction-cert
kubectl rollout restart deploy/istio-ingressgateway -n istio-system
```

You can check if the cert is still loaded in the istio ingress gateway, for example:

```bash
istioctl pc secret deploy/istio-ingressgateway -n istio-system 
```

```
RESOURCE NAME                       TYPE           STATUS      VALID CERT     SERIAL NUMBER                               NOT AFTER                NOT BEFORE
kubernetes://istioinaction-cert                    WARMING     false                                                                               
default                             Cert Chain     ACTIVE      true           241284066253111748685603285574737309740     2021-03-03T17:52:27Z     2021-03-02T17:52:27Z
ROOTCA                              CA             ACTIVE      true           266801602762712535092892179697980789542     2031-02-28T16:35:53Z     2021-03-02T16:35:53Z
```

Now let's go ahead and create the cert in our own (`istioinaction`) namespace:

```bash
kubectl create -n istioinaction secret tls istioinaction-cert --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt
```

This doesn't help us much because the Istio ingress gateway is located in the `istio-system` namespace and the secret must be there too but we don't have access to this namespace.

Let's use `kubed` to help here. Let's label `istio-system` namespace (done by an administrator) to indicate we can sync secrets to it:

```bash
kubectl label namespace istio-system secrets-sync=true
```

Then from our namespace we can label it and have it automatically sync'd:

```bash
kubectl -n istioinaction annotate secret istioinaction-cert kubed.appscode.com/sync="secrets-sync=true"
```

Now the cert should be loaded in the istio ingress gateway and marked as `ACTIVE`, for example:

```bash
istioctl pc secret deploy/istio-ingressgateway -n istio-system 
```

```
RESOURCE NAME                       TYPE           STATUS     VALID CERT     SERIAL NUMBER                               NOT AFTER                NOT BEFORE
kubernetes://istioinaction-cert     Cert Chain     ACTIVE     true           121991962222466462275317923552518909586     2031-02-23T17:16:32Z     2021-02-25T17:16:32Z
default                             Cert Chain     ACTIVE     true           241284066253111748685603285574737309740     2021-03-03T17:52:27Z     2021-03-02T17:52:27Z
ROOTCA                              CA             ACTIVE     true           266801602762712535092892179697980789542     2031-02-28T16:35:53Z     2021-03-02T16:35:53Z
```

**NOTE: we list this use case here because that's what folks seem to be doing in the wild.. however... at Solo.io we don't particularly recommend this approach. There are other approaches that we'll cover in this lab and in the second part of this workshop to more securely deliver secrets for your ingress gateway.**


cleanup:
remove annotation
kubectl -n istioinaction annotate secret istioinaction-cert kubed.appscode.com/sync-
kubectl -n istio-system delete secret istioinaction-cert
kubectl -n istioinaction delete secret istioinaction-cert
kubectl rollout restart deploy/istio-ingressgateway -n istio-system
curl to make sure it fails

## Create custom Ingress Gateways in a user namespace

In the previous steps, we created the out-of-the-box ingress gateway in the `istio-system` namespace. In this section, we'll create a custom ingress gateway named `my-user-gateway` in the `istioinaction` namespace. When deployed like this, the user can completely own all resources including secrets/certificates for the domains they wish to expose on this gateway.

Let's take a look at how we can define our custom gateway:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: my-user-gateway-install
  namespace: istioinaction
spec:
  profile: empty
  values:
    gateways:
      istio-ingressgateway:
        autoscaleEnabled: false
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: false    
    - name: my-user-gateway
      namespace: istioinaction
      enabled: true
      label:
        istio: my-user-gateway
```

We can install it with the `istioctl` cli:

```bash
istioctl install -y -n istioinaction -f labs/04/my-user-gateway.yaml --revision 1-8-3
```

We should the check the pod and services that were created:

```bash
kubectl get po -n istioinaction
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
my-user-gateway-6746b98474-tkzn7      1/1     Running   0          12s
purchase-history-v1-b47996677-lskt9   1/1     Running   0          31h
recommendation-69995f55c9-rddwz       1/1     Running   0          31h
web-api-745fdb5bdf-jbbp4              1/1     Running   0          31h
```

```bash
kubectl get svc -n istioinaction
```

NAME               TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                                                      AGE
my-user-gateway    LoadBalancer   10.44.4.247    34.68.73.162   15021:30141/TCP,80:32728/TCP,443:30664/TCP,15443:30746/TCP   3m45s
purchase-history   ClusterIP      10.44.3.84     <none>         8080/TCP                                                     3h49m
recommendation     ClusterIP      10.44.11.68    <none>         8080/TCP                                                     3h49m
web-api            ClusterIP      10.44.13.102   <none>         8080/TCP                                                     3h49m


From here, you can create any domain certs in the `istioinaction` namespace (either using cert-manager or directly)

```bash
kubectl create -n istioinaction secret tls my-user-gw-istioinaction-cert --key labs/04/certs/istioinaction.io.key --cert labs/04/certs/istioinaction.io.crt
```

And then create the appropriate `Gateway` and `VirtualService` resources:

```bash
kubectl apply -f labs/04/my-user-gw-https.yaml
kubectl apply -f labs/04/my-user-gw-vs.yaml
```

If everything is installed correctly, you can get the IP address of your custom ingress gateway and then call the services through the new custom gateway:

```bash
CUSTOM_GATEWAY_IP=$(kubectl get svc -n istioinaction my-user-gateway  -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$CUSTOM_GATEWAY_IP
```

#### Clean up custom gateway

```bash
kubectl apply -f sample-apps/ingress/web-api-gw-vs.yaml
kubectl delete Gateway -n istioinaction my-gw-web-api-gateway 
kubectl delete deploy/my-user-gateway -n istioinaction
kubectl delete svc/my-user-gateway -n istioinaction
kubectl delete sa/my-user-gateway-service-account -n istioinaction
kubectl delete secret/my-user-gw-istioinaction-cert -n istioinaction
```

## Reduce Gateway Config for large meshes

By default, the ingress gateways will be configured with information about every service in the mesh and in fact every service that Istio's control plane has discovered. This is likely overkill for most large mesh deployments. With the gateway, we can scope down the number of backend services that get configured on the gateway to only those that have routing rules defined for them. For example, in our current status with the gateway, let's see what "clusters" it knows about:


```bash
istioctl pc clusters deploy/istio-ingressgateway -n istio-system
```

As you see, the output here is quite extensive and includes clusters that the gateway does not need to know anything about. The only clusters that get traffic routed to it are the `web-api` cluster. Let's configure the control plane to scope this down:

```bash
istioctl install -y -n istio-system -f labs/04/control-plane-reduce-gw-config.yaml --revision 1-8-3
```

Give a few moments for `istiod` to come back up. Then run the following to verify the setting `PILOT_FILTER_GATEWAY_CLUSTER_CONFIG` took effect: 

```bash
kubectl get deploy/istiod-1-8-3 -n istio-system -o jsonpath="{.spec.template.spec.containers[].env[0]}"
```

You should see something like this:

```
{"name":"PILOT_FILTER_GATEWAY_CLUSTER_CONFIG","value":"true"}
```

Let's check the ingress gateway again:

```bash
istioctl pc clusters deploy/istio-ingressgateway -n istio-system
```

You should see a much more slimmed down list including the `web-api.istioinaction.svc.cluster.local` cluster. There are a couple of additional clusters that have been configured as `static` clusters. 

## Access logging for gateway

In this last section of this lab, we will see how to enable access logging for the ingress gateway. Access logging is instrumental in understanding what traffic is coming and what are the results of that traffic. Istio's documentation [shows how to enable access logging](https://istio.io/latest/docs/tasks/observability/logs/access-log/) but it's for the entire mesh. In this section, we will enable access logging for *just* the ingress gateway. The UX around this is continuously improving, so in the future there may be an easier way to do this. These steps were accurate for Istio 1.8.3. 

Let's take a look at the configuration we'll use to configure access logging for the ingress gateway:

```bash
cat labs/04/ingress-gw-access-logging.yaml
```

We should see a file similar to this:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingressgateway-access-logging
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: MERGE
      value:
        typed_config:
          "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager"
          access_log:
          - name: envoy.access_loggers.file
            typed_config:
              "@type": "type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog"
              path: /dev/stdout
              format: "[%START_TIME%] \"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%\" %RESPONSE_CODE% %RESPONSE_FLAGS% \"%UPSTREAM_TRANSPORT_FAILURE_REASON%\" %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% \"%REQ(X-FORWARDED-FOR)%\" \"%REQ(USER-AGENT)%\" \"%REQ(X-REQUEST-ID)%\" \"%REQ(:AUTHORITY)%\" \"%UPSTREAM_HOST%\" %UPSTREAM_CLUSTER% %UPSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_LOCAL_ADDRESS% %DOWNSTREAM_REMOTE_ADDRESS% %REQUESTED_SERVER_NAME% %ROUTE_NAME%\n"
```

You can see we are using an `EnvoyFilter` resource to affect the configuration of the gateway proxy. Let's apply this resource:

```bash
kubectl apply -f labs/04/ingress-gw-access-logging.yaml
```

Now send some traffic through the ingress gateway:

Recall how to get the ingress gateway IP:

```bash
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

After sending some traffic through the gateway, check the logs:

```bash
kubectl logs -n istio-system deploy/istio-ingressgateway -c istio-proxy
```

You should see something like the following access log:

```
[2021-03-02T20:43:27.195Z] "GET / HTTP/2" 200 - "-" 0 1102 11 11 "10.128.0.61" "curl/7.64.1" "8821b96b-ecab-4303-9f6d-11681ee22e8f" "istioinaction.io" "10.40.2.49:8080" outbound|8080||web-api.istioinaction.svc.cluster.local 10.40.0.43:32838 10.40.0.43:8443 10.128.0.61:53829 istioinaction.io -
```

####  TODO :: private vs public gateway/LB -- integrating with ALB/NLB

understand AWS LB: 
https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html

Install AWS LB Controller
https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/

Use NLB-IP mode:
https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/nlb_ip_mode/

See following gateway resources:

cat ./labs/04/ingress-gateways-public.yaml
cat ./labs/04/ingress-gateways-private.yaml
cat ./labs/04/ingress-gateways-nlb-hc.yaml