# use the step certificate tool: 
# https://github.com/smallstep/cli
# https://github.com/smallstep/certificates

step certificate create istioinaction.io istioinaction.io.crt istioinaction.io.key --profile self-signed --subtle --no-password --kty RSA --insecure --not-after="87600h"