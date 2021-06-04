# Get Started With Istio Service Mesh

This lab explains how to get started with Istio and explore various functions Istio provides to your organization.  We cover the following topics in this workshop:

* Install Istio
* Secure services with Istio Ingress Gateway
* Add Services to the Mesh
* Secure interservices communication with Istio
* Control Traffic

## Lab environment and prep

We will use a Kubernetes cluster offered by instruqt to run the lab. 

### Lab environment prep on your local laptop
You can also run this lab on your laptop where Docker is supported. If you are using Linux, run the following commands to download k3d and setup a Kubernetes cluster after you start your Docker deamon:

```
# download k3d
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

# create docker network if it does not exist
network=demo-1
docker network create $network || true

# use loadbalancer and port mapping
k3d cluster create istiocluster --image "rancher/k3s:v1.20.2-k3s1" --k3s-server-arg "--disable=traefik" --network $network

kube_ctx=k3d-istiocluster
k3d kubeconfig get istiocluster > ~/.kube/istiocluster
```

You should have a working k3s cluster:

```
kubectl get pods -A                                                     (8d22h44m) 14:27:26
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   metrics-server-86cbb8457f-d9rch           1/1     Running   0          52s
kube-system   local-path-provisioner-7c458769fb-qczf5   1/1     Running   0          52s
kube-system   coredns-854c77959c-d69qd                  1/1     Running   0          52s
```

## Start the lab!

Now go to the directory that has the workshop material:

```
cd /home/solo/workshops/istio-basics/
```

* [Lab 1 - Install Istio](./01-install-istio.md)
* [Lab 2 - Secure services with Istio Ingress Gateway](./02-secure-service-ingress.md)
* [Lab 3 - Add Services to the Mesh](./03-add-services-to-mesh.md)
* [Lab 4 - Secure interservices communication with Istio](./04-secure-services-with-istio.md)
* [Lab 5 - Control Traffic](./05-control-traffic.md)

