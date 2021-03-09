# Lab 4 Bonus :: Ingress Gateway


## Bonus: Certificates in own namespace

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

Now let's try call our ingress gateway again to verify it works as expected:

```bash
curl --cacert ./labs/04/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

> :warning: We list this use case here because that's what folks seem to be doing in the wild, however, **at Solo.io we don't recommend this approach**. There are other approaches that we'll cover in this lab and in the second part of this workshop to more securely deliver secrets for your ingress gateway.


If you would like o clean up this portion of the lab, you can run:

```
kubectl -n istioinaction annotate secret istioinaction-cert kubed.appscode.com/sync-
kubectl -n istio-system delete secret istioinaction-cert
kubectl -n istioinaction delete secret istioinaction-cert
kubectl rollout restart deploy/istio-ingressgateway -n istio-system
```

## Bonus: Create custom Ingress Gateways in a user namespace

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

```
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                                                      AGE
my-user-gateway    LoadBalancer   10.44.4.247    34.68.73.162   15021:30141/TCP,80:32728/TCP,443:30664/TCP,15443:30746/TCP   3m45s
purchase-history   ClusterIP      10.44.3.84     <none>         8080/TCP                                                     3h49m
recommendation     ClusterIP      10.44.11.68    <none>         8080/TCP                                                     3h49m
web-api            ClusterIP      10.44.13.102   <none>         8080/TCP                                                     3h49m
```


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


####  TODO :: private vs public gateway/LB -- integrating with ALB/NLB

> :construction: This section is WIP!!

* understand AWS LB: 
  https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html

* Install AWS LB Controller
  https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/

* Use NLB-IP mode: 
  https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/nlb_ip_mode/

See following gateway resources:

```
cat ./labs/04/ingress-gateways-public.yaml
cat ./labs/04/ingress-gateways-private.yaml
cat ./labs/04/ingress-gateways-nlb-hc.yaml
```