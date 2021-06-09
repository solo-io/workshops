# Lab 5 :: Control Traffic

You are now ready to take control of how traffic flows between services. In a Kubernetes environment, there is simple round-robin load balancing between service endpoints. While Kubernetes does support rolling upgrade, it is fairly coarse grained and is limited to moving to a new version of the service. You may find it necessary to dark launch your new version, then canary test your new version before shift all traffics to the new version completely. We will explore many of these types of features provided by Istio to control the traffic between services while increasing the resiliency between the services.

## Dark Launch

You may find the v1 of the `purchase-history` service is rather boring as it always return the `Hello From Purchase History (v1)!` message. You want to make a new version of the `purchase-history` service so that it returns dynamic messages based on the result from querying an external service, for example the [JsonPlaceholder service](http://jsonplaceholder.typicode.com).

## Canary Testing

## Resiliency and Chaos Testing

## Controlling Outbound Traffic

