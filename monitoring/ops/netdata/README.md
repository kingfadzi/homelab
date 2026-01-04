# Netdata Cloud Homelab Monitoring (Ansible)

This bundle provisions Netdata collectors on Ubuntu 22 and configures vCenter + SNMP sources. Optional VM agent installs are explicitly gated.

## Prerequisites

- Ubuntu 22 collector VM(s)
- SSH + sudo access
- SNMP v2c enabled on:
  - QNAP
  - Ubiquiti
- vCenter read-only account

## How to run

```bash
cd ops/netdata
ansible-playbook playbooks/site.yml -i inventory/homelab.yml --ask-vault-pass
```

## VM agents via vCenter discovery (optional)

To auto-discover powered-on VMs from vCenter and install agents (when explicitly enabled), export vCenter credentials as environment variables and include the dynamic inventory:

```bash
export VMWARE_HOST=192.168.1.200
export VMWARE_USER=administrator@vsphere.local
export VMWARE_PASSWORD='PASTE_PASSWORD'

ansible-playbook playbooks/site.yml \
  -i inventory/homelab.yml \
  -i inventory/vcenter.yml \
  --ask-vault-pass \
  -e netdata_allow_vm_agents=true
```

## Enable VM agents (explicit)

```bash
ansible-playbook playbooks/site.yml \
  -i inventory/homelab.yml \
  --ask-vault-pass \
  -e netdata_allow_vm_agents=true
```
