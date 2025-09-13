#!/usr/bin/env python3
import argparse, sys, logging, yaml, time
from paramiko import SSHClient, AutoAddPolicy
from pyVim.connect import SmartConnectNoSSL, Disconnect
from pyVmomi import vim

# ─── Logging setup ───────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.StreamHandler()]
)
log = logging.getLogger(__name__)

# ─── Helpers ─────────────────────────────────────────────────────────────────────
def run_remote_cmd(host, user, pwd, cmd):
    ssh = SSHClient()
    ssh.set_missing_host_key_policy(AutoAddPolicy())
    ssh.connect(host, username=user, password=pwd)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    ssh.close()
    if exit_code != 0:
        raise RuntimeError(f"{host}: `{cmd}` failed ({exit_code}): {err}")
    return out

def find_and_power(host, user, pwd, vm_name):
    # on ESXi: get VM ID, then power it on
    script = (
        "vmid=$(vim-cmd vmsvc/getallvms | "
        f"awk -v name='{vm_name}' '$2==name {{print $1}}');"
        " if [ -z \"$vmid\" ]; then echo VM_NOT_FOUND; exit 1; fi;"
        " vim-cmd vmsvc/power.on \"$vmid\";"
        " echo VM_POWERED_ON"
    )
    out = run_remote_cmd(host, user, pwd, script)
    if "VM_NOT_FOUND" in out:
        raise RuntimeError(f"VM '{vm_name}' not found on ESXi {host}")
    log.info(f"[{host}] powered on VM '{vm_name}'")

def vcenter_power_on(content, vm_name):
    # via vCenter API: find VM object, then power or reset
    container = content.rootFolder
    view = content.viewManager.CreateContainerView(container, [vim.VirtualMachine], True)
    vm = next((m for m in view.view if m.name == vm_name), None)
    view.Destroy()
    if not vm:
        raise RuntimeError(f"VM '{vm_name}' not found in vCenter inventory")
    if vm.runtime.powerState == vim.VirtualMachinePowerState.poweredOn:
        log.info(f"🔄 Resetting already-on VM: {vm_name}")
        vm.ResetVM_Task()
    else:
        log.info(f"▶ Powering on VM: {vm_name}")
        vm.PowerOn()
    # (could wait on the task here if desired)

# ─── Main ────────────────────────────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser()
    p.add_argument("-c", "--config", required=True, help="Path to config.yaml")
    args = p.parse_args()

    cfg = yaml.safe_load(open(args.config, "r"))

    # Phase 1/2: NFS reconfigure on all ESXi hosts
    esxi = cfg["esxi"]
    ds  = cfg["datastore"]
    for host in esxi["hosts"]:
        log.info(f"[{host}] verifying SSH…")
        run_remote_cmd(host, esxi["user"], esxi["password"], "echo OK")

        log.info(f"[{host}] removing old NFS mount (if exists)…")
        run_remote_cmd(
            host, esxi["user"], esxi["password"],
            f"esxcli storage nfs41 remove --volume-name={ds['name']}"
        )
        log.info(f"[{host}] adding NFS mount…")
        run_remote_cmd(
            host, esxi["user"], esxi["password"],
            f"esxcli storage nfs41 add --hosts={ds['nas_ip']} "
            f"--share={ds['nas_path']} --volume-name={ds['name']}"
        )
        log.info(f"[{host}] NFS reconfigured successfully")

    # Phase 3: start vCenter Appliance via ESXi
    vc = cfg["vcenter"]
    log.info(f"🔌 Powering on vCenter ({vc['appliance_vm_name']}) via ESXi {vc['esxi_host']}…")
    find_and_power(vc["esxi_host"], esxi["user"], esxi["password"], vc["appliance_vm_name"])

    # wait a bit for vCenter to come up
    log.info("⏳ Waiting for vCenter API to become available…")
    for _ in range(12):
        try:
            si = SmartConnectNoSSL(host=vc["api_host"], user=vc["api_user"], pwd=vc["api_password"])
            Disconnect(si)
            break
        except Exception:
            time.sleep(15)
    else:
        log.error("vCenter API still unreachable after timeout")
        sys.exit(1)

    # Phase 4: start other VMs via vCenter API
    log.info(f"🔌 Connecting to vCenter API at {vc['api_host']}…")
    si = SmartConnectNoSSL(host=vc["api_host"], user=vc["api_user"], pwd=vc["api_password"])
    content = si.RetrieveContent()
    for vm_name in vc["vms_to_start"]:
        vcenter_power_on(content, vm_name)
    Disconnect(si)

    log.info("✅ All specified VMs have been powered on/cycled")

if __name__ == "__main__":
    try:
        main()
    except Exception:
        log.exception("Fatal error")
        sys.exit(1)
