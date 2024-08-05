#!/bin/bash

# Variables
NAMESPACE="backstage-xyz"
SERVICE_ACCOUNT_NAME="new-backstage-sa"
KUBECONFIG_FILE="kubeconfig-new-backstage-sa.yaml"
TOKEN_FILE="token-file"
SERVER_URL="https://192.168.1.189:6443"

# Step 1: Ensure the Namespace Exists
echo "Ensuring the namespace exists..."
kubectl get namespace $NAMESPACE || kubectl create namespace $NAMESPACE

# Step 2: Create Service Account
echo "Creating Service Account..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
EOF

# Step 3: Create Role and RoleBinding
echo "Creating Role and RoleBinding..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $NAMESPACE
  name: new-backstage-role
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps", "services", "limitranges", "resourcequotas"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: new-backstage-rolebinding
  namespace: $NAMESPACE
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: Role
  name: new-backstage-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Step 4: Create ClusterRole and ClusterRoleBinding
echo "Creating ClusterRole and ClusterRoleBinding..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: new-backstage-clusterrole
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods", "configmaps", "services", "limitranges", "resourcequotas", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: new-backstage-clusterrolebinding
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: new-backstage-clusterrole
  apiGroup: rbac.authorization.k8s.io
EOF

# Step 5: Create Secret for the Service Account
echo "Creating Secret for the Service Account..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SERVICE_ACCOUNT_NAME}-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: $SERVICE_ACCOUNT_NAME
type: kubernetes.io/service-account-token
EOF

# Give Kubernetes some time to populate the secret with the token
sleep 10

# Step 6: Extract the Service Account Token
echo "Extracting Service Account Token..."
SECRET_NAME="${SERVICE_ACCOUNT_NAME}-token"
echo "Secret Name: $SECRET_NAME"

TOKEN=$(kubectl get secret $SECRET_NAME -o jsonpath="{.data.token}" -n $NAMESPACE | base64 --decode | tr -d '\n')
echo "Token: $TOKEN"

if [ -z "$TOKEN" ]; then
  echo "Error: Token is empty. Exiting."
  exit 1
fi

echo $TOKEN > $TOKEN_FILE

# Check if the token file is created and not empty
if [[ ! -s $TOKEN_FILE ]]; then
  echo "Error: Token file is empty. Exiting."
  exit 1
fi

# Step 7: Create kubeconfig File
echo "Creating kubeconfig file..."
cat <<EOF > $KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $SERVER_URL
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    namespace: $NAMESPACE
    user: $SERVICE_ACCOUNT_NAME
  name: backstage-context
current-context: backstage-context
users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    tokenFile: ./$TOKEN_FILE
EOF

# Step 8: Test Access with kubectl
echo "Testing access with kubectl..."
KUBECONFIG=./$KUBECONFIG_FILE kubectl get pods -n $NAMESPACE
KUBECONFIG=./$KUBECONFIG_FILE kubectl get svc -n $NAMESPACE
KUBECONFIG=./$KUBECONFIG_FILE kubectl describe pod $(kubectl get pods -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}") -n $NAMESPACE
KUBECONFIG=./$KUBECONFIG_FILE kubectl get namespaces

echo "Script execution completed."