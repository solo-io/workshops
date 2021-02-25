# use the step certificate tool: 
# https://github.com/smallstep/cli
# https://github.com/smallstep/certificates

# generate self-signed
# step certificate create istioinaction.io istioinaction.io.crt istioinaction.io.key --profile self-signed --subtle --no-password --kty RSA --insecure --not-after="87600h"

# create signed by CA
# pw is `abc123` from the pwfile in this folder
#step certificate create istioinaction.io istioinaction.io.crt istioinaction.io.key --profile leaf --subtle --no-password --kty RSA --insecure --not-after="87600h" --ca ./istio-workshop-ca/certs/intermediate_ca.crt --ca-key ./istio-workshop-ca/secrets/intermediate_ca_key


# create signed by CA no pw
step certificate create istioinaction.io istioinaction.io.crt istioinaction.io.key --profile leaf --subtle --no-password --kty RSA --insecure --not-after="87600h" --ca ./ca/root-ca.crt --ca-key ./ca/root-ca.key

