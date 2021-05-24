# Lab 1 :: Zero downtime upgrades

In this lab, we will learn the proper method of upgrading Istio without your applications experiencing any downtime. This involves deploying a canary version, testing with a small workload first and then gradually the remaining while moniotoring. This approach is safe and effective when done correctly.

In this portion of the lab, we will upgrade from Istio 1.8 to 1.10

## Prerequisites

You will need access to a Kubernetes cluster. If you're doing this via the Solo.io Workshop format, you should have everything ready to go.

Verify you're in the correct folder for this lab: `/home/solo/workshops/istio-day2/2-operate-istio/`. 

## Install Istio 1.8
In the workshop material, you should already have Istio `1.8.3` cli installed and ready to go. 

To verify, run 

```bash
istioctl version
```

```
# OUTPUT:
no running Istio pods in "istio-system"
1.8.3
```

We don't have the Istio control plane installed and running yet. Let's go ahead and do that.


## Installing Istio

Install Istio as described in first part of these series. 

Start with creating the namespace and a service for istiod:

```bash
kubectl create ns istio-system
kubectl apply -f labs/01/istiod-service.yaml
```

Now let's install the control plane. This installation uses the `IstioOperator` CR along with `istioctl`. The IstioOperator'r profile is set to minimal, which only installs the control plane (no gateways):

```
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: control-plane
spec:
  profile: minimal
```

```bash
istioctl install -y -n istio-system -f labs/01/control-plane.yaml --revision 1-8-3
```

```
# OUTPUT:
✔ Istio core installed
✔ Istiod installed
✔ Installation complete
```

If we check the `istio-system` workspace, we should see the control plane running:

```bash
kubectl get pod -n istio-system
```

```
# OUTPUT:
NAME                            READY   STATUS    RESTARTS   AGE
istiod-1-8-3-78b88c997d-rpnck   1/1     Running   0          2m1s
```

## Install Istio Gateway

We recommend installing your Istio Ingress Gateways in a different namespace than istio-system for additional security. Let's install it in the a namespace called `istio-ingress`

```bash
kubectl create namespace istio-ingress
istioctl install -y -f labs/01/ingress-gateway-1-8-3.yaml
```

## Install demo app

In this section, we'll enable automatic sidecar injection on the `default` namespace and deploy the httpbin application. Remove any previous injection labels and set the the label to point to the 1.8.3 revision injector

```bash
kubectl label namespace default istio-injection-
kubectl label namespace default istio.io/rev=1-8-3 --overwrite
```

```bash
kubectl apply -f labs/01/httpbin.yaml
```

Check the status of the proxy to see the version and istiod the proxy is pointed to:

```bash
istioctl ps
```

```
# OUTPUT:
NAME                                                    CDS        LDS        EDS        RDS          ISTIOD                            VERSION
httpbin-66cdbdb6c5-z8xhh.default                        SYNCED     SYNCED     SYNCED     SYNCED       istiod-1-8-3-78b88c997d-7chhm     1.8.3
istio-ingressgateway-1-8-3-c5d84b5c-r7nvc.istio-ingress     SYNCED     SYNCED     SYNCED     NOT SENT     istiod-1-8-3-78b88c997d-7chhm     1.8.3
```

# Download Istio 1.10

```
TAG="1.10.0-rc.0"
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${TAG}  sh -
export PATH=$PWD/istio-${TAG}/bin:$PATH
```

Check your istioctl version:
```bash
istioctl version
```

```bash
# OUTPUT:
client version: 1.10.0-rc.1
control plane version: 1.8.3
data plane version: 1.8.3 (1 proxies)
```

## Deploy Istio 1.10 control plane

```bash
istioctl x precheck
istioctl install -y -n istio-system -f labs/01/control-plane.yaml --revision=1-10-0
```

You should now have both istiod versions running:
```
kubectl get pods -n istio-system
```

```bash
# OUTPUT:
NAME                             READY   STATUS    RESTARTS   AGE
istiod-1-10-0-68b8bf78dd-j7bff   1/1     Running   0          33s
istiod-1-8-3-78b88c997d-7chhm    1/1     Running   0          47h
```

## Switch workloads to the new control plane

Point the default namespace injection label to the 1-10-0 revision injector:

```bash
kubectl label namespace default istio.io/rev=1-10-0 --overwrite
``

Then, recreate the httpbin pods

```
kubectl rollout restart deployment httpbin
```

Check that the pod now points to the new istio version:

```bash
istioctl ps
```

```bash
# OUTPUT
NAME                                                    CDS        LDS        EDS        RDS          ISTIOD                             VERSION
httpbin-85f6c75d69-xj6xz.default                        SYNCED     SYNCED     SYNCED     SYNCED       istiod-1-10-0-68b8bf78dd-j7bff     1.10.0-rc.1
istio-ingressgateway-69b5ffc84c-nw58w.istio-ingress     SYNCED     SYNCED     SYNCED     NOT SENT     istiod-1-8-3-78b88c997d-7chhm      1.8.3
```

## Deploy Istio 1.10 Gateway

Install Istio Ingress 1.10 gateway with the name "istio-ingressgateway-1-10" 
```bash
istioctl install -y -f labs/01/ingress-gateway-1-10-0.yaml
```

Check that you now have both versions of the gateways installed
```
kubectl get pods,svc -n istio-ingress
```

```
# OUTPUT:
NAME                                            READY   STATUS    RESTARTS   AGE
pod/istio-ingressgateway-1-10-7b95c86cd-b54cg   1/1     Running   0          6m19s
pod/istio-ingressgateway-1-8-3-c5d84b5c-r7nvc   1/1     Running   0          8m8s

NAME                                 TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                                                      AGE
service/istio-ingressgateway-1-10    LoadBalancer   10.56.57.33   35.239.151.156   15021:31334/TCP,80:31674/TCP,443:31578/TCP                   6m19s
service/istio-ingressgateway-1-8-3   LoadBalancer   10.56.52.85   146.148.32.224   15021:32671/TCP,80:30277/TCP,443:30557/TCP,15443:31103/TCP   8m7s

## Next Lab

  
