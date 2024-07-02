instance-id: cloud-vm
local-hostname: ${vm_hostname}
network:
  version: 2
  ethernets:
    ens192:
      dhcp4: false
      addresses:
        - ${vm_ipv4_address}/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 192.168.1.1
          - 8.8.8.8
