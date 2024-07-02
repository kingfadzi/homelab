#cloud-config
hostname: ${vm_hostname}
manage_etc_hosts: true
ssh_pwauth: true
disable_root: false
chpasswd:
  list: |
    root:${root_password}
  expire: False
