# use the step certificate tool: 
# https://github.com/smallstep/cli
# https://github.com/smallstep/certificates

STEPPATH="./istio-workshop-ca" step ca init --pki --name "istio-workshop-ca" --provisioner "info@solo.io" --password-file ./pwfile

# store a cert chain file
step certificate bundle ./istio-workshop-ca/certs/intermediate_ca.crt ./istio-workshop-ca/certs/root_ca.crt ./istio-workshop-ca/certs/cert-chain.pem