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

Now that you have a namespace with automatic sidecar injection enabled, you are ready to start adding services in the `istioinaction` namespace to the mesh. Since you added the `istio-injection` label to the `istioinaction` namespace, the Istio mutating admission controller automatically injects the Envoy proxy sidecar during the deployment or restart of the pod.

## Review Service requirements

Before you add Kubernete services to the mesh, you need to be aware of the [application requirements](https://istio.io/latest/docs/ops/deployment/requirements/) to ensure that your Kubernetes services meet the minimum requirements.

Service descriptors:
- each service port name must start with the protocol name, for example `name: http`

Deployment descriptors:
- The pods must be associated with a Kubernetes service.
- The pods must not run as a user with UID 1337
- App and version labels are added to provide contextual information for metrics and tracing.

Check the above requirements for each of the Kubernetes services and make adjustments as necessary. If you don't have `NET_ADMIN` security rights, you would need to explore the Istio CNI plugin to remove the `NET_ADMIN` requirement for deploying services.

TODO: add a tip for statefulset.

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

Validate the `web-api` pod has reached running status with Istio's default sidecar proxy injected:

```bash
kubectl get pod -l app=web-api -n istioinaction
```

You should see `2/2` in the output which indicates the sidecar proxy runs alongside of the `web-api` application container in the `web-api` pod:

```
NAME                       READY   STATUS    RESTARTS   AGE
web-api-7d5ccfd7b4-m7lkj   2/2     Running   0          9m4s
```

Validate the `web-api` pod log looks good:

```bash
kubectl logs deploy/web-api -c web-api -n istioinaction
```

Validate you can continue to call the `web-api` service securely:

```bash
curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP
```

### Understand what happens

Use the command below to get the details of the `web-api` pod:

```bash
kubectl get pod -l app=web-api -n istioinaction -o yaml
```

From the output, the `web-api` pod contains 1 init container and 2 normal containers.  The Istio mutating admission controller was responsible for injecting the `istio-init` init container and the `istio-proxy` container. The entry point of the container is `pilot-agent`, which contains the `istio-iptables` command to setup port forwarding for Istio's sidecar proxy. 


```bash
kubectl exec deploy/web-api -c istio-proxy -n istioinaction -- /usr/local/bin/pilot-agent istio-iptables --help
```

Want to know more about the flags for istio-iptables, run the command below:

```
istio-iptables is responsible for setting up port forwarding for Istio Sidecar.

Usage:
  pilot-agent istio-iptables [flags]

Flags:
  -n, --dry-run                                     Do not call any external dependencies like iptables
  -p, --envoy-port string                           Specify the envoy port to which redirect all TCP traffic (default $ENVOY_PORT = 15001)
  -h, --help                                        help for istio-iptables
  -z, --inbound-capture-port string                 Port to which all inbound TCP traffic to the pod/VM should be redirected to (default $INBOUND_CAPTURE_PORT = 15006)
  -e, --inbound-tunnel-port string                  Specify the istio tunnel port for inbound tcp traffic (default $INBOUND_TUNNEL_PORT = 15008)
      --iptables-probe-port string                  set listen port for failure detection (default "15002")
  -m, --istio-inbound-interception-mode string      The mode used to redirect inbound connections to Envoy, either "REDIRECT" or "TPROXY"
  -b, --istio-inbound-ports string                  Comma separated list of inbound ports for which traffic is to be redirected to Envoy (optional). The wildcard character "*" can be used to configure redirection for all ports. An empty list will disable
  -t, --istio-inbound-tproxy-mark string
  -r, --istio-inbound-tproxy-route-table string
  -d, --istio-local-exclude-ports string            Comma separated list of inbound ports to be excluded from redirection to Envoy (optional). Only applies  when all inbound traffic (i.e. "*") is being redirected (default to $ISTIO_LOCAL_EXCLUDE_PORTS)
  -o, --istio-local-outbound-ports-exclude string   Comma separated list of outbound ports to be excluded from redirection to Envoy
  -q, --istio-outbound-ports string                 Comma separated list of outbound ports to be explicitly included for redirection to Envoy
  -i, --istio-service-cidr string                   Comma separated list of IP ranges in CIDR form to redirect to envoy (optional). The wildcard character "*" can be used to redirect all outbound traffic. An empty list will disable all outbound
  -x, --istio-service-exclude-cidr string           Comma separated list of IP ranges in CIDR form to be excluded from redirection. Only applies when all  outbound traffic (i.e. "*") is being redirected (default to $ISTIO_SERVICE_EXCLUDE_CIDR)
  -k, --kube-virt-interfaces string                 Comma separated list of virtual interfaces whose inbound traffic (from VM) will be treated as outbound
      --probe-timeout duration                      failure detection timeout (default 5s)
  -g, --proxy-gid string                            Specify the GID of the user for which the redirection is not applied. (same default value as -u param)
  -u, --proxy-uid string                            Specify the UID of the user for which the redirection is not applied. Typically, this is the UID of the proxy container
      --redirect-dns                                Enable capture of dns traffic by istio-agent
...
```

You will notice that all inbound ports are redirected to the Envoy proxy container within the pod. You can also see a few ports such as 15020 are excluded from redirection (you'll soon learn why this is the case).

Next, let us add the sidecar to all other services in the `istioinaction` namespace

```bash
kubectl rollout restart deployment purchase-history-v1 -n istioinaction
kubectl rollout restart deployment recommendation -n istioinaction
kubectl rollout restart deployment sleep -n istioinaction
```
## What have you gained?

Congratulations on getting all services in the `istioinaction` namespace to the Istio service mesh. One of the values of using a service mesh is that you can gain immediate insights into the behaviors and interactions of your services. Istio deliveres a set of dashboards as addon components that provide you access to important telemetry data that is available just by adding services to the mesh.

Let's also generate some load to the data plane (by calling our `web-api` service) so that you can observe interactions among your services:

```bash
for i in {1..10}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io --resolve istioinaction.io:443:$GATEWAY_IP; done
```

You can visualize the services in the mesh in Kiali.  Launch Kiali using the command below:

```bash
istioctl dashboard kiali
```

TODO: add a screen shot for Kiali UI.

You can view distributed tracing information using the Jaeger dashboard, which you can launch using `istioctl dashboard jaeger` command:

```bash
istioctl dashboard jaeger
```

TODO: capture a screen shot of Jaeger.

You can also view various service metrics from the Grafana dashboard.  Launch the Grafana dashboard:

```bash
istioctl dashboard grafana
```

TODO: capture a screen shot of Grafana service level metrics.

TODO: add some content for prometheus and connect it to generate alerts.

## Propogate Trace Headers

TODO: check if the sample services already propogate trace headers. If not, we need to add code to do it.

## Next lab
Congratulations, you have added the sample application successfully to Istio service mesh and observed the services' communications. We'll explore securing these services in the mesh in the [next lab](./04-secure-services-with-istio.md).



