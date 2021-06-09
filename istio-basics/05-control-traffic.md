# Lab 5 :: Control Traffic

You are now ready to take control of how traffic flows between services. In a Kubernetes environment, there is simple round-robin load balancing between service endpoints. While Kubernetes does support rolling upgrade, it is fairly coarse grained and is limited to moving to a new version of the service. You may find it necessary to dark launch your new version, then canary test your new version before shift all traffics to the new version completely. We will explore many of these types of features provided by Istio to control the traffic between services while increasing the resiliency between the services.

## Dark Launch

You may find the v1 of the `purchase-history` service is rather boring as it always return the `Hello From Purchase History (v1)!` message. You want to make a new version of the `purchase-history` service so that it returns dynamic messages based on the result from querying an external service, for example the [JsonPlaceholder service](http://jsonplaceholder.typicode.com).

Dark launch allows you to deploy and test a new version of a service while minimizing the impact to users, e.g. you can keep the new version of the service in the dark. Using a dark launch appoach enables you to deliver new functions rapidly with reduced risk. Istio allows you to preceisely control how new versions of services are rolled out without the need to make any code change to your services or redeploy your services.

You have v2 of the `purchase-history` service ready in the `labs/05/purchase-history-v2.yaml` file. 

```bash
cat labs/05/purchase-history-v2.yaml
```

The key change is the `purchase-history-v2` deployment name  and the `version:v2` labels, along with the `fake-service:v2` image and the `EXTERNAL_SERVICE_URL`:

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

Should you deploy the `labs/05/purchase-history-v2.yaml` to your Kubernetes cluster?  How much percentage of the traffic will visit v1 and v2 of the `purchase-history` services? Because both of the deployments have `replicas: 1`, you will see 50% traffic goes to v1 and 50% traffic goes to v2.  This is not really what you wanted because you haven't had chance to test v2 yet in your Kubernetes cluster.

Deploy the istio configuration:

Test the v2 service:

Deploy an updated v2 service:

Test the v2 service:

## Canary Testing

Shift traffic 10% to v2

Shift more traffic to v2

## Resiliency and Chaos Testing

## Controlling Outbound Traffic

