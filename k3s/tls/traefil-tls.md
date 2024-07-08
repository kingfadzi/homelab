### 1. Create a ConfigMap for Traefik Configuration

1. Create a file named `traefik-config.yaml` with the following content:
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: traefik-config
      labels:
        name: traefik-config
      namespace: kube-system
    data:
      traefik-config.yaml: |
        tls:
          stores:
            default:
              defaultCertificate:
                certFile: '/certs/tls.crt'
                keyFile: '/certs/tls.key'
    ```

2. Load the ConfigMap into Kubernetes:
    ```sh
    kubectl create configmap traefik-config --namespace kube-system --from-file=traefik-config.yaml
    ```

### 2. Customize the Traefik Helm Chart

Create a file named `traefik-helm-chart.yaml` with the following content to customize the Traefik Helm chart:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    rbac:
      enabled: true
    ports:
      websecure:
        tls:
          enabled: true
    podAnnotations:
      prometheus.io/port: "8082"
      prometheus.io/scrape: "true"
    providers:
      kubernetesIngress:
        publishedService:
          enabled: true
    priorityClassName: "system-cluster-critical"
    image:
      name: "rancher/mirrored-library-traefik"
    tolerations:
    - key: "CriticalAddonsOnly"
      operator: "Exists"
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node-role.kubernetes.io/master"
      operator: "Exists"
      effect: "NoSchedule"
    additionalArguments:
      - '--providers.file.filename=/config/traefik-config.yaml'
    volumes:
      - name: tls-secret
        mountPath: '/certs'
        type: secret
      - name: traefik-config
        mountPath: '/config'
        type: configMap
```

Save this file under `/var/lib/rancher/k3s/server/manifests/traefik-helm-chart.yaml`.

### 3. Create a TLS Secret

Prepare your certificate and key files:
- `butterflycluster_com.crt` (use `butterflycluster_com.crt.pem` if it contains the full certificate chain)
- `butterflycluster_com.key`

Create the secret:
```sh
kubectl create secret tls tls-secret --namespace kube-system --cert butterflycluster_com.crt.pem --key butterflycluster_com.key
```

### 4. Create a TLSStore

Create a file named `traefik-tls-store.yaml` with the following content:
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: kube-system
spec:
  defaultCertificate:
    secretName: tls-secret
```

Apply this configuration:
```sh
kubectl apply -f traefik-tls-store.yaml --namespace kube-system
```

### 5. Define Ingress Rules for Backstage

Create or update your ingress rule, for example, `backstage-ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage-ingress
  namespace: backstage
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: backstage.charon.butterflycluster.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  number: 80
  tls:
    - hosts:
        - backstage.charon.butterflycluster.com
      secretName: tls-secret
```

Apply the ingress configuration:
```sh
kubectl apply -f backstage-ingress.yaml
```
