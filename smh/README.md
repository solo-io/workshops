# Service Mesh Hub workshop

Service Mesh Hub (smh) is a Kubernetes-native management plane that enables configuration and operational management of multiple heterogeneous service meshes across multiple clusters through a unified API. The Service Mesh Hub API integrates with the leading service meshes and abstracts away differences between their disparate API's, allowing users to configure a set of different service meshes through a single API. Service Mesh Hub is engineered with a focus on its utility as an operational management tool, providing both graphical and command line UIs, observability features, and debugging tools.

The goal of this workshop is to show several unique features of the Service Mesh Hub (smh) in action:

- Mesh Discovery
- Unified Identity / Trust domain
- Access control
- Multi-cluster traffic
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
../scripts/deploy.sh 1
../scripts/deploy.sh 2
../scripts/deploy.sh 3
```

Then run the following commands to wait for all the Pods to be ready:

```bash
../scripts/check.sh 1
../scripts/check.sh 2
../scripts/check.sh 3
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

## Lab 2 : Deploy Service Mesh Hub and register the clusters

First of all, you need to install the *meshctl* CLI:

```bash
curl -sL https://run.solo.io/meshctl/install | sh
export PATH=$HOME/.service-mesh-hub/bin:$PATH
```

Now, you can install Service Mesh Hub on your admin cluster:

```bash
meshctl install
```

Then, you need to register the two other clusters:

```bash
meshctl cluster register \
  --cluster-name kind2 \
  --mgmt-context kind-kind1 \
  --remote-context kind-kind2

meshctl cluster register \
  --cluster-name kind3 \
  --mgmt-context kind-kind1 \
  --remote-context kind-kind3
```

## Lab 3 : Deploy Istio on both clusters

Now let's deploy Istio on the first cluster:

```bash
./istio-1.7.0/bin/istioctl --context kind-kind2 operator init

```bash
cat << EOF | kubectl --context kind-kind2 apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istiocontrolplane-default
  namespace: istio-system
spec:
  profile: default
  addonComponents:
    istiocoredns:
      enabled: true
    grafana:
      enabled: true
    kiali:
      enabled: true
    prometheus:
      enabled: true
    tracing:
      enabled: true
  meshConfig:
    accessLogFile: /dev/stdout
    enableAutoMtls: true
EOF
```

And deploy Istio on the second cluster:

```bash
./istio-1.7.0/bin/istioctl --context kind-kind3 operator init

cat << EOF | kubectl --context kind-kind3 apply -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istiocontrolplane-default
  namespace: istio-system
spec:
  profile: default
  addonComponents:
    istiocoredns:
      enabled: true
    grafana:
      enabled: true
    kiali:
      enabled: true
    prometheus:
      enabled: true
    tracing:
      enabled: true
  meshConfig:
    accessLogFile: /dev/stdout
    enableAutoMtls: true
EOF
```

<!--bash
until kubectl --context kind-kind2 get ns istio-system
do
  sleep 1
done

until [ $(kubectl --context kind-kind2 -n istio-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep true -c) -eq 8 ]; do
  echo "Waiting for all the Istio pods to become ready"
  sleep 1
done

until kubectl --context kind-kind3 get ns istio-system
do
  sleep 1
done

until [ $(kubectl --context kind-kind3 -n istio-system get pods -o jsonpath='{range .items[*].status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep true -c) -eq 8 ]; do
  echo "Waiting for all the Istio pods to become ready"
  sleep 1
done
-->

Run the following command until all the Istio Pods are ready:

```
kubectl --context kind-kind2 get pods -n istio-system
```

When it's case, you should get this output:

```
NAME                                    READY   STATUS    RESTARTS   AGE
grafana-7d7f48894b-7gl6d                1/1     Running   0          84s
istio-ingressgateway-658c5c4489-kq8hl   1/1     Running   0          88s
istio-tracing-68b5cc6685-9wdlz          1/1     Running   0          84s
istiocoredns-685b5c449f-wk4l5           2/2     Running   0          84s
istiod-6f5fd7cb8f-mvwbk                 1/1     Running   0          98s
kiali-64f76f6c9b-bzkls                  1/1     Running   0          84s
prometheus-5bcb77c949-zjl9d             1/1     Running   0          83s
```

Check the status on the second cluster using `kubectl --context kind-kind3 get pods -n istio-system`

## Lab 4 : Create the Virtual Mesh

Service Mesh Hub can help unify the root identity between multiple service mesh installations so any intermediates are signed by the same Root CA and end-to-end mTLS between clusters and services can be established correctly.

Run the following command to create the *Virtual Mesh*:

```bash
cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha2
kind: VirtualMesh
metadata:
  name: virtual-mesh
  namespace: service-mesh-hub
spec:
  mtlsConfig:
    autoRestartPods: true
    shared:
      rootCertificateAuthority:
        generated: null
  federation: {}
  meshes:
  - name: istiod-istio-system-kind2
    namespace: service-mesh-hub
  - name: istiod-istio-system-kind3
    namespace: service-mesh-hub
EOF
```










kubectl --context kind-kind2 label namespace default istio-injection=enabled
#kubectl --context kind-kind2 apply -f https://raw.githubusercontent.com/istio/istio/1.6.7/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl --context kind-kind2 apply -f https://raw.githubusercontent.com/istio/istio/1.6.7/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)'
kubectl --context kind-kind2 apply -f https://raw.githubusercontent.com/istio/istio/1.6.7/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'
kubectl --context kind-kind2 apply -f https://raw.githubusercontent.com/istio/istio/1.6.7/samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl --context kind-kind3 label namespace default istio-injection=enabled
kubectl --context kind-kind3 apply -f https://raw.githubusercontent.com/istio/istio/1.6.7/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl --context kind-kind3 apply -f https://raw.githubusercontent.com/istio/istio/1.6.7/samples/bookinfo/networking/bookinfo-gateway.yaml

```bash
cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha2
kind: VirtualMesh
metadata:
  name: virtual-mesh
  namespace: service-mesh-hub
spec:
  mtlsConfig:
    autoRestartPods: true
    shared:
      rootCertificateAuthority:
        generated: null
  federation: {}
  globalAccessPolicy: ENABLED
  meshes:
  - name: istiod-istio-system-kind2
    namespace: service-mesh-hub
  - name: istiod-istio-system-kind3
    namespace: service-mesh-hub
EOF
```

kubectl --context kind-kind2 apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF

# Verify TLS (before and after)

kubectl --context kind-kind3 apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha1
kind: VirtualMesh
metadata:
  name: virtual-mesh
  namespace: service-mesh-hub
spec:
  displayName: "Demo Mesh Federation"
  certificateAuthority:
    builtin:
      ttlDays: 356
      rsaKeySizeBytes: 4096
      orgName: "service-mesh-hub"
  federation:
    mode: PERMISSIVE
  shared: {}
  enforceAccessControl: ENABLED
  meshes:
  - name: istio-istio-system-management-plane
    namespace: service-mesh-hub
  - name: istio-istio-system-new-remote-cluster
    namespace: service-mesh-hub
EOF

sleep 15

kubectl --context kind-kind1 get virtualmeshcertificatesigningrequest -n service-mesh-hub

until kubectl --context kind-kind1 get secret -n istio-system cacerts
do
  sleep 1
done

until kubectl --context kind-kind2 get secret -n istio-system cacerts
do
  sleep 1
done

kubectl --context kind-kind1 get serviceentry -n istio-system
kubectl --context kind-kind2 get serviceentry -n istio-system

until meshctl check
do
  sleep 1
done

kubectl --context kind-kind2 apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "productpage-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - to:
    - operation:
        methods: ["GET"]
EOF

kubectl --context kind-kind3 apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "productpage-viewer"
  namespace: default
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - to:
    - operation:
        methods: ["GET"]
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha2
kind: AccessPolicy
metadata:
  namespace: service-mesh-hub
  name: productpage
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: bookinfo-productpage
          namespace: default
          clusterName: kind2
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha2
kind: AccessPolicy
metadata:
  namespace: service-mesh-hub
  name: reviews
spec:
  sourceSelector:
  - kubeServiceAccountRefs:
      serviceAccounts:
        - name: bookinfo-reviews
          namespace: default
          clusterName: kind2
  destinationSelector:
  - kubeServiceMatcher:
      namespaces:
      - default
      labels:
        service: ratings


apiVersion: networking.smh.solo.io/v1alpha1
kind: AccessControlPolicy
metadata:
  namespace: service-mesh-hub
  name: reviews
spec:
  sourceSelector:
    serviceAccountRefs:
      serviceAccounts:
        - name: bookinfo-reviews
          namespace: default
          cluster: remote-cluster
  destinationSelector:
    matcher:
      namespaces:
        - default
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha1
kind: AccessControlPolicy
metadata:
  namespace: service-mesh-hub
  name: reviews
spec:
  sourceSelector:
    serviceAccountRefs:
      serviceAccounts:
        - name: bookinfo-reviews
          namespace: default
          cluster: management-plane
  destinationSelector:
    matcher:
      namespaces:
        - default
      labels:
        service: ratings
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha1
kind: TrafficPolicy
metadata:
  namespace: service-mesh-hub
  name: local-reviews
spec:
  destinationSelector:
    serviceRefs:
      services:
        - cluster: management-plane
          name: reviews
          namespace: default
  trafficShift:
    destinations:
      - destination:
          cluster: management-plane
          name: reviews
          namespace: default
        weight: 50
      - destination:
          cluster: new-remote-cluster
          name: reviews
          namespace: default
        weight: 50
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha1
kind: TrafficPolicy
metadata:
  namespace: service-mesh-hub
  name: remote-reviews
spec:
  outlierDetection:
    consecutiveErrors: 3
    interval: 60s
    baseEjectionTime: 3m
  destinationSelector:
    serviceRefs:
      services:
        - cluster: new-remote-cluster
          name: reviews
          namespace: default
EOF

#spec:
#  requestTimeout: 2s
# Doesn't work when kind2 is down
# outlierDetection:
#    consecutiveErrors: 3
# Doesn't work either

kubectl --context kind-kind1 -n istio-system delete pod -l app=istiod
kubectl --context kind-kind2 -n istio-system delete pod -l app=istiod

kubectl --context kind-kind1 delete po --all
kubectl --context kind-kind2 delete po --all

kubectl --context kind-kind1 -n istio-system delete pod -l app=istio-ingressgateway
kubectl --context kind-kind2 -n istio-system delete pod -l app=istio-ingressgateway

#kubectl --context kind-kind1 -n istio-system delete pod -l app=prometheus
#kubectl --context kind-kind2 -n istio-system delete pod -l app=prometheus

#kubectl --context kind-kind1 -n istio-system delete po --all
#kubectl --context kind-kind2 -n istio-system delete po --all

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: istio-system
  labels:
    app: istiocoredns
    release: istio
data:
  Corefile: |
    management-plane {
             grpc . 127.0.0.1:8053
          }
    new-remote-cluster {
             grpc . 127.0.0.1:8053
          }
    .:53 {
          errors
          health
          grpc global 127.0.0.1:8053
          forward . /etc/resolv.conf {
            except global
          }
          prometheus :9153
          cache 30
          reload
        }
EOF

cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    management-plane:53 {
        errors
        cache 30
        forward . $(kubectl --context kind-kind1 get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}):53
    }
    new-remote-cluster:53 {
        errors
        cache 30
        forward . $(kubectl --context kind-kind1 get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}):53
    }
    global:53 {
        errors
        cache 30
        forward . $(kubectl --context kind-kind1 get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}):53
    }
EOF

cat << EOF | kubectl --context kind-kind2 apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: istio-system
  labels:
    app: istiocoredns
    release: istio
data:
  Corefile: |
    management-plane {
             grpc . 127.0.0.1:8053
          }
    new-remote-cluster {
             grpc . 127.0.0.1:8053
          }
    .:53 {
          errors
          health
          grpc global 127.0.0.1:8053
          forward . /etc/resolv.conf {
            except global
          }
          prometheus :9153
          cache 30
          reload
        }
EOF

cat << EOF | kubectl --context kind-kind2 apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    management-plane:53 {
        errors
        cache 30
        forward . $(kubectl --context kind-kind2 get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}):53
    }
    new-remote-cluster:53 {
        errors
        cache 30
        forward . $(kubectl --context kind-kind2 get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}):53
    }
    global:53 {
        errors
        cache 30
        forward . $(kubectl --context kind-kind2 get svc -n istio-system istiocoredns -o jsonpath={.spec.clusterIP}):53
    }
EOF

while true; do 
  curl -s -o /dev/null -w '%{response_code}\t%{time_starttransfer}\n' http://172.18.0.210/productpage
  sleep 1
done

cat << EOF # | kubectl --context kind-kind2 delete -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

# k --context kind-kind2 scale deployment -n istio-system istio-ingressgateway --replicas=0






exit

kubectl --context kind-kind1 apply -f - <<EOF
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: STRICT
EOF


cat << EOF | kubectl --context kind-kind1 apply -f -
apiVersion: networking.smh.solo.io/v1alpha1
kind: AccessControlPolicy
metadata:
  namespace: service-mesh-hub
  name: bash
spec:
  sourceSelector:
    serviceAccountRefs:
      serviceAccounts:
        - name: default
          namespace: default
          cluster: management-plane
  destinationSelector:
    matcher:
      namespaces:
        - default
EOF