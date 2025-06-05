#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Pure‐bash launcher that SSHes into ESXi hosts (with only /bin/sh)
# and runs POSIX‐compatible commands to reconfigure the “hermes” NFS datastore.
#
# Requirements on your Mac:
#   • sshpass installed (`brew install hudochenkov/sshpass/sshpass`)
#   • This script saved in UTF-8 so emojis display correctly.
#   • Make executable: chmod +x fix_hermes_nfs.sh
#   • Run: ./fix_hermes_nfs.sh

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# ESXi hosts
hosts=(
  "192.168.1.170"
  "192.168.1.171"
  "192.168.1.100"
  "192.168.1.72"
  "192.168.1.175"
)

username="root"
datastore="hermes"
nas_ip="192.168.1.182"
nas_path="/virtual_machines"

# Prompt silently for ESXi root password
read -s -p "Enter ESXi root password: " password
echo

# Ensure logs directory exists
mkdir -p logs

# ---------------- Phase 1: Verify SSH access ----------------
echo -e "\n${YELLOW}🔍 PHASE 1: Verifying SSH access to all hosts...${RESET}"
for ip in "${hosts[@]}"; do
  echo -e "${YELLOW}🔗 Testing SSH to ${ip}...${RESET}"
  sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o BatchMode=no \
    "$username@$ip" "echo OK" &> /dev/null
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Connected to ${ip}${RESET}"
  else
    echo -e "${RED}❌ Cannot connect to ${ip}. Aborting.${RESET}"
    exit 1
  fi
done
echo -e "${GREEN}✅ All hosts are reachable.${RESET}"
echo "----------------------------------"

# ---------------- Phase 2: Reconfigure NFS ----------------
echo -e "\n${YELLOW}🔧 PHASE 2: Reconfiguring NFS Datastore \"${datastore}\" ========${RESET}"
for ip in "${hosts[@]}"; do
  echo -e "${YELLOW}▶ Processing ${ip}...${RESET}"
  logfile="logs/${ip}.log"

  # Note: unquoted heredoc so $datastore, $nas_ip, $nas_path expand locally.
  sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" sh <<ENDSSH >"$logfile" 2>&1
# Fail fast on any error
set -eu

# If “${datastore}” is already mounted, remove it
if esxcli storage filesystem list | grep -q "${datastore}"; then
  echo "🧹 Removing existing mount..."
  esxcli storage nfs41 remove --volume-name="${datastore}"
  sleep 2
fi

# Add the NFS mount back
echo "➕ Re-adding mount..."
esxcli storage nfs41 add --hosts="${nas_ip}" --share="${nas_path}" --volume-name="${datastore}"

# Verify that “${datastore}” is now present
MOUNT=\$(esxcli storage filesystem list | grep "${datastore}" || echo "")
if [ -z "\$MOUNT" ]; then
  echo "❌ Mount failed"
  exit 1
fi

echo "✅ Mounted: \$MOUNT"
ENDSSH

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully mounted on ${ip}${RESET}"
  else
    echo -e "${RED}❌ Mount failed on ${ip} — see ${logfile}${RESET}"
    exit 1
  fi

  echo -e "${GREEN}📄 Log written to ${logfile}${RESET}"
  echo "---------------------------"
done

echo -e "\n${GREEN}🎉 All hosts completed successfully.${RESET}"
