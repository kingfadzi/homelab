#!/usr/bin/perl

use strict;
use warnings;

# Check and install the Net::IP Perl module if needed
eval {
    require Net::IP;
    Net::IP->import();
};
if ($@) {
    print "Net::IP Perl module not found. Attempting to install it.\n";
    system("sudo apt-get update") == 0 or die "Failed to update package lists.\n";
    system("sudo apt-get install -y libnet-ip-perl") == 0
        or die "Failed to install Net::IP. Please install it manually and rerun the script.\n";
}

# Updating the package list
print "Updating package lists...\n";
system("sudo apt-get update");

# Upgrading the installed packages
print "Upgrading installed packages...\n";
system("sudo apt-get upgrade -y");

# Installing specified packages
my @packages = ('joe', 'net-tools', 'openssh-server', 'nfs-common', 'curl', 'git');
foreach my $package (@packages) {
    print "Installing $package...\n";
    system("sudo apt-get install -y $package");
}

# Installing additional utilities for cloud guest
print "Installing cloud-guest-utils...\n";
system("sudo apt install -y cloud-guest-utils");

# Expanding the partition
print "Expanding partition /dev/sda 3...\n";
system("sudo growpart /dev/sda 3");

# Resizing the filesystem
print "Resizing filesystem on /dev/sda3...\n";
system("sudo resize2fs /dev/sda3");

# Installing Webmin, overwrite existing GPG key without asking for user confirmation
print "Installing Webmin...\n";
system("curl -fsSL https://download.webmin.com/jcameron-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/webmin.gpg");
system("echo 'deb [signed-by=/usr/share/keyrings/webmin.gpg arch=amd64] http://download.webmin.com/download/repository sarge contrib' | sudo tee /etc/apt/sources.list.d/webmin.list");
system("sudo apt-get update");
system("sudo apt-get install -y webmin");

# Mounting NFS share
print "Mounting NFS share...\n";
my $fstab_entry = "192.168.1.79:/Public /home/fadzi/fsbackup nfs defaults,vers=4.0 0 0\n";
system("sudo mkdir -p /home/fadzi/fsbackup");
open(my $fh, '>>', '/etc/fstab') or die "Could not open file '/etc/fstab' $!";
print $fh $fstab_entry;
close $fh;

# Prompting for hostname and IP address
print "Please enter the new hostname: ";
my $hostname = <STDIN>;
chomp $hostname;
system("echo $hostname | sudo tee /etc/hostname");

print "Enter IP address (e.g., 192.168.1.2/24): ";
my $ip_address = <STDIN>;
chomp $ip_address;

# Hard-code network settings
my $gateway = "192.168.1.1";
my $dns_servers = "192.168.1.1";

# Automatically configuring the connection for ens160 without activating it
my $connection_name = `nmcli -g GENERAL.CONNECTION device show ens160`;
chomp $connection_name;
if (!$connection_name || $connection_name eq '') {
    print "No NM connection found for ens160. Attempting to create one.\n";
    system("nmcli con add type ethernet ifname ens160 con-name ens160 autoconnect yes");
    $connection_name = "ens160";
}
system("nmcli con mod \"$connection_name\" ipv4.addresses $ip_address ipv4.gateway $gateway ipv4.dns \"$dns_servers\" ipv4.method manual autoconnect yes");

print "Network settings updated. A reboot is required to apply these changes.\n";
print "Would you like to reboot now? (y/N): ";
my $reboot = <STDIN>;
chomp $reboot;
if (lc($reboot) eq 'y') {
    system("sudo reboot");
}
