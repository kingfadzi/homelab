#!/bin/sh

# Fail the script if any command fails
set -e

# Ensure VAULT_ADDR and VAULT_TOKEN are set
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
  echo "VAULT_ADDR and VAULT_TOKEN must be set"
  exit 1
fi

# Ensure the project path is set
if [ -z "$PROJECT_PATH" ]; then
  echo "PROJECT_PATH must be set"
  exit 1
fi

# Fetch secrets from Vault
secrets=$(vault kv get -format=json secret/data/projects/$PROJECT_PATH | jq -r '.data.data')

# Export secrets as environment variables
for key in $(echo $secrets | jq -r 'keys[]'); do
  value=$(echo $secrets | jq -r --arg key "$key" '.[$key]')
  export "$key=$value"
  echo "Exported $key"
done

# Execute the passed command
exec "$@"
