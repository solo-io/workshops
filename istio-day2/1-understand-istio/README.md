# Understanding Istio and How it Works


In this first of a two-part series of workshops on Istio service mesh, we dive into Istio foundations with a focus on understanding how it all works and how to roll it out to your organization. Istio is a powerful tool, but learning how to deploy it, configure it, debug it, secure it has its own challenges.  We've cultivated a lot of this knowledge from working organizations across the world and helping them operationalize Istio.  We cover the following topics in this first workshop:

* Understanding Istio's data plane (Envoy Proxy)
* Installing Istio with upgrades in mind
* Istio functionality hands on
* Introducing Istio in your organization

## Lab environment and prep

We will use both a combination of Docker and a Kubernetes cluster on the lab machine to work through the following labs. In this prep section we will download `istioctl` and set up our Kubernetes cluster.

### Check that docker exists

```
docker version
```

### Download and set up istioctl

Make sure you're on your home directory:

```bash
cd
```

And download Istio 1.8.3

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.8.3 sh -
```

Let's make `istioctl` available on your `PATH`:

```bash
export PATH="$PATH:/home/solo/istio-1.8.3/bin"
```

Now you should be able to run `istioctl` commands from any directory:

```bash
istioctl version
```

### Se up Kubernetes cluster with Kind

From the terminal go to the `/home/solo/workshops/scripts` directory:

```
cd /home/solo/workshops/scripts
```

Run the following commands to deploy a single Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):


```bash
./deploy.sh 1 istio-workshop
```

Kind should automatically set up the Kubernetes context for the `kubectl` CLI tool, but to make sure you're pointed to the right cluster, run the following:

```bash
kubectl config use-context kind-istio-workshop
```

### Start the lab!

Now go to the directory that has the workshop material:

```
cd /home/solo/workshops/istio-day2/1-understand-istio/
```

* [Lab 1 - Run Envoy Proxy](./01-run-envoy.md)
* [Lab 2 - Installing Istio](./02-install-istio.md)
* [Lab 3 - Connecting to observability systems](./03-observability.md)
* [Lab 4 - Using ingress gateways across teams](./04-ingress-gateway.md)
* [Lab 5 - Onboarding services to the mesh](./05-app-rollout.md)
* [Lab 6 - Rolling out mTLS for services in a controlled manner](./06-mtls-rollout.md)
* [Lab 7 - Controlling configuration](./07-controlling-config.md)
* [Lab 8 - Debugging networking configurations](./08-debugging-config.md)

### Additional tools needed to install on the workshop VMs:

* [Istioctl 1.8.3](https://github.com/istio/istio/releases/tag/1.8.3)
* [Step cli](https://smallstep.com/cli/)
