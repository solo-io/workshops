# Section 2: Set Up Sample apps

We will be using sample apps based on [fakeservice](https://github.com/nicholasjackson/fake-service) and Istio's [sleep sample](https://github.com/istio/istio/tree/master/samples/sleep)

The flow of the calls is similar to the following:

Ingress --&gt; Web-API --&gt; Recommendation --&gt; Purchase History

for Ingress it could be Istio ingress gateway or it could be Gloo Edge Gateway, just depending on what's needed for the edge.

