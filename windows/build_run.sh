#!/bin/bash
set -e

IMAGE_NAME="dev-environment"
CONTAINER_NAME="dev-environment"

usage() {
  echo "Usage: $0 <POSTGRES_DATA_DIR> <POSTGRES_BACKUPS_DIR>"
  echo "Example: $0 /home/user/pgdata /home/user/pgbackups"
  echo "Both arguments are required, and the specified directories must already exist."
  exit 1
}

# Require exactly 2 arguments
if [ $# -ne 2 ]; then
  echo "ERROR: You must specify exactly two directories (data + backups)."
  usage
fi

HOST_POSTGRES_DATA_DIR="$1"
HOST_POSTGRES_BACKUPS_DIR="$2"

CONTAINER_POSTGRES_DATA_DIR="/var/lib/pgsql/13/data"
CONTAINER_POSTGRES_BACKUPS_DIR="/mnt/pgdb_backups"

echo "Using host Postgres data dir: $HOST_POSTGRES_DATA_DIR"
echo "Using host Postgres backups dir: $HOST_POSTGRES_BACKUPS_DIR"

# Fail if the data dir doesn't exist
if [ ! -d "$HOST_POSTGRES_DATA_DIR" ]; then
  echo "ERROR: Directory '$HOST_POSTGRES_DATA_DIR' does not exist."
  usage
fi

# Fail if the backups dir doesn't exist
if [ ! -d "$HOST_POSTGRES_BACKUPS_DIR" ]; then
  echo "ERROR: Directory '$HOST_POSTGRES_BACKUPS_DIR' does not exist."
  usage
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
