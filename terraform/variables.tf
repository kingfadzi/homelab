variable "vm_hostname" {
  description = "The hostname of the VM"
}

variable "vm_ipv4_address" {
  description = "The IPv4 address to assign to the VM"
}

variable "num_cpus" {
  description = "Number of CPUs"
}

variable "memory" {
  description = "Amount of memory in GB"
}

variable "disk_size" {
  description = "Disk size in GB"
}

variable "root_password" {
  description = "Root password for SSH"
}
