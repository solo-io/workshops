# Gloo Federation workshop

Gloo Federation allows users to manage the configuration for all of their Gloo instances from one place, no matter what platform they run on. In addition Gloo Federation elevates Gloo’s powerful routing features beyond the environment they live in, allowing users to create all new global routing features between different Gloo instances. Gloo Federation enables consistent configuration, service failover, unified debugging, and automated Gloo discovery across all of your Gloo instances.

The goal of this workshop is to show several unique features of the Gloo Federation in action:

- Multicluster RBAC
- Federated configuration
- Failover

## Lab environment

![Lab](images/lab.png)

To make sure anyone can easily perform the different tasks, we have provisioned a Virtual Machine for each of you.

You'll be able to deploy several Kubernetes clusters on this machine using *Kind*.

*MetalLB* has been deployed to expose the Load Balancer services you'll create on your Kubernetes clusters.

All the prerequisites have already been deployed on your machine.

## Prerequisites

You will be accessing your Virtual Machine using [Apache Guacamole](https://guacamole.apache.org/).

Apache Guacamole is a clientless remote desktop gateway. Thanks to HTML5, once Guacamole is installed on a server, all you need to access your desktops is a web browser.

## Access your virtual machine

Log into your Virtual Machine using your web browser.

The URL is `http://<ip address provided by the instructor>/guacamole/`

The user is `solo` and the password is `Workshop1#`

![Desktop](images/desktop.png)

> If you have an issue with the keyboard layout, click on the `Applications` button on the top left corner, select `Settings` and then `Keyboard`.
>
> In the `Layout` tab, you can add the layout you want to use and delete the default one:
>
> <img src="images/keyboard.png" alt="keyboard" width="300"/>

## Lab 1 : Deploy your Kubernetes clusters

From the terminal go to the `/home/solo/workshops/smh` directory:

```
cd /home/solo/workshops/smh
```

Run the following commands to deploy 2 Kubernetes clusters:

```bash
../../scripts/deploy.sh 1
../../scripts/deploy.sh 2
../../scripts/deploy.sh 3
```

Then run the following commands to wait for all the Pods to be ready:

```bash
../../scripts/check.sh 1
../../scripts/check.sh 2
../../scripts/check.sh 3
```

Now, if you execute the `kubectl get pods -A` command, you should obtain the following:

```
NAMESPACE            NAME                                          READY   STATUS    RESTARTS   AGE
kube-system          calico-kube-controllers-59d85c5c84-sbk4k      1/1     Running   0          4h26m
kube-system          calico-node-przxs                             1/1     Running   0          4h26m
kube-system          coredns-6955765f44-ln8f5                      1/1     Running   0          4h26m
kube-system          coredns-6955765f44-s7xxx                      1/1     Running   0          4h26m
kube-system          etcd-kind2-control-plane                      1/1     Running   0          4h27m
kube-system          kube-apiserver-kind2-control-plane            1/1     Running   0          4h27m
kube-system          kube-controller-manager-kind2-control-plane   1/1     Running   0          4h27m
kube-system          kube-proxy-ksvzw                              1/1     Running   0          4h26m
kube-system          kube-scheduler-kind2-control-plane            1/1     Running   0          4h27m
local-path-storage   local-path-provisioner-58f6947c7-lfmdx        1/1     Running   0          4h26m
metallb-system       controller-5c9894b5cd-cn9x2                   1/1     Running   0          4h26m
metallb-system       speaker-d7jkp                                 1/1     Running   0          4h26m
```

Note that this the output for the third cluster.

You can see that your currently connected to this cluster by executing the `kubectl config get-contexts` command:

```
CURRENT   NAME         CLUSTER      AUTHINFO     NAMESPACE
          kind-kind1   kind-kind1   kind-kind1   
          kind-kind2   kind-kind2   kind-kind2
*         kind-kind3   kind-kind3   kind-kind3
````

Run the following command to make `kind-kind1` the current cluster.

```bash
kubectl config use-context kind-kind1
```

## Deploy Gloo Federation on the first clusters

Upgrade `glooctl` using the following command:

```bash
glooctl upgrade --release=v1.5.0-beta18
```

Set the `LICENSE_KEY` variable with the value provided by the instructor:

```
export LICENSE_KEY=<license>
```

Create the following configuration file to enable Multicluster RBAC:

```bash
cat << EOF > values-federation.yaml
enableMultiClusterRbac: true
EOF
```

Deploy Gloo:

```bash
kubectl config use-context kind-kind1
glooctl install federation --values values-federation.yaml --license-key $LICENSE_KEY
```

## Deploy Gloo on the two other clusters

Create the following configuration file:

```bash
cat << EOF > values.yaml
devPortal:
  enabled: true
EOF
```

Deploy Gloo on the second cluster:

```bash
kubectl config use-context kind-kind2
glooctl install gateway enterprise --version 1.5.0-beta7 --values values.yaml --license-key $LICENSE_KEY
```

Deploy Gloo on the third cluster:

```bash
kubectl config use-context kind-kind3
glooctl install gateway enterprise --version 1.5.0-beta7 --values values.yaml --license-key $LICENSE_KEY
```

Use the following commands to wait for the Gloo components to be deployed on all the clusters:

```bash

kubectl --context kind-kind1 -n gloo-fed rollout status deployment gloo-fed

until kubectl --context kind-kind2 get ns gloo-system
do
  sleep 1
done

until kubectl --context kind-kind3 get ns gloo-system
do
  sleep 1
done

until [ $(kubectl --context kind-kind2 -n gloo-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  echo "Waiting for all the gloo-system pods to become ready on cluster kind-kind2"
  sleep 1
done

until [ $(kubectl --context kind-kind3 -n gloo-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep false -c) -eq 0 ]; do
  echo "Waiting for all the gloo-system pods to become ready on cluster kind-kind3"
  sleep 1
done
```

## Register the Gloo clusters

Register the 2 Gloo clusters:

```bash
kubectl config use-context kind-kind1

glooctl cluster register --cluster-name kind2 --remote-context kind-kind2
glooctl cluster register --cluster-name kind3 --remote-context kind-kind3
```

Once a cluster has been registered, Gloo Federation will automatically discover all instances of Gloo within the cluster. The discovered instances are stored in a Custom Resource of type `glooinstances.fed.solo.io` in the `gloo-fed` namespace.

You can view the discovered instances by running the following command:

```bash
kubectl --context kind-kind1 get glooinstances -n gloo-fed
```

You should see something like that:

```
NAME                AGE
kind2-gloo-system   76s
kind3-gloo-system   74s
```

## Access the Gloo Federation UI

Run the following command in a different tab:

```
kubectl config use-context kind-kind1
kubectl port-forward svc/gloo-fed-console -n gloo-fed 8090:8090
```

Access the UI at http://localhost:8090

## Secure the communications between the Gloo clusters

Failover will allow communication between the Gloo clusters, so it is crucial that the traffic be encrypted. Therefore certificates need to be provisioned and placed in the clusters to allow for mTLS between the Gloo instances running on separate clusters.

Run the following commands to provision de certificates:

```bash
# Generate downstream cert and key
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=solo.io"

# Generate upstream ca cert and key
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout mtls.key -out mtls.crt -subj "/CN=solo.io"

# Set context to second cluster
kubectl config use-context kind-kind3

# Create the secret
glooctl create secret tls --name failover-downstream \
--certchain tls.crt --privatekey tls.key --rootca mtls.crt

# Set the context to the first cluster
kubectl config use-context kind-kind2

# Create the secret
glooctl create secret tls --name failover-upstream \
--certchain mtls.crt --privatekey mtls.key
```

## Multicluster RBAC

Gloo Federation allows you to administer multiple instances of Gloo across multiple Kubernetes clusters. One Gloo Federation object might modify configuration across many instances of Gloo across many Kubernetes clusters. Multicluster role-based access control is a feature of Gloo Federation that controls access and actions on Gloo Federation APIs that might reconfigure many Gloo instances. The feature ensures that users are only allowed to modify Gloo Federation resources that configure Gloo resources in clusters and namespaces that they have explicitly been granted access to in order to facilitate multitenancy in the Gloo Federation control plane.

The installation of Multicluster RBAC creates two `MultiClusterRole` Custom Resources and two `MultiClusterRoleBinding` Custom Resources.

Run the following command to make `kind-kind1` the current cluster.

```bash
kubectl config use-context kind-kind1
```

List the MultiClusterRole objects:

```bash
kubectl get multiclusterrole -n gloo-fed 
```

The output should be similar to below:

````
NAME               AGE
gloo-fed           19m
gloo-fed-console   19m
````

List the MultiClusterRoleBinding objects:

```bash
kubectl get multiclusterrolebinding -n gloo-fed
```

The output should be similar to below:

````
NAME               AGE
gloo-fed           22m
gloo-fed-console   22m
````

You can inspect these objects, but to summarize, the `gloo-fed` MultiClusterRoleBinding associates the MultiClusterRole with the `gloo-fed` service account. Without the binding, the `gloo-fed` pod wouldn’t be able to update the status of Gloo Federation API objects.

The `gloo-fed-console` MultiClusterRole and MultiClusterRoleBinding grant the same set of permissions to the `gloo-fed-console` service account.

Now let’s create a new MultiClusterRoleBinding for the `kubernetes-admin` account binding it to the `gloo-fed` MultiClusterRole.

```bash
kubectl --context kind-kind1 apply -f - <<EOF
apiVersion: multicluster.solo.io/v1alpha1
kind: MultiClusterRoleBinding
metadata:
  name: kind-admin
  namespace: gloo-fed
spec:
  roleRef:
    name: gloo-fed
    namespace: gloo-fed
  subjects:
  - kind: User
    name: kubernetes-admin
EOF
```

## Federated configuration

Gloo Federation enables you to create consistent configurations across multiple Gloo instances. The resources being configured could be resources such as Upstreams, UpstreamGroups, and Virtual Services.

First of all, let's deploy workloads on the Gloo clusters:

```bash
kubectl apply --context kind-kind2 -f - <<EOF
apiVersion: v1
kind: Service
metadata:
 labels:
   app: bluegreen
   text: blue
 name: service-blue
 namespace: default
spec:
 ports:
 - name: color
   port: 10000
   protocol: TCP
   targetPort: 10000
 selector:
   app: bluegreen
   text: blue
 sessionAffinity: None
 type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
 labels:
   app: bluegreen
   text: blue
 name: echo-blue
 namespace: default
spec:
 progressDeadlineSeconds: 600
 replicas: 1
 revisionHistoryLimit: 10
 selector:
   matchLabels:
     app: bluegreen
     text: blue
 strategy:
   rollingUpdate:
     maxSurge: 25%
     maxUnavailable: 25%
   type: RollingUpdate
 template:
   metadata:
     creationTimestamp: null
     labels:
       app: bluegreen
       text: blue
   spec:
     containers:
     - args:
       - -text="blue-pod"
       image: hashicorp/http-echo@sha256:ba27d460cd1f22a1a4331bdf74f4fccbc025552357e8a3249c40ae216275de96
       imagePullPolicy: IfNotPresent
       name: echo
       resources: {}
       terminationMessagePath: /dev/termination-log
       terminationMessagePolicy: File
     - args:
       - --config-yaml
       - |2

         node:
          cluster: ingress
          id: "ingress~for-testing"
          metadata:
           role: "default~proxy"
         static_resources:
           listeners:
           - name: listener_0
             address:
               socket_address: { address: 0.0.0.0, port_value: 10000 }
             filter_chains:
             - filters:
               - name: envoy.filters.network.http_connection_manager
                 typed_config:
                   "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                   stat_prefix: ingress_http
                   codec_type: AUTO
                   route_config:
                     name: local_route
                     virtual_hosts:
                     - name: local_service
                       domains: ["*"]
                       routes:
                       - match: { prefix: "/" }
                         route: { cluster: some_service }
                   http_filters:
                   - name: envoy.filters.http.health_check
                     typed_config:
                       "@type": type.googleapis.com/envoy.extensions.filters.http.health_check.v3.HealthCheck
                       pass_through_mode: true
                   - name: envoy.filters.http.router
           clusters:
           - name: some_service
             connect_timeout: 0.25s
             type: STATIC
             lb_policy: ROUND_ROBIN
             load_assignment:
               cluster_name: some_service
               endpoints:
               - lb_endpoints:
                 - endpoint:
                     address:
                       socket_address:
                         address: 0.0.0.0
                         port_value: 5678
         admin:
           access_log_path: /dev/null
           address:
             socket_address:
               address: 0.0.0.0
               port_value: 19000
       - --disable-hot-restart
       - --log-level
       - debug
       - --concurrency
       - "1"
       - --file-flush-interval-msec
       - "10"
       image: envoyproxy/envoy:v1.14.2
       imagePullPolicy: IfNotPresent
       name: envoy
       resources: {}
       terminationMessagePath: /dev/termination-log
       terminationMessagePolicy: File
     dnsPolicy: ClusterFirst
     restartPolicy: Always
     schedulerName: default-scheduler
     securityContext: {}
     terminationGracePeriodSeconds: 0
EOF

kubectl apply --context kind-kind3 -f - <<EOF
apiVersion: v1
kind: Service
metadata:
 labels:
   app: bluegreen
 name: service-green
 namespace: default
spec:
 ports:
 - name: color
   port: 10000
   protocol: TCP
   targetPort: 10000
 selector:
   app: bluegreen
   text: green
 sessionAffinity: None
 type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
 labels:
   app: bluegreen
   text: green
 name: echo-green
 namespace: default
spec:
 progressDeadlineSeconds: 600
 replicas: 1
 revisionHistoryLimit: 10
 selector:
   matchLabels:
     app: bluegreen
     text: green
 strategy:
   rollingUpdate:
     maxSurge: 25%
     maxUnavailable: 25%
   type: RollingUpdate
 template:
   metadata:
     creationTimestamp: null
     labels:
       app: bluegreen
       text: green
   spec:
     containers:
     - args:
       - -text="green-pod"
       image: hashicorp/http-echo@sha256:ba27d460cd1f22a1a4331bdf74f4fccbc025552357e8a3249c40ae216275de96
       imagePullPolicy: IfNotPresent
       name: echo
       resources: {}
       terminationMessagePath: /dev/termination-log
       terminationMessagePolicy: File
     - args:
       - --config-yaml
       - |2

         node:
          cluster: ingress
          id: "ingress~for-testing"
          metadata:
           role: "default~proxy"
         static_resources:
           listeners:
           - name: listener_0
             address:
               socket_address: { address: 0.0.0.0, port_value: 10000 }
             filter_chains:
             - filters:
               - name: envoy.filters.network.http_connection_manager
                 typed_config:
                   "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                   stat_prefix: ingress_http
                   codec_type: AUTO
                   route_config:
                     name: local_route
                     virtual_hosts:
                     - name: local_service
                       domains: ["*"]
                       routes:
                       - match: { prefix: "/" }
                         route: { cluster: some_service }
                   http_filters:
                   - name: envoy.filters.http.health_check
                     typed_config:
                       "@type": type.googleapis.com/envoy.extensions.filters.http.health_check.v3.HealthCheck
                       pass_through_mode: true
                   - name: envoy.filters.http.router
           clusters:
           - name: some_service
             connect_timeout: 0.25s
             type: STATIC
             lb_policy: ROUND_ROBIN
             load_assignment:
               cluster_name: some_service
               endpoints:
               - lb_endpoints:
                 - endpoint:
                     address:
                       socket_address:
                         address: 0.0.0.0
                         port_value: 5678
         admin:
           access_log_path: /dev/null
           address:
             socket_address:
               address: 0.0.0.0
               port_value: 19000
       - --disable-hot-restart
       - --log-level
       - debug
       - --concurrency
       - "1"
       - --file-flush-interval-msec
       - "10"
       image: envoyproxy/envoy:v1.14.2
       imagePullPolicy: IfNotPresent
       name: envoy
       resources: {}
       terminationMessagePath: /dev/termination-log
       terminationMessagePolicy: File
     dnsPolicy: ClusterFirst
     restartPolicy: Always
     schedulerName: default-scheduler
     securityContext: {}
     terminationGracePeriodSeconds: 0
EOF
```

Now, let's create some federated objects:

```bash
kubectl apply --context kind-kind1 -f - <<EOF
apiVersion: fed.gloo.solo.io/v1
kind: FederatedUpstream
metadata:
  name: default-service-blue
  namespace: gloo-fed
spec:
  placement:
    clusters:
      - kind2
    namespaces:
      - gloo-system
  template:
    metadata:
      name: default-service-blue-10000
    spec:
      discoveryMetadata: {}
      healthChecks:
        - healthyThreshold: 1
          httpHealthCheck:
            path: /health
          interval: 1s
          noTrafficInterval: 1s
          timeout: 1s
          unhealthyThreshold: 1
      kube:
        selector:
          app: bluegreen
          text: blue
        serviceName: service-blue
        serviceNamespace: default
        servicePort: 10000
---
apiVersion: fed.gateway.solo.io/v1
kind: FederatedVirtualService
metadata:
  name: simple-route
  namespace: gloo-fed
spec:
  placement:
    clusters:
      - kind2
    namespaces:
      - gloo-system
  template:
    spec:
      virtualHost:
        domains:
        - '*'
        routes:
        - matchers:
          - prefix: /
          routeAction:
            single:
              upstream:
                name: default-service-blue-10000
                namespace: gloo-system
    metadata:
      name: simple-route
EOF
```

The FederatedUpstream creates an Upstream in the target clusters (only the first Gloo cluster in this case) and the FederatedVirtualService does the same with VirtualServices.

You can run execute the following command to validate tha the Upstream object has been correctly created in the first Gloo cluster:

```bash
kubectl --context kind-kind2 -n gloo-system get upstream default-service-blue-10000 -o yaml
```

You should get something similar to that:

```
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
...
  name: default-service-blue-10000
  namespace: gloo-system
  resourceVersion: "7621"
  selfLink: /apis/gloo.solo.io/v1/namespaces/gloo-system/upstreams/default-service-blue-10000
  uid: 20f8737f-8f55-469b-933b-f766a3623e2a
spec:
  discoveryMetadata:
    labels:
      app: bluegreen
      text: blue
  healthChecks:
  - healthyThreshold: 1
    httpHealthCheck:
      path: /health
    interval: 1s
    noTrafficInterval: 1s
    timeout: 1s
    unhealthyThreshold: 1
  kube:
    selector:
      app: bluegreen
      text: blue
    serviceName: service-blue
    serviceNamespace: default
    servicePort: 10000
status:
  reportedBy: gloo
  state: 1
```

You can do the same for the VirtualService object

## Failover

When an Upstream fails or becomes unhealthy, Gloo Federation can automatically fail traffic over to a different Gloo instance and Upstream.

Let's create a FailoverScheme object to determine how we want the failover to happen:

```bash
kubectl apply --context kind-kind1 -f - <<EOF
apiVersion: fed.solo.io/v1
kind: FailoverScheme
metadata:
 name: failover-scheme
 namespace: gloo-fed
spec:
 failoverGroups:
 - priorityGroup:
   - cluster: kind3
     upstreams:
     - name: default-service-green-10000
       namespace: gloo-system
 primary:
   clusterName: kind2
   name: default-service-blue-10000
   namespace: gloo-system
EOF
```

In order to use a Gloo Instance as a failover target it first needs to be configured with an additional listener to route incoming failover requests.

The Gateway resource below sets up a TCP proxy which is configured to terminate mTLS traffic from the primary gloo instance, and forward the traffic based on the SNI name. The SNI name and routing are automatically handled by Gloo Federation, but the certificates are the ones created in the previous step.


```bash
kubectl config use-context kind-kind3

kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: Gateway
metadata:
 name: failover-gateway
 namespace: gloo-system
 labels:
   app: gloo
spec:
 bindAddress: "::"
 bindPort: 15443
 tcpGateway:
   tcpHosts:
   - name: failover
     sslConfig:
       secretRef:
         name: failover-downstream
         namespace: gloo-system
     destination:
       forwardSniClusterName: {}
---
apiVersion: v1
kind: Service
metadata:
 labels:
   app: gloo
   gateway-proxy-id: gateway-proxy
   gloo: gateway-proxy
 name: failover
 namespace: gloo-system
spec:
 ports:
 - name: failover
   nodePort: 32000
   port: 15443
   protocol: TCP
   targetPort: 15443
 selector:
   gateway-proxy: live
   gateway-proxy-id: gateway-proxy
 sessionAffinity: None
 type: LoadBalancer
EOF
```

Check that you can access the application on the first Gloo cluster:

```bash
kubectl config use-context kind-kind2
curl $(glooctl proxy url)/
```

You should get this output:

```
"blue-pod"
```

## Failover the workload

Run the following commands to fail te blue Pod:

```bash
kubectl config use-context kind-kind2
kubectl port-forward deploy/echo-blue 19000 &
curl -v -X POST  http://localhost:19000/healthcheck/fail
```
 
Check that you can access the application on the first Gloo cluster:

```bash
kubectl config use-context kind-kind2
curl $(glooctl proxy url)/
```

You should now get this output:

```
"green-pod"
```

## Cleanup

```bash
pkill kubectl
```