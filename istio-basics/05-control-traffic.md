# Lab 5 :: Control Traffic

You are now ready to take control of how traffic flows between services. In a Kubernetes environment, there is simple round-robin load balancing between service endpoints. While Kubernetes does support rolling upgrade, it is fairly coarse grained and is limited to moving to a new version of the service. You may find it necessary to dark launch your new version, then canary test your new version before shift all traffics to the new version completely. We will explore many of these types of features provided by Istio to control the traffic between services while increasing the resiliency between the services.

## Dark Launch

You may find the v1 of the `purchase-history` service is rather boring as it always return the `Hello From Purchase History (v1)!` message. You want to make a new version of the `purchase-history` service so that it returns dynamic messages based on the result from querying an external service, for example the [JsonPlaceholder service](http://jsonplaceholder.typicode.com).

Dark launch allows you to deploy and test a new version of a service while minimizing the impact to users, e.g. you can keep the new version of the service in the dark. Using a dark launch appoach enables you to deliver new functions rapidly with reduced risk. Istio allows you to preceisely control how new versions of services are rolled out without the need to make any code change to your services or redeploy your services.

You have v2 of the `purchase-history` service ready in the `labs/05/purchase-history-v2.yaml` file. 

```bash
cat labs/05/purchase-history-v2.yaml
```

The main change is the `purchase-history-v2` deployment name  and the `version:v2` labels, along with the `fake-service:v2` image and the newly added `EXTERNAL_SERVICE_URL` environment variable. The `purchase-history-v2` pod establishes the connection to the external service at startup time and obtain a random response from the external service when clients call the v2 of the `purchase-history` service.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: purchase-history-v2
  labels:
    app: purchase-history
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
        app: purchase-history
        version: v2
  template:
    metadata:
      labels:
        app: purchase-history
        version: v2
    spec:
      serviceAccountName: purchase-history    
      containers:
      - name: purchase-history
        image: linsun/fake-service:v2
        ports:
        - containerPort: 8080
        env:
        - name: "LISTEN_ADDR"
          value: "0.0.0.0:8080"
        - name: "NAME"
          value: "purchase-history-v2"
        - name: "SERVER_TYPE"
          value: "http"
        - name: "MESSAGE"
          value: "Hello From Purchase History (v2)!"
        - name: "EXTERNAL_SERVICE_URL"
          value: "http://jsonplaceholder.typicode.com/posts"
        imagePullPolicy: Always
```

Should you deploy the `labs/05/purchase-history-v2.yaml` to your Kubernetes cluster?  How much percentage of the traffic will visit v1 and v2 of the `purchase-history` services? Because both of the deployments have `replicas: 1`, you will see 50% traffic goes to v1 and 50% traffic goes to v2. This is not what you wanted because you haven't had chance to test v2 in your Kubernetes cluster yet.

You can use Istio's networking resources to dark launch the v2 of the `purchase-history` service. Virtual Service provides you with the ability to configure a list of routing rules that control how the Envoy proxies of the client routes requests to a given service within the service mesh. The client could be Istio's ingress gateway or any of your service in the mesh.  In lab 02, when the client is `istio-ingressgateway`, the virtual service is bound to the `web-api-gateway` gateway. If you recall the Kiali graph for our application from the prior labs, the client for the `purchase-history` service is the `recommendation` service.

Destination rule allows you to define configurations of policies that are applied to a request after the routing rules are enforced as defined in the destination virtual service. In addition, destination rule is also used to define the set of Kubernetes pods that belong to a subset grouping, for example multiple versions of a service, which are called "subsets" in Istio.

You can review the virtual service resource for the `purchase-history` service that configures all traffic to v1 of the `purchase-history` service:

```bash
cat labs/05/purchase-history-vs-all-v1.yaml
```

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: purchase-history-vs
spec:
  hosts:
  - purchase-history.istioinaction.svc.cluster.local
  http: 
  - route:
    - destination:
        host: purchase-history.istioinaction.svc.cluster.local
        subset: v1
        port:
          number: 8080
      weight: 100
```

Also review the destination rule resource for the `purchase-history` service that defines the `v1` and `v2` subsets. Since `v2` is dark launched and no traffic will go to `v2`, it is not required to have `v2` subsets now but you will need it soon.

```bash
cat labs/05/purchase-history-dr.yaml
```

```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: purchase-history-dr
spec:
  host: purchase-history.istioinaction.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

Apply the `purchase-history-vs` and `purchase-history-dr` resources:

```bash
kubectl apply -f labs/05/purchase-history-vs-all-v1.yaml -n istioinaction
kubectl apply -f labs/05/purchase-history-dr.yaml -n istioinaction
```

After you have configured Istio to control 100% of traffic to `purchase-history` to v1 of the service, you can now deploy the v2:

```bash
kubectl apply -f labs/05/purchase-history-v2.yaml -n istioinaction
```

Confirm the new v2 `purchase-history` pod has reached running:
<!--bash
kubectl wait --for=condition=Ready pod -l app=purchase-history -n istioinaction
-->
```bash
kubectl get pods -n istioinaction -l app=purchase-history
```

You should see both v1 and v2 are running with its own sidecar proxy.

```
NAME                                   READY   STATUS    RESTARTS   AGE
purchase-history-v1-55989d4c56-vv5d4   2/2     Running   0          2d4h
purchase-history-v2-74886f799f-lgzfn   2/2     Running   0          4m
```

Generate some load on the `web-api` service to ensure your users are not impacted by deploying of the v2 of the `purchase-history` service:
<!--bash
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
SECURE_INGRESS_PORT=443
-->
```bash
for i in {1..10}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP|grep "Hello From Purchase History"; done
```

You will see all of the 10 responses from `purchase-history` are from v1 of the service.  This is great!  We introduced v2 of the service but it didn't impact any of the behavior of the existing requests.  Next, let us test the v2 of the service:

```bash
kubectl exec deploy/purchase-history-v2 -n istioinaction -c istio-proxy -- curl localhost:8080
```

You will notice the output is not good:

```
curl: (52) Empty reply from server
command terminated with exit code 52
```

Run the same test on the v1 of the service:

```bash
kubectl exec deploy/purchase-history-v1 -n istioinaction -c istio-proxy -- curl localhost:8080
```

You will get the following expected output:

```
{
  "name": "purchase-history-v1",
  "uri": "/",
  "type": "HTTP",
  "ip_addresses": [
    "10.42.0.18"
  ],
  "start_time": "2021-06-10T18:23:23.400270",
  "end_time": "2021-06-10T18:23:23.400314",
  "duration": "43.951µs",
  "body": "Hello From Purchase History (v1)!",
  "code": 200
}
```

Let us check out the logs for the v2 of the `purchase-history` pod:

```bash
kubectl logs deploy/purchase-history-v2 -n istioinaction
```

Note the `connection refused` error at the beginning of the log during the service initialization:

```
2021-06-10T17:50:22.209Z [INFO]  Starting service: name=purchase-history-v2 upstreamURIs= upstreamWorkers=1 listenAddress=0.0.0.0:8080 service type=http
Get "http://jsonplaceholder.typicode.com/posts?id=24": dial tcp 172.67.189.121:80: connect: connection refused
2021-06-10T17:50:22.241Z [INFO]  Adding handler for UI static files
2021-06-10T17:50:22.242Z [INFO]  Settings CORS options: allow_creds=false allow_headers=Accept,Accept-Language,Content-Language,Origin,Content-Type allow_origins=*
2021-06-10T17:52:29.853Z [INFO]  Handle inbound request: request="GET / HTTP/1.1
Host: localhost:8080
user-agent: curl/7.58.0
accept: */*"
2021-06-10T17:52:29.854Z [INFO]  Sleeping for: duration=-179.485µs
2021-06-10T17:52:29.854Z [INFO]  Finished handling request: duration=409.607µs
2021/06/10 17:52:29 http: panic serving [::1]:50228: json: error calling MarshalJSON for type json.RawMessage: invalid character 'h' after top-level value
goroutine 15 [running]:
net/http.(*conn).serve.func1(0xc000182aa0)
```

Recall the `v2` of the `purchase-history` service added some code to call the external service and requires the ability for the pod to connect to the external service during initialization. By default in Istio, the `istio-proxy` starts in parallel with the application container (`purchase-history` here in our example) so it is possible that the application container reaches running before `istio-proxy` fully starts thus unable to connect to anything outside of the cluster.

How can we solve this problem and ensure the application container can connect to services outside of the cluster during the container start time? The `holdApplicationUntilProxyStarts` configuration is introduced in Istio to solve this problem.  Let us add this configuration to the pod annotation of v2 of the `purchase-history` to use it:

```bash
cat labs/05/purchase-history-v2-updated.yaml
```

Through the `holdApplicationUntilProxyStarts` annotation below, you have configured the v2 of `purchase-history` pod to delay starting until the `istio-proxy` container reaches the `Running` status:

```
  template:
    metadata:
      labels:
        app: purchase-history
        version: v2
      annotations:
        proxy.istio.io/config: '{ "holdApplicationUntilProxyStarts": true }'
    spec:
```

Deploy the updated v2 of the `purchase-history`.

```bash
kubectl apply -f labs/05/purchase-history-v2-updated.yaml -n istioinaction
```

Test the v2 service:
<!--bash
sleep 2
-->
```bash
kubectl exec deploy/purchase-history-v2 -n istioinaction -c istio-proxy -- curl localhost:8080
```

Awesome! You are getting a valid response this time, from v2!

```
{
  "name": "purchase-history-v2",
  "uri": "/",
  "type": "HTTP",
  "ip_addresses": [
    "10.42.0.23"
  ],
  "start_time": "2021-06-10T18:47:15.624118",
  "end_time": "2021-06-10T18:47:15.624438",
  "duration": "320.459µs",
  "body": "Hello From Purchase History (v2)! + History: 24 Title: autem hic labore sunt dolores incidunt Body: autem hic labore sunt dolores incidunt",
  "code": 200
}
```

TODO: add header based routing
## Canary Testing

You have dark launched and did some basic testing of the v2 of the `purchase-history` service. You want to canary test a small percentage of requests to the new version to determine whether ther are problems before routing all traffic to the new version. Canary tests are often performed to ensure the new version of the service not only functions properly but also doesn't cause any degradation in performance or reliability.

### Shift 20% Traffic to v2

Review the updated `purchase-history` virtual service resource:

```bash
cat labs/05/purchase-history-vs-20-v2.yaml
```

You will notice `subset: v2` is added which will get 20% of the traffic while `subset: v1` will get 80% of the traffic:

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: purchase-history-vs
spec:
  hosts:
  - purchase-history.istioinaction.svc.cluster.local
  http: 
  - route:
    - destination:
        host: purchase-history.istioinaction.svc.cluster.local
        subset: v1
        port:
          number: 8080
      weight: 80
    - destination:
        host: purchase-history.istioinaction.svc.cluster.local
        subset: v2
        port:
          number: 8080
      weight: 20
```

Deploy the updated `purchase-history` virtual service resource:

```bash
kubectl apply -f labs/05/purchase-history-vs-20-v2.yaml -n istioinaction
```

Generate some load on the `web-api` service to check how many requests are served by v1 and v2 of the `purchase-history` service. You should see only a few from v2 while the rest from v1. You may be curious why you are not observe an exactly 80%/20% distribution among v1 and v2.  You likely need to have over 100 requests to get the desired 80%/20% weighted version distribution.

<!--bash
sleep 2
-->
```bash
for i in {1..20}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP|grep "Hello From Purchase History"; done
```

### Shift 50% Traffic to v2

Review the updated `purchase-history` virtual service resource:

```bash
cat labs/05/purchase-history-vs-50-v2.yaml
```

You will notice `subset: v2` is updated to get 50% of the traffic while `subset: v1` will get 50% of the traffic:

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: purchase-history-vs
spec:
  hosts:
  - purchase-history.istioinaction.svc.cluster.local
  http: 
  - route:
    - destination:
        host: purchase-history.istioinaction.svc.cluster.local
        subset: v1
        port:
          number: 8080
      weight: 50
    - destination:
        host: purchase-history.istioinaction.svc.cluster.local
        subset: v2
        port:
          number: 8080
      weight: 50
```

Deploy the updated `purchase-history` virtual service resource:

```bash
kubectl apply -f labs/05/purchase-history-vs-50-v2.yaml -n istioinaction
```

Generate some load on the `web-api` service to check how many requests are served by v1 and v2 of the `purchase-history` service. You should observe *roughly* 50%/50% distribution among the v1 and v2 of the service.

<!--bash
sleep 2
-->
```bash
for i in {1..20}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP|grep "Hello From Purchase History"; done
```

### Shift All Traffic to v2
Now you haven't observed any ill effect during your test, you can adjust the routing rules to direct all of the traffic to the canary deployment:

Deploy the updated `purchase-history` virtual service resource:

```bash
kubectl apply -f labs/05/purchase-history-vs-all-v2.yaml -n istioinaction
```

Generate some load on the `web-api` service, you should only see traffic to the v2 of the `purchase-history` service.

<!--bash
sleep 2
-->
```bash
for i in {1..20}; do curl --cacert ./labs/02/certs/ca/root-ca.crt -H "Host: istioinaction.io" https://istioinaction.io:$SECURE_INGRESS_PORT --resolve istioinaction.io:$SECURE_INGRESS_PORT:$GATEWAY_IP|grep "Hello From Purchase History"; done
```

## Resiliency and Chaos Testing

When you build a distributed application, it is critical to ensure the services in your application are resilient to failures in the underlying platforms or the dependent services. Istio has support for retries, timeouts, circuit breakers and even injecting faults into your service calls to help you test and tune your timeouts. Similar as the dark launch and canary testing you explored earlier, you don't need to add these logic into your application code or redeploy your application when configuring these Istio features to increase the resiliency of your services.

### Retries



### Timeouts


### Circuit Breakers

### Fault Injection


## Controlling Outbound Traffic

### Understand the Default Behavior

### 

Question: Do you want to securely restrict all other pods from accessing the external service? Do you always want traffic to external service go through the egress gateway? We will cover this in the Istio Expert workshop.

## Conclusion

A service mesh like Istio has the capabilities that enable you to manage traffic flows within the mesh as well as entering and leaving the mesh. These capabilities allow you to efficiently control rollout and access to new features, and make it possible to build resilient services without having to make complicated changes to your application code.