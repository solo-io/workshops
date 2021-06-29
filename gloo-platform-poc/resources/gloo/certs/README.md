If keys get mangled somehow, just run this on your local machine:

generate-ca
generate-cert-for edge-west
generate-cert-for edge-east
generate-cert-for edge-europe

Then run the following to create the certs:


## WEST
glooctl create secret tls --name edge-west-failover --certchain ./gloo/certs/edge-west.crt --privatekey ./gloo/certs/keys/edge-west.key --rootca ./gloo/certs/root-ca.crt 
kubectl -n gloo-system get secret edge-west-failover -o yaml | kubectl neat | sed 's/edge-west-failover/failover-downstream/' | kubectl neat > ./gloo/certs/secrets/edge-west-failover-upstream.yaml

kubectl -n gloo-system get secret edge-west-failover -o yaml | kubectl neat | sed 's/edge-west-failover/failover-upstream/' | kubectl neat > ./gloo/certs/secrets/edge-west-failover-upstream.yaml





## EAST
glooctl create secret tls --name edge-east-failover --certchain ./gloo/certs/edge-east.crt --privatekey ./gloo/certs/keys/edge-east.key --rootca ./gloo/certs/root-ca.crt 

kubectl -n gloo-system get secret edge-east-failover -o yaml| sed 's/edge-east-failover/failover-upstream/'  | kubectl neat > ./gloo/certs/secrets/edge-east-failover-upstream.yaml

kubectl -n gloo-system get secret edge-east-failover -o yaml | sed 's/edge-east-failover/failover-downstream/' | kubectl neat > ./gloo/certs/secrets/edge-east-failover-downstream.yaml


## EUROPE
glooctl create secret tls --name edge-europe-failover --certchain ./gloo/certs/edge-europe.crt --privatekey ./gloo/certs/keys/edge-europe.key --rootca ./gloo/certs/root-ca.crt 

kubectl -n gloo-system get secret edge-europe-failover -o yaml| sed 's/edge-europe-failover/failover-upstream/'  | kubectl neat > ./gloo/certs/secrets/edge-europe-failover-upstream.yaml


kubectl -n gloo-system get secret edge-europe-failover -o yaml| sed 's/edge-europe-failover/failover-downstream/'  | kubectl neat > ./gloo/certs/secrets/edge-europe-failover-downstream.yaml