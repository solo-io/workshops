# use the step certificate tool: 
# https://github.com/smallstep/cli
# https://github.com/smallstep/certificates

rm -fr ./ca
mkdir ./ca
step certificate create istio-workshop-ca ./ca/root-ca.crt ./ca/root-ca.key --profile root-ca --subtle --no-password --kty RSA --insecure --not-after="87600h"

#STEPPATH="./istio-workshop-ca" step ca init --pki --name "istio-workshop-ca" --provisioner "info@solo.io" --password-file ./pwfile

# store a cert chain file
#step certificate bundle ./istio-workshop-ca/certs/intermediate_ca.crt ./istio-workshop-ca/certs/root_ca.crt ./istio-workshop-ca/certs/cert-chain.pem