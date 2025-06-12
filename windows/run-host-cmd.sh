#!/usr/bin/env bash
set -euo pipefail

# Use HOST_RUNNER_IMAGE env var if set, otherwise fall back to almalinux:8
IMAGE="${HOST_RUNNER_IMAGE:-almalinux:8}"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <command> [args...]"
  exit 1
fi

docker run --rm -it \
  --privileged \
  --pid=host \
  -v /:/host:rw \
  "$IMAGE" \
  bash -c 'chroot /host /bin/bash -c "$@"' dummy "$@"
