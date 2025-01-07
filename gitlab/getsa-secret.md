### Step 1: Identify the Secret Associated with the Service Account
Service Account tokens are stored in secrets created automatically by Kubernetes when the Service Account is created. You first need to find the name of the secret associated with your Service Account.

```bash
kubectl get sa gitlab-sa -n backstage-system -o jsonpath="{.secrets[*].name}"
```

### Step 2: Retrieve the Token from the Secret
Once you have the secret's name, you can retrieve the token from that secret with the following command:

```bash
kubectl get secret [secret-name] -n backstage-system -o jsonpath="{.data.token}" | base64 --decode
```

Replace `[secret-name]` with the actual name of the secret you identified in the previous step. This command decodes the token from Base64 format, making it readable and usable for authentication.

### Example in Action

1. **Find the Secret Name**:
   ```bash
   kubectl get sa gitlab-sa -n backstage-system -o jsonpath="{.secrets[*].name}"
   ```

   Output might be something like: `gitlab-sa-token-abcde`

2. **Get the Token**:
   ```bash
   kubectl get secret gitlab-sa-token-abcde -n backstage-system -o jsonpath="{.data.token}" | base64 --decode
   ```

### Using the Token for Authentication

```bash
curl -H "Authorization: Bearer [token]" https://your-kubernetes-api-server/api
```
