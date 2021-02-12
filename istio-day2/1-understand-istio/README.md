# Understanding Istio and How it Works


In this first of a two-part series of workshops on Istio service mesh, we dive into Istio foundations with a focus on understanding how it all works and how to roll it out to your organization. Istio is a powerful tool, but learning how to deploy it, configure it, debug it, secure it has its own challenges.  We've cultivated a lot of this knowledge from working organizations across the world and helping them operationalize Istio.  We cover the following topics in this first workshop:

* Understanding Istio's data plane (Envoy Proxy)
* Installing Istio with upgrades in mind
* Istio functionality hands on
* Introducing Istio in your organization

## Lab environment

We will use both a combination of Docker and a Kubernetes cluster on the lab machine to work through the following labs. 

Check that docker exists:

```
docker version
```

From the terminal go to the `/home/solo/workshops/scripts` directory:

```
cd /home/solo/workshops/scripts
```

Run the following commands to deploy a single Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):


```bash
./deploy.sh 1 istio-k8s
```

Kind should automatically set up the Kubernetes context for the `kubectl` CLI tool, but to make sure you're pointed to the right cluster, run the following:

```bash
kubectl config use-context istio-k8s
```

Now go to the directory that has the workshop material:

```
cd /home/solo/workshops/istio-day2/1-understand-istio/
```

* [Lab 1 - Run Envoy Proxy](./01-run-envoy.md)
* [Lab 2 - Installing Istio](./02-install-istio.md)
* [Lab 3 - Connecting to observability systems](./03-observability.md)
* [Lab 4 - Onboarding services to the mesh]()
* [Lab 5 - Rolling out mTLS for services in a controlled manner]()
* [Lab 6 - Controlling configuration]()
* [Lab 7 - Using gateways across teams]()
* [Lab 8 - Debugging networking configurations]()
