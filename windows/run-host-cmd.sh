#!/usr/bin/env bash
set -euo pipefail

# global IMAGE, defaulting to almalinux:8 but override with HOST_RUNNER_IMAGE
IMAGE="${HOST_RUNNER_IMAGE:-almalinux:8}"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <command> [args...]"
  exit 1
fi

# join all args into one string, then escape any single-quotes for safe embedding
COMMAND="$*"
escaped=${COMMAND//\'/\'\"\'\"\'}  # turns ' into '\''

# build the chroot call so that the inner bash -c gets the entire command as one string
SCRIPT="chroot /host /bin/bash -c '$escaped'"

docker run --rm -it \
  --privileged \
  --pid=host \
  -v /:/host:rw \
  "$IMAGE" \
  bash -c "$SCRIPT"
