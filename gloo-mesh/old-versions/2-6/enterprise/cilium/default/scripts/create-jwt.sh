#!/bin/bash

if ! command -v openssl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Both openssl and jq are required to run this script."
    exit 1
fi

PRIVATE_KEY_PATH=$1
SUBJECT=$2
TEAM=$3
LLM=$4
MODEL=$5

if [ -z "$PRIVATE_KEY_PATH" ] || [ -z "$SUBJECT" ] || [ -z "$TEAM" ] || [ -z "$LLM" ] || [ -z "$MODEL" ]; then
    echo "Usage: $0 <private_key_path> <subject> <team> <llm> <model>"
    exit 1
fi


if [[ "$LLM" != "openai" && "$LLM" != "mistralai" ]]; then
    echo "LLM must be either 'openai' or 'mistralai'."
    exit 1
fi

HEADER='{"alg":"RS256","typ":"JWT"}'
PAYLOAD=$(jq -n --arg sub "$SUBJECT" --arg team "$TEAM" --arg llm "$LLM" --arg model "$MODEL" \
'{
  "iss": "solo.io",
  "org": "solo.io",
  "sub": $sub,
  "team": $team,
  "llms": {
    ($llm): [$model]
  }
}')

# Encode Base64URL function
base64url_encode() {
    openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

# Create JWT Header
HEADER_BASE64=$(echo -n $HEADER | base64url_encode)

# Create JWT Payload
PAYLOAD_BASE64=$(echo -n $PAYLOAD | base64url_encode)

# Create JWT Signature
SIGNING_INPUT="${HEADER_BASE64}.${PAYLOAD_BASE64}"
SIGNATURE=$(echo -n $SIGNING_INPUT | openssl dgst -sha256 -sign $PRIVATE_KEY_PATH | base64url_encode)

# Combine all parts to get the final JWT token
JWT_TOKEN="${SIGNING_INPUT}.${SIGNATURE}"

# Output the JWT token
echo $JWT_TOKEN
