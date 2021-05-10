# Lab 3 :: Adding Services to the Mesh
In this lab, we will incrementally add services to the mesh. As part of adding services to the mesh, the mesh is actually integrated as part of the services themselves to make the mesh mostly trasparent to the service implementation.

## Sidecar injection

Adding services to the mesh requires that the client-side proxies be associated with the service components and registered with the control plane. With Istio, you have two methods to inject the Envoy proxy sidecar into the microservice Kubernetes pods:
- Automatic sidecar injection
- Manual sidecar injection.

To enable the automatic sidecar injection, use the command below to add the `istio-injection` label to the `istioinaction` namespace:

```bash
kubectl label namespace istioinaction istio-injection=enabled
```

Validate the `istioinaction` namespace is annotated with the `istio-injection` label:

```bash
kubectl get namespace -L istio-injection
```

Now that you have a namespace with automatic sidecar injection enabled, you are ready to start adding services in the `istioinaction` namespace to the mesh.
## Review Service requirements

Before you add Kubernete services to the mesh, you need to be aware of the [application requirements](https://istio.io/latest/docs/ops/deployment/requirements/) to ensure that your Kubernetes services meet the minimum requirements.

Service descriptors:
- each service port name must start with the protocol name, for example `name: http`

Deployment descriptors:
- The pods must be associated with a Kubernetes service.
- The pods must not run as a user with UID 1337
- App and version labels are added to provide contextual information for metrics and tracing.

Check the above requirements for each of the Kubernetes services and make adjustments as necessary. If you don't have `NET_ADMIN` security rights, you would need to explore the Istio CNI plugin to remove the `NET_ADMIN` requirement for deploying services.

Using the `web-api` service as an example, Let's review its service and deployment descriptor.

```bash
cat sample-apps/web-api.yaml
```

From the service descriptor, the `name: http` declares the `http` protocol for the service port `8080`:

```yaml
  - name: http
    protocol: TCP
    port: 8080
    targetPort: 8081
```

From the deployment descriptor, the `app: web-api` label matches the `web-api` service's selector of `app: web-api` so this deployment and its pod are associated with the `web-api` service.  Further, the `app: web-api` label and `version: v1` labels provide contextual information for metrics and tracing. The `containerPort: 8080` declares the listening port for the container, which matches the `targetPort: 8081` in the `web-api` service descriptor earlier.

```yaml
  template:
    metadata:
      labels:
        app: web-api
        version: v1
      annotations:
    spec:
      serviceAccountName: web-api    
      containers:
      - name: web-api
        image: nicholasjackson/fake-service:v0.7.8
        ports:
        - containerPort: 8081
```

Check the `purchase-history-v1`, `recommendation` and `sleep` service and validate they all meet the above requirements.

## Adding services to the mesh

Let us add the sidecar to each of the services in the `istioinaction` namespace, starting with the `web-api` service:


```bash
kubectl rollout restart deployment web-api -n istioinaction
```

Validate the `web-api` pod has reached running status with sidecar injected:

```bash
kubectl get pod -l app=web-api -n istioinaction
```

Validate the `web-api` pod log looks good:

```bash
kubectl logs -c web-api -n istioinaction
```

Validate you can continue to call the `web-api` service securely:

```bash
curl -H "Host: istioinaction.io" http://$GATEWAY_IP:$INGRESS_PORT
```

TODO: describe the pod to view the init-container and sidecar container.

Next, let us add the sidecar to all other services in the `istioinaction` namespace

```bash
kubectl rollout restart deployment purchase-history-v1 -n istioinaction
kubectl rollout restart deployment recommendation -n istioinaction
kubectl rollout restart deployment sleep -n istioinaction
```
## What have you gained?

Congratulations on getting all services in the `istioinaction` namespace to the Istio service mesh. One of the values of using a service mesh is that you can gain immediate insights into the behaviors and interactions of your services. Istio deliveres a set of dashboards as addon components that provide you access to important telemetry data that is available just by adding services to the mesh.

TODO: open up jaeger

TODO: open up kiali

## Propogate Trace Headers

## Next lab
Congratulations, you have added the sample application successfully to Istio service mesh and observed the services' communications. We'll explore securing these services in the mesh in the [next lab](./04-secure-services-with-istio.md).



