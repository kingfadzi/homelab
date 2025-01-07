FROM alpine:latest

# Install necessary tools
RUN apk add --no-cache curl jq

# Install Vault CLI
RUN curl -sL https://releases.hashicorp.com/vault/1.11.2/vault_1.11.2_linux_amd64.zip -o vault.zip && \
    unzip vault.zip && \
    mv vault /usr/local/bin/ && \
    rm vault.zip

# Copy the script that fetches secrets
COPY fetch-secrets.sh /usr/local/bin/fetch-secrets.sh
RUN chmod +x /usr/local/bin/fetch-secrets.sh

ENTRYPOINT ["/usr/local/bin/fetch-secrets.sh"]
