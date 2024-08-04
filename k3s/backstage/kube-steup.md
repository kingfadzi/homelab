To create a service account with read-only permissions for the specified resources, you need to define a `Role` and a `RoleBinding` in addition to the `ServiceAccount`. Here are the necessary YAML files:

1. **Namespace YAML (namespace.yaml):**
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: backstage
   ```

2. **Service Account YAML (service-account.yaml):**
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: backstage-sa
     namespace: backstage
   ```

3. **Create a Secret for the Service Account (secret-backstage-sa-token.yaml)**:
      ```yaml
    apiVersion: v1
   kind: Secret
   metadata:
   name: backstage-sa-token
   namespace: backstage
   annotations:
   kubernetes.io/service-account.name: backstage-sa
   type: kubernetes.io/service-account-token
      ```

4. **Role YAML (role-backstage-read-only.yaml):**
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     namespace: backstage
     name: backstage-read-only
   rules:
   - apiGroups: [""]
     resources: 
       - pods
       - configmaps
       - services
       - deployments
       - replicasets
       - horizontalpodautoscalers
       - ingresses
       - statefulsets
       - limitranges
       - resourcequotas
       - daemonsets
     verbs: ["get", "list", "watch"]
   - apiGroups: ["batch"]
     resources: 
       - jobs
       - cronjobs
     verbs: ["get", "list", "watch"]
   - apiGroups: ["metrics.k8s.io"]
     resources: 
       - pods
     verbs: ["get", "list"]
   ```

5. **RoleBinding YAML (rolebinding-backstage-read-only.yaml):**
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata:
     name: backstage-read-only
     namespace: backstage
   subjects:
   - kind: ServiceAccount
     name: backstage-sa
     namespace: backstage
   roleRef:
     kind: Role
     name: backstage-read-only
     apiGroup: rbac.authorization.k8s.io
   ```

Apply these YAML files using the following commands:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f service-account.yaml
kubectl apply -f role-backstage-read-only.yaml
kubectl apply -f rolebinding-backstage-read-only.yaml
```

Finally, use the following command to retrieve the service account token:

```bash
kubectl -n backstage get secret $(kubectl -n backstage get sa backstage-sa -o=jsonpath='{.secrets[0].name}') -o=jsonpath='{.data.token}' | base64 --decode
```