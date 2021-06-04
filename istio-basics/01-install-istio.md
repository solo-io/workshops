# Lab 1 :: Install Istio

One of the quickest way to get started with Istio is to leverage the demo profile. The demo profile is designed to showcase Istio functionality with modest resource requirements. The demo profile contains Istio control plane (also called Istiod), Istio ingress-gateway and egress-gateway, and a few addon components. In this lab, you will install Istio with the demo profile. You will validate the installation is successfully and examinate the installation artifacts.

## Download Istio

Download the istio release binary:

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.3 sh -
```

Add istioctl client to your path:

```bash
cd istio-1.9.3
export PATH=$PWD/bin:$PATH
```

Check istioctl version:

```bash
istioctl version
```

Check if your Kubernetes environment meets Istio's platform requirement:

```bash
istioctl x precheck
```

## Install Istio

List available installation profiles:

```bash
istioctl profile list
```

Since this is a get started workshop, let's use the demo profile.

```bash
istioctl install --set profile=demo -y
```

{% hint style="info" %}
If your Kubernetes environment can only support Kubernetes Service of type `NodePort`, configure your Istio ingress gateway to use type `NodePort`

```bash
istioctl install --set profile=demo -y --set values.gateways.istio-ingressgateway.type=NodePort
```

{% endhint %}

Check out the resources installed by Istio:

```bash
kubectl get all,cm,secrets -n istio-system
```

Check out CRDs installed by Istio:

```bash
kubectl get crds -n istio-system
```

Check out Istio resources installed by Istio and used by Istio internally:

```bash
kubectl get istio-io -n istio-system
```

## Install Istio Telemetry Addons

Istio telemetry addons are shipped as samples because these addons are optimized for quick get started and demo purpose and not for production usage. They provides a convenient way to install these telemetry components that integrate with Istio.

```bash
kubectl apply -f samples/addons
```

If you hit an error like below, rerun the above command to ensure the `samples/addons` are applied to your Kubernetes cluster. The error below could happen when you attempt to install any `MonitoringDashboard` custom resource before the `MonitoringDashboard` custom resource definition (CRD) is installed.

```
unable to recognize "samples/addons/kiali.yaml": no matches for kind "MonitoringDashboard" in version "monitoring.kiali.io/v1alpha1"
```

Verify you can access the Prometheus dashboard:

```bash
istioctl dashboard prometheus
```

Verify you can access the Grafana dashboard:

```bash
istioctl dashboard grafana
```

Verify you can access the Jaeger dashboard:

```bash
istioctl dashboard jaeger
```

Verify you can access the Kiali dashboard:

```bash
istioctl dashboard kiali
```

You will not see much telemetry data from any of these dashboards, as we don't have any services in the Istio service mesh yet. We will revisit these dashboards in the [lab 03](03-add-services-to-mesh.md).

## Next lab

Congratulations, you have installed Istio control plane (Istiod), Istio ingress-gateway and egress-gateway and its addon components successfully.  We'll learn to expose and secure your services to Istio ingress gateway in the [next lab](./02-secure-service-ingress.md).




