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

## Enable VM agents (explicit)

```bash
ansible-playbook playbooks/site.yml \
  -i inventory/homelab.yml \
  --ask-vault-pass \
  -e netdata_allow_vm_agents=true
```
