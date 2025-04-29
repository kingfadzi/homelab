#!/bin/bash

set -e

# Check GITLAB_API_TOKEN
if [[ -z "$GITLAB_API_TOKEN" ]]; then
  echo "❌ ERROR: GITLAB_API_TOKEN environment variable is not set."
  echo "➡️  Please export it before running this script:"
  echo "    export GITLAB_API_TOKEN=your-token"
  exit 1
fi

GITLAB_URL="https://eros.butterflycluster.com"
CONFIG_FILE="${1:-migrate_config.yaml}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ ERROR: Config file '$CONFIG_FILE' not found."
  echo "➡️  Usage: ./migrate_repos.sh path/to/config.yaml"
  exit 1
fi

# Requires yq and jq
if ! command -v yq &> /dev/null || ! command -v jq &> /dev/null; then
  echo "❌ ERROR: 'yq' and 'jq' are required but not installed."
  echo "➡️  Install with: pip install yq OR brew install yq; also install jq"
  exit 1
fi

# URL encoding function
urlencode() {
  local raw="$1"
  local encoded=""
  local length=${#raw}
  for (( i = 0; i < length; i++ )); do
    local c="${raw:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      *) encoded+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  echo "$encoded"
}

group_count=$(yq 'length' "$CONFIG_FILE")

for (( group_idx = 0; group_idx < group_count; group_idx++ )); do
  TARGET_GROUP_ID=$(yq ".[$group_idx].target_group_id" "$CONFIG_FILE")
  PROJECT_COUNT=$(yq ".[$group_idx].projects | length" "$CONFIG_FILE")

  if [[ -z "$TARGET_GROUP_ID" ]]; then
    echo "⚠️  WARNING: Missing target_group_id at block index $group_idx. Skipping."
    continue
  fi

  for (( proj_idx = 0; proj_idx < PROJECT_COUNT; proj_idx++ )); do
    PROJECT=$(yq ".[$group_idx].projects[$proj_idx]" "$CONFIG_FILE")

    if [[ -z "$PROJECT" ]]; then
      echo "⚠️  WARNING: Missing project at block $group_idx index $proj_idx. Skipping."
      continue
    fi

    ENCODED_PROJECT=$(urlencode "$PROJECT")

    PROJECT_ID=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
      "$GITLAB_URL/api/v4/projects/$ENCODED_PROJECT" | jq '.id')

    if [[ "$PROJECT_ID" == "null" || -z "$PROJECT_ID" ]]; then
      echo "⚠️  WARNING: Could not find project ID for '$PROJECT'. Skipping."
      continue
    fi

    echo "➡️  Transferring '$PROJECT' (ID: $PROJECT_ID) to group $TARGET_GROUP_ID"

    curl --request PUT \
      --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
      "$GITLAB_URL/api/v4/projects/$PROJECT_ID/transfer" \
      --form "namespace=$TARGET_GROUP_ID"

    echo "✅ Done with '$PROJECT'."
  done
done
