# Base image
FROM alpine:latest

# Define the version of the OpenShift CLI
ENV OC_VERSION=4.6.0

# Install necessary packages
RUN apk add --no-cache curl tar

# Download and install the OpenShift CLI
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_VERSION}/openshift-client-linux-${OC_VERSION}.tar.gz | tar -xz -C /usr/local/bin/ oc

# Check the contents and permissions
RUN ls -l /usr/local/bin/ && chmod +x /usr/local/bin/oc

# Set the working directory
WORKDIR /workspace

# Set the entrypoint to the oc binary
ENTRYPOINT ["/usr/local/bin/oc"]
