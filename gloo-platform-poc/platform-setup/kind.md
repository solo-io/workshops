# Using Kind (Kubernetes in Docker)

You may use Kind for this POC if you don't have access to an alternative platform/cloud provider Kubernetes. We recommend using a platform that can leverage LoadBalancers to expose Kubernetes services, but NodePort should work well too. We will capture NodePort scenarios in the POC document.

## Setting up Kind using Workshop scripts

In the Solo.io workshop material, we have scripts to help you quickly deploy clusters for testing purposes. We will use those scripts for setting up Kind in this section, but you may customize/use your own as you see fit. 

Using the following command lines from the $ROOT_DIR of the workshops, you can spin up two Kubernetes clusters using Kind that have metallb installed (used for LoadBalancers):

```bash
./scripts/deploy.sh 1 gloo-mesh-1 us-west us-west-1
./scripts/deploy.sh 2 gloo-mesh-2 us-east us-east-1

echo "pause for clusters"
sleep 5s

kubectl config set-context gloo-mesh-1
```

You can check the status of these clusters with the following:

```bash
./scripts/check.sh gloo-mesh-1 
./scripts/check.sh gloo-mesh-2
```

Note that we've named our Kubernetes clusters `gloo-mesh-1` and `gloo-mesh-2`. The name of the Kubernetes contexts are the same as the cluster names:

```bash
kubectl config get-contexts
```
## Setting up Kind yourself

You are free to set up Kind yourself and customize the Kubernetes bootstrap yourself. Please refer to the `deploy.sh` script in the $ROOT_DIR/scripts folder for more detail about how the clusters are set up and you can modify accordingly.
