variable "vm_hostname" {
  description = "The hostname of the VM"
  type        = string
}

variable "vm_domain" {
  description = "The domain of the VM"
  type        = string
  default     = "localdomain"
}

variable "vm_ipv4_address" {
  description = "Static IPv4 address for the VM"
  type        = string
  default     = ""
}

variable "vm_ipv4_netmask" {
  description = "Netmask for the VM's static IPv4 address"
  type        = number
  default     = 24
}

variable "vm_ipv4_gateway" {
  description = "Default gateway for the VM"
  type        = string
  default     = ""
}
variable "root_password" {
  description = "Root password for the VM"
  type        = string
  sensitive   = true
}
