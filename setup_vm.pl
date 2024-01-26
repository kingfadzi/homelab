#!/usr/bin/perl

use strict;
use warnings;

# Updating the package list
print "Updating package lists...\n";
system("sudo apt-get update");

# Installing the packages
my @packages = ('joe', 'net-tools', 'openssh-server', 'nfs-common', 'curl', 'git');
foreach my $package (@packages) {
    print "Installing $package...\n";
    system("sudo apt-get install -y $package");
}

# Installing Webmin
print "Installing Webmin...\n";
system("curl -fsSL https://download.webmin.com/jcameron-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/webmin.gpg");
system("echo 'deb [signed-by=/usr/share/keyrings/webmin.gpg arch=amd64] http://download.webmin.com/download/repository sarge contrib' | sudo tee /etc/apt/sources.list.d/webmin.list");
system("sudo apt-get update");
system("sudo apt-get install -y webmin");

# Mounting NFS share
print "Mounting NFS share...\n";
my $fstab_entry = "192.168.1.79:/Public /home/fadzi/fsbackup nfs defaults,vers=4.0 0 0\n";

# Create the mount directory
system("sudo mkdir -p /home/fadzi/fsbackup");

# Append the fstab entry
open(my $fh, '>>', '/etc/fstab') or die "Could not open file '/etc/fstab' $!";
print $fh $fstab_entry;
close $fh;

print "Installation and configuration complete.\n";
