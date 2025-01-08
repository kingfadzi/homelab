#!/bin/bash
set -e

IMAGE_NAME="dev-environment"
CONTAINER_NAME="dev-environment"

usage() {
  echo "Usage: $0 [POSTGRES_DATA_DIR [POSTGRES_BACKUPS_DIR]]"
  echo "Example: $0 /home/user/pgdata /home/user/pgbackups"
  echo "Defaults to ./postgres_data and ./postgres_backups if not provided."
  exit 1
}

if [ $# -gt 2 ]; then
  echo "Too many arguments."
  usage
fi

HOST_POSTGRES_DATA_DIR="${1:-$(pwd)/postgres_data}"
HOST_POSTGRES_BACKUPS_DIR="${2:-$(pwd)/postgres_backups}"

CONTAINER_POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
CONTAINER_POSTGRES_BACKUPS_DIR="/mnt/pgdb_backups"

echo "Using host Postgres data dir: $HOST_POSTGRES_DATA_DIR"
echo "Using host Postgres backups dir: $HOST_POSTGRES_BACKUPS_DIR"

# 1) FAIL if data dir doesn't exist
if [ ! -d "$HOST_POSTGRES_DATA_DIR" ]; then
  echo "ERROR: Directory '$HOST_POSTGRES_DATA_DIR' not found or is not a directory."
  echo "Please create it first or specify a valid path."
  exit 1
fi

# 2) FAIL if backups dir doesn't exist
if [ ! -d "$HOST_POSTGRES_BACKUPS_DIR" ]; then
  echo "ERROR: Directory '$HOST_POSTGRES_BACKUPS_DIR' not found or is not a directory."
  echo "Please create it first or specify a valid path."
  exit 1
fi

docker build -t "$IMAGE_NAME" .

docker run -d \
  --name "$CONTAINER_NAME" \
  -p 5432:5432 \
  -p 6379:6379 \
  -p 3000:3000 \
  -p 3010:3010 \
  -p 8099:8099 \
  -p 8088:8088 \
  -v "$HOST_POSTGRES_DATA_DIR":"$CONTAINER_POSTGRES_DATA_DIR" \
  -v "$HOST_POSTGRES_BACKUPS_DIR":"$CONTAINER_POSTGRES_BACKUPS_DIR" \
  "$IMAGE_NAME" \
  tail -f /dev/null

echo "Container '$CONTAINER_NAME' started with volumes mounted."
