# Access Management for GitLab Runners and ClusterServiceVersions in OpenShift

## Prerequisites

- Administrative access to the OpenShift cluster.
- The `oc` command-line tool installed and configured.

## Grant Access to ClusterServiceVersions

### 1. Create the Role for CSV Viewing

- **File Name**: `csv-viewer-role.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: openshift-operators
  name: csv-viewer
rules:
- apiGroups: ["operators.coreos.com"]
  resources: ["clusterserviceversions"]
  verbs: ["get", "list", "watch"]
```

- **Command**:

```sh
oc apply -f csv-viewer-role.yaml
```

### 2. Bind the Role to a User

- **File Name**: `csv-viewer-rolebinding.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: csv-viewer-binding
  namespace: openshift-operators
subjects:
- kind: User
  name: "USER_NAME"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: csv-viewer
  apiGroup: rbac.authorization.k8s.io
```

- **Command**:

```sh
oc apply -f csv-viewer-rolebinding.yaml
```

## Grant Access to GitLab Runners

### 1. Create the Role for GitLab Runner Access

- **File Name**: `gitlab-runner-role.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: openshift-operators
  name: gitlab-runner-viewer
rules:
- apiGroups: ["apps.gitlab.com"]
  resources: ["runners"]
  verbs: ["get", "list", "watch"]
```

- **Command**:

```sh
oc apply -f gitlab-runner-role.yaml
```

### 2. Bind the Role to a User

- **File Name**: `gitlab-runner-rolebinding.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-runner-viewer-binding
  namespace: openshift-operators
subjects:
- kind: User
  name: "USER_NAME"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: gitlab-runner-viewer
  apiGroup: rbac.authorization.k8s.io
```

- **Command**:

```sh
oc apply -f gitlab-runner-rolebinding.yaml
```

## Instructions

- Replace `"USER_NAME"` with the actual username or email of the user.
- Apply the YAML files using the `oc apply -f <filename>.yaml` command as shown.
- These steps grant users the ability to view CSVs and GitLab Runners in the `openshift-operators` namespace. Adjust the namespace if necessary.

## Verification

To verify access, have the user attempt to list the relevant resources in the `openshift-operators` namespace using their credentials. If configured correctly, there should be no permissions errors.