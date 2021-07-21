# Gloo Platform POC

This document will guide you through a Proof of Concept / Proof of Value of the Gloo Platform solving multi-cluster traffic challenges around security and failover.

The POC will include components Gloo Edge Gateway, Istio service mesh, and Gloo Mesh assuming a multi-cluster set up consisting of two Kubernetes clusters. These two clusters should be connected with network connectivity, but they should be in their own networks \(ie, overlapping CIDR range for Pod IPs is fine\) and traffic between the clusters will be bridged with Istio gateways.

## Success Criteria

* Services will use a global name to communicate with each other
* All traffic within the mesh will be secured with mTLS
* Ingress traffic will failover to a different cluster if local service is not available
* Service to service traffic will failover to a different cluster if local service is not available
* Passive health checking will be used for circuit breaking
* Service to service access policy will be deny all by default
* Fine-grained service-to-service access policies will enable traffic as needed

## Lab environment and prep

We will be using the following products to prove the success criteria:

* [Gloo Mesh \(Istio\)](https://docs.solo.io/gloo-mesh/latest/setup/gloo_mesh_istio/)
* [Gloo Mesh Management Plane](https://docs.solo.io/gloo-mesh/latest/getting_started/)
* [Gloo Edge](https://docs.solo.io/gloo-edge/latest/) with [Federation](https://docs.solo.io/gloo-edge/latest/guides/gloo_federation/)

Let's see what each product will do for the POC:

### Gloo Mesh Istio

We will use Istio for service-to-service traffic needs including global naming DNS resolution, enforcing access policies, and failing over to remote clusters.

Istio will also be set up in a multi-primary "federated mode" which is different from the multi-cluster approach taken in the community. The reason we use federation instead of the multi-cluster approach described in the community is for security and separated failure domains to achieve the highest level of availability.

We will use Gloo Mesh Management plane to coordinate this federation.

### Gloo Mesh Management Plane

We will use the Gloo Mesh Management plane to simplify multi-cluster operations \(Istio doesn't have a multi-cluster API\) as well as to implement multi-primary federation. We will see in this POC how Gloo Mesh significantly simplifies operating Istio for these success criteria.

### Gloo Edge with Federation

We will use Gloo Edge as an optional component for Ingress and failover between clusters at the edge. Gloo Edge can be used to add OIDC, WAF, rate limiting, request transformation and other edge capabilities not available in the Istio ingress. Gloo Edge also has a federation mode that will be used for failover.

{% hint style="info" %}
Although Gloo Edge is optional for this POC, most organizations we work with desire this enhanced edge capability. Also note that when Gloo Mesh Gateway will be released it will include this capability natively in the Istio mesh, so we will update the instructions accordingly.
{% endhint %}

## Set up Kubernetes clusters for the POC

You will need two Kubernetes clusters for this workshop. See how to set up an environment using these platform-specific guides:

* [GKE](section0/gke.md)
* [EKS](section0/eks.md)
* [AKS](section0/aks.md)
* [OpenShift](section0/openshift.md)
* [Kind](section0/kind.md)

## Running the POC

The POC is conducted in three separate sections:

1. Set up Istio, Gloo Mesh, Gloo Edge 
2. Set up sample applications across both clusters
3. Test out specific scenarios as outlined in the success criteria section

### POC Section 1: Set up Istio, Gloo Mesh, Gloo Edge

In this section, we'll install all of the components needed to run this POC. We will install Istio, Gloo Mesh Management Plane, and Gloo Edge with Federation.

### POC Section 2: Set up and configure sample applications

In this section we will install the sample applications that will be used to exercise the various success criteria. The sample apps will be simple enough to understand but have enough complex communication scenarios that we can adequately cover enterprise usecases.

### POC Section 3: Test specific scenarios

In this section we cover the scenarios outlined earlier. The usecases are intended to be run in order as they build on the previous use case \(ie, when we enable security/access policy, the subsequent use cases will use configuration with those policies in mind\).

## Where to get help?

We usually run these POCs as part of working directly with a prospect. You can [reach out to our expert team](https://www.solo.io/company/contact/) to help guide you on this POC including [working directly in Slack](https://slack.solo.io) for real-time support and assistance.

## Next steps

From here, you should [set up a Kuberentes environment](section0/) that best suits you and then start [deploying the components](section1/) that will comprise the solution.

