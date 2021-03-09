# Lab 2 :: Installing Istio

## Bonus: Digging into the Istio sidecar proxy

In the previous lab we saw an introduction to the Envoy proxy data plane. In Istio, we deploy a sidecar proxy next to each workload to enhance the capabilities of the application network. When a service gets called, or makes a call, all traffic is routed to the sidecar Envoy proxy first. How can we be certain that's the case?



To update the security configuration of the sidecar container, run the following command from the cli:

```
kubectl edit deploy/httpbin -n default
```

> :warning: You should edit the resource in place; we've seen instances where saving to a file and trying to apply doesn't actually apply the changes. 

Update the sidecar container to have security context like this:

```
      containers:
      - name: istio-proxy 
        image: docker.io/istio/proxyv2:1.8.3       
        securityContext:
          allowPrivilegeEscalation: true
          privileged: true
        
```

Specifically the `allowPrivilegeEscalation` and `privileged` fields change to true. Once you save this change, we should see a new `httpbin` pod with updated security privilege and we can explore some of the `iptables` rules that redirect traffic. 

> :eyes: Double check the changes you made actually got applied if you the following steps do not work. 

```
kubectl -n default exec -it deploy/httpbin -c istio-proxy -- sudo iptables -L -t nat
```

We should see an output similar to:

```
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
ISTIO_INBOUND  tcp  --  anywhere             anywhere            

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         
ISTIO_OUTPUT  tcp  --  anywhere             anywhere            

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain ISTIO_INBOUND (1 references)
target     prot opt source               destination         
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15008
RETURN     tcp  --  anywhere             anywhere             tcp dpt:22
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15090
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15021
RETURN     tcp  --  anywhere             anywhere             tcp dpt:15020
ISTIO_IN_REDIRECT  tcp  --  anywhere             anywhere            

Chain ISTIO_IN_REDIRECT (3 references)
target     prot opt source               destination         
REDIRECT   tcp  --  anywhere             anywhere             redir ports 15006

Chain ISTIO_OUTPUT (1 references)
target     prot opt source               destination         
RETURN     all  --  127.0.0.6            anywhere            
ISTIO_IN_REDIRECT  all  --  anywhere            !localhost            owner UID match istio-proxy
RETURN     all  --  anywhere             anywhere             ! owner UID match istio-proxy
RETURN     all  --  anywhere             anywhere             owner UID match istio-proxy
ISTIO_IN_REDIRECT  all  --  anywhere            !localhost            owner GID match istio-proxy
RETURN     all  --  anywhere             anywhere             ! owner GID match istio-proxy
RETURN     all  --  anywhere             anywhere             owner GID match istio-proxy
RETURN     all  --  anywhere             localhost           
ISTIO_REDIRECT  all  --  anywhere             anywhere            

Chain ISTIO_REDIRECT (1 references)
target     prot opt source               destination         
REDIRECT   tcp  --  anywhere             anywhere             redir ports 15001
```

We can see here iptables is used to redirect incoming and outgoing traffic to Istio's data plane proxy. Incoming traffic goes to port `15006` of the Istio proxy while outgoing traffic will go through `15001`. If we check the Envoy listeners for those ports, we can see exactly how the traffic gets handled.


## Next Lab

In the [next lab](03-observability.md), we will leverage Istio's telemetry collection and scrap it into Prometheus, Grafana, and Kiali. Istio ships with some sample addons to install those components in a POC environment, but we'll look at a more realistic environment.                   
