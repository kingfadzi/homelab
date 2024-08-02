#!/bin/bash

# Check if the project path is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <project-path>"
  exit 1
fi

PROJECT_PATH=$1

# Step 1: Decode the Base64 Encoded JWT Token in token.txt
JWT_TOKEN=$(cat token.txt | base64 --decode)
echo "Decoded JWT Token: $JWT_TOKEN"

# Save the decoded JWT token to a file for further use
echo $JWT_TOKEN > jwt.token

# Decode and format JWT payload
JWT_PAYLOAD=$(echo "$JWT_TOKEN" | cut -d '.' -f2 | base64 --decode | jq .)
echo "JWT Payload: $JWT_PAYLOAD"

# Extract the `aud` claim from JWT payload
AUD_CLAIM=$(echo "$JWT_PAYLOAD" | jq -r .aud)
echo "aud claim: $AUD_CLAIM"

# Step 2: Prepare the Authentication Request
cat <<EOF > auth_payload.json
{
  "role": "gitlab-ci",
  "jwt": "$(cat jwt.token)"
}
EOF

# Step 3: Send the Authentication Request to Vault
VAULT_ADDR="https://phobos.butterflycluster.com:8200"

AUTH_RESPONSE=$(curl -k -s --request POST --data @auth_payload.json "$VAULT_ADDR/v1/auth/jwt/login")
echo "Auth Response: $AUTH_RESPONSE"

# Extract the Vault token from the response
VAULT_TOKEN=$(echo $AUTH_RESPONSE | jq -r .auth.client_token)

# Check if the Vault token was obtained successfully
if [ -z "$VAULT_TOKEN" ]; then
  echo "Failed to obtain Vault token"
  exit 1
fi

# Step 4: Use the Vault Token to Retrieve Secrets
VAULT_PATH="secret/data/projects/$PROJECT_PATH"

SECRETS_RESPONSE=$(curl -k -s --header "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/$VAULT_PATH")
echo "Secrets Response: $SECRETS_RESPONSE"
