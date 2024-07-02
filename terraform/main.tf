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
  memory   = var.memory * 1024  # Convert GB to MB
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
  }

  extra_config = {
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/metadata.tpl", {
      vm_hostname     = var.vm_hostname,
      vm_ipv4_address = var.vm_ipv4_address
    }))
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/userdata.tpl", {
      vm_hostname   = var.vm_hostname,
      root_password = var.root_password
    }))
    "guestinfo.userdata.encoding" = "base64"
  }


}
