# Deploy Istio for Production

In this first of a three-part series of workshops on Istio service mesh, we dive into Istio with a focus on rolling out the mesh to your organization in a production-ready way. We've cultivated a lot of this knowledge from working with organizations across the world and helping them operationalize Istio.  We cover the following topics in this first workshop:

* Understanding Istio's data plane (Envoy Proxy)
* Installing Istio with day-2 in mind
* Iteratively introducing Istio in your organization
* Leveraging gateways
* Debugging when things go wrong

Let's get the lab environment set up.

## Lab environment and prep

We will use a Kubernetes cluster on the lab machine to work through the following labs. In this prep section we will set up our cluster and download `istioctl`.

### Set up Kubernetes cluster with Kind

From the terminal go to the `/home/solo/workshops/scripts` directory:

```
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
curl -L https://raw.githubusercontent.com/istio/istio/master/release/downloadIstioCandidate.sh | ISTIO_VERSION=1.8.3 sh -
```

{% hint style="success" %}
You may be wondering why we are using Istio 1.8.x when 1.9.x is out. This is purposeful -- in the second part of this workshop we will be doing upgrades of Istio and being on the previous version is helpful to illustrate proper upgrades.
{% endhint %}

Let's make `istioctl` available on your `PATH`:

```bash
export PATH="$PATH:/home/solo/istio-1.8.3/bin"
```

Now you should be able to run `istioctl` commands from any directory:

```bash
istioctl version
```

### Start the lab!

Interested in running the lab?  [Sign up](https://www.solo.io/events-webinars/) for one of our upcoming `deploy Istio to production` workshop! This workshop also includes a certification option. This credential, offered by Solo.io with Credly, certifies that you possess the essential skills to deploy, configure, debug, secure, and operationalize Istio for your organization. At the completion of the workshop, you will be able to take an assessment and a score 80% or higher earns the certification.

### Additional tools needed to install on the workshop VMs:

* [Istioctl 1.8.3](https://github.com/istio/istio/releases/tag/1.8.3)
* [Step cli](https://smallstep.com/cli/)
