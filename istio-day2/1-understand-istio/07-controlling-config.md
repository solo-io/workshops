sidecar, export-to, VS merging, and VS delegation

# Lab 7 :: Controlling configuration scope

By default, Istio networking resources and services are visible to all services running in all namespaces that are part of the Istio service mesh. As you add more services to the mesh, the amount of sidecar proxy's configuration increases dramatically which will grow your sidecar proxy's memory accordingly. Thus this default behavior is not desired when you have more than a few services and not all of your services communicate to all other services.

The `Sidecar` resource is designed to solve this problem from the service consumers perspective. This configuration allows you to configure the sidecar proxy that mediates inbound and outbound communication to the workload instance it is applicable to.  The `Export-To` configuration allows service producers to declare the scope of the services to be exported. With both of these configuration, service owners can effectively control the scope of the sidecar configuration. 

## Sidecar resource for service consumers

Let's declare services in the istioinaction namespace is allowed to reach out to services within the namespace or services in the istio-system namespace.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: istioinaction
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
```

Apply this resource:

```bash
kubectl apply -f labs/07/default-sidecar.yaml -n istioinaction
```

Let us reach to web-api service from the sleep pod in the istioinaction namespace.

```bash
kubectl exec -it deploy/sleep -n istioinaction -- curl http://web-api.istioinaction:8080/
```

Now reach to web-api service from the sleep pod in the default namespace.

```bash
kubectl exec -it deploy/sleep -- curl http://web-api.istioinaction:8080/
```

Let's declare web-api is also added from the sleep service in the default namespace.


## Export-To scope for service producers

As the service owner for the recommendation service, you want to control that web-api service is only available for the istioinaction namespace


Call the recommendation service from the sleep service in the default namespace.


## Virtual service resource merging

Istio supports virtual service resource merging for resources that are not conflicted.

Explain VS merging with httpbin and web-api.

Test endpoint.

## Virtual service resource delegation

Gateway resource in istio-system, and delegate the VS resource to the service's namespace.  for example platform owner owns the gateway resources on which hosts and associated port numbers and TLS configuration but want to delegate the details of the virtual service resources to service owners.


Validate VS delegation working by visit the web-api:


## Next Lab

As you explore your services in Istio, things may not go smoothly.  In the [next lab](08-debugging-config.md), we will explore how to debug your services or Istio resources in your service mesh.

