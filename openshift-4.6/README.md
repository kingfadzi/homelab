### README.md

---

# OpenShift IPI on vSphere with HAProxy

Quickstart guide to setting up OpenShift 4.6 in a vSphere environment using HAProxy for load balancing.

## Step 1: Prepare OpenShift Install Config

Create an `install-config.yaml` file with the following content, adjusting as necessary for your environment:

```yaml
apiVersion: v1
baseDomain: butterflycluster.com
compute:
  - architecture: amd64
    hyperthreading: Enabled
    name: worker
    platform: {}
    replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
metadata:
  creationTimestamp: null
  name: ocp4
networking:
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  machineNetwork:
    - cidr: 192.168.1.0/24
  networkType: OpenShiftSDN
  serviceNetwork:
    - 172.30.0.0/16
platform:
  vsphere:
    apiVIP: 192.168.1.21
    cluster: cosmo-core
    datacenter: butterflycluster
    defaultDatastore: Roots
    ingressVIP: 192.168.1.22
    network: VM Network
    password: "" # Removed for security
    username: "" # Removed for security
    vCenter: vcenter.butterflycluster.com
    clusterOSImage: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/4.6.1/rhcos-vmware.x86_64.ova
publish: External
pullSecret: "" # Removed for security
sshKey: "" # Removed for security
```

## Step 2: Configure HAProxy

Use this HAProxy configuration:

```haproxy
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log /dev/log local0
    log /dev/log local1 notice
    user haproxy
    group haproxy
    daemon

#---------------------------------------------------------------------
# Default settings
#---------------------------------------------------------------------
defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

#---------------------------------------------------------------------
# Frontend for OpenShift API Server
#---------------------------------------------------------------------
frontend openshift_api_frontend
    bind *:6443
    default_backend openshift_api_backend

backend openshift_api_backend
    balance roundrobin
    # Direct API server traffic to the bootstrap VM while it holds the API VIP
    server bootstrap 192.168.1.21:6443 check
    #server api-vip 192.168.1.21:6443 check  #<= enable post installation 

#---------------------------------------------------------------------
# Frontend for OpenShift Ingress - HTTP
#---------------------------------------------------------------------
frontend ingress_http_frontend
    bind *:80
    default_backend ingress_http_backend

backend ingress_http_backend
    balance roundrobin
    server ingress-vip 192.168.1.22:80 check

#---------------------------------------------------------------------
# Frontend for OpenShift Ingress - HTTPS
#---------------------------------------------------------------------
frontend ingress_https_frontend
    bind *:443
    default_backend ingress_https_backend

backend ingress_https_backend
    balance roundrobin
    server ingress-vip 192.168.1.22:443 check

#---------------------------------------------------------------------
# Frontend for Machine Config Server
#---------------------------------------------------------------------
frontend machine_config_server_frontend
    bind *:22623
    default_backend machine_config_server_backend

backend machine_config_server_backend
    balance roundrobin
    # MCS traffic is also directed to the bootstrap VM during initial setup
    server bootstrap 192.168.1.21:22623 check

```

## Step 3: Start OpenShift Installation

Initiate the OpenShift installation using the OpenShift Installer with your `install-config.yaml`.

## Step 4: Post-Installation Adjustments

After installation:

- Remove bootstrap entries from HAProxy configuration.
- Ensure API and Ingress VIPs are managed by the control plane and OpenShift routers, respectively.

---

**Note:** Replace `<your_pull_secret>` and `<your_ssh_key>` with your actual pull secret and SSH key. Adjust IP addresses in the HAProxy configuration to match your environment's specifics.

## Step 5: Add custom-tls to console URL
[Custom TLS Configuration](./custom-tls.md)
