#!/bin/bash
set -eo pipefail

# RHEL WSL Cleanup Script (No wsl.exe Commands)
# Purpose: Clean a RHEL-based WSL instance to reclaim space before exporting it.
# This operation removes caches and temporary files while preserving settings:
#  - User cache directories (.cache, .npm, .m2, etc.) will be deleted.
#  - System caches, logs, and temporary files will be removed.
#  - Journal logs will be limited to 50MB.
#  - PostgreSQL databases will be vacuumed to reclaim space.
#  - Docker resources (images, containers, etc.) will be pruned.
#  - User configs and SSH keys are preserved.
#
# Usage: ./wsl_cleanup.sh

# Clean only cache directories, preserve configs and settings
echo "Cleaning cache directories from $HOME..."
rm -rf "$HOME/.cache" "$HOME/.npm" "$HOME/.m2" "$HOME/.gradle" \
       "$HOME/.ivy2" "$HOME/.nuget" "$HOME/.local/share/Trash" 2>/dev/null || true

# System cleanup for RHEL
echo "Starting system cleanup..."
sudo dnf autoremove -y
sudo dnf clean all
sudo dnf clean packages
sudo dnf clean metadata
sudo dnf clean dbcache
sudo rm -rf /var/cache/dnf/*
sudo rm -rf /tmp/* /var/tmp/*
# Limit journal logs to 50MB instead of deleting all
sudo journalctl --vacuum-size=50M 2>/dev/null || true
sudo rm -rf /var/log/*.log /var/log/dnf

# PostgreSQL vacuum
echo "Vacuuming PostgreSQL databases..."
if command -v vacuumdb >/dev/null 2>&1; then
    sudo -u postgres vacuumdb --all --analyze
else
    echo "vacuumdb not found. Skipping PostgreSQL vacuum."
fi

# Docker cleanup (if Docker is used within WSL)
echo "Cleaning Docker resources..."
docker system prune --all --force || true
docker image prune --force 2>/dev/null || true

if [ "$(docker ps -aq)" ]; then
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
fi

echo "Cleanup complete!"