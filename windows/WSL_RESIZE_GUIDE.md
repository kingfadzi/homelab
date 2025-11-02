# WSL Distro Resize Guide

## Problem
Your WSL distro has grown large and is consuming too much disk space on your Windows machine. WSL virtual disks don't automatically shrink when you delete files - you need to manually reclaim the space.

## Solution
Use the cleanup and port scripts to reclaim space by:
1. Cleaning caches and temporary files inside WSL
2. Exporting, unregistering, and re-importing the distro (which compresses it)

---

## Prerequisites

- Windows 10/11 with WSL2 installed
- Sufficient disk space for the export tar file (temporarily needs ~current distro size)
- Scripts location: `/home/fadzi/tools/homelab/windows/` (or adjust paths accordingly)

---

## Step 1: Run Cleanup Inside WSL

**⚠️ IMPORTANT: Do this from INSIDE your WSL distro**

### 1.1 Navigate to the scripts directory
```bash
cd /home/fadzi/tools/homelab/windows
```

### 1.2 Make the cleanup script executable (if not already)
```bash
chmod +x cleanup_wsl.sh
```

### 1.3 Run the cleanup script
```bash
./cleanup_wsl.sh
```

**What this does:**
- Removes cache directories (.cache, .npm, .m2, .gradle, .ivy2, .nuget)
- Cleans system package caches (dnf)
- Removes temporary files from /tmp and /var/tmp
- Limits journal logs to 50MB
- Vacuums PostgreSQL databases (if installed)
- Prunes Docker resources (if Docker is running)
- **PRESERVES:** All configs, SSH keys, installed software, settings

**Expected output:**
```
Cleaning cache directories from /home/fadzi...
Starting system cleanup...
Vacuuming PostgreSQL databases...
Cleaning Docker resources...
Cleanup complete!
```

### 1.4 Check current disk usage (optional)
```bash
df -h /
```

---

## Step 2: Run Port Script from Windows

**⚠️ IMPORTANT: Do this from Windows Command Prompt or PowerShell**

### 2.1 Open Command Prompt as Administrator
- Press `Win + X`
- Select "Windows Terminal (Admin)" or "Command Prompt (Admin)"

### 2.2 Navigate to the scripts directory
```cmd
cd C:\path\to\homelab\windows
```

### 2.3 Determine your parameters

You need:
- **DistroName**: Your WSL distro name (check with `wsl -l -q`)
- **ExportPath**: Where to temporarily save the tar file
- **ImportPath**: Where to store the new distro
- **Username**: Your WSL username (optional, will auto-detect)

**Check your distro name:**
```cmd
wsl -l -q
```

### 2.4 Run the port script

**Example 1: Auto-detect username**
```cmd
wsl_port.bat AlmaLinux-8 C:\Temp\alma_clean.tar C:\WSL\AlmaLinux-8
```

**Example 2: Specify username**
```cmd
wsl_port.bat AlmaLinux-8 C:\Temp\alma_clean.tar C:\WSL\AlmaLinux-8 fadzi
```

**Example 3: Different distro**
```cmd
wsl_port.bat Ubuntu-22.04 C:\Backups\ubuntu_clean.tar C:\WSL\Ubuntu-22.04 youruser
```

### 2.5 Follow the prompts

The script will:
1. **Detect your default user** (or use the one you specified)
2. **Show a summary** of the operation:
   ```
   ========================================
   WSL Distro Port Operation
   ========================================
   Distro:       AlmaLinux-8
   Export to:    C:\Temp\alma_clean.tar
   Import to:    C:\WSL\AlmaLinux-8
   Default user: fadzi
   Current size: 15G
   ========================================

   WARNING: This will UNREGISTER the current distro after export.
   Make sure you have run cleanup script first for maximum space savings.

   Type 'yes' to continue:
   ```

3. **Type `yes`** and press Enter to continue

4. **Export** your distro (this may take several minutes)
   ```
   Exporting AlmaLinux-8 to C:\Temp\alma_clean.tar...
   Export successful. File size: 8589934592 bytes
   Verifying tar file integrity...
   Tar file integrity verified.
   ```

5. **Unregister** the old distro
   ```
   Unregistering AlmaLinux-8...
   Unregister successful.
   ```

6. **Import** the distro to the new location
   ```
   Importing AlmaLinux-8 from C:\Temp\alma_clean.tar to C:\WSL\AlmaLinux-8...
   Import successful.
   ```

7. **Restore your default user**
   ```
   Setting default user to fadzi...
   Default user set to fadzi
   Restarting distro to apply changes...
   ```

8. **Show results**
   ```
   ========================================
   Operation Complete!
   ========================================
   Distro:        AlmaLinux-8
   Location:      C:\WSL\AlmaLinux-8
   Default user:  fadzi
   Original size: 15G
   New size:      8G
   Export file:   C:\Temp\alma_clean.tar (8589934592 bytes)
   ========================================

   Delete the export tar file to save space? (yes/no):
   ```

9. **Type `yes`** to delete the temporary tar file and free up space, or `no` to keep it as a backup

---

## Step 3: Verify Everything Works

### 3.1 Login to your WSL distro
```cmd
wsl -d AlmaLinux-8
```

You should be logged in as your normal user (not root).

### 3.2 Check your home directory
```bash
ls -la ~
```

Verify your files and configs are intact.

### 3.3 Test your services (if applicable)
```bash
# Check PostgreSQL
sudo systemctl status postgresql-13

# Check Redis
sudo systemctl status redis

# Or use your services script
sudo /usr/local/bin/services.sh status all
```

### 3.4 Check disk usage
```bash
df -h /
```

You should see significantly less space used.

---

## Quick Reference Commands

### From inside WSL (Step 1):
```bash
cd /home/fadzi/tools/homelab/windows
./cleanup_wsl.sh
```

### From Windows CMD (Step 2):
```cmd
cd C:\path\to\homelab\windows
wsl_port.bat <DistroName> <ExportPath.tar> <ImportPath> [username]
```

### Real-world example (complete workflow):

**Inside WSL:**
```bash
cd /home/fadzi/tools/homelab/windows
./cleanup_wsl.sh
```

**In Windows CMD (as Admin):**
```cmd
cd C:\Users\YourName\tools\homelab\windows
wsl_port.bat AlmaLinux-8 C:\Temp\alma_clean.tar C:\WSL\AlmaLinux-8 fadzi
```

---

## Expected Space Savings

Typical results:
- **Before:** 15-20 GB
- **After cleanup script:** 12-15 GB (removed caches)
- **After port script:** 6-10 GB (compression + reclaimed space)

**Total savings:** 50-60% reduction in disk usage

---

## Troubleshooting

### "Distribution not found"
```cmd
wsl -l -q
```
Use the exact name shown (case-sensitive).

### "Export directory does not exist"
Create the directory first:
```cmd
mkdir C:\Temp
```

### "Tar file may be corrupted"
- Could be a temporary issue
- Try the export again
- Check disk space on export drive

### "User does not exist after import"
This shouldn't happen, but if it does:
```cmd
wsl -d AlmaLinux-8 -u root
useradd -m -s /bin/bash fadzi
passwd fadzi
usermod -aG wheel fadzi
```

### Lost default user (logging in as root)
```cmd
wsl -d AlmaLinux-8 -u root
echo '[user]' > /etc/wsl.conf
echo 'default=fadzi' >> /etc/wsl.conf
exit
wsl --terminate AlmaLinux-8
wsl -d AlmaLinux-8
```

### Services not starting after import
```bash
sudo systemctl daemon-reload
sudo /usr/local/bin/services.sh start all
```

---

## Safety Notes

✅ **Safe Operations:**
- The cleanup script preserves all configs and settings
- The port script validates the export before unregistering
- Your data is in the tar file even if import fails
- Default user is automatically restored

⚠️ **Caution:**
- You need enough disk space for the temporary tar file
- WSL distro is unregistered after successful export
- If import fails, manually re-import using the command shown

🛟 **Recovery:**
If something goes wrong during import:
```cmd
wsl --import AlmaLinux-8 C:\WSL\AlmaLinux-8 C:\Temp\alma_clean.tar
```

---

## Time Estimates

- **Cleanup script:** 2-5 minutes
- **Export:** 5-15 minutes (depends on distro size)
- **Unregister:** 10-30 seconds
- **Import:** 5-15 minutes (depends on distro size)

**Total time:** 15-35 minutes

---

## Notes

- Run this process during a maintenance window (services will be down briefly)
- Close all WSL terminals before running the port script
- The export tar file can be kept as a backup
- You can repeat this process periodically to maintain optimal disk usage
- This process works for any WSL2 distro (Ubuntu, Debian, Fedora, etc.)

---

## What Gets Preserved

✅ **Kept:**
- All installed packages and software
- All configuration files (.bashrc, .ssh, .gitconfig, etc.)
- All databases and data files
- All user accounts and permissions
- All systemd services and cron jobs
- All your application directories (~/tools/*)

❌ **Removed:**
- Cache directories (.cache, .npm, .m2, etc.)
- System package caches (dnf, apt)
- Temporary files (/tmp, /var/tmp)
- Old log files (limited to 50MB)
- Docker images and containers
- Journal logs (limited to 50MB)

---

## Additional Tips

1. **Schedule regular cleanups:**
   ```bash
   # Add to crontab
   0 2 * * 0 /home/fadzi/tools/homelab/windows/cleanup_wsl.sh
   ```

2. **Check space before running:**
   ```bash
   df -h /
   du -sh ~/tools/*
   ```

3. **Monitor Docker usage:**
   ```bash
   docker system df
   ```

4. **Keep the tar as backup:**
   - Store export tar on external drive
   - Quick restore point if needed
   - Can import on different machine

5. **Alternative import location:**
   - Use faster drive (SSD vs HDD)
   - Use drive with more space
   - Example: `D:\WSL\AlmaLinux-8` instead of `C:\WSL\`

---

## Questions?

For issues or improvements to these scripts:
- Check the scripts at: `/home/fadzi/tools/homelab/windows/`
- Review script comments for detailed behavior
- Test in a non-production environment first
