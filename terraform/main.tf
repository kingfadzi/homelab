terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.0"
    }
  }
}

provider "vsphere" {
  user           = "administrator@vsphere.local"
  password       = "Password1!"
  vsphere_server = "192.168.1.200"
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "butterflycluster"
}

data "vsphere_datastore" "datastore" {
  name          = "Lucas"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = "cosmo-core"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "ubuntu22-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_hostname
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = var.num_cpus
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    eagerly_scrub    = false
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.vm_hostname
        domain    = "example.com"
      }

      network_interface {
        ipv4_address = var.vm_ipv4_address
        ipv4_netmask = "24"
      }
      ipv4_gateway = "192.168.1.1"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'network:' > /etc/netplan/01-netcfg.yaml",
      "echo '  version: 2' >> /etc/netplan/01-netcfg.yaml",
      "echo '  ethernets:' >> /etc/netplan/01-netcfg.yaml",
      "echo '    ens192:' >> /etc/netplan/01-netcfg.yaml",
      "echo '      addresses: [\"${var.vm_ipv4_address}/24\"]' >> /etc/netplan/01-netcfg.yaml",
      "echo '      gateway4: 192.168.1.1' >> /etc/netplan/01-netcfg.yaml",
      "echo '      nameservers:' >> /etc/netplan/01-netcfg.yaml",
      "echo '        addresses: [\"192.168.1.1\", \"8.8.8.8\"]' >> /etc/netplan/01-netcfg.yaml",
      "netplan apply"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = var.root_password
      host     = self.default_ip_address
    }
  }
}
