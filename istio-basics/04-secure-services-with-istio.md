# Lab 4 :: Securing Communication Within Istio

In the previous lab, we explored adding services into a mesh. However, when we installed Istio using the demo profile, it has permissive security mode. Istio permissive security setting is useful when you have services that are being moved into the service mesh incrementally by allowing both plain text and mTLS traffic. In this lab, we explore how Istio manages secure communication between services and how to enable strict security communication between services in our sample application.

## Permissive mode

Validate you have `PERMISSIVE` in the mTLS mode:

```bash
kubectl get peerauthentication default -n istio-system -o yaml
```

You should see `PERMISSIVE` in the output:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE
```

## Visualize the mesh with security badge

We use Kiali to show how communication is visualized between Istio services. Open the Kiali console using the following command  and log in with admin/admin as the default credentials for the Istio demo profile:

```bash
istioctl dashboard kiali
```

Let us change some settings to enable security visualization. Start by switching to the Graph tab on the left sidebar. Change the namespace selection to include `istioinaction` namespace, as shown in the figure below:
TODO: add a figure

Adjust the Kiali display settings to show Traffic Animation and Security as illustrated  in the Figure below.
TODO: add a figure

Let us generate some load so that you can see how Kiali captures and visualizes traffic between services. 

```bash
for i in {1..10}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP; done
```

Return to the Kiali console, where you should see traffic flowing between the services as shown in figure below. A green line indicates that traffic is successfully flowing between the services.

## Enable strict mTLS

You can lock down the secure access to all services in the `istioinaction` namespace to require mTLS using a peer authentication policy. Execute this command to define a default policy for the `istioinaction` namespace that updates all of the servers to accept only mTLS traffic:

```bash
kubectl apply -n istioinaction -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
spec:
  mtls:
    mode: STRICT
EOF
```

## Understand Strict mTLS

Use `openssl` tool to check if certificate is valid:

```bash
kubectl exec $(kubectl get pod -l app=web-api -o jsonpath={.items..metadata.name}) -c istio-proxy -- cat /etc/certs/cert-chain.pem | openssl x509 -text -noout  | grep Validity -A 2
```

You can also check the identify of the client certificate:

```bash
$ kubectl exec $(kubectl get pod -l app=web-api -o jsonpath={.items..metadata.name}) -c istio-proxy -- cat /etc/certs/cert-chain.pem | openssl x509 -text -noout  | grep 'Subject Alternative Name' -A 1
```

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

You should see the request succeed. Let us generate some load so that you can see how Kiali captures and visualizes traffic between services. 

```bash
for i in {1..10}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP; done
```

Return to the Kiali console, where you should see the security badge is enabled for all services communications within the `istioinaction` namespace.

TODO: add a figure

## Next lab

Congratulations, you have enabled strict mTLS policy to the sample services. We'll explore controlling traffic with these services in the [next lab](./05-control-traffic.md).