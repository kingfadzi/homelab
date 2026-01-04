# Netdata Cloud Homelab Monitoring (Ansible)

This bundle provisions Netdata collectors on Ubuntu 22 and configures vCenter + SNMP sources. Optional VM agent installs are explicitly gated.

## Prerequisites

- Ubuntu 22 collector VM(s)
- SSH + sudo access
- SNMP v2c enabled on:
  - QNAP
  - Ubiquiti
- vCenter read-only account

## SNMP setup checklist (high level)

- QNAP: Control Panel → Network & File Services → SNMP → enable v2c, set community, allow collector IP
- UniFi USG/USW: UniFi Controller → Settings → Services → SNMP → enable v2c, set community, allow collector IP
- Supermicro IPMI: IPMI web UI → Configuration → SNMP → enable v2c, set community, restrict to collector IP
- OPNsense: Services → SNMP → enable v2c, set community, allow collector IP

## Infra setup (Mac control node + Ubuntu 22 collector)

You run Ansible from your Mac (control node). The collector VM(s) must be Ubuntu 22 and reachable via SSH.

### Install Ansible (macOS)

```bash
brew install ansible
```

### Install VMware inventory dependencies (macOS)

```bash
ansible-galaxy collection install community.vmware
python3 -m pip install --user pyvmomi
```

### SSH access

Use SSH keys from your Mac to the collector and any Linux nodes you manage with agents:

```bash
ssh-keygen -t ed25519 -C "netdata-ansible"
ssh-copy-id fadzi@COLLECTOR_IP
```

### Vault file

Create a real vault file from the example:

```bash
cp ops/netdata/group_vars/all.vault.yml.example ops/netdata/group_vars/all.vault.yml
ansible-vault encrypt ops/netdata/group_vars/all.vault.yml
```

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
