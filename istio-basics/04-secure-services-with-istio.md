# Lab 4 :: Securing Communication Within Istio

In the previous lab, we explored adding services into a mesh. However, when we installed Istio using the demo profile, it has permissive security mode. Istio permissive security setting is useful when you have services that are being moved into the service mesh incrementally by allowing both plain text and mTLS traffic. In this lab, we explore how Istio manages secure communication between services and how to enable strict security communication between services in our sample application.

## Permissive mode

By default, Istio automatically upgrades the connection securely from the source service's sidecar proxy to the target service's sidecar proxy. This is why you saw the paddlelock icon in the Kiali graph earlier from Istio ingress gateway to the `web-api` service to the `history` service then to the `recommendation` service. While this is good when onboarding your services to Istio service mesh as the communication between source and target services continues to be allowed via plain text if mutual TLS communication fails, you don't want this in production environment without proper security policy in place. 

Check if you have any `peerauthentication` policy in all of your namespaces:

```bash
kubectl get peerauthentication --all-namespaces
```

You should see `No resources found` in the output, which means no peer authentication has been specified and the default `PERMISSIVE` mTLS mode is being used.

## Enable strict mTLS

You can lock down the secure access to all services in the `istioinaction` namespace to require mTLS using a peer authentication policy. Execute this command to define a default policy for the `istioinaction` namespace that updates all of the servers to accept only mTLS traffic:

```bash
kubectl apply -n istio-system -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF
```

Verify your  `peerauthentication` policy is installed:

```bash
kubectl get peerauthentication --all-namespaces
```

You should see the the default `peerauthentication` policy installed in the `istio-system` namespace with STRICT mTLS enabled:

```
NAMESPACE      NAME      MODE     AGE
istio-system   default   STRICT   84s
```

Because the `istio-system` namespace is also the Istio mesh configuration root namespace in your environment, this `peerauthentication` policy is the default policy for all of your services in the mesh regardless of which namespaces your services run.

Let us see mTLS in action! First, we want to send some traffic to web-api from a pod that is not part of the Istio service mesh. Deploy the `sleep` service and pod in the default namespace:

```bash
kubectl apply -n default -f sample-apps/sleep.yaml
```

Access the `web-api` service from the `sleep` pod in the default namespace:

```bash
kubectl exec -it deploy/sleep -n default -- curl http://web-api.istioinaction:8080/
```

The request will fail because the `web-api` service can only be accessed with mutual TLS. The `sleep` pod in the default namespace doesn't have the sidecar proxy so it doesn't have the needed keys and certificates to communicate to the `web-api` service via mutual TLS.  Run the same command from the `sleep` pod in the `istioinaction` namespace:

```bash
kubectl exec -it deploy/sleep -n istioinaction -- curl http://web-api.istioinaction:8080/
```

You should see the request succeed.

Question: How can you check if a service or namespace is ready to enable the `STRICT` mtls mode?  What is the best practice to enable mTLS for your services? We'll cover this topic in our Istio essential workshop.

### Visualize mTLS enforcement in Kiali

You can visualize the services in the mesh in Kiali.  Launch Kiali using the command below:

```bash
istioctl dashboard kiali
```

Navigate to [http://localhost:20001](http://localhost:20001) and select the Graph tab.

On the "Namespace" dropdown, select "istioinaction". On the "Display" drop down, select "Traffic Animation" and "Security". Let's also generate some load to the data plane (by calling our `web-api` service) so that you can observe interactions among your services:

```bash
for i in {1..200}; 
  do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP;
  sleep 1;
done
```

You should observe the service interaction graph with some traffic animation and security badges like below:

![](./images/kiali-istioinaction-mtls-enforced.png)

### Understand how mTLS works in Istio service mesh

Inspect the key and/or certificates used by Istio for the `web-api` service in the `istioinaction` namespace:

```bash
istioctl pc secret deploy/web-api -n istioinaction
```

From the output, you'll see there is the default secret and your Istio service mesh's root CA public certificate:

```
RESOURCE NAME     TYPE           STATUS     VALID CERT     SERIAL NUMBER                               NOT AFTER                NOT BEFORE
default           Cert Chain     ACTIVE     true           289941409853020398869969650517379116839     2021-06-09T13:39:16Z     2021-06-08T13:39:16Z
ROOTCA            CA             ACTIVE     true           333717302760067951717891865272094769364     2031-06-06T13:36:14Z     2021-06-08T13:36:14Z
```

The `default` secret containers the public certificate information for the `web-api` service. You can analyze the contents of the default secret using openssl.  


First, check the issuer of the public certificate:

```bash
istioctl pc secret deploy/web-api -n istioinaction -o json | jq '[.dynamicActiveSecrets[] | select(.name == "default")][0].secret.tlsCertificate.certificateChain.inlineBytes' -r | base64 -d | openssl x509 -noout -text | grep 'Issuer'
```

```
        Issuer: O = cluster.local
```

Second, you can check if the public certificate in the default secret is valid:

```bash
istioctl pc secret deploy/web-api -n istioinaction -o json | jq '[.dynamicActiveSecrets[] | select(.name == "default")][0].secret.tlsCertificate.certificateChain.inlineBytes' -r | base64 -d | openssl x509 -noout -text | grep 'Validity' -A 2
```

You should see the public certificate is valid and expires in 24 hours:

```
        Validity
            Not Before: Jun  8 13:39:16 2021 GMT
            Not After : Jun  9 13:39:16 2021 GMT
```

Third, you can check if the identity of the client certificate:

```bash
istioctl pc secret deploy/web-api -n istioinaction -o json | jq '[.dynamicActiveSecrets[] | select(.name == "default")][0].secret.tlsCertificate.certificateChain.inlineBytes' -r | base64 -d | openssl x509 -noout -text | grep 'Subject Alternative Name' -A 1
```

You should see the identity of the `web-api` service. Note it is using the spiffe format, e.g. `spiffe://{my-trust-domain}/ns/{namespace}/sa/{service-account}`:

```
            X509v3 Subject Alternative Name: critical
                URI:spiffe://cluster.local/ns/istioinaction/sa/web-api
```

#### Understand the SPIFFE format used by Istio

Where are the `cluster.local` and `web-api` values come from?  Check the `istio` configmap in the `istio-system` namespace:

```bash
kubectl get cm istio -n istio-system -o yaml | grep trustDomain -m 1
```

You'll see the `cluster.local` returned as the trustDomain value, per the installation of your Istio using the demo profile.

```
    trustDomain: cluster.local
```

If you review the `sample-apps/web-api.yaml` file, you will see the `web-api` service account in there.

```bash
cat sample-apps/web-api.yaml | grep ServiceAccount -A 3
```

```
kind: ServiceAccount
metadata:
  name: web-api
---
```

#### How does the `web-api` service obtain the needed key and/or certificates?

In lab 03, you reviewed the injected `istio-proxy` container for the `web-api` pod. Recall there are a few volumes mounted to the `istio-proxy` container.

```
      volumeMounts`
      - mountPath: /var/run/secrets/istio
        name: istiod-ca-cert
      - mountPath: /var/lib/istio/data
        name: istio-data
      - mountPath: /etc/istio/proxy
        name: istio-envoy
      - mountPath: /var/run/secrets/tokens
        name: istio-token
      - mountPath: /etc/istio/pod
        name: istio-podinfo
      - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
        name: web-api-token-ztk5d
        readOnly: true
...
    - name: istio-token
      projected:
        defaultMode: 420
        sources:
        - serviceAccountToken:
            audience: istio-ca
            expirationSeconds: 43200
            path: istio-token
    - configMap:
        defaultMode: 420
        name: istio-ca-root-cert
      name: istiod-ca-cert
    - name: web-api-token-ztk5d
      secret:
        defaultMode: 420
        secretName: web-api-token-ztk5d        
```

The `istio-ca-cert` is from the `istio-ca-root-cert` configmap in the `istioinaction` namespace. During start up time, Istio agent (internally also called `pilot-agent`) creates the private key for the `web-api` service and then uses the `istio-token` and the `web-api` service's service account token `web-api-token-ztk5d` to generate the certificate signing request (CSR) for the Istio CA (Istio control plane is the Istio CA in your installation) to sign the private key. The Istio agent sends the certificates received from the Istio CA along with the private key to Envoy via the Envoy SDS API.

You noticed earlier that the certificate expires in 24 hours.  What happens when the certificate expires? The Istio agent monitors the `web-api` certificate for expiration and repeat the CSR request process described above periodically.

#### How is mTLS strict enforced?

## Next lab

Congratulations, you have enabled strict mTLS policy for all services in the entire Istio mesh. We'll explore controlling traffic with these services in the [next lab](./05-control-traffic.md).