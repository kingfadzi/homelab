### Step 0: Delete Existing Resources
This is a precautionary step to ensure that there are no conflicts with existing resources of the same name.

**Delete Commands:**
```bash
kubectl delete sa gitlab-sa -n backstage-system
kubectl delete role cluster-deployment-manager
kubectl delete rolebinding cluster-deployment-manager-binding
```

If you need the permissions specified in the `project-management` Role to be cluster-wide, you should convert the `Role` to a `ClusterRole` and the `RoleBinding` to a `ClusterRoleBinding`. This change will extend the permissions across all namespaces in the cluster, rather than being limited to a specific namespace.

Here is how you can update your configuration to make the permissions cluster-wide:

### Step 2: Create ClusterRole
This YAML defines a `ClusterRole` that allows actions on `projects` within the `project.openshift.io` API group.

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-deployment-manager
rules:
- apiGroups: ["batch"]
  resources: ["cronjobs", "jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["namespaces", "services", "configmaps", "limitranges", "resourcequotas"]
  verbs: ["get", "list", "create", "delete", "update"]
- apiGroups: ["apps", "extensions"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]  # Added "pods/log" here
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

```

### Step 3: Create ClusterRoleBinding
This YAML binds the `gitlab-sa` Service Account to the `project-management` ClusterRole, applying these permissions across the entire cluster.

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-deployment-manager-binding
subjects:
- kind: ServiceAccount
  name: gitlab-sa
  namespace: backstage-system
roleRef:
  kind: ClusterRole
  name: cluster-deployment-manager
  apiGroup: rbac.authorization.k8s.io

```

### Full Setup in One YAML File
Here’s how you can combine these configurations into a single YAML file:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-sa
  namespace: backstage-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-deployment-manager
rules:
- apiGroups: ["batch"]
  resources: ["cronjobs", "jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["namespaces", "services", "configmaps", "limitranges", "resourcequotas"]
  verbs: ["get", "list", "create", "delete", "update"]
- apiGroups: ["apps", "extensions"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]  # Added "pods/log" here
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-deployment-manager-binding
subjects:
- kind: ServiceAccount
  name: gitlab-sa
  namespace: backstage-system
roleRef:
  kind: ClusterRole
  name: cluster-deployment-manager
  apiGroup: rbac.authorization.k8s.io

```

### Instructions to Apply the YAML

1. **Save this configuration** into a file, for example, `gitlab-cluster-wide-setup.yaml`.
2. **Apply the configuration** with the following command:
   ```bash
   kubectl apply -f gitlab-cluster-wide-setup.yaml
   ```


