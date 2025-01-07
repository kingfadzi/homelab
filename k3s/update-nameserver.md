
### Step 1: Modify the CoreDNS ConfigMap

You still need to edit the CoreDNS ConfigMap to direct DNS queries to your specific DNS server. You can modify the ConfigMap with the following command:

```bash
kubectl -n kube-system edit configmap coredns
```

### Step 2: Update the Forward Directive

In the CoreDNS ConfigMap, change the `forward . /etc/resolv.conf` line to `forward . 192.168.1.253`. This tells CoreDNS to forward all DNS queries to `192.168.1.253`.

Here's how the updated section might look:

```yaml
.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    hosts /etc/coredns/NodeHosts {
      ttl 60
      reload 15s
      fallthrough
    }
    prometheus :9153
    forward . 192.168.1.253
    cache 30
    loop
    reload
    loadbalance
    import /etc/coredns/custom/*.override
}
import /etc/coredns/custom/*.server
```

### Step 3: Save and Restart CoreDNS

After saving your changes, restart the CoreDNS pods to apply the configuration:

```bash
kubectl -n kube-system rollout restart deployment coredns
```

### Step 4: Verify the Configuration

Check the logs of the CoreDNS pods to ensure there are no errors and that the configuration is loaded:

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns
```

### Step 5: Test DNS Functionality

Finally, you should test that DNS queries are being resolved correctly. You can do this by running a simple DNS lookup within the cluster:

```bash
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- nslookup google.com
```
