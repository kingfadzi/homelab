#!/usr/bin/env bash
#
# mount-vm-migration-nfs.sh
# Mount /mnt/vm-migration to aquarius.butterflycluster.com:/Public/vm-migration via NFS.
# Installs nfs-common, creates mountpoint, backs up /etc/fstab, updates fstab, and mounts immediately.
#
# Usage: sudo ./mount-vm-migration-nfs.sh

set -eo pipefail

SERVER="aquarius.butterflycluster.com"
SHARE="/Public/vm-migration"
MOUNTPOINT="/mnt/vm-migration"
FSTAB="/etc/fstab"
FSTAB_BACKUP="/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
REMOTE="${SERVER}:${SHARE}"
FSTAB_OPTS="defaults,_netdev"
FSTAB_ENTRY="${REMOTE}  ${MOUNTPOINT}  nfs  ${FSTAB_OPTS}  0 0"

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

# Install NFS client tools if needed
if ! dpkg -s nfs-common &>/dev/null; then
  echo "Installing nfs-common..."
  apt-get update
  apt-get install -y nfs-common
fi

# Create the mountpoint if it doesn’t exist
if [[ ! -d "$MOUNTPOINT" ]]; then
  echo "Creating mountpoint $MOUNTPOINT..."
  mkdir -p "$MOUNTPOINT"
fi

# Backup /etc/fstab
echo "Backing up $FSTAB to $FSTAB_BACKUP..."
cp "$FSTAB" "$FSTAB_BACKUP"

# Add fstab entry if not already present
if ! grep -Fqs "$REMOTE" "$FSTAB"; then
  echo "Adding NFS mount to $FSTAB:"
  echo "  $FSTAB_ENTRY"
  echo "$FSTAB_ENTRY" >> "$FSTAB"
else
  echo "fstab already contains an entry for $REMOTE, skipping."
fi

# Mount all entries
echo "Mounting all filesystems..."
mount -a

# Verify
if mountpoint -q "$MOUNTPOINT"; then
  echo "SUCCESS: $MOUNTPOINT is now mounted from $REMOTE"
else
  echo "ERROR: Failed to mount $MOUNTPOINT"
  exit 1
fi