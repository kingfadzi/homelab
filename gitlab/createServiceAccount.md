To clearly outline the steps to create a Service Account, attach a Role to it, and set up a RoleBinding, and include deletion of the resources as a preliminary step, here's how you can structure the information, including the YAML contents for each resource:

### Step 0: Delete Existing Resources
This is a precautionary step to ensure that there are no conflicts with existing resources of the same name.

**Delete Commands:**
```bash
kubectl delete sa gitlab-sa -n backstage-system
kubectl delete role project-management -n master
kubectl delete rolebinding project-management-binding -n master
```

### Step 1: Create Service Account
This YAML creates a Service Account named `gitlab-sa` in the `backstage-system` namespace.

**YAML Content (`service-account.yaml`):**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-sa
  namespace: backstage-system
```

**Apply Command:**
```bash
kubectl apply -f service-account.yaml
```

### Step 2: Create Role
This YAML defines a Role named `project-management` in the `master` namespace that allows actions on `projects`.

**YAML Content (`role.yaml`):**
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: master
  name: project-management
rules:
- apiGroups: ["project.openshift.io"]
  resources: ["projects"]
  verbs: ["get", "create"]
```

**Apply Command:**
```bash
kubectl apply -f role.yaml
```

### Step 3: Create RoleBinding
This YAML binds the `gitlab-sa` Service Account to the `project-management` Role.

**YAML Content (`role-binding.yaml`):**
```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: project-management-binding
  namespace: master
subjects:
- kind: ServiceAccount
  name: gitlab-sa
  namespace: backstage-system
roleRef:
  kind: Role
  name: project-management
  apiGroup: rbac.authorization.k8s.io
```

**Apply Command:**
```bash
kubectl apply -f role-binding.yaml
```

For a comprehensive setup using a single YAML file for the lazty

### Combined YAML Content (`full-setup.yaml`)
```yaml
---
# Step 0: Delete Existing Resources (Provided for reference, use separate commands to delete)
# kubectl delete sa gitlab-sa -n backstage-system
# kubectl delete role project-management -n master
# kubectl delete rolebinding project-management-binding -n master

---
# Step 1: Create Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-sa
  namespace: backstage-system

---
# Step 2: Create Role
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: project-management
  namespace: master
rules:
- apiGroups: ["project.openshift.io"]
  resources: ["projects"]
  verbs: ["get", "create"]

---
# Step 3: Create RoleBinding
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: project-management-binding
  namespace: master
subjects:
- kind: ServiceAccount
  name: gitlab-sa
  namespace: backstage-system
roleRef:
  kind: Role
  name: project-management
  apiGroup: rbac.authorization.k8s.io
```

### Apply the Combined YAML
This single command applies all the configurations defined in the YAML file:
```bash
kubectl apply -f full-setup.yaml
```

