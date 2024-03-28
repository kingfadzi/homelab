### Step 1: Install Certbot on CentOS

1. **Install EPEL Repository** (if not already installed):
   ```bash
   sudo yum install epel-release
   ```
2. **Install Certbot**:
   ```bash
   sudo yum install certbot
   ```

### Step 2: Obtain Certificates from Let's Encrypt

1. **Run Certbot for a Wildcard and Specific Domain**:
   Use the manual mode for DNS challenges, as this will cover most scenarios including those without direct DNS plugin support for Certbot:
   ```bash
   sudo certbot certonly --manual --preferred-challenges=dns -d '*.apps.ocp4.butterflycluster.com' -d 'api.ocp4.butterflycluster.com'
   ```
   Follow Certbot's instructions to create the necessary DNS TXT records at your DNS provider (since you're using Google Domains, you'll manually add these records there). This proves domain ownership to Let's Encrypt.

### Step 3: Prepare the Certificate for HAProxy

1. **Combine the Certificate and Private Key**:
   HAProxy requires the certificate and private key in one file for SSL termination. Assuming Certbot stored your certificates under `/etc/letsencrypt/live/apps.ocp4.butterflycluster.com`, combine them like this:
   ```bash
   sudo bash -c 'cat /etc/letsencrypt/live/apps.ocp4.butterflycluster.com/fullchain.pem /etc/letsencrypt/live/apps.ocp4.butterflycluster.com/privkey.pem > /etc/haproxy/certs/apps.ocp4.butterflycluster.com.pem'
   ```
   Ensure the directory `/etc/haproxy/certs/` exists, or adjust the path according to your setup.

### Step 4: Automate Renewals

Let's Encrypt certificates are valid for 90 days. Set up automatic renewal:
```bash
sudo certbot renew --dry-run
```
For a fully automated renewal process, including reloading HAProxy to apply renewed certificates, add a renewal hook to Certbot:
```bash
echo "systemctl reload haproxy" | sudo tee /etc/letsencrypt/renewal-hooks/post/reload-haproxy.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/post/reload-haproxy.sh
```
### Step 5: Add the custom certificate for the console URL
1. **Navigate to the Certificate Directory**
    ```bash
    cd /etc/letsencrypt/live/apps.ocp4.butterflycluster.com
    ```

2. **Create a Secret Using the Private Key and Certificate Files**
    ```bash
    oc create secret tls console-tls --key=privkey.pem --cert=cert.pem -n openshift-config
    ```
   The above command creates a secret named "console-tls" in the "openshift-config" namespace.

3. **Edit the Console Operator Configuration**
    ```bash
    oc edit consoles.operator.openshift.io cluster
    ```
   In the editor, add the following stanza to the resource configuration:

    ```yaml
    spec:
      route:
        secret:
          name: console-tls
    ```
   Save and exit the editor. The Console Operator updates the console deployment to use the newly specified certificate for the console URL.