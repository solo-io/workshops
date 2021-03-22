# Deploy Istio for Production

In this first of a three-part series of workshops on Istio service mesh, we dive into Istio with a focus on rolling out the mesh to your organization in a production-ready way. We've cultivated a lot of this knowledge from working with organizations across the world and helping them operationalize Istio. We cover the following topics in this first workshop:

* Understanding Istio's data plane \(Envoy Proxy\)
* Installing Istio with day-2 in mind
* Iteratively introducing Istio in your organization
* Leveraging gateways
* Debugging when things go wrong

Let's get the lab environment set up.

## Lab environment and prep

We will use a Kubernetes cluster on the lab machine to work through the following labs. In this prep section we will set up our cluster and download `istioctl`.

### Set up Kubernetes cluster with Kind

From the terminal go to the `/home/solo/workshops/scripts` directory:

```text
cd /home/solo/workshops/scripts
```

Run the following commands to deploy a single Kubernetes cluster using [Kind](https://kind.sigs.k8s.io/):

```bash
./deploy.sh 1 istio-workshop
```

{% hint style="info" %}
Note the `1` in the CLI command above
{% endhint %}

Kind should automatically set up the Kubernetes context for the `kubectl` CLI tool, but to make sure you're pointed to the right cluster, run the following:

```bash
kubectl config use-context istio-workshop
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

### Start the lab!

Now go to the directory that has the workshop material:

```text
cd /home/solo/workshops/istio-day2/1-deploy-istio/
```

* [Lab 1 - Run Envoy Proxy](01-run-envoy/)
* [Lab 2 - Installing Istio](02-install-istio/)
* [Lab 3 - Connecting to observability systems](03-observability/)
* [Lab 4 - Using ingress gateways across teams](04-ingress-gateway/)
* [Lab 5 - Onboarding services to the mesh](05-app-rollout/)
* [Lab 6 - Rolling out mTLS for services in a controlled manner](06-mtls-rollout.md)
* [Lab 7 - Controlling configuration](07-controlling-config.md)
* [Lab 8 - Debugging networking configurations](08-debugging-config.md)

### Additional tools needed to install on the workshop VMs:

* [Istioctl 1.8.3](https://github.com/istio/istio/releases/tag/1.8.3)
* [Step cli](https://smallstep.com/cli/)

