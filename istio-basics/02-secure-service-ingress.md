In this lab, you will deploy the sample application to your Kubernetes cluster, and expose the web-api service to the Istio ingress gateway and configure secure access to it.


## Prerequisites

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-basics`. This lab builds on both lab 01 where we already installed Istio using the demo profile. 

## Deploy the sample application

Verify you're in the correct folder for this lab: /home/solo/workshops/istio-basics/.

Let's set up the sample-apps:

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

### Note the GATEWAY_IP and PORT



## Secure the inbound traffic

Congratulations, you have exposed the web-api service to Istio ingress gateway securely. We'll explore adding services to the mesh in the [next lab](./03-add-services-to-mesh.md).


