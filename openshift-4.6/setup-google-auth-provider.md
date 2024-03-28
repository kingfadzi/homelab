## Configure Google OAuth in OpenShift

### Step 1: Create OAuth 2.0 Credentials in Google Cloud

1. Go to the **Google Cloud Console**.
2. Select or create a new project.
3. Navigate to **APIs & Services > OAuth consent screen**, choose the user type, and fill in the required fields.
4. Go to **Credentials**, click **Create Credentials**, and select **OAuth client ID**.
5. Choose **Web application** as the application type.
6. Add an Authorized redirect URI: `https://<openshift_master>/oauth2callback/Google`, replacing `<openshift_master>` with your OpenShift API URL.
7. Note the **Client ID** and **Client Secret**.

### Step 2: Configure OpenShift to Use Google as an Identity Provider

1. Log into your OpenShift cluster as an administrator.
2. Execute `oc edit oauth cluster`.
3. Add Google as an identity provider in the `spec.identityProviders` section:
   ```yaml
   - name: Google
     mappingMethod: claim
     type: Google
     google:
       clientID: "<Client ID>"
       clientSecret:
         name: google-secret
       hostedDomain: "<your-domain.com>"
   ```
   Replace `<Client ID>`, `<Client Secret>`, and `<your-domain.com>` with your actual values.
4. Create the secret for the client secret:
   ```sh
   oc create secret generic google-secret --from-literal=clientSecret=<Client Secret> -n openshift-config
   ```

## Manual Namespace Creation and User Mapping

### Step 1: Monitor New User Logins

- Check for new users who have logged in through Google OAuth.

### Step 2: Create a Namespace for Each New User

1. Determine an appropriate namespace name, usually based on the user's Google ID or email prefix.
2. Execute:
   ```sh
   oc new-project <namespace-name>
   ```
   Replace `<namespace-name>` with the chosen namespace name.

### Step 3: Assign Roles to the User

- Assign the `edit` role to the new user within their namespace:
  ```sh
  oc adm policy add-role-to-user edit <username> -n <namespace-name>
  ```
  Replace `<username>` and `<namespace-name>` with the actual username and the created namespace name.
---