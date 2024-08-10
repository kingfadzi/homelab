
---

# Change DNS Settings on Ubuntu 22.04

This guide provides concise instructions on how to update DNS settings using NetworkManager's command-line tool, `nmcli`.

## Requirements

- Ubuntu 22.04
- NetworkManager

## Instructions

1. **Identify the Connection Name**
   ```bash
   nmcli con show
   ```

2. **Set the DNS Server**
   Replace `YourConnectionName` with the name of your network connection (e.g., 'Wired connection 1').
   ```bash
   nmcli con mod "Wired connection 1" ipv4.dns "192.168.1.253"
   nmcli con mod "Wired connection 1" ipv4.ignore-auto-dns yes
   nmcli con mod "Wired connection 1" ipv4.method auto
   ```

3. **Reactivate the Connection**
   ```bash
   nmcli con down "Wired connection 1"
   nmcli con up "Wired connection 1"
   ```

4. **Verify the Changes**
   ```bash
   nmcli device show | grep IP4.DNS
   ```

