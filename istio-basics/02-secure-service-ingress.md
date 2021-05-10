In this lab, you will deploy the sample application to your Kubernetes cluster, and expose the web-api service to the Istio ingress gateway and configure secure access to it. The intention of the ingress gateway is to allow traffic into the mesh. If you need more sophisticated edge gateway capabilities (rate limiting, request transformation, OIDC, LDAP, OPA, etc) then use a gateway specifically built for those use cases like [Gloo Edge](https://docs.solo.io/gloo-edge/latest/).

## Prerequisites

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-basics`. This lab builds on lab 01 where we already installed Istio using the demo profile. 

## Deploy the sample application

Let's set up the namespace for our services:

```bash
kubectl create ns istioinaction
```

Now let's create some services:

```bash
kubectl apply -n istioinaction -f sample-apps/web-api.yaml
kubectl apply -n istioinaction -f sample-apps/recommendation.yaml
kubectl apply -n istioinaction -f sample-apps/purchase-history-v1.yaml
kubectl apply -n istioinaction -f sample-apps/sleep.yaml
```

After running these commands, we should check the pods running in the istioinaction namespace:

```bash
kubectl get po -n istioinaction
```

```
NAME                                   READY   STATUS    RESTARTS   AGE
purchase-history-v1-6c8cb7f8f8-wn4dr   1/1     Running   0          22s
recommendation-c9f7cc86f-nfvmk         1/1     Running   0          22s
sleep-8f795f47d-5jfbn                  1/1     Running   0          14s
web-api-6d544cff77-drrbm               1/1     Running   0          22s
```

## Configure the inbound traffic

The ingress gateway will create a Kubernetes Service of type `LoadBalancer`. Use this IP address to reach the gateway:

```bash
kubectl get svc -n istio-system
```

```
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.44.0.91     35.202.132.20   15021:32218/TCP,80:30062/TCP,443:30105/TCP,15012:32488/TCP,15443:30178/TCP   5m45s
istiod                 ClusterIP      10.44.10.140   <none>          15010/TCP,15012/TCP,443/TCP,15014/TCP                                        47m
```

### Note the GATEWAY_IP env variable

{% hint style="success" %}
We use the `GATEWAY_IP` environment variable in other parts of this lab.
{% endhint %}

```bash
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

{% hint style="info" %}
There is a known issue with MetalLB with MacOS. If you are running this lab on your MacBook, we recommend you to run a vagrant Ubuntu VM on your MacBook and access the `GATEWAY_IP` from your VM's terminal.
{% endhint %}

{% hint style="info" %}
If your ingress gateway created a Kubernetes Service of type `NodePort`, use the following commands to set your `GATEWAY_IP`:

```bash
export GATEWAY_IP=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
```

Set the `INGRESS_PORT` and `SECURE_INGRESS_PORT`:

```bash
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
```

{% endhint %}


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



## Secure the inbound traffic

Congratulations, you have exposed the web-api service to Istio ingress gateway securely. We'll explore adding services to the mesh in the [next lab](./03-add-services-to-mesh.md).


